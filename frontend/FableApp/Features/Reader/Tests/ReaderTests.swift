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
        assert(MangaReadingMode.rightToLeft.iconName == "arrow.right.to.line", "RTL Reading Mode Icon")
        assert(MangaReadingMode.allCases.count == 3, "All Three Manga Reading Modes Defined")

        // Test 8: Manga Panel and Cover Separation
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

        // Scenario B: A story cover remains a cover and is not rendered as a manga panel
        let emptyChapter = Chapter(
            storyId: testStoryId,
            chapterNumber: 2,
            title: "Ch 2",
            pageUrls: []
        )
        assert(emptyChapter.pageUrls.isEmpty, "Manga Empty Panels Do Not Use Story Cover")
        assert(mangaWithPanels.effectiveCoverImage == "https://cdn.manga.org/cover.jpg", "Manga Story Cover Remains Available")

        let textChapter = Chapter(
            storyId: testStoryId,
            chapterNumber: 3,
            title: "Readable Chapter",
            content: "The chapter text is available to the in-app reader."
        )
        let externalChapter = Chapter(
            storyId: testStoryId,
            chapterNumber: 4,
            title: "Official Release",
            content: "https://publisher.example/chapters/4"
        )
        assert(
            textChapter.hasReadableText && textChapter.externalSourceURL == nil,
            "Prose Chapter Text Is Cached for In-App Reading"
        )
        assert(
            !externalChapter.hasReadableText
                && externalChapter.externalSourceURL?.absoluteString == externalChapter.content,
            "Publisher URL Is Distinguished from Chapter Text"
        )

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
        assert(ReaderFont.allCases.count == 4, "Reader Font Option Count")
        assert(ReaderFont.sans.displayName == "SF Pro", "Reader Sans Display Name SF Pro")
        assert(ReaderTheme.allCases.count == 6, "Reader Theme Count (White, Paper, Sepia, Midnight, Charcoal, OLED)")
        assert(ReaderLineSpacing.allCases.count == 3, "Reader Line Spacing Options Count")

        // Test 11: Multi-Chapter Progress Persistence & Restoration Invariant
        let store = StoryStore()
        let trackedStoryId = UUID()
        let ch1 = Chapter(storyId: trackedStoryId, chapterNumber: 1, title: "Part I", content: "Chapter one text.")
        let ch2 = Chapter(storyId: trackedStoryId, chapterNumber: 2, title: "Part II", content: "Chapter two text.")
        let trackedStory = Story(
            id: trackedStoryId,
            title: "Tracked Odyssey",
            author: "Homer",
            genre: "Classics",
            excerpt: "Sing in me, Muse.",
            paragraphs: ["Chapter one text."],
            totalPages: 4,
            currentPage: 1,
            progressPercent: 0,
            contentFormat: .prose,
            chapters: [ch1, ch2]
        )
        store.stories.append(trackedStory)
        store.updateProgress(
            for: trackedStoryId,
            page: 2,
            totalPages: 4,
            chapterIndex: 1,
            totalChapters: 2,
            chapterId: ch2.id.uuidString,
            chapterNumber: 2
        )
        let saved = store.stories.first(where: { $0.id == trackedStoryId })
        assert(
            saved?.currentPage == 2
                && saved?.totalPages == 4
                && saved?.lastReadChapterId == ch2.id.uuidString
                && saved?.lastReadChapterNumber == 2
                && saved?.progressPercent == 75
                && saved?.isCompleted == false,
            "Multi-Chapter Prose Reading Progress Saves Exact Chapter and Page"
        )

        // Test 11: ReaderFont Enum Coverage & Rounded Font Support
        assert(ReaderFont.allCases.contains(.rounded), "ReaderFont Contains Rounded Option")
        assert(ReaderFont.rounded.displayName == "SF Rounded", "ReaderFont Rounded Display Name")
        assert(ReaderFont.allCases.count == 4, "ReaderFont Has All 4 Defined Typography Options")

        // Test 12: ReaderTheme Extended Palette & Darkness Contrast Classification
        assert(ReaderTheme.allCases.contains(.paper), "ReaderTheme Contains Paper Option")
        assert(ReaderTheme.allCases.contains(.midnight), "ReaderTheme Contains Midnight Option")
        assert(!ReaderTheme.white.isDark && !ReaderTheme.paper.isDark && !ReaderTheme.sepia.isDark, "Light Themes Correctly Classified")
        assert(ReaderTheme.charcoal.isDark && ReaderTheme.midnight.isDark && ReaderTheme.oled.isDark, "Dark Themes Correctly Classified")
        assert(ReaderTheme.allCases.count == 6, "ReaderTheme Has All 6 Reading Palettes")

        return (passed, total, failures)
    }
}
