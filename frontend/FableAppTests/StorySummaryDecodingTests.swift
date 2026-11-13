import SwiftData
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
        XCTAssertNil(story.ownerUserId)
    }

    func testStoryDecodingCapturesOwnerUserId() throws {
        let ownerId = UUID()
        let payload = Data(
            """
            {
              "id": "5A04D708-498F-4D8C-9B6B-30F0FBB38C44",
              "title": "Author Original",
              "author": "Jane Pen",
              "genre": "Drama",
              "synopsis": "Owned manuscript.",
              "readTimeMinutes": 4,
              "ownerUserId": "\(ownerId.uuidString)",
              "createdAtUtc": "2026-01-01T00:00:00Z"
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let story = try decoder.decode(Story.self, from: payload)
        XCTAssertEqual(story.ownerUserId, ownerId)
    }

    @MainActor
    func testCatalogWriterStoriesExcludeUserOwnedStories() {
        let store = StoryStore()
        let catalogStory = Story(
            id: UUID(),
            title: "Pride and Prejudice",
            author: "Jane Austen",
            genre: Genre(rawValue: "Classics"),
            synopsis: "Public domain classic",
            content: "It is a truth universally acknowledged.",
            readTimeMinutes: 10,
            sourceProvider: .gutenberg,
            providerId: "1342",
            ownerUserId: nil
        )
        let spoofedUserStory = Story(
            id: UUID(),
            title: "Unauthorized Fanfic",
            author: "Jane Austen",
            genre: Genre(rawValue: "Romance"),
            synopsis: "User-owned",
            content: "Should not appear on catalog writer page.",
            readTimeMinutes: 3,
            sourceProvider: .fableOriginal,
            ownerUserId: UUID()
        )
        store.stories = [catalogStory, spoofedUserStory]

        let writer = Writer(name: "Jane Austen", avatarImageName: "person.circle", storyCount: 1)
        let matched = store.stories(for: writer)

        XCTAssertEqual(matched.map(\.id), [catalogStory.id])
    }

    @MainActor
    func testPersistenceResilientContainerRecoversFromCorruptStoreAndSupportsInMemoryFallback() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let corruptURL = tempDir.appendingPathComponent("corrupt.store")
        try Data("not a valid sqlite database".utf8).write(to: corruptURL)

        let recovered = PersistenceService.makeResilientContainer(
            schema: PersistenceService.defaultSchema,
            storeURL: corruptURL
        )
        XCTAssertTrue(recovered.didRecoverByReset)
        XCTAssertFalse(recovered.isInMemoryFallback)

        let fallbackURL = tempDir.appendingPathComponent("fallback.store")
        var persistentAttempts = 0
        let fallback = PersistenceService.makeResilientContainer(
            schema: PersistenceService.defaultSchema,
            storeURL: fallbackURL
        ) { schema, configuration in
            if !configuration.isStoredInMemoryOnly {
                persistentAttempts += 1
                throw NSError(domain: "PersistenceTest", code: 1)
            }
            return try ModelContainer(for: schema, configurations: [configuration])
        }
        XCTAssertEqual(persistentAttempts, 2)
        XCTAssertTrue(fallback.didRecoverByReset)
        XCTAssertTrue(fallback.isInMemoryFallback)
    }

    @MainActor
    func testPersistenceMigratesLegacyShelfUserDefaultsAndCleansUpOnAccountDeletion() throws {
        let service = PersistenceService(isStoredInMemoryOnly: true)
        let suiteName = "fable.test.shelf.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let userId = UUID()
        let otherUserId = UUID()
        let ownerKey = userId.uuidString.lowercased()
        let otherKey = otherUserId.uuidString.lowercased()
        let legacyKey = "fable_shelf_state_\(userId.uuidString)"
        let bookId = UUID()
        let legacyRecord = PersistenceService.ShelfStateRecord(
            storyId: bookId,
            readingProgress: 0.75,
            isBookmarked: true,
            isCompleted: false,
            currentPage: 12,
            totalPages: 16,
            lastReadChapterId: "ch-2",
            lastReadChapterNumber: 2,
            updatedAtUtc: Date()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode([bookId.uuidString: legacyRecord]), forKey: legacyKey)

        let migrated = service.migrateLegacyShelfStatesIfNeeded(
            ownerKey: ownerKey,
            legacyStorageKey: legacyKey,
            defaults: defaults
        )
        XCTAssertNil(defaults.data(forKey: legacyKey))
        XCTAssertEqual(migrated[bookId]?.isBookmarked, true)
        XCTAssertEqual(migrated[bookId]?.lastReadChapterNumber, 2)
        XCTAssertEqual(service.fetchShelfStates(ownerKey: ownerKey)[bookId]?.currentPage, 12)

        service.upsertShelfState(legacyRecord, ownerKey: otherKey)
        service.saveStory(
            Story(
                id: UUID(),
                title: "Owned Draft",
                author: "Owner",
                genre: Genre(rawValue: "Mystery"),
                synopsis: "Owned story",
                content: "Secret text",
                readTimeMinutes: 2,
                ownerUserId: userId
            )
        )
        service.logReadingSession(
            storyId: bookId,
            storyTitle: "Book",
            seconds: 30,
            ownerUserId: userId,
            isCompleted: true
        )

        service.deleteAccountData(ownerUserId: userId)

        XCTAssertTrue(service.fetchShelfStates(ownerKey: ownerKey).isEmpty)
        XCTAssertEqual(service.fetchReadingStats(ownerUserId: userId).storiesReadCount, 0)
        XCTAssertTrue(service.fetchAllStories().filter { $0.ownerUserId == userId }.isEmpty)
        XCTAssertEqual(service.fetchShelfStates(ownerKey: otherKey)[bookId]?.isBookmarked, true)
    }

    func testUpdateStoryRequestEncodesFieldsForBackendContract() throws {
        let request = UpdateStoryRequest(
            title: "Revised Title",
            synopsis: "Updated synopsis",
            readTimeMinutes: 7
        )
        let data = try JSONEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["title"] as? String, "Revised Title")
        XCTAssertEqual(json["synopsis"] as? String, "Updated synopsis")
        XCTAssertEqual(json["readTimeMinutes"] as? Int, 7)
    }

    func testDraftValidationAndReadTimeEstimation() {
        XCTAssertNotNil(
            CreateStoryRequest.validateDraftFields(
                title: "",
                genre: "Drama",
                chapter: "",
                synopsis: "Summary",
                content: "Body",
                requireContent: true
            )
        )
        XCTAssertNil(
            CreateStoryRequest.validateDraftFields(
                title: "A Tale",
                genre: "Folklore",
                chapter: "Chapter 1",
                synopsis: "A short synopsis.",
                content: "",
                requireContent: false
            )
        )
        XCTAssertEqual(CreateStoryRequest.estimatedReadTimeMinutes(for: "word " + String(repeating: "story ", count: 300)), 2)
    }
}
