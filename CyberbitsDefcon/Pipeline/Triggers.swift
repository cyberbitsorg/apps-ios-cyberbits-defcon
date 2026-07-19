import Foundation

enum TriggerType: String, CaseIterable {
    case activeExploitation      = "active_exploitation"
    case kevAddition             = "kev_addition"
    case ceilingCvss             = "ceiling_cvss"
    case supplyChainCompromise   = "supply_chain_compromise"
    case publicExploit           = "public_exploit"
    case criticalScopeVuln       = "critical_scope_vuln"
    case confirmedBreach         = "confirmed_breach"
    case aptCampaign             = "apt_campaign"
    case malwareCampaign         = "malware_campaign"

    /// Track A base score for this trigger (0–100). Matches docker `TRIGGER_BASE`.
    var baseScore: Double {
        switch self {
        case .activeExploitation:    return 70
        case .kevAddition:           return 70
        case .ceilingCvss:           return 65
        case .supplyChainCompromise: return 65
        case .publicExploit:         return 65
        case .criticalScopeVuln:     return 65
        case .confirmedBreach:       return 65
        case .aptCampaign:           return 60
        case .malwareCampaign:       return 55
        }
    }

    var label: String {
        switch self {
        case .activeExploitation:    return "Active Exploitation"
        case .kevAddition:           return "KEV Addition"
        case .ceilingCvss:           return "Ceiling CVSS"
        case .supplyChainCompromise: return "Supply Chain Compromise"
        case .publicExploit:         return "Public Exploit"
        case .criticalScopeVuln:     return "Critical Scope Vuln"
        case .confirmedBreach:       return "Confirmed Breach"
        case .aptCampaign:           return "APT Campaign"
        case .malwareCampaign:       return "Malware Campaign"
        }
    }
}

struct TriggerMatch {
    let trigger: TriggerType
    let matchedText: String
}

enum Triggers {

    /// Explicit precedence order — matches docker `PRECEDENCE`. Highest-severity first.
    private static let precedence: [TriggerType] = [
        .activeExploitation, .kevAddition, .ceilingCvss, .supplyChainCompromise,
        .publicExploit, .criticalScopeVuln, .confirmedBreach, .aptCampaign, .malwareCampaign,
    ]

    /// Detect the highest-precedence trigger in `text`. Returns nil if none match.
    /// `text` must be pre-lowercased. Contest/bug-bounty contexts (Pwn2Own, CTF,
    /// HackerOne) exclude active_exploitation, kev_addition, ceiling_cvss,
    /// critical_scope_vuln and public_exploit.
    static func detect(_ text: String) -> TriggerMatch? {
        let contest = isContestContext(text)
        for trigger in precedence {
            if contest, trigger == .activeExploitation || trigger == .kevAddition
                || trigger == .ceilingCvss || trigger == .criticalScopeVuln
                || trigger == .publicExploit {
                continue
            }
            if let matched = match(trigger, in: text) {
                return TriggerMatch(trigger: trigger, matchedText: matched)
            }
        }
        return nil
    }

    static func isContestContext(_ text: String) -> Bool {
        regex(contestPattern).firstMatch(in: text) != nil
    }

    static func hasScopeAmplifier(_ text: String) -> Bool {
        regex(scopeAmplifierPattern).firstMatch(in: text) != nil
    }

