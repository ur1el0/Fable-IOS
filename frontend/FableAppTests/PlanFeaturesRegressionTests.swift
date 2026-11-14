import AVFAudio
import MediaPlayer
import SwiftData
import XCTest
@testable import FableApp

final class PlanFeaturesRegressionTests: XCTestCase {
    @MainActor
    func testStoryEntityProgressClampingAndDiskRoundTrip() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appendingPathComponent("plans_01.store")
        let storyId = UUID()
        let lowClamp = StoryEntity(
            id: UUID(),
            title: "Negative Clamp",
            author: "Author",
            genreRaw: "Folklore",
            synopsis: "Clamp check",
            content: "Text",
            readTimeMinutes: 1,
            readingProgress: -0.5
        )
        let highClamp = StoryEntity(
            id: UUID(),
            title: "High Clamp",
            author: "Author",
            genreRaw: "Folklore",
            synopsis: "Clamp check",
            content: "Text",
            readTimeMinutes: 1,
            readingProgress: 1.8
        )
        XCTAssertEqual(lowClamp.readingProgress, 0.0, accuracy: 0.0001)
        XCTAssertEqual(highClamp.readingProgress, 1.0, accuracy: 0.0001)

        do {
            let service = PersistenceService(storeURL: storeURL)
            let story = Story(
                id: storyId,
                title: "The Obsidian Spire",
                author: "Gothic Author",
                genre: Genre(rawValue: "Gothic"),
                synopsis: "Persisted across context reset.",
                content: "Paragraph one.\n\nParagraph two.",
                readTimeMinutes: 3
            )
            service.saveStory(story)
            service.updateProgress(storyId: storyId, progressPercent: 180, isCompleted: false, page: 4, totalPages: 4)
        }

