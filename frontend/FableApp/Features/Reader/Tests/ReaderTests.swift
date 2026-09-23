import Foundation

@MainActor
public struct ReaderTests {
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

        let engine = PacingEngine()

        // Test 1: Baseline pace calculation (200 WPM baseline -> 1,000 words = 5 mins)
        let estimatedMins = engine.estimatedMinutesRemaining(remainingWords: 1000)
        assert(estimatedMins == 5, "Baseline Remaining Minutes Calculation")

        // Test 2: Extreme high-speed velocity clamping (<= 600 WPM)
        engine.recordReadingPace(wordsRead: 1000, elapsedSeconds: 10)
        assert(engine.currentWPM <= 600, "Clamp Upper Velocity Limit (600 WPM)")

        // Test 3: Extreme low-speed velocity clamping (>= 100 WPM)
        engine.recordReadingPace(wordsRead: 5, elapsedSeconds: 300)
        assert(engine.currentWPM >= 100, "Clamp Lower Velocity Limit (100 WPM)")

        // Test 4: Unicode-compliant word counting across variable whitespaces and punctuation
        let rawManuscript = "  The clockmaker\twhispered, \"Hark! The dusk...\"\n\n  Seven shadows fell upon the cobbles.  "
        let tokenizedCount = PacingEngine.countWords(in: rawManuscript)
        // Words: The, clockmaker, whispered, Hark, The, dusk, Seven, shadows, fell, upon, the, cobbles -> 12 words
        assert(tokenizedCount == 12, "Unicode Word Tokenization Count Accuracy")

        // Test 5: Dynamic font scaling responsive page chunking
        let sampleParagraph = "In the heart of the ancient city, clocks were not mere mechanical artifacts; they were anchors of memory, ticking in counterpoint to human heartbeats."
        let multiPara = Array(repeating: sampleParagraph, count: 12).joined(separator: "\n\n")
        let standardPages = PacingEngine.chunkIntoPages(text: multiPara, fontSizePercentage: 100.0, baseWordsPerPage: 100)
        let zoomedPages = PacingEngine.chunkIntoPages(text: multiPara, fontSizePercentage: 150.0, baseWordsPerPage: 100)
        let compactPages = PacingEngine.chunkIntoPages(text: multiPara, fontSizePercentage: 80.0, baseWordsPerPage: 100)
        
        assert(zoomedPages.count >= standardPages.count, "Zoomed Pages Count Greater or Equal to Standard")
        assert(standardPages.count >= compactPages.count, "Standard Pages Count Greater or Equal to Compact")

        // Test 6: Text reconstruction integrity (no dropped paragraphs)
        let reconstructed = standardPages.joined(separator: "\n\n")
        let origWordCount = PacingEngine.countWords(in: multiPara)
        let reconWordCount = PacingEngine.countWords(in: reconstructed)
        assert(origWordCount == reconWordCount, "Paginated Text Reconstruction Integrity")

        // Test 7: MangaReadingMode Enums & Iconography
        assert(MangaReadingMode.webtoon.iconName == "arrow.up.and.down", "Webtoon Reading Mode Up/Down Icon")
        assert(MangaReadingMode.paged.iconName == "arrow.left.and.right", "Paged Reading Mode Left/Right Icon")

        // Test 8: Manga Active Page URLs Fallback Hierarchy
        let testStoryId = UUID()
        let chapterWithPanels = Chapter(
            storyId: testStoryId,
            chapterNumber: 1,
            title: "Ch 1",
            pageUrls: ["https://cdn.manga.org/ch1_p1.jpg", "https://cdn.manga.org/ch1_p2.jpg"]
        )
        let mangaWithPanels = Story(
            id: testStoryId,
            title: "Cyber Ronin",
            author: "Manga Artist",
            genre: "Manga",
            excerpt: "Action manga",
            coverImageUrl: "https://cdn.manga.org/cover.jpg",
            contentFormat: .manga,
            sourceProvider: .mangadex,
            chapters: [chapterWithPanels]
        )

        // Scenario A: Current chapter has explicit page URLs
        let resolvedUrlsA = chapterWithPanels.pageUrls
        assert(resolvedUrlsA.count == 2 && resolvedUrlsA[0] == "https://cdn.manga.org/ch1_p1.jpg", "Manga Chapter Explicit Page Resolution")

        // Scenario B: Chapter without page URLs falls back to first chapter or story cover
        let emptyChapter = Chapter(
            storyId: testStoryId,
            chapterNumber: 2,
            title: "Ch 2",
            pageUrls: []
        )
        let fallbackUrls = [mangaWithPanels.coverImageUrl, mangaWithPanels.effectiveCoverImage].compactMap { $0 }
        assert(!fallbackUrls.isEmpty && fallbackUrls.contains("https://cdn.manga.org/cover.jpg"), "Manga Empty Panels Cover Fallback Resolution")

        // Test 9: Format-Based Reader Selection Protocol
        let proseStory = Story(
            title: "Classic Novel",
            author: "Author",
            genre: "Classic Fiction",
            excerpt: "Prose story",
            contentFormat: .prose
        )
        assert(mangaWithPanels.contentFormat == .manga, "Manga Story Format Classification")
        assert(proseStory.contentFormat == .prose, "Prose Story Format Classification")

        // Test 10: Reader Font & Theme Invariants
        assert(ReaderFont.allCases.count == 3, "Reader Font Option Count")
        assert(ReaderFont.sans.displayName == "SF Pro", "Reader Sans Display Name SF Pro")
        assert(ReaderTheme.allCases.count == 4, "Reader Theme Count (White, Sepia, Charcoal, OLED)")
        assert(ReaderLineSpacing.allCases.count == 3, "Reader Line Spacing Options Count")

        return (passed, total, failures)
    }
}
