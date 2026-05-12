import Foundation

enum Scorer {

    static func computeArticleScore(title: String, summary: String) -> Double {
        let text = "\(title) \(summary)".lowercased()
        return computeGlobalScore(texts: [text], newCount: 1).total
    }

    static func computeGlobalScore(texts rawTexts: [String], newCount: Int) -> DefconFactors {
        let texts = rawTexts.map { $0.lowercased() }
        let n = texts.count
        guard n > 0 else { return DefconFactors(volumeScore: 0, cveScore: 0, impactScore: 0, keywordScore: 0) }

        // Dimension 1 — Volume
        let volumeScore = min(Double(newCount) / 12.0, 1.0) * 25

        // Dimension 2 — CVE Severity
        var cvssScores: [Double] = []
        let cvssRe = try? NSRegularExpression(pattern: #"cvss[\s:v]*(\d+\.?\d*)"#, options: .caseInsensitive)
        let severityFallback: [(String, Double)] = [("critical", 9.0), ("high", 7.0), ("medium", 5.0), ("low", 2.5)]
        for text in texts {
            let range = NSRange(text.startIndex..., in: text)
            if let matches = cvssRe?.matches(in: text, range: range), !matches.isEmpty {
                for match in matches {
                    if let r = Range(match.range(at: 1), in: text), let v = Double(text[r]), v >= 0, v <= 10 {
                        cvssScores.append(v)
                    }
                }
            } else {
                for (word, score) in severityFallback {
                    if text.contains(word) { cvssScores.append(score); break }
                }
            }
        }
        let cveScore = cvssScores.isEmpty ? 0 :
            (cvssScores.reduce(0, +) / Double(cvssScores.count) / 10.0) * 25

        // Dimension 3 — Impact
        var impactRaw = 0.0
        for text in texts {
            if text.range(of: #"\d+\s*million"#, options: .regularExpression) != nil { impactRaw += 8 }
            if text.range(of: "power grid|hospital|water treatment|government|military|critical infrastructure",
                          options: .regularExpression) != nil { impactRaw += 7 }
            if text.contains("actively exploit") { impactRaw += 6 }
            if let m = text.range(of: #"(\d+)\s*countries"#, options: .regularExpression) {
                let numStr = String(text[m]).components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let num = Int(numStr), num > 5 { impactRaw += 6 }
            }
            if text.range(of: "data breach|leaked|exposed", options: .regularExpression) != nil { impactRaw += 4 }
            if text.range(of: #"\d{6,}\s*(users|records|devices|systems)"#, options: .regularExpression) != nil { impactRaw += 5 }
        }
        let impactScore = min(impactRaw / (Double(n) * 3), 1.0) * 25

        // Dimension 4 — Keywords
        let tier1 = ["zero-day", "zero day", "nation-state", "state-sponsored", "ransomware attack", "critical infrastructure"]
        let tier2 = ["ransomware", "backdoor", "supply chain", "apt", "wiper", "botnet", "ddos", "rce", "remote code execution"]
        let tier3 = ["vulnerability", "exploit", "patch", "breach", "malware", "phishing", "cve", "zero-day", "trojan", "spyware"]
        var keywordRaw = 0.0
        for text in texts {
            for kw in tier1 where text.contains(kw) { keywordRaw += 5 }
            for kw in tier2 where text.contains(kw) { keywordRaw += 3 }
            for kw in tier3 where text.contains(kw) { keywordRaw += 1 }
        }
        let keywordScore = min(keywordRaw / (Double(n) * 8), 1.0) * 25

        return DefconFactors(volumeScore: round(volumeScore * 100) / 100,
                             cveScore: round(cveScore * 100) / 100,
                             impactScore: round(impactScore * 100) / 100,
                             keywordScore: round(keywordScore * 100) / 100)
    }
}