        let reloadedService = PersistenceService(storeURL: storeURL)
        let reloadedStory = try XCTUnwrap(reloadedService.fetchStory(id: storyId))
        XCTAssertEqual(reloadedStory.title, "The Obsidian Spire")
        XCTAssertEqual(reloadedStory.progressPercent, 100)
        XCTAssertTrue(reloadedStory.isCompleted)
        XCTAssertEqual(reloadedStory.currentPage, 4)
    }

    @MainActor
    func testPersistenceCascadeDeleteRemovesAnnotations() throws {
        let service = PersistenceService(isStoredInMemoryOnly: true)
        let ownerId = UUID()
        let storyId = UUID()
        let story = Story(
            id: storyId,
            title: "Clockwork Tales",
            author: "Tester",
            genre: Genre(rawValue: "Mystery"),
            synopsis: "Cascade test",
            content: "Opening line.\n\nClosing line.",
            readTimeMinutes: 2,
            ownerUserId: ownerId
        )

        let annot1 = Annotation(
            storyId: storyId,
            storyTitle: story.title,
            storyAuthor: story.author,
            chapterNumber: 1,
            utf16StartOffset: 0,
            utf16EndOffset: 13,
            selectedText: "Opening line.",
            note: "First note",
            color: .terracotta,
            isPinnedToJournal: true
        )
        let annot2 = Annotation(
            storyId: storyId,
            storyTitle: story.title,
            storyAuthor: story.author,
            chapterNumber: 1,
            utf16StartOffset: 15,
            utf16EndOffset: 28,
            selectedText: "Closing line.",
            note: nil,
            color: .sage,
            isPinnedToJournal: false
        )

        service.saveAnnotation(annot1, ownerUserId: ownerId, storyFallback: story)
        service.saveAnnotation(annot2, ownerUserId: ownerId, storyFallback: story)
        XCTAssertEqual(service.fetchAnnotations(for: storyId, ownerUserId: ownerId).count, 2)
        XCTAssertEqual(service.fetchAllPinnedAnnotations(ownerUserId: ownerId).count, 1)

        service.deleteStory(storyId: storyId)

        XCTAssertNil(service.fetchStory(id: storyId))
        XCTAssertTrue(service.fetchAnnotations(for: storyId, ownerUserId: ownerId).isEmpty)
        XCTAssertTrue(service.fetchAllPinnedAnnotations(ownerUserId: ownerId).isEmpty)
        let remainingAnnotationRows = try service.context.fetchCount(FetchDescriptor<AnnotationEntity>())
        XCTAssertEqual(remainingAnnotationRows, 0)
    }

    @MainActor
    func testSaveAnnotationPersistsFallbackStoryPinUpdatesAndAccountIsolation() {
        let service = PersistenceService(isStoredInMemoryOnly: true)
        let userA = UUID()
        let userB = UUID()
        let storyId = UUID()
        let fallbackStory = Story(
            id: storyId,
            title: "Explore Story",
            author: "Classic Author",
            genre: Genre(rawValue: "Classics"),
            synopsis: "Not yet saved before reading.",
            content: "Time is not a stream, but a clockwork wheel.",
            readTimeMinutes: 4,
            sourceProvider: .gutenberg,
            providerId: "999"
        )

        let annotationId = UUID()
        let initial = Annotation(
            id: annotationId,
            storyId: storyId,
            storyTitle: fallbackStory.title,
            storyAuthor: fallbackStory.author,
            chapterNumber: 2,
            utf16StartOffset: 0,
            utf16EndOffset: 44,
            selectedText: "Time is not a stream, but a clockwork wheel.",
            note: "Motif",
            color: .amber,
            isPinnedToJournal: true
        )

        service.saveAnnotation(initial, ownerUserId: userA, storyFallback: fallbackStory)

        XCTAssertNotNil(service.fetchStory(id: storyId))
        let pinnedForA = service.fetchAllPinnedAnnotations(ownerUserId: userA)
        XCTAssertEqual(pinnedForA.count, 1)
        XCTAssertEqual(pinnedForA.first?.chapterNumber, 2)
        XCTAssertTrue(service.fetchAllPinnedAnnotations(ownerUserId: userB).isEmpty)

        var unpinnedUpdate = initial
        unpinnedUpdate.isPinnedToJournal = false
        unpinnedUpdate.note = "Updated reflection"
        unpinnedUpdate.color = .sage
        service.saveAnnotation(unpinnedUpdate, ownerUserId: userA)

        XCTAssertTrue(service.fetchAllPinnedAnnotations(ownerUserId: userA).isEmpty)
        let fetchedForA = service.fetchAnnotations(for: storyId, ownerUserId: userA)
        XCTAssertEqual(fetchedForA.first?.note, "Updated reflection")
        XCTAssertEqual(fetchedForA.first?.color, .sage)

        service.deleteAnnotation(id: annotationId, ownerUserId: userB)
        XCTAssertEqual(service.fetchAnnotations(for: storyId, ownerUserId: userA).count, 1)

        service.deleteAnnotation(id: annotationId, ownerUserId: userA)
        XCTAssertTrue(service.fetchAnnotations(for: storyId, ownerUserId: userA).isEmpty)
    }

    @MainActor
    func testReaderPassageMatcherLocatesChapterParagraphAndPageForQuote() {
        let storyId = UUID()
        let chapter1 = Chapter(
            storyId: storyId,
            chapterNumber: 1,
            title: "Chapter I",
            content: "Once upon a midnight dreary.\n\nNothing unusual occurred."
        )
        let targetParagraph = "Time is not a stream, but a clockwork wheel."
        let paddingPara = Array(repeating: "ticking", count: 80).joined(separator: " ")
        let chapter2Content = [paddingPara, paddingPara, targetParagraph].joined(separator: "\n\n")
        let chapter2 = Chapter(
            storyId: storyId,
            chapterNumber: 2,
            title: "Chapter II",
            content: chapter2Content
        )
        let chapters = [chapter1, chapter2]

        let quoteWithChapter = Annotation(
            storyId: storyId,
            chapterNumber: 2,
            utf16StartOffset: 0,
            utf16EndOffset: targetParagraph.utf16.count,
            selectedText: targetParagraph,
            isPinnedToJournal: true
        )
        let quoteWithoutChapter = Annotation(
            storyId: storyId,
            chapterNumber: nil,
            utf16StartOffset: 0,
            utf16EndOffset: targetParagraph.utf16.count,
            selectedText: targetParagraph,
            isPinnedToJournal: true
        )

        XCTAssertEqual(ReaderPassageMatcher.chapterIndex(for: quoteWithChapter, in: chapters), 1)
        XCTAssertEqual(ReaderPassageMatcher.chapterIndex(for: quoteWithoutChapter, in: chapters), 1)

        let ch2Paragraphs = ReaderPassageMatcher.paragraphs(from: chapter2.content)
        XCTAssertEqual(ReaderPassageMatcher.paragraphIndex(for: quoteWithChapter, in: ch2Paragraphs), 2)

        let pages = PacingEngine.chunkIntoPages(text: chapter2.content, fontSizePercentage: 100.0, baseWordsPerPage: 100)
        XCTAssertEqual(ReaderPassageMatcher.pageNumber(for: quoteWithChapter, in: pages), pages.count)
    }

    @MainActor
    func testPacingEngineRejectsSubThreeSecondPageTurnsCapsIdleTimeAndMonotonicallyEstimatesRemainingMinutes() {
        let engine = PacingEngine()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        engine.startSession(at: t0)

        // Sub-3s page flip must be discarded
        engine.recordPageTurn(wordsOnPage: 150, at: t0.addingTimeInterval(2.0))
        XCTAssertEqual(engine.pacingVelocityWPM, 200.0, accuracy: 0.001)

        // Deliberate turn: 120 words in 30s = 240 WPM -> 0.25*240 + 0.75*200 = 210 WPM
        engine.recordPageTurn(wordsOnPage: 120, at: t0.addingTimeInterval(32.0))
        XCTAssertEqual(engine.pacingVelocityWPM, 210.0, accuracy: 0.001)

        // Long idle (> 180s) caps at 180s -> 210 words / 3.0 min = 70 WPM -> 0.25*70 + 0.75*210 = 175 WPM
        engine.recordPageTurn(wordsOnPage: 210, at: t0.addingTimeInterval(632.0))
        XCTAssertEqual(engine.pacingVelocityWPM, 175.0, accuracy: 0.001)

        let est1 = engine.estimatedMinutesRemaining(remainingWords: 1200)
        let est2 = engine.estimatedMinutesRemaining(remainingWords: 600)
        let est3 = engine.estimatedMinutesRemaining(remainingWords: 100)
        XCTAssertGreaterThan(est1, est2)
        XCTAssertGreaterThanOrEqual(est2, est3)
        XCTAssertEqual(engine.estimatedMinutesRemaining(remainingWords: 0), 1)
    }

    @MainActor
    func testAudioNarratorRateClampingBackgroundBundleKeyAndNowPlayingMetadata() throws {
        let narrator = AudioNarratorController()
        defer { AudioNarratorController.shared.configureRemoteCommandCenter() }

        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        XCTAssertTrue(narrator.isRemoteCommandCenterConfigured)

        let center = MPRemoteCommandCenter.shared()
        XCTAssertTrue(center.playCommand.isEnabled)
        XCTAssertTrue(center.pauseCommand.isEnabled)
        XCTAssertTrue(center.togglePlayPauseCommand.isEnabled)
        XCTAssertTrue(center.stopCommand.isEnabled)

        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        XCTAssertEqual(backgroundModes?.contains("audio"), true)

        narrator.setRateMultiplier(0.25)
        XCTAssertEqual(narrator.playbackRateMultiplier, 0.75, accuracy: 0.001)
        narrator.setRateMultiplier(3.0)
        XCTAssertEqual(narrator.playbackRateMultiplier, 1.75, accuracy: 0.001)

        let story = Story(
            title: "The Clockmaker",
            author: "Aesop",
            genre: Genre(rawValue: "Fables"),
            synopsis: "Tick.",
            content: "Tick tock.",
            readTimeMinutes: 1
        )
        let chapter = Chapter(storyId: story.id, chapterNumber: 3, title: "Chapter Three", content: "Tick tock.")
        narrator.updateNowPlayingMetadata(story: story, chapter: chapter)

        let nowPlaying = try XCTUnwrap(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        XCTAssertEqual(nowPlaying[MPMediaItemPropertyTitle] as? String, "The Clockmaker • Ch. 3")
        XCTAssertEqual(nowPlaying[MPMediaItemPropertyArtist] as? String, "Aesop")
        XCTAssertEqual(nowPlaying[MPMediaItemPropertyAlbumTitle] as? String, "Chapter Three")

        narrator.stop()
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().playbackState, .stopped)
    }

    @MainActor
    func testUnreadableCachedStoryHydrationAndStaleCloudPruningHelpers() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let service = PersistenceService(storeURL: tempDir.appendingPathComponent("stale_cleanup.store"))

        let deadStub = Story(
            id: UUID(),
            title: "Stale Server Summary",
            author: "Unknown",
            genre: Genre(rawValue: "Folklore"),
            synopsis: "Summary without content",
            content: "",
            readTimeMinutes: 1,
            sourceProvider: .fableOriginal
        )
        let annotatedStub = Story(
            id: UUID(),
            title: "Annotated Server Summary",
            author: "Unknown",
            genre: Genre(rawValue: "Folklore"),
            synopsis: "Summary with annotation",
            content: "",
            readTimeMinutes: 1,
            sourceProvider: .fableOriginal
        )
        let liveRemoteOriginal = Story(
            id: UUID(),
            title: "Active Backend Story",
            author: "Author",
            genre: Genre(rawValue: "Classics"),
            synopsis: "Available remotely",
            content: "",
            readTimeMinutes: 3,
            sourceProvider: .fableOriginal
        )
        let localInlineOriginal = Story(
            id: UUID(),
            title: "Local Readable Story",
            author: "Author",
            genre: Genre(rawValue: "Fiction"),
            synopsis: "Has inline prose",
            content: "Readable prose paragraph.",
            readTimeMinutes: 2,
            sourceProvider: .fableOriginal
        )
        let gutenbergStory = Story(
            id: UUID(),
            title: "Alice",
            author: "Lewis Carroll",
            genre: Genre(rawValue: "Classics"),
            synopsis: "Public domain",
            content: "",
            readTimeMinutes: 10,
            sourceProvider: .gutenberg,
            providerId: "11"
        )

        XCTAssertFalse(
            StoryStore.shouldHydratePersistedStory(
                content: "",
                cachedChapters: [],
                format: .prose,
                isBookmarked: false,
                isCompleted: false,
                readingProgress: 0,
                lastReadChapterId: nil
            )
        )
        XCTAssertTrue(
            StoryStore.shouldHydratePersistedStory(
                content: "Readable offline prose",
                cachedChapters: [],
                format: .prose,
                isBookmarked: false,
                isCompleted: false,
                readingProgress: 0,
                lastReadChapterId: nil
            )
        )

        let staleIDs = StoryStore.staleUnavailableOriginalStoryIDs(
            in: [deadStub, annotatedStub, liveRemoteOriginal, localInlineOriginal, gutenbergStory],
            remoteStoryIDs: [liveRemoteOriginal.id],
            profileStoryIDs: [],
            cachedChaptersProvider: { _ in [] }
        )
        XCTAssertEqual(staleIDs, [deadStub.id, annotatedStub.id])

        service.saveStory(deadStub)
        service.saveStory(annotatedStub)
        service.saveAnnotation(
            Annotation(
                storyId: annotatedStub.id,
                storyTitle: annotatedStub.title,
                storyAuthor: annotatedStub.author,
                chapterNumber: 1,
                utf16StartOffset: 0,
                utf16EndOffset: 4,
                selectedText: "Note",
                isPinnedToJournal: true
            ),
            ownerUserId: nil
        )

        service.deleteStory(storyId: deadStub.id, onlyIfUnannotated: true)
        service.deleteStory(storyId: annotatedStub.id, onlyIfUnannotated: true)

        XCTAssertNil(service.fetchStory(id: deadStub.id))
        XCTAssertNotNil(service.fetchStory(id: annotatedStub.id))
        XCTAssertEqual(service.fetchAllPinnedAnnotations(ownerUserId: nil).count, 1)
    }

    @MainActor
    func testLibraryFeaturedDeduplicationAndDiscoveryTaxonomyHelpers() {
        let featured = Story(
            id: UUID(),
            title: "Pride and Prejudice",
            author: "Jane Austen",
            genre: "Fiction",
            excerpt: "Classic romance.",
            paragraphs: ["It is a truth universally acknowledged."],
            readingTimeMinutes: 12,
            isTaleOfTheDay: true
        )
        let second = Story(
            id: UUID(),
            title: "Dracula",
            author: "Bram Stoker",
            genre: Genre(rawValue: "Gothic"),
            synopsis: "Vampire epistolary.",
            content: "Left Munich at 8:35 PM.",
            readTimeMinutes: 15
        )
        let compoundSubject = Story(
            id: UUID(),
            title: "Anna Karenina",
            author: "Leo Tolstoy",
            genre: Genre(rawValue: "Adultery -- Fiction"),
            synopsis: "Russian realism.",
            content: "Happy families are all alike.",
            readTimeMinutes: 20
        )

        let remaining = LibraryView.latestStories(from: [featured, second], excluding: featured.id)
        XCTAssertEqual(remaining.map(\.id), [second.id])
        XCTAssertTrue(LibraryView.latestStories(from: [featured], excluding: featured.id).isEmpty)

        let store = StoryStore()
        XCTAssertTrue(store.storyMatchesCategory(featured, category: "Fiction"))
        XCTAssertFalse(store.storyMatchesCategory(compoundSubject, category: "Fiction"))
        XCTAssertEqual(StoryStore.pluralizedCount(1, singular: "Title"), "1 Title")
        XCTAssertEqual(StoryStore.pluralizedCount(2, singular: "Title"), "2 Titles")
        XCTAssertEqual(StoryStore.pluralizedCount(1, singular: "story", plural: "stories"), "1 story")
        XCTAssertEqual(StoryStore.pluralizedCount(4, singular: "story", plural: "stories"), "4 stories")
        XCTAssertTrue(StoryStore.isExcludedPlaceholderAuthor("Various"))
        XCTAssertTrue(StoryStore.isExcludedPlaceholderAuthor(" anonymous "))
        XCTAssertFalse(StoryStore.isExcludedPlaceholderAuthor("Jane Austen"))
    }
}
