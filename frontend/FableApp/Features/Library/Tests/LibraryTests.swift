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

        // Test 1: Story store initialization
        assert(!store.stories.isEmpty, "Stories Catalog Loaded")

        // Test 2: Bookmark toggling
        if let first = store.stories.first {
            let initialState = first.isBookmarked
            store.toggleBookmark(for: first)
            let updatedState = store.stories.first(where: { $0.id == first.id })?.isBookmarked ?? false
            assert(updatedState != initialState, "Toggle Bookmark State")
            store.toggleBookmark(for: first) // revert
        }

        // Test 3: Reading progress mutation
        if let first = store.stories.first {
            store.updateProgress(for: first.id, page: 3, totalPages: 4)
            let updated = store.stories.first(where: { $0.id == first.id })
            assert(updated?.progressPercent == 75 && updated?.currentPage == 3, "Update Reading Progress")
        }

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
        } else {
            assert(false, "Legacy Story JSON Decoding Failed")
        }

        // Test 5: Multi-Format Manga Payload Decoding (MangaDex Ingestion Contract)
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

        // Test 6: Chapter JSON Page URLs Decoding (Panel Manifest & Fallback)
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

        // Test 7: Catalog Multi-Format Diversity
        let hasProse = store.stories.contains(where: { $0.contentFormat == .prose })
        let hasManga = store.stories.contains(where: { $0.contentFormat == .manga })
        assert(hasProse, "StoryStore Contains Prose Literature")
        assert(hasManga, "StoryStore Contains Manga Releases")

        // Test 8: Multi-Provider Ingestion Recognition
        let hasGutenberg = store.stories.contains(where: { $0.sourceProvider == .gutenberg })
        let hasMangaDex = store.stories.contains(where: { $0.sourceProvider == .mangadex })
        assert(hasGutenberg, "Catalog Contains Project Gutenberg Ingested Titles")
        assert(hasMangaDex, "Catalog Contains MangaDex Ingested Titles")

        return (passed, total, failures)
    }
}
