import XCTest
@testable import CyberbitsDefcon

final class TriggersTests: XCTestCase {

    // MARK: - confirmed_breach: repos/packages as scale entities

    func test_confirmedBreach_githubRepos_commaScale() {
        // Now classified as supply_chain_compromise (same base score 65, more specific label).
        let text = "github confirms breach of 3,800 repos via malicious vscode extension"
        let match = Triggers.detect(text.lowercased())
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.trigger, .supplyChainCompromise)
    }

    func test_confirmedBreach_npmPackages_commaScale() {
        let text = "npm registry data breach exposes source code of 15,000 packages"
        let match = Triggers.detect(text.lowercased())
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.trigger, .confirmedBreach)
    }

    func test_confirmedBreach_packageRegistry_sectorScale() {
        // package registry as critical sector — no numeric scale needed
        let text = "npm package registry confirms breach of developer credentials"
        let match = Triggers.detect(text.lowercased())
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.trigger, .confirmedBreach)
    }

    // MARK: - No false positives

    func test_noFP_repos_withoutBreachVerb() {
        // "shares 3,800 repos" has no breach verb — must not fire confirmed_breach
        let text = "developer shares 3,800 repos on github under open source license"
        let match = Triggers.detect(text.lowercased())
        XCTAssert(match == nil || match?.trigger != .confirmedBreach)
    }

    func test_noFP_packages_withoutBreachVerb() {
        let text = "npm publishes 15,000 packages per day as ecosystem grows"
        let match = Triggers.detect(text.lowercased())
        XCTAssert(match == nil || match?.trigger != .confirmedBreach)
    }

    // MARK: - Vocabulary: supply chain terms in TIER1

    func test_tier1_containsSupplyChainTerms() {
        XCTAssertTrue(Vocabulary.tier1.contains("malicious extension"))
        XCTAssertTrue(Vocabulary.tier1.contains("malicious plugin"))
        XCTAssertTrue(Vocabulary.tier1.contains("malicious package"))
        XCTAssertTrue(Vocabulary.tier1.contains("malicious dependency"))
    }

    func test_criticalSectors_containsPackageRegistry() {
        XCTAssertTrue(Vocabulary.criticalSectors.contains("package registry"))
    }

    // MARK: - ceiling_cvss

    func test_ceilingCvss_10_fires() {
        let m = Triggers.detect("cisco patches cvss 10.0 secure workload rest api flaw".lowercased())
        XCTAssertEqual(m?.trigger, .ceilingCvss)
    }

    func test_ceilingCvss_98_fires() {
        let m = Triggers.detect("fortinet discloses cvss 9.8 fortios bug".lowercased())
        XCTAssertEqual(m?.trigger, .ceilingCvss)
    }

    func test_ceilingCvss_97_doesNotFire() {
        XCTAssertNil(Triggers.detect("cvss 9.7 vulnerability disclosed in vendor product".lowercased()))
    }

    func test_ceilingCvss_yieldsToActiveExploitation() {
        let m = Triggers.detect("cvss 10.0 flaw actively exploited in the wild".lowercased())
        XCTAssertEqual(m?.trigger, .activeExploitation)
    }

    // MARK: - supply_chain_compromise

    func test_supplyChain_5561Repos_maliciousWorkflows() {
        let text = "megalodon github attack targets 5,561 repos with malicious ci/cd workflows"
        let m = Triggers.detect(text.lowercased())
        XCTAssertEqual(m?.trigger, .supplyChainCompromise)
    }

    func test_supplyChain_maliciousNpmPackages() {
        let m = Triggers.detect("threat actors publish 200 malicious npm packages".lowercased())
        XCTAssertEqual(m?.trigger, .supplyChainCompromise)
    }

    func test_supplyChain_requiresScaleOrArtifact() {
        XCTAssertNil(Triggers.detect("vendor warns about a single malicious update".lowercased()))
    }

    func test_supplyChain_yieldsToActiveExploitation() {
        let text = "actively exploited flaw in 5,000 repos with malicious workflows"
        XCTAssertEqual(Triggers.detect(text.lowercased())?.trigger, .activeExploitation)
    }

    // MARK: - public_exploit

    func test_publicExploit_exploitCodeForZeroDay_fires() {
        let text = "microsoft's worst nightmare unleashes bitlocker bypass 0-day, another windows exploit code"
        XCTAssertEqual(Triggers.detect(text.lowercased())?.trigger, .publicExploit)
    }

    func test_publicExploit_publishedExploitForBypass_fires() {
        let text = "security researcher has released a new windows bitlocker bypass dubbed greatxml, a day after they published an exploit for microsoft defender"
        XCTAssertEqual(Triggers.detect(text.lowercased())?.trigger, .publicExploit)
    }

    func test_publicExploit_proofOfConcept_fires() {
        let text = "researcher drops proof-of-concept exploit for unpatched fortinet rce flaw"
        XCTAssertEqual(Triggers.detect(text.lowercased())?.trigger, .publicExploit)
    }

    func test_publicExploit_yieldsToActiveExploitation() {
        let text = "exploit code released for zero-day now actively exploited in the wild"
        XCTAssertEqual(Triggers.detect(text.lowercased())?.trigger, .activeExploitation)
    }

    func test_publicExploit_negatedNoPublicExploit_doesNotFire() {
        let text = "critical flaw disclosed but no public exploit is available yet"
        let m = Triggers.detect(text.lowercased())
        XCTAssert(m == nil || m?.trigger != .publicExploit)
    }

    func test_publicExploit_couldBeExploitedNoReleaseSignal_doesNotFire() {
        let text = "vendor warns the bug could be exploited by attackers in the future"
        let m = Triggers.detect(text.lowercased())
        XCTAssert(m == nil || m?.trigger != .publicExploit)
    }

    func test_publicExploit_contestExcluded() {
        let text = "researcher released exploit code for windows zero-day at pwn2own berlin"
        let m = Triggers.detect(text.lowercased())
        XCTAssert(m == nil || m?.trigger != .publicExploit)
    }

    // MARK: - Vocabulary: numeric zero-day spellings

    func test_tier1_containsNumericZeroDaySpellings() {
        XCTAssertTrue(Vocabulary.tier1.contains("0-day"))
        XCTAssertTrue(Vocabulary.tier1.contains("0day"))
        XCTAssertTrue(Vocabulary.tier1.contains("0 day"))
    }

    func test_wordBoundaryRequired_containsNumericZeroDaySpellings() {
        XCTAssertTrue(Vocabulary.wordBoundaryRequired.contains("0-day"))
        XCTAssertTrue(Vocabulary.wordBoundaryRequired.contains("0day"))
        XCTAssertTrue(Vocabulary.wordBoundaryRequired.contains("0 day"))
    }
}
