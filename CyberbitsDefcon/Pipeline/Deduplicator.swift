import Foundation
import CryptoKit
import NaturalLanguage

/// Two-layer deduplication mirroring docker `pipeline/deduplicator.py`:
///   L1 — SHA-256 fingerprint of normalised title tokens (exact / near-exact).
///   L1b — CVE-ID match within 36h TTL.
///   L2 — semantic checks vs recent titles: shared quoted phrase, threat-actor +
///        shared token, vendor-product pair + shared token, Jaccard ≥ 0.28,
///        TF-IDF cosine ≥ 0.45.
struct Deduplicator {
    let existingFingerprints: Set<String>
    let recentTitles: [String]
    let recentTokens: [Set<String>]?
    let recentCves: Set<String>

    init(existingFingerprints: Set<String>,
         recentTitles: [String],
         recentTokens: [Set<String>]? = nil,
         recentCves: Set<String> = []) {
        self.existingFingerprints = existingFingerprints
        self.recentTitles = recentTitles
        self.recentTokens = recentTokens
        self.recentCves = recentCves
    }

    // MARK: - Thresholds (docker parity)

    static let jaccardThreshold: Double = 0.28
    static let tfidfThreshold: Double = 0.45
    static let minTokenLength: Int = 3

    // MARK: - Vocab

    private static let stopWords: Set<String> = [
        "a","an","the","and","or","but","in","on","at","to","for","of","with",
        "by","from","is","are","was","were","be","been","has","have","had","it",
        "its","as","this","that","these","those","how","what","when","where",
        "who","why","will","can","could","would","should","may","might","do",
        "does","did","not","no","up","out","so","than","into","over","after",
        "new","using","via","says","say","said","report","reports","found",
        "finds","warns","warn","reveals","reveal","shows","show"
    ]

    private static let months: Set<String> = [
        "january","february","march","april","may","june","july","august",
        "september","october","november","december","jan","feb","mar","apr",
        "jun","jul","aug","sep","oct","nov","dec"
    ]

    /// Known vendor→product pairs (docker `VENDOR_PRODUCT_PAIRS`). When both
    /// titles share a pair AND any other meaningful token, treat as duplicate.
    private static let vendorProductPairs: [(vendor: String, product: String)] = [
        ("cisco","sd-wan"), ("cisco","ios"), ("cisco","catalyst"), ("cisco","asa"),
        ("microsoft","exchange"), ("microsoft","sharepoint"),
        ("microsoft","azure"), ("microsoft","outlook"), ("microsoft","teams"),
        ("microsoft","bitlocker"), ("microsoft","defender"),
        ("apple","macos"), ("apple","safari"),
        ("google","chrome"),
        ("fortinet","fortigate"), ("fortinet","fortios"),
        ("fortinet","fortimanager"), ("fortinet","fortisandbox"),
        ("ivanti","epmm"), ("ivanti","connect secure"), ("ivanti","endpoint manager"),
        ("palo alto","pan-os"), ("vmware","esxi"), ("vmware","vcenter"),
        ("vmware","fusion"),
        ("citrix","netscaler"), ("citrix","adc"),
        ("sonicwall","sma"), ("sonicwall","firewall"),
        ("oracle","weblogic"), ("oracle","java"), ("oracle","peoplesoft"), ("oracle","e-business"),
        ("openssh",""), ("openssl",""), ("nginx",""), ("apache","struts"),
        ("wordpress",""), ("drupal",""),
    ]

    // CVE-2024-1234, CVE-2024-12345, CVE 2024 12345 (incl. en/em dashes & spaces).
    // Canonical pattern for the whole app — Scorer and RecentCVEs reuse it.
    static let cvePattern = #"\bCVE[-–— ]?(\d{4})[-–— ]?(\d{3,7})\b"#

    private static let quotedPhrasePattern = #"['""''""]([^'""]{4,})['""''""]"#

    // MARK: - Fingerprint (Layer 1)

