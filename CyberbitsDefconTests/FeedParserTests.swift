import XCTest
@testable import CyberbitsDefcon

final class FeedParserTests: XCTestCase {

    func test_rss_parsesTitle() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0"><channel>
          <item>
            <title>Zero-day in OpenSSL</title>
            <link>https://hackread.com/zero-day</link>
            <guid>https://hackread.com/zero-day</guid>
            <description>Critical flaw found</description>
            <pubDate>Mon, 01 Jan 2024 12:00:00 +0000</pubDate>
          </item>
        </channel></rss>
        """
        let articles = try await FeedParser.parse(xmlData: Data(xml.utf8), source: .hackread)
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].title, "Zero-day in OpenSSL")
        XCTAssertEqual(articles[0].source, .hackread)
    }

    func test_rss_skipsItemWithNoDate() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0"><channel>
          <item>
            <title>No date article</title>
            <link>https://example.com/1</link>
            <guid>https://example.com/1</guid>
            <description>Summary</description>
          </item>
        </channel></rss>
        """
        let articles = try await FeedParser.parse(xmlData: Data(xml.utf8), source: .hackread)
        XCTAssertEqual(articles.count, 0)
    }

    func test_atom_parsesEntry() async throws {
        let xml = """
        <?xml version="1.0"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <title>Register Security Story</title>
            <link href="https://theregister.com/story"/>
            <id>https://theregister.com/story</id>
            <summary>Story summary</summary>
            <published>2024-01-01T12:00:00Z</published>
          </entry>
        </feed>
        """
        let articles = try await FeedParser.parse(xmlData: Data(xml.utf8), source: .theRegister)
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].title, "Register Security Story")
    }

    func test_json_parsesPost() async throws {
        let json = """
        [{"id":12345,"title":{"rendered":"SA Article"},"excerpt":{"rendered":"<p>Summary text</p>"},
          "link":"https://securityaffairs.com/12345","date_gmt":"2024-01-01T12:00:00","categories":[99]}]
        """.data(using: .utf8)!
        let articles = try await FeedParser.parseSecurityAffairs(jsonData: json)
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].title, "SA Article")
        XCTAssertEqual(articles[0].summary, "Summary text")
        XCTAssertEqual(articles[0].source, .securityAffairs)
    }
}
