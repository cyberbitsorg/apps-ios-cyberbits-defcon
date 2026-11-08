import Foundation

enum Vocabulary {
    static let tier1: [String] = [
        "zero-day", "zero day", "0-day", "0day", "0 day",
        "nation-state", "nation state",
        "state-sponsored", "state sponsored",
        "ransomware attack", "critical infrastructure",
        "infostealer", "stealer campaign", "malware campaign",
        "supply chain attack", "credential stealer",
        "malicious extension", "malicious plugin",
        "malicious package", "malicious dependency",
    ]

    static let tier2: [String] = [
        "ransomware", "backdoor", "back door", "supply chain", "apt", "wiper",
        "botnet", "ddos", "rce", "remote code execution",
        "rootkit", "privilege escalation", "local privilege escalation",
        "root access", "root privileges", "root shell",
        "lateral movement", "vishing", "smishing", "credential stuffing",
        "session hijacking", "account takeover",
        "data exfiltration", "exfiltrate", "exfiltration",
        "hijack", "hijacking",
        "bypass authentication", "authentication bypass", "authorization bypass",
        "stealer", "info-stealer", "credential theft", "credential harvesting",
        "clickfix", "loader", "dropper", "keylogger", "rat",
        "route to root", "compromised", "compromise", "infect", "infecting",
    ]

    static let tier3: [String] = [
        "vulnerability", "exploit", "patch", "breach", "malware",
        "phishing", "cve", "trojan", "spyware",
        "data leak", "threat actor", "unauthorized access", "credential",
        "dump", "database leak", "vendor advisory", "incident response",
        "extortion",
        "campaign", "targeting", "payload",
    ]

    static let threatActors: [String] = [
        "shinyhunters", "lockbit", "cl0p", "qilin", "alphv", "blackcat", "scattered spider",
        "lazarus", "muddywater", "apt28", "apt29", "volt typhoon", "salt typhoon",
        "fancy bear", "cozy bear", "kimsuky",
    ]

    static let criticalSectors: [String] = [
        "power grid", "hospital", "water treatment", "government", "military",
        "critical infrastructure", "airline", "bank", "financial",
        "university", "universities", "college", "colleges", "educational",
        "rail", "railway", "metro", "transit", "subway",
        "school", "schools", "k-12",
        "hospital system", "health system", "healthcare",
        "package registry",
    ]

    static let knownStealers: [String] = [
        "amos", "redline", "lumma", "vidar", "atomic stealer", "shub",
        "metastealer", "stealc", "raccoon",
    ]

    /// Short terms that need word-boundary matching to avoid false positives
    /// ("rce" in "force", "apt" in "capture", "rat" in "rate").
    static let wordBoundaryRequired: Set<String> = ["rce", "apt", "rat", "0-day", "0day", "0 day"]

    // MARK: - Content-based tags (Tagger.swift)

    /// Actor names reused by `tagKeywords` below so tag classification can group by motive.
    /// All entries are subsets of `threatActors` (kept in sync with it).
    static let ransomwareGroups = ["lockbit", "cl0p", "qilin", "alphv", "blackcat"]
    static let aptGroups = [
        "lazarus", "muddywater", "apt28", "apt29", "volt typhoon", "salt typhoon",
        "fancy bear", "cozy bear", "kimsuky",
    ]
    static let breachGroups = ["shinyhunters", "scattered spider"]

