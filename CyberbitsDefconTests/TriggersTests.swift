import XCTest
@testable import CyberbitsDefcon

final class TriggersTests: XCTestCase {

    // MARK: - confirmed_breach: repos/packages as scale entities

    func test_confirmedBreach_githubRepos_commaScale() {
        // The article that triggered this fix: GitHub breach of 3,800 repos
        let text = "github confirms breach of 3,800 repos via malicious vscode extension"
        let match = Triggers.detect(text.lowercased())
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.trigger, .confirmedBreach)
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
}