    static func fingerprint(_ title: String) -> String {
        let tokens = tokenSet(title).sorted().joined(separator: " ")
        let hash = SHA256.hash(data: Data(tokens.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - CVE extraction

    /// Return canonical CVE IDs (e.g. "CVE-2024-1234") found in text.
    static func extractCVEs(_ text: String) -> Set<String> {
        let ns = text as NSString
        var out = Set<String>()
        for m in NSRegularExpression.cached(cvePattern).matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let year = ns.substring(with: m.range(at: 1))
            let num  = ns.substring(with: m.range(at: 2))
            out.insert("CVE-\(year)-\(num)")
        }
        return out
    }

    // MARK: - L2 detection

    func isDuplicate(_ article: RawArticle) -> Bool {
        let fp = Deduplicator.fingerprint(article.title)
        if existingFingerprints.contains(fp) { return true }

        // L1b — CVE match
        let articleText = "\(article.title) \(article.summary)"
        if !recentCves.isEmpty {
            for cve in Deduplicator.extractCVEs(articleText) {
                if recentCves.contains(cve) { return true }
            }
        }

        let newTokens = Deduplicator.tokenSet(article.title)

        for (i, existing) in recentTitles.enumerated() {
            if Deduplicator.hasTemporalConflict(article.title, existing) { continue }

            // L0a — shared quoted phrase
            if Deduplicator.sharedNamedPhrase(article.title, existing) { return true }

            // L0b — shared threat actor + any other token
            if Deduplicator.sharedActorAndToken(article.title, existing) { return true }

            let existingTokens = recentTokens?[i] ?? Deduplicator.tokenSet(existing)

            // L0c — shared vendor+product pair + any other token
            if let pair = Deduplicator.sharedVendorProduct(article.title, existing) {
                let pairTokens = Set(pair.split(separator: " ").map(String.init))
                let sharedExtra = (newTokens.subtracting(pairTokens))
                    .intersection(existingTokens.subtracting(pairTokens))
                if !sharedExtra.isEmpty { return true }
            }

            // L2-J — Jaccard
            if Deduplicator.jaccard(newTokens, existingTokens) >= Deduplicator.jaccardThreshold {
                return true
            }
        }

        // L2-T — TF-IDF cosine over comparable titles (skip temporal-conflicting)
        let comparableIndices = recentTitles.enumerated().compactMap { (i, t) in
            Deduplicator.hasTemporalConflict(article.title, t) ? nil : i
        }
        if !comparableIndices.isEmpty {
            let comparableTitles = comparableIndices.map { recentTitles[$0] }
            let sims = Deduplicator.tfidfCosineSimilarities(query: article.title, corpus: comparableTitles)
            if (sims.max() ?? 0) >= Deduplicator.tfidfThreshold { return true }
        }

        return false
    }

    // MARK: - Helpers

    static func tokenSet(_ text: String) -> Set<String> {
        // Lowercase, strip punctuation by replacing with spaces, then split on whitespace.
        // Mirrors docker `_token_set` exactly: re.sub(r"[^\w\s]", " ", title).split().
        let lowered = text.lowercased()
        var stripped = ""
        stripped.reserveCapacity(lowered.count)
        for ch in lowered.unicodeScalars {
            if ch == " " || ch == "\t" || ch == "\n" || CharacterSet.alphanumerics.contains(ch) || ch == "_" {
                stripped.unicodeScalars.append(ch)
            } else {
                stripped.append(" ")
            }
        }
        var out = Set<String>()
        for tok in stripped.split(separator: " ", omittingEmptySubsequences: true) {
            let s = String(tok)
            if s.count >= minTokenLength && !stopWords.contains(s) {
                out.insert(s)
            }
        }
        return out
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    static func hasTemporalConflict(_ a: String, _ b: String) -> Bool {
        let la = a.lowercased().split(separator: " ").map(String.init)
        let lb = b.lowercased().split(separator: " ").map(String.init)
        let monthsA = Set(la.filter { months.contains($0) })
        let monthsB = Set(lb.filter { months.contains($0) })
        if !monthsA.isEmpty && !monthsB.isEmpty && monthsA != monthsB { return true }
        let yearPattern = NSRegularExpression.cached(#"\b(20\d{2})\b"#)
        func years(_ s: String) -> Set<String> {
            let r = NSRange(s.startIndex..., in: s)
            return Set(yearPattern.matches(in: s, range: r).compactMap {
                Range($0.range(at: 1), in: s).map { String(s[$0]) }
            })
        }
        let ya = years(a); let yb = years(b)
        if !ya.isEmpty && !yb.isEmpty && ya != yb { return true }
        return false
    }

    private static func sharedNamedPhrase(_ a: String, _ b: String) -> Bool {
        let la = a.lowercased(); let lb = b.lowercased()
        for s in [a, b] {
            let ns = s as NSString
            let matches = NSRegularExpression.cached(quotedPhrasePattern).matches(in: s, range: NSRange(location: 0, length: ns.length))
            for m in matches {
                let phrase = ns.substring(with: m.range(at: 1)).lowercased()
                    .trimmingCharacters(in: .whitespaces)
                if phrase.count >= 4 && la.contains(phrase) && lb.contains(phrase) {
                    return true
                }
            }
        }
        return false
    }

    private static func sharedActorAndToken(_ a: String, _ b: String) -> Bool {
        let la = a.lowercased(); let lb = b.lowercased()
        for actor in Vocabulary.threatActors {
            guard la.contains(actor) && lb.contains(actor) else { continue }
            let actorTokens = Set(actor.split(separator: " ").map(String.init))
            let extra = tokenSet(a).subtracting(actorTokens)
                .intersection(tokenSet(b).subtracting(actorTokens))
            if !extra.isEmpty { return true }
        }
        return false
    }

    private static func sharedVendorProduct(_ a: String, _ b: String) -> String? {
        let la = a.lowercased(); let lb = b.lowercased()
        for (vendor, product) in vendorProductPairs {
            guard la.contains(vendor), lb.contains(vendor) else { continue }
            if !product.isEmpty {
                guard la.contains(product), lb.contains(product) else { continue }
            }
            return product.isEmpty ? vendor : "\(vendor) \(product)"
        }
        return nil
    }

    // MARK: - TF-IDF cosine

    /// Compute cosine similarities between `query` and each `corpus` title.
    /// Builds a fresh TF-IDF vocabulary over (corpus + query). For perf hot paths,
    /// callers should batch and reuse — but we keep this stateless to stay close
    /// to docker's per-query `TfidfVectorizer.fit_transform`.
    static func tfidfCosineSimilarities(query: String, corpus: [String]) -> [Double] {
        let documents = corpus + [query]
        let tokenSets = documents.map { tokenSet($0) }
        let vocabulary = tokenSets.reduce(Set<String>()) { $0.union($1) }
        let n = Double(documents.count)

        var idf: [String: Double] = [:]
        for term in vocabulary {
            let df = Double(tokenSets.filter { $0.contains(term) }.count)
            idf[term] = log((n + 1) / (df + 1)) + 1
        }
        let vocabArray = vocabulary.sorted()

        func vector(_ tokens: Set<String>) -> [Double] {
            vocabArray.map { (tokens.contains($0) ? 1.0 : 0.0) * (idf[$0] ?? 0) }
        }
        func norm(_ v: [Double]) -> Double { sqrt(v.reduce(0) { $0 + $1 * $1 }) }

        let queryVec = vector(tokenSets.last!)
        let queryNorm = norm(queryVec)
        guard queryNorm > 0 else { return Array(repeating: 0, count: corpus.count) }

        return tokenSets.dropLast().map { tokens in
            let docVec = vector(tokens)
            let docNorm = norm(docVec)
            guard docNorm > 0 else { return 0 }
            let dot = zip(queryVec, docVec).reduce(0) { $0 + $1.0 * $1.1 }
            return dot / (queryNorm * docNorm)
        }
    }
}
