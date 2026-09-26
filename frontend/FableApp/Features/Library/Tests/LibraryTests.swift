import Foundation

@MainActor
public struct LibraryTests {
    public static func runAllTests() -> (passed: Int, total: Int, failures: [String]) {
        var passed = 0
        var total = 0
        var failures: [String] = []

        func assert(_ condition: Bool, _ testName: String) {
            total += 1
            if condition {
                passed += 1
            } else {
                failures.append(testName)
            }
        }

        let store = StoryStore()

        // Test 1: Cached provider records require stable provider identity.
        assert(store.stories.allSatisfy {
            $0.sourceProvider == .fableOriginal || $0.providerId?.isEmpty == false
        }, "Cached Provider Stories Have Provider IDs")

        let actionStory = Story(
            title: "Diagnostic Fixture",
            author: "Diagnostic",
            genre: .folklore,
            synopsis: "",
            content: "",
            readTimeMinutes: 4
        )
        store.stories.append(actionStory)

        // Test 2: Bookmark toggling
        store.toggleBookmark(for: actionStory)
        let bookmarked = store.stories.first(where: { $0.id == actionStory.id })?.isBookmarked ?? false
        assert(bookmarked, "Toggle Bookmark State")
        store.toggleBookmark(for: actionStory)

        // Test 3: Reading progress mutation
        store.updateProgress(for: actionStory.id, page: 3, totalPages: 4)
        let updated = store.stories.first(where: { $0.id == actionStory.id })
        assert(updated?.progressPercent == 75 && updated?.currentPage == 3, "Update Reading Progress")

        // Test 4: Legacy JSON Fallback Decoding (Defaults to .prose and .fableOriginal)
        let legacyJSON = """
        {
            "id": "A0000000-0000-0000-0000-000000000001",
            "title": "Legacy Classic",
            "author": "Anonymous"
        }
        """.data(using: .utf8)!

        if let legacyStory = try? JSONDecoder().decode(Story.self, from: legacyJSON) {
            assert(legacyStory.contentFormat == .prose, "Legacy Story ContentFormat Defaults to Prose")
            assert(legacyStory.sourceProvider == .fableOriginal, "Legacy Story SourceProvider Defaults to FableOriginal")
            assert(legacyStory.lastReadChapterId == nil && legacyStory.lastReadChapterNumber == nil, "Legacy Story Chapter Progress Defaults to Empty")
        } else {
            assert(false, "Legacy Story JSON Decoding Failed")
        }

        // Test 5: Granular Chapter Progress Decoding
        let chapterProgressJSON = """
        {
            "id": "A0000000-0000-0000-0000-000000000005",
            "title": "Saved Chapter",
            "author": "Anonymous",
            "lastReadChapterId": "C0000000-0000-0000-0000-000000000005",
            "lastReadChapterNumber": 5
        }
        """.data(using: .utf8)!

        if let progressedStory = try? JSONDecoder().decode(Story.self, from: chapterProgressJSON) {
            assert(progressedStory.lastReadChapterId == "C0000000-0000-0000-0000-000000000005", "Story Decodes Saved Chapter ID")
            assert(progressedStory.lastReadChapterNumber == 5, "Story Decodes Saved Chapter Number")
        } else {
            assert(false, "Chapter Progress JSON Decoding Failed")
        }

        let liveProviderJSON = """
        {
            "id": "00000000-0000-0000-0000-00000000053E",
            "title": "Pride and Prejudice",
            "author": "Jane Austen",
            "sourceProvider": "GUTENBERG",
            "providerId": "1342"
        }
        """.data(using: .utf8)!

        if let liveBook = try? JSONDecoder().decode(Story.self, from: liveProviderJSON) {
            assert(liveBook.sourceProvider == .gutenberg, "Live Book Decodes Gutenberg Source")
            assert(liveBook.providerId == "1342", "Live Book Decodes Provider ID")
        } else {
            assert(false, "Live Provider Story JSON Decoding Failed")
        }

        let liveStatsJSON = """
        {
            "id": "00000000-0000-0000-0000-000000000053",
            "title": "Live Statistics",
            "author": "Source Author",
            "rating": null,
            "savesCount": "3",
            "readsCount": "8",
            "providerDownloadCount": 940
        }
        """.data(using: .utf8)!

        if let liveStatsStory = try? JSONDecoder().decode(Story.self, from: liveStatsJSON) {
            assert(liveStatsStory.rating == 0, "Missing Provider Rating Does Not Invent a Score")
            assert(liveStatsStory.savesCount == "3" && liveStatsStory.readsCount == "8", "Story Counts Decode")
            assert(liveStatsStory.providerDownloadCount == 940, "Provider Downloads Decode")
        } else {
            assert(false, "Live Story Statistics JSON Decoding Failed")
        }

        // Test 6: Multi-Format Manga Payload Decoding (MangaDex Ingestion Contract)
        let mangaJSON = """
        {
            "id": "B0000000-0000-0000-0000-000000000002",
            "title": "Chainsaw Man",
            "author": "Tatsuki Fujimoto",
            "contentFormat": "MANGA",
            "sourceProvider": "MANGADEX",
            "totalChapters": 12
        }
        """.data(using: .utf8)!

        if let mangaStory = try? JSONDecoder().decode(Story.self, from: mangaJSON) {
            assert(mangaStory.contentFormat == .manga, "Manga Story Decodes ContentFormat Manga")
            assert(mangaStory.sourceProvider == .mangadex, "Manga Story Decodes SourceProvider MangaDex")
            assert(mangaStory.totalChapters == 12, "Manga Story Decodes Total Chapters")
        } else {
            assert(false, "Manga Story JSON Decoding Failed")
        }

        // Test 7: Chapter JSON Page URLs Decoding (Panel Manifest & Fallback)
        let chapterWithPagesJSON = """
        {
            "id": "C0000000-0000-0000-0000-000000000003",
            "title": "Chapter 1: Dog & Chainsaw",
            "chapterNumber": 1,
            "pageUrls": [
                "https://uploads.mangadex.org/data/ch1_p1.jpg",
                "https://uploads.mangadex.org/data/ch1_p2.jpg"
            ]
        }
        """.data(using: .utf8)!

        if let chapter = try? JSONDecoder().decode(Chapter.self, from: chapterWithPagesJSON) {
            assert(chapter.pageUrls.count == 2, "Chapter Page URLs Decoded Array Count")
            assert(chapter.pageUrls.first == "https://uploads.mangadex.org/data/ch1_p1.jpg", "Chapter First Page URL Integrity")
        } else {
            assert(false, "Chapter Page URLs JSON Decoding Failed")
        }

        let legacyChapterJSON = """
        {
            "id": "C0000000-0000-0000-0000-000000000004",
            "title": "Chapter 1: The Beginning"
        }
        """.data(using: .utf8)!

        if let chapter = try? JSONDecoder().decode(Chapter.self, from: legacyChapterJSON) {
            assert(chapter.pageUrls.isEmpty, "Legacy Chapter Defaults Empty Page URLs")
        } else {
            assert(false, "Legacy Chapter JSON Decoding Failed")
        }

        let cachedChapter = Chapter(
            id: UUID(uuidString: "C0000000-0000-0000-0000-000000000006")!,
            storyId: UUID(uuidString: "A0000000-0000-0000-0000-000000000006")!,
            chapterNumber: 1,
            title: "Cached Chapter",
            content: "Chapter text stored for offline reading."
        )
        let cachedChapterRoundTrip = (try? JSONEncoder().encode([cachedChapter]))
            .flatMap { try? JSONDecoder().decode([Chapter].self, from: $0) }
        assert(cachedChapterRoundTrip == [cachedChapter], "Chapter Payload Can Be Persisted and Restored")

        // Test 8: Provider formats are decoded without requiring a bundled catalog.
        assert(liveBook.contentFormat == .prose && mangaStory.contentFormat == .manga, "Live Prose and Manga Formats Decode")

        // Test 9: Provider identities survive decoding and can address live chapter endpoints.
        assert(liveBook.providerId == "1342" && mangaStory.sourceProvider == .mangadex, "Live Provider Identity Decodes")

        // Test 10: Internal App Health & Subsystem Diagnostics Suite
        let healthResult = AppHealthTests.runAllTests()
        assert(healthResult.failures.isEmpty && healthResult.passed == healthResult.total, "Internal App Health Diagnostics Verification (\(healthResult.passed)/\(healthResult.total) Passed)")

        store.stories.removeAll(where: { $0.id == actionStory.id })
        return (passed, total, failures)
    }
}