    /// Content-based article tags (Tagger.swift). Array order is the tie-break priority
    /// when tags compete for one of the MAX_TAGS slots. Matches docker `TAG_KEYWORDS`.
    static let tagKeywords: [(tag: String, keywords: [String])] = [
        ("attacks", [
            "attack", "phishing", "vishing", "smishing", "ddos", "denial of service",
            "credential stuffing", "brute force", "social engineering", "web shell",
            "hijack", "account takeover", "man-in-the-middle", "mitm", "watering hole",
            "in the wild",
        ]),
        ("vulnerabilities", [
            "vulnerability", "vulnerabilities", "cve", "zero-day", "zero day",
            "0-day", "0day", "0 day", "rce", "remote code execution",
            "privilege escalation", "sql injection", "xss", "cross-site scripting",
            "ssrf", "path traversal", "buffer overflow", "flaw", "security advisory",
            "vendor advisory", "patch", "cvss", "proof-of-concept", "exploit chain",
        ]),
        ("malware", [
            "malware", "infostealer", "stealer", "info-stealer", "backdoor", "back door",
            "trojan", "rat", "keylogger", "rootkit", "botnet", "worm", "loader",
            "dropper", "wiper",
        ] + knownStealers),
        ("ransomware", [
            "ransomware", "leak site", "extortion", "double extortion",
        ] + ransomwareGroups),
        ("breaches", [
            "breach", "data leak", "database leak", "leaked", "expose", "data theft",
            "stolen data", "exfiltration",
        ] + breachGroups),
        ("apt", [
            "apt", "advanced persistent threat", "nation-state", "nation state",
            "state-sponsored", "state sponsored", "espionage", "cyber espionage",
        ] + aptGroups),
        ("fraud", [
            "fraud", "scam", "bec", "business email compromise", "money laundering",
            "counterfeit",
        ]),
        ("privacy", [
            "privacy", "gdpr", "data protection", "surveillance", "spyware", "tracking",
            "personal data", "telemetry", "facial recognition", "location data",
            "cctv", "wiretap", "pegasus",
        ]),
        ("ai", [
            "ai", "artificial intelligence", "llm", "gpt", "chatgpt", "openai",
            "gemini", "copilot", "deepfake", "machine learning", "generative",
            "chatbot", "prompt injection",
        ]),
        ("supply-chain", [
            "supply chain", "supply-chain", "malicious package", "malicious dependency",
            "malicious extension", "malicious plugin", "npm", "pypi", "typosquatting",
            "dependency confusion", "open source", "open-source", "package registry",
        ]),
        ("cloud", [
            "cloud", "aws", "azure", "google cloud", "gcp", "s3 bucket", "kubernetes",
            "docker", "saas", "microsoft 365", "o365", "sharepoint",
        ]),
        ("ics-ot", [
            "ics", "scada", "plc", "ot security", "operational technology",
            "industrial control", "smart grid", "substation", "utility", "utilities",
            "power grid", "water treatment", "critical infrastructure",
        ]),
    ]

    /// Short `tagKeywords` tokens that appear as substrings of unrelated words ("ai" in
    /// "said", "apt" in "capture", "ics" in "physics", "bec" in "because", "aws" in
    /// "lawsuit") plus the numeric zero-day spellings, which must not match "10-day trial".
    static let tagWordBoundaryRequired: Set<String> = [
        "ai", "rat", "apt", "ics", "plc", "llm", "gpt", "bec", "mitm", "rce",
        "cve", "xss", "ssrf", "ddos", "gdpr", "npm", "pypi", "aws", "gcp",
        "saas", "o365",
        "0-day", "0day", "0 day",
    ]

    /// Tag assigned when nothing matches. Deliberately NOT a `tagKeywords` key — it must
    /// never compete in the ranking, only fill in after it.
    static let fallbackTag = "news"

    /// Display labels for content-based article tags (canonical keys come from the
    /// tagger). Unknown keys fall back to the raw key. Matches docker `TAG_LABELS`.
    static let tagDisplayLabels: [String: String] = [
        "attacks":         "Attacks",
        "vulnerabilities": "Vulnerabilities",
        "malware":         "Malware",
        "ransomware":      "Ransomware",
        "breaches":        "Breaches",
        "apt":             "APT",
        "fraud":           "Fraud",
        "privacy":         "Privacy",
        "ai":              "AI",
        "supply-chain":    "Supply Chain",
        "cloud":           "Cloud",
        "ics-ot":          "ICS/OT",
        "news":            "News",
    ]
}
