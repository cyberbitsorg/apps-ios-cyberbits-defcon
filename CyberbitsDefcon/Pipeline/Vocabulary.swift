import Foundation

enum Vocabulary {
    static let tier1: [String] = [
        "zero-day", "zero day", "nation-state", "nation state",
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
    static let wordBoundaryRequired: Set<String> = ["rce", "apt", "rat"]
}