    static func isNewsletterTitle(_ title: String) -> Bool {
        regex(#"\bnewsletter\b|\bround\s+\d+\b|\bweekly\s+(roundup|recap|digest)\b|\bweek in (review|security)\b"#)
            .firstMatch(in: title) != nil
    }

    // MARK: - Regex cache

    private static var cache: [String: NSRegularExpression] = [:]
    private static let cacheLock = NSLock()

    private static func regex(_ pattern: String) -> NSRegularExpression {
        cacheLock.lock(); defer { cacheLock.unlock() }
        if let r = cache[pattern] { return r }
        // We pre-lowercase texts so caseInsensitive is redundant, but cheap.
        let r = (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]))
            ?? NSRegularExpression()
        cache[pattern] = r
        return r
    }

    // MARK: - Patterns

    private static let activeExploitationPatterns: [String] = [
        #"\bactively exploited\b"#,
        #"\bactive exploitation\b"#,
        #"\bexploited in (the wild|attacks?|the open)\b"#,
        #"\bin[- ]the[- ]wild\b"#,
        #"\bunder (active )?attack\b"#,
        #"\bunder exploitation\b"#,
        #"\b(zero[- ]day|0[- ]day) exploited\b"#,
        #"\bexploits?\s+(cve|known|critical|vuln|flaw|bug|zero[- ]?day)"#,
        #"\bexploited\s+as\s+a?\s*(zero|0)[- ]?day\b"#,
        #"\bweaponized\b"#,
        #"\bactively\s+exploiting\b"#,
        // Bare "exploiting" must reference a vuln-like indicator within ~80 chars to
        // avoid false positives like "exploiting human trust" / "exploiting confusion".
        #"\bexploiting\b[^.\n]{0,80}(cve|flaw|bug|vuln|zero[- ]?day|0[- ]?day|rce|remote code execution|patch|advisory|exploit)"#,
        #"\bcashing in on\s+(?:fresh|new|unpatched|critical)?\s*(?:\w+\s+){0,3}(flaw|bug|vuln|vulnerability|cve)"#,
        #"\bwave of attacks?\b"#,
        #"\bin active use\s+by\b"#,
        #"\bpreying on\b"#,
    ]

    private static let kevPatterns: [String] = [
        #"\bcisa\b.{0,50}\b(kev|known exploited)\b.{0,50}\b(adds?|added)\b"#,
        #"\bcisa\b.{0,50}\b(adds?|added)\b.{0,50}\b(kev|known exploited)\b"#,
        #"\bkev catalog\b"#,
    ]

    private static let breachVerbPattern =
        #"\b(confirms? breach|breached|data breach|data leak|data dump|dump puts|leaked database|claims dump|"# +
        #"exposed (personal information|data of|records of|user data|customer data|credentials|emails|accounts)|"# +
        #"(stolen|stole|theft of|claimed theft of|stealing) .{0,40}(records|users|emails|customers|accounts|tokens|credentials))\b"#

    private static let breachScaleMillionsPattern = #"\bmillions? of\b"#
    private static let breachScaleNumericPattern  = #"\b\d+[kKmM]\+?\s*(users|records|emails|accounts|customers|repos|repositories|packages|codebases?)\b"#
    private static let breachScaleCommaPattern    =
        #"\b\d{1,3}(?:,\d{3})+\s+(users|records|emails|accounts|customers|people|schools|patients|students|employees|individuals|organizations|repos|repositories|packages|codebases?)\b"#

    private static var criticalSectorPattern: String {
        let esc = Vocabulary.criticalSectors.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return #"\b("# + esc + #")\b"#
    }

    private static var threatActorPattern: String {
        let esc = Vocabulary.threatActors.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return #"\b("# + esc + #")\b"#
    }

    private static let aptHintsPattern  = #"\b(apt|nation[- ]state|state[- ]sponsored)\b"#
    private static let aptVerbPattern   = #"\b(campaign|targets|targeting|espionage|breach)\b"#
    private static let aptBreachVerbPattern = #"\b(breach|breached|theft|stole|stolen|leak|leaked|hack|hacked|compromise|compromised|exfiltrat\w+)\b"#

    private static let scopeAmplifierPattern: String = {
        let parts = [
            #"\b(all|most)\s+major\s+(linux|windows|macos|android|ios|distros?|distributions?|systems?|platforms?|versions?|releases?)\b"#,
            #"\bevery\s+(version|release)\b"#,
            #"\bbillions?\s+of\s+(devices|users)\b"#,
            #"\bany\s+(linux|windows|macos|android|ios)\b"#,
        ]
        return parts.joined(separator: "|")
    }()

    private static let negationPattern = #"\b(no|never|not|without|unsuccessful|fails?|failed|prevent(?:ed|s)?|denied|blocked)\b"#

    private static let vulnKeywordPattern = #"\b(zero[- ]?day|0[- ]?day|RCE|remote code execution|privilege escalation|unauthenticated)\b"#

    // public_exploit: release/availability signals — each independently implies a
    // real, public exploit. Matches docker `_PUBLIC_EXPLOIT_RELEASE_PATTERNS`.
    private static let publicExploitReleasePatterns: [String] = [
        #"\bexploit code\b"#,
        #"\bpublic(?:ly available)? exploit\b"#,
        #"\bproof[- ]of[- ]concept\b"#,
        #"\bpoc\s+(?:exploit|code|available|released|published|now public)\b"#,
        #"\b(released?|releases?|publish(?:ed|es)?|drops?|dropped|posts?|posted|leak(?:ed|s)?)\b[^.\n]{0,40}\bexploit\b"#,
        #"\bexploit\b[^.\n]{0,25}\b(released?|published|now public|posted|available online|now available)\b"#,
    ]

    // A release signal alone is generic — require a concrete vulnerability
    // indicator too. Matches docker `_EXPLOIT_VULN_INDICATOR_RE`.
    private static let exploitVulnIndicatorPattern =
        #"\b(0[- ]?day|zero[- ]?day|bypass(?:es|ed)?|rce|remote code execution|flaw|bug|"# +
        #"vulnerabilit(?:y|ies)|cve|privilege escalation|unauthenticated|backdoor)\b"#

    private static let malwareNounPattern = #"\b(stealer|infostealer|info-stealer|loader|dropper|keylogger|rat|malware)\b"#

    private static var knownStealerPattern: String {
        let esc = Vocabulary.knownStealers.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
        return #"\b("# + esc + #")\b"#
    }

    private static let campaignVerbPattern = #"\b(targeting|deploys?|distributes?|spreads?|drops?|delivers?|campaign|infects?|infecting)\b"#

    // ceiling_cvss: explicit CVSS 10.0 / 9.8 / 9.9
    private static let ceilingCvssPattern = #"\bcvss[^\n]{0,20}?(10(?:\.0)?|9\.[89])\b"#

    // supply_chain_compromise: artifact + badness + scale
    private static let supplyChainArtifactPattern =
        #"\b(repos|repositories|packages|codebases?|workflows|ci/cd|registry|"# +
        #"npm|pypi|rubygems|crates\.io|docker images?|container images?|maven|nuget)\b"#
    private static let supplyChainBadnessPattern =
        #"\b(malicious|compromised?|poisoned|backdoor(?:ed)?|typosquat\w*|trojanized|infected|hijacked)\b"#
    private static let supplyChainScalePattern =
        #"\b(\d{1,3}(?:,\d{3})+|\d{2,}|hundreds|thousands|dozens)\b"#

    private static let contestPattern =
        #"\bpwn2own\b|\bcapture[- ]the[- ]flag\b|\bctf\b|\bhack(?:athon|fest|the box)\b|"# +
        #"\bbug bounty\b|\bdef ?con (?:ctf|village|finals?)\b|\bhackone\b|\bhackerone\b|"# +
        #"\bzero day initiative\b|\bzdi\b"#

    // MARK: - Detection

    private static func match(_ trigger: TriggerType, in text: String) -> String? {
        switch trigger {
        case .activeExploitation:
            for pattern in activeExploitationPatterns {
                let matches = regex(pattern).allMatches(in: text)
                for m in matches where !isNegated(text, start: m.range.location, end: m.range.upperBound) {
                    return text.substring(m.range)
                }
            }
            return nil

        case .kevAddition:
            for pattern in kevPatterns {
                if let m = regex(pattern).firstMatch(in: text) {
                    return text.substring(m.range)
                }
            }
            return nil

        case .confirmedBreach:
            guard let verb = regex(breachVerbPattern).firstMatch(in: text) else { return nil }
            let hasScale =
                regex(breachScaleMillionsPattern).firstMatch(in: text) != nil ||
                regex(breachScaleNumericPattern).firstMatch(in: text) != nil ||
                regex(breachScaleCommaPattern).firstMatch(in: text) != nil ||
                regex(criticalSectorPattern).firstMatch(in: text) != nil
            guard hasScale else { return nil }
            return text.substring(verb.range)

        case .aptCampaign:
            let hint = regex(aptHintsPattern).firstMatch(in: text)
                ?? regex(threatActorPattern).firstMatch(in: text)
            guard let hint else { return nil }
            guard regex(aptVerbPattern).firstMatch(in: text) != nil else { return nil }
            let hasTarget =
                regex(criticalSectorPattern).firstMatch(in: text) != nil ||
                regex(aptBreachVerbPattern).firstMatch(in: text) != nil
            guard hasTarget else { return nil }
            return text.substring(hint.range)

        case .criticalScopeVuln:
            guard let vuln = regex(vulnKeywordPattern).firstMatch(in: text) else { return nil }
            guard hasScopeAmplifier(text) else { return nil }
            return text.substring(vuln.range)

        case .ceilingCvss:
            guard let m = regex(ceilingCvssPattern).firstMatch(in: text) else { return nil }
            return text.substring(m.range)

        case .supplyChainCompromise:
            guard let artifact = regex(supplyChainArtifactPattern).firstMatch(in: text) else { return nil }
            guard regex(supplyChainBadnessPattern).firstMatch(in: text) != nil else { return nil }
            guard regex(supplyChainScalePattern).firstMatch(in: text) != nil else { return nil }
            return text.substring(artifact.range)

        case .publicExploit:
            // A release signal alone is generic — require a concrete vuln indicator.
            guard regex(exploitVulnIndicatorPattern).firstMatch(in: text) != nil else { return nil }
            for pattern in publicExploitReleasePatterns {
                for m in regex(pattern).allMatches(in: text) {
                    let span = text.substring(m.range)
                    // Pre-window negation ("no public exploit") — 30 chars before the
                    // match start only (docker `_is_negated(text, m.start())` with no
                    // post-window). Plus intra-span negation ("exploit ... not released").
                    let windowStart = max(0, m.range.location - 30)
                    let preRange = NSRange(location: windowStart, length: m.range.location - windowStart)
                    let preNegated = regex(negationPattern).firstMatch(in: text, options: [], range: preRange) != nil
                    let spanNegated = regex(negationPattern).firstMatch(in: span) != nil
                    if preNegated || spanNegated { continue }
                    return span
                }
            }
            return nil

        case .malwareCampaign:
            let noun = regex(malwareNounPattern).firstMatch(in: text)
                ?? regex(knownStealerPattern).firstMatch(in: text)
            guard let noun else { return nil }
            guard regex(campaignVerbPattern).firstMatch(in: text) != nil else { return nil }
            return text.substring(noun.range)
        }
    }

    private static func isNegated(_ text: String, start: Int, end: Int) -> Bool {
        let windowStart = max(0, start - 30)
        let preNS = NSString(string: text)
        let preRange = NSRange(location: windowStart, length: start - windowStart)
        if regex(negationPattern).firstMatch(in: text, options: [], range: preRange) != nil { return true }
        let windowEnd = min(preNS.length, end + 60)
        let postRange = NSRange(location: end, length: max(0, windowEnd - end))
        if regex(negationPattern).firstMatch(in: text, options: [], range: postRange) != nil { return true }
        return false
    }
}

// MARK: - NSRegularExpression helpers

extension NSRegularExpression {
    func firstMatch(in s: String) -> NSTextCheckingResult? {
        let range = NSRange(location: 0, length: (s as NSString).length)
        return firstMatch(in: s, options: [], range: range)
    }

    func allMatches(in s: String) -> [NSTextCheckingResult] {
        let range = NSRange(location: 0, length: (s as NSString).length)
        return matches(in: s, options: [], range: range)
    }
}

extension String {
    func substring(_ range: NSRange) -> String {
        let ns = self as NSString
        let clamped = NSRange(location: max(0, range.location),
                              length: min(range.length, ns.length - max(0, range.location)))
        guard clamped.length > 0 else { return "" }
        return ns.substring(with: clamped)
    }
}
