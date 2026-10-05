import XCTest
@testable import FableApp

final class StorySummaryDecodingTests: XCTestCase {
    func testCatalogSummaryCanOmitManuscriptContent() throws {
        let payload = Data(
            """
            {
              "id": "4A04D708-498F-4D8C-9B6B-30F0FBB38C43",
              "title": "Catalog Entry",
              "author": "Fable Author",
              "genre": "Folklore",
              "synopsis": "A short catalog synopsis.",
              "readTimeMinutes": 1,
              "createdAtUtc": "2026-01-01T00:00:00Z"
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let story = try decoder.decode(Story.self, from: payload)

        XCTAssertEqual(story.title, "Catalog Entry")
        XCTAssertEqual(story.content, "")
    }
}
