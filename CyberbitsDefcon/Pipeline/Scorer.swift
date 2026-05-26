import Foundation

/// Result of scoring a single article (v2).
struct ArticleScoreResult {
    let score: Double           // final per-article score (0–100)
    let trigger: TriggerType?   // matched Track A trigger (nil if Track B alone)
    let trackA: Double          // Track A score (0 if no trigger)
    let trackB: Double          // Track B final (capped at 80)
    let cve: Double             // Track B sub-score
    let impact: Double          // Track B sub-score
    let keywords: Double        // Track B sub-score
}

/// Result of computing the global DEFCON score (v2).
struct GlobalScoreResult {
    let score: Double           // 0–100
    let weightedMax: Double     // best article * (1 - age/windowHours)
    let volumeBonus: Double     // 0–10
    let trigger: TriggerType?
    let triggerArticleTitle: String?
    let triggerArticlePublishedAt: Date?
}

enum Scorer {

    // MARK: - Per-article (v2)

    static func computeArticleScore(title: String, summary: String) -> ArticleScoreResult {
        let text = "\(title) \(summary)".lowercased()
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ArticleScoreResult(score: 0, trigger: nil, trackA: 0, trackB: 0,
                                      cve: 0, impact: 0, keywords: 0)
        }

        let (cve, impact, keywords) = trackBUnclamped(text)

        // Title keyword bonus — boosts headline emphasis on top of body.
        let titleRaw = keywordRaw(title.lowercased())
        let titleBoost = min(Double(titleRaw) / 8.0, 1.0) * 20.0

        let trackBUnc = cve + impact + keywords + titleBoost
        var trackB = min(trackBUnc, 80.0)

        let isNewsletter = Triggers.isNewsletterTitle(title)
        if isNewsletter {
            // Recaps bundle many unrelated threats; keyword density inflates Track B
            // even though no single item carries a dense article's severity.
            trackB *= 0.5
        }

        var trigger = Triggers.detect(text)
        if trigger != nil, isNewsletter {
            trigger = nil
        }

        if let trigger {
            let base = trigger.trigger.baseScore
            let bonus = min(trackBUnc, 10.0)
            let trackA = min(base + bonus, 100.0)
            let final = max(trackA, trackB)
            return ArticleScoreResult(
                score: round(final * 100) / 100,
                trigger: trigger.trigger,
                trackA: round(trackA * 100) / 100,
                trackB: round(trackB * 100) / 100,
                cve: round(cve * 100) / 100,
                impact: round(impact * 100) / 100,
                keywords: round(keywords * 100) / 100
            )
        }

