import Foundation

/// Content-based article tagging.
///
/// Matches each tag's keyword regex against title and summary, weighs title matches
/// double, and returns the top MAX_TAGS tag keys ranked by distinct keyword matches.
/// Mirrors the compiled-regex + word-boundary pattern of Triggers/Scorer
/// (docker `pipeline/tagger.py`).
enum Tagger {

    static let maxTags = 3
    private static let titleWeight = 2
    private static let summaryWeight = 1

    /// One compiled regex per tag, in `Vocabulary.tagKeywords` taxonomy order
    /// (the order is the tie-break when tags score equally).
    private static let compiledTags: [(tag: String, regex: NSRegularExpression)] =
        Vocabulary.tagKeywords.map { tag, keywords in
            let pattern = keywords
                .map { kw in
                    Vocabulary.tagWordBoundaryRequired.contains(kw)
                        ? #"\b"# + NSRegularExpression.escapedPattern(for: kw) + #"\b"#
                        : NSRegularExpression.escapedPattern(for: kw)
                }
                .joined(separator: "|")
            return (tag: tag, regex: NSRegularExpression.cached(pattern))
        }

    /// Return up to `maxTags` category tags, strongest match first.
    ///
    /// Ties resolve to the earlier tag in the `tagKeywords` taxonomy order.
    /// Articles matching nothing get the fallback tag so every article has at
    /// least one tag.
    static func classifyTags(title: String, summary: String) -> [String] {
        let titleLower = title.lowercased()
        let summaryLower = summary.lowercased()

        var ranked: [(score: Int, order: Int, tag: String)] = []
        for (order, entry) in compiledTags.enumerated() {
            let score = titleWeight * distinctMatches(entry.regex, in: titleLower)
                      + summaryWeight * distinctMatches(entry.regex, in: summaryLower)
            if score > 0 {
                ranked.append((score: -score, order: order, tag: entry.tag))
            }
        }
        if ranked.isEmpty { return [Vocabulary.fallbackTag] }
        ranked.sort {
            $0.score != $1.score ? $0.score < $1.score : $0.order < $1.order
        }
        return ranked.prefix(maxTags).map(\.tag)
    }

    /// Count distinct keywords matched (a keyword repeated twice counts once).
    private static func distinctMatches(_ regex: NSRegularExpression, in text: String) -> Int {
        var matched = Set<String>()
        for m in regex.allMatches(in: text) {
            matched.insert(text.substring(m.range).lowercased())
        }
        return matched.count
    }
}
