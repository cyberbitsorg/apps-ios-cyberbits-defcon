import Foundation
import CryptoKit
import NaturalLanguage

struct Deduplicator {
    let existingFingerprints: Set<String>
    let recentTitles: [String]

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

    static func fingerprint(_ title: String) -> String {
        let tokens = tokenSet(title).sorted().joined(separator: " ")
        let hash = SHA256.hash(data: Data(tokens.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    func isDuplicate(_ article: RawArticle) -> Bool {
        let fp = Deduplicator.fingerprint(article.title)
        if existingFingerprints.contains(fp) { return true }

        let newTokens = Deduplicator.tokenSet(article.title)

        for existing in recentTitles {
            guard !Deduplicator.hasTemporalConflict(article.title, existing) else { continue }
            let existingTokens = Deduplicator.tokenSet(existing)
            if Deduplicator.jaccard(newTokens, existingTokens) >= 0.35 { return true }
        }

        let comparable = recentTitles.filter { !Deduplicator.hasTemporalConflict(article.title, $0) }
        if !comparable.isEmpty {
            let sims = Deduplicator.tfidfCosineSimilarities(query: article.title, corpus: comparable)
            if sims.max() ?? 0 >= 0.55 { return true }
        }

        return false
    }

    static func tokenSet(_ text: String) -> Set<String> {
        let tokenizer = NLTokenizer(unit: .word)
        let lowercased = text.lowercased()
        tokenizer.string = lowercased
        var tokens = Set<String>()
        tokenizer.enumerateTokens(in: lowercased.startIndex..<lowercased.endIndex) { range, _ in
            let token = String(lowercased[range])
            if token.count >= 3 && !stopWords.contains(token) { tokens.insert(token) }
            return true
        }
        return tokens
    }

    private static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    private static func hasTemporalConflict(_ a: String, _ b: String) -> Bool {
        let la = a.lowercased().split(separator: " ").map(String.init)
        let lb = b.lowercased().split(separator: " ").map(String.init)
        let monthsA = Set(la.filter { months.contains($0) })
        let monthsB = Set(lb.filter { months.contains($0) })
        if !monthsA.isEmpty && !monthsB.isEmpty && monthsA != monthsB { return true }
        let yearPattern = try? NSRegularExpression(pattern: #"\b(20\d{2})\b"#)
        func years(_ s: String) -> Set<String> {
            let r = NSRange(s.startIndex..., in: s)
            return Set(yearPattern?.matches(in: s, range: r).compactMap {
                Range($0.range(at: 1), in: s).map { String(s[$0]) }
            } ?? [])
        }
        let ya = years(a); let yb = years(b)
        if !ya.isEmpty && !yb.isEmpty && ya != yb { return true }
        return false
    }

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
            vocabArray.map { term in
                (tokens.contains(term) ? 1.0 : 0.0) * (idf[term] ?? 0)
            }
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