        return ArticleScoreResult(
            score: round(trackB * 100) / 100,
            trigger: nil,
            trackA: 0,
            trackB: round(trackB * 100) / 100,
            cve: round(cve * 100) / 100,
            impact: round(impact * 100) / 100,
            keywords: round(keywords * 100) / 100
        )
    }

    // MARK: - Global (v2)

    /// Each tuple represents an article in the 24h scoring window.
    struct WindowArticle {
        let title: String
        let score: Double
        let trigger: TriggerType?
        let publishedAt: Date
    }

    private static let windowHoursWeekday: Double = 48
    private static let windowHoursWeekend: Double = 72
    private static let volumeBonusCap: Double = 10

    /// Returns the active decay window in hours, based on the UTC day of `now`.
    /// Weekends (Sat/Sun UTC) use a 72h window; weekdays use 48h.
    static func currentWindowHours(now: Date = Date()) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let weekday = cal.component(.weekday, from: now)
        // Cocoa: 1=Sunday, 7=Saturday
        return (weekday == 1 || weekday == 7) ? windowHoursWeekend : windowHoursWeekday
    }

    static func computeGlobalScore(
        window: [WindowArticle],
        newCount: Int,
        baseline: Double?,
        now: Date = Date(),
        windowHours: Double? = nil
    ) -> GlobalScoreResult {
        let activeWindow = windowHours ?? currentWindowHours(now: now)
        var weightedMax: Double = 0
        var winner: WindowArticle?
        for art in window {
            let ageHours = now.timeIntervalSince(art.publishedAt) / 3600
            let weight = max(0, 1.0 - ageHours / activeWindow)
            let contribution = art.score * weight
            if contribution > weightedMax {
                weightedMax = contribution
                winner = art
            }
        }

        let volumeBonus: Double
        if let baseline, baseline > 0 {
            let ratio = Double(newCount) / baseline
            volumeBonus = max(0, min((ratio - 1) * 10, volumeBonusCap))
        } else {
            volumeBonus = 0
        }

        let total = min(weightedMax + volumeBonus, 100)
        return GlobalScoreResult(
            score: round(total * 100) / 100,
            weightedMax: round(weightedMax * 100) / 100,
            volumeBonus: round(volumeBonus * 100) / 100,
            trigger: winner?.trigger,
            triggerArticleTitle: winner?.title,
            triggerArticlePublishedAt: winner?.publishedAt
        )
    }

    /// Convert a 0–100 score to an official DEFCON level (1=highest threat, 5=lowest).
    static func levelFromScore(_ score: Double) -> Int {
        if score >= 80 { return 1 }
        if score >= 60 { return 2 }
        if score >= 40 { return 3 }
        if score >= 20 { return 4 }
        return 5
    }

    // MARK: - Track B sub-scores

    private static func trackBUnclamped(_ text: String) -> (cve: Double, impact: Double, keywords: Double) {
        let cveRaw = extractCVSS(text)
        let cveScore = (cveRaw / 10.0) * 30.0
        let impactScore = extractImpactScore(text)
        let keywordScore = extractKeywordScoreNormalized(text)
        return (cveScore, impactScore, keywordScore)
    }

    private static let cveIdPattern = #"\bCVE[-–— ]?\d{4}[-–— ]?\d{3,}\b"#
    private static let severityWords: [(String, Double)] =
        [("critical", 9.0), ("high", 7.0), ("medium", 5.0), ("low", 2.5)]

    private static func extractCVSS(_ text: String) -> Double {
        // 1) Explicit CVSS scores within 50-char window
        var scores: [Double] = []
        let cvssWindow = NSRegularExpression.cached(#"cvss[^\n]{0,50}"#)
        for m in cvssWindow.allMatches(in: text) {
            let window = text.substring(m.range)
            let numRe = NSRegularExpression.cached(#"(?<![.\w])(\d+\.?\d*)(?!\w)"#)
            for nm in numRe.allMatches(in: window) {
                if let val = Double(window.substring(nm.range)), val >= 0, val <= 10 {
                    scores.append(val)
                }
            }
        }
        if let best = scores.max() { return best }

        // "max severity" / "maximum severity" — vendor-press shorthand for CVSS ~10.
        if NSRegularExpression.cached(#"\bmax(?:imum)?\s+severity\b"#).firstMatch(in: text) != nil {
            return 9.0
        }

        // 2) CVE id + severity word co-occurrence
        if NSRegularExpression.cached(cveIdPattern).firstMatch(in: text) != nil {
            let matched = severityWords
                .filter { NSRegularExpression.cached(#"\b\#($0.0)\b"#).firstMatch(in: text) != nil }
                .map { $0.1 }
            if let best = matched.max() { return best }
        }

        // 3) Prose-described vulnerabilities with strong scope/qualifier
        let scope = Triggers.hasScopeAmplifier(text)
        if NSRegularExpression.cached(#"\bzero[- ]?day\b"#).firstMatch(in: text) != nil, scope { return 8.0 }
        if NSRegularExpression.cached(#"\b(remote code execution|RCE)\b"#).firstMatch(in: text) != nil {
            let unauth = NSRegularExpression.cached(#"\bunauthenticated\b"#).firstMatch(in: text) != nil
            if unauth || scope { return 8.0 }
        }
        if NSRegularExpression.cached(#"\b(root|kernel)\b"#).firstMatch(in: text) != nil, scope { return 7.5 }

        return 0
    }

    private static let impactCap: Double = 12

    private static func extractImpactScore(_ text: String) -> Double {
        var raw = 0.0
        if NSRegularExpression.cached(#"power grid|hospital|water treatment|government|military|critical infrastructure"#)
            .firstMatch(in: text) != nil { raw += 5 }
        if NSRegularExpression.cached(#"(?:\d[\d,.]*\s*)?millions?\b"#).firstMatch(in: text) != nil { raw += 4 }
        if let m = NSRegularExpression.cached(#"(\d+)\s*countries"#).firstMatch(in: text) {
            let numRange = m.range(at: 1)
            if numRange.location != NSNotFound, let n = Int(text.substring(numRange)), n > 5 { raw += 4 }
        }
        if NSRegularExpression.cached(#"data breach|breached|breaches|\bbreach\b|leaked|exposed|exposing"#)
            .firstMatch(in: text) != nil { raw += 3 }
        if NSRegularExpression.cached(#"(?:\d{6,}|\d{3,}[kK])\s*(users|records|devices|systems)"#)
            .firstMatch(in: text) != nil { raw += 3 }
        if NSRegularExpression.cached(#"hundreds of\s+(colleges?|universities|schools|organizations|companies|agencies)"#)
            .firstMatch(in: text) != nil { raw += 3 }
        if NSRegularExpression.cached(#"\b(all|most)\s+(major|popular|common)\s+(linux|windows|macos|android|ios|mobile\s+)?(distributions?|versions?|systems?|platforms?|devices?|distros?)\b"#)
            .firstMatch(in: text) != nil { raw += 3 }
        if NSRegularExpression.cached(#"\bbillions?\s+of\s+(devices|users)\b"#).firstMatch(in: text) != nil { raw += 5 }
        if NSRegularExpression.cached(#"\bevery\s+(version|release)\b"#).firstMatch(in: text) != nil { raw += 4 }
        if NSRegularExpression.cached(#"\bany\s+(linux|windows|macos|android|ios)\s+(system|device|user)\b"#)
            .firstMatch(in: text) != nil { raw += 4 }
        return min(raw / impactCap, 1.0) * 25.0
    }

    private static func keywordRaw(_ text: String) -> Int {
        var raw = 0
        let tiers: [([String], Int)] = [(Vocabulary.tier1, 8), (Vocabulary.tier2, 4), (Vocabulary.tier3, 1)]
        for (tier, pts) in tiers {
            for kw in tier {
                if Vocabulary.wordBoundaryRequired.contains(kw) {
                    let pattern = #"\b\#(NSRegularExpression.escapedPattern(for: kw))\b"#
                    if NSRegularExpression.cached(pattern).firstMatch(in: text) != nil { raw += pts }
                } else {
                    if text.contains(kw) { raw += pts }
                }
            }
        }
        return raw
    }

    private static let densityCap: Double = 2.0

    private static func extractKeywordScoreNormalized(_ text: String) -> Double {
        let raw = keywordRaw(text)
        if raw == 0 { return 0 }
        let tokenCount = max(1, text.split(separator: " ").count)
        let denom = max(1.0, log2(Double(tokenCount) + 1))
        let density = Double(raw) / denom
        return min(density / densityCap, 1.0) * 25.0
    }
}

// MARK: - Regex cache helper

private extension NSRegularExpression {
    private static var staticCache: [String: NSRegularExpression] = [:]
    private static let staticLock = NSLock()

    static func cached(_ pattern: String) -> NSRegularExpression {
        staticLock.lock(); defer { staticLock.unlock() }
        if let r = staticCache[pattern] { return r }
        let r = (try? NSRegularExpression(pattern: pattern,
                                          options: [.caseInsensitive, .dotMatchesLineSeparators]))
            ?? NSRegularExpression()
        staticCache[pattern] = r
        return r
    }
}
