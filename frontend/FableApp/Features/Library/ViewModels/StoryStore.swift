import SwiftUI
import Combine

@MainActor
public final class StoryStore: ObservableObject {
    @Published var stories: [Story] = []
    @Published var selectedCategory: String = "All"
    @Published var activeReaderStory: Story?
    @Published var isShowingDisplayOptions: Bool = false
    @Published var isShowingSettings: Bool = false
    @Published var isShowingProfile: Bool = false
    @Published var isShowingGenreDetail: Bool = false
    @Published var selectedGenre: GenreCategory?
    @Published var isStoryPublished: Bool = false
    @Published var selectedTab: FableTab = .library
    
    // Reader Preferences (Persisted across launches)
    @Published var readerFont: ReaderFont = .serif {
        didSet { UserDefaults.standard.set(readerFont.rawValue, forKey: "fable_pref_reader_font") }
    }
    @Published var readerFontSize: Double = 100.0 {
        didSet { UserDefaults.standard.set(readerFontSize, forKey: "fable_pref_reader_font_size") }
    }
    @Published var readerTheme: ReaderTheme = .sepia {
        didSet { UserDefaults.standard.set(readerTheme.rawValue, forKey: "fable_pref_reader_theme") }
    }
    @Published var readerLineSpacing: ReaderLineSpacing = .normal {
        didSet { UserDefaults.standard.set(readerLineSpacing.rawValue, forKey: "fable_pref_reader_line_spacing") }
    }
    @Published var hapticFeedback: Bool = true {
        didSet { UserDefaults.standard.set(hapticFeedback, forKey: "fable_pref_reader_haptics") }
    }
    @Published var isPaginatedMode: Bool = false {
        didSet { UserDefaults.standard.set(isPaginatedMode, forKey: "fable_pref_reader_paginated") }
    }
    
    // Cloud Synchronization Pipeline (Plan 05)
    @Published var isCloudSyncActive: Bool = false
    @Published var isBackendReachable: Bool = false
    private let apiService: StoryAPIServiceProtocol = StoryAPIService()
    
    public var persistentDeviceId: UUID {
        let key = "fable_device_id"
        if let saved = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: saved) {
            return uuid
        }
        let newId = UUID()
        UserDefaults.standard.set(newId.uuidString, forKey: key)
        return newId
    }
    
    // Marginalia & Quotes (Plan 02)
    @Published var activeStoryAnnotations: [Annotation] = []
    @Published var pinnedQuotes: [Annotation] = []
    
    // Living Reading Stats (Plan 03 & Mobile Hardening)
    @Published var readingStats: PersistenceService.ReadingStatsSummary = PersistenceService.ReadingStatsSummary(storiesReadCount: 12, totalMinutesRead: 48, streakDays: 3)
    
    // Writing Draft
    @Published var draftTitle: String = ""
    @Published var draftGenre: String = "Folklore"
    @Published var draftChapter: String = "Chapter I"
    @Published var draftSynopsis: String = ""
    @Published var draftManuscript: String = ""
    
    // Live Server-Driven Genres (with bundled defaults)
    @Published var genres: [GenreCategory] = GenreCategory.defaultCategories
    
    // Live Server-Driven Trending Writers (with bundled defaults)
    @Published var writers: [Writer] = Writer.defaultWriters
    
    // User Profile Stories
    @Published var profileStories: [Story] = []
    
    init() {
        loadReaderPreferences()
        syncWithPersistence()
        Task { [weak self] in
            await self?.syncWithCloudBackend()
        }
    }
    
    private func loadReaderPreferences() {
        if let fontRaw = UserDefaults.standard.string(forKey: "fable_pref_reader_font"),
           let font = ReaderFont(rawValue: fontRaw) {
            self.readerFont = font
        }
        let storedSize = UserDefaults.standard.double(forKey: "fable_pref_reader_font_size")
        if storedSize >= 80.0 && storedSize <= 150.0 {
            self.readerFontSize = storedSize
        }
        if let themeRaw = UserDefaults.standard.string(forKey: "fable_pref_reader_theme"),
           let theme = ReaderTheme(rawValue: themeRaw) {
            self.readerTheme = theme
        }
        if let spacingRaw = UserDefaults.standard.string(forKey: "fable_pref_reader_line_spacing"),
           let spacing = ReaderLineSpacing(rawValue: spacingRaw) {
            self.readerLineSpacing = spacing
        }
        if UserDefaults.standard.object(forKey: "fable_pref_reader_haptics") != nil {
            self.hapticFeedback = UserDefaults.standard.bool(forKey: "fable_pref_reader_haptics")
        }
        if UserDefaults.standard.object(forKey: "fable_pref_reader_paginated") != nil {
            self.isPaginatedMode = UserDefaults.standard.bool(forKey: "fable_pref_reader_paginated")
        }
    }

    
    var draftWordCount: Int {
        draftManuscript.split { $0.isWhitespace || $0.isNewline }.count
    }
    
    func resetDisplayOptions() {
        readerFont = .serif
        readerFontSize = 100.0
        readerTheme = .sepia
        readerLineSpacing = .normal
    }
    
    func publishStory() {
        let newStory = Story(
            title: draftTitle.isEmpty ? "Untitled Tale" : draftTitle,
            author: AuthManager.shared.currentSession?.name ?? "Independent Author",
            genre: draftGenre,
            excerpt: draftSynopsis,
            paragraphs: [draftManuscript],
            coverImageName: "thumb_metamorphosis",
            readingTimeMinutes: max(1, draftWordCount / 150),
            totalPages: 1,
            currentPage: 1,
            progressPercent: 0,
            rating: 5.0,
            isRecentSubmission: true
        )
        stories.insert(newStory, at: 0)
        profileStories.insert(newStory, at: 0)
        isStoryPublished = true
        
        // Persist to SwiftData SQLite
        PersistenceService.shared.saveStory(newStory)
        
        // Asynchronously sync newly published manuscript with cloud backend
        Task { [weak self] in
            guard let self = self else { return }
            let req = CreateStoryRequest(
                title: newStory.title,
                author: newStory.author,
                genre: newStory.genre.rawValue,
                synopsis: newStory.synopsis,
                content: newStory.content,
                readTimeMinutes: newStory.readTimeMinutes,
                contentFormat: newStory.contentFormat.rawValue,
                sourceProvider: newStory.sourceProvider.rawValue
            )
            _ = try? await self.apiService.createStory(req)
        }
    }
    
    private func syncWithPersistence() {
        // Seed default stories if SQLite is empty
        PersistenceService.shared.seedInitialDataIfNeeded(seedStories: Story.defaultSeedStories)
        
        // Hydrate and reconcile from SQLite
        let persisted = PersistenceService.shared.fetchAllStories()
        if !persisted.isEmpty {
            for entity in persisted {
                if let idx = stories.firstIndex(where: { $0.id == entity.id }) {
                    stories[idx].isBookmarked = entity.isBookmarked
                    stories[idx].isCompleted = entity.isCompleted
                    stories[idx].progressPercent = Int(entity.readingProgress * 100.0)
                    stories[idx].currentPage = max(1, entity.currentPage)
                    stories[idx].totalPages = max(1, entity.totalPages)
                } else {
                    let userStory = Story(
                        id: entity.id,
                        title: entity.title,
                        author: entity.author,
                        genre: entity.genreRaw,
                        excerpt: entity.synopsis,
                        paragraphs: [entity.content],
                        coverImageName: "thumb_metamorphosis",
                        readingTimeMinutes: entity.readTimeMinutes,
                        totalPages: max(1, entity.totalPages),
                        currentPage: max(1, entity.currentPage),
                        progressPercent: Int(entity.readingProgress * 100.0),
                        rating: 5.0,
                        isRecentSubmission: true,
                        isSaved: entity.isBookmarked,
                        isFinished: entity.isCompleted
                    )
                    stories.insert(userStory, at: 0)
                    profileStories.insert(userStory, at: 0)
                }
            }
        }
        
        if stories.isEmpty {
            self.stories = Story.defaultSeedStories
        }
        
        if profileStories.isEmpty {
            self.profileStories = [
                Story(
                    title: "The Clockmaker of Prague",
                    author: AuthManager.shared.currentSession?.name ?? "Roosc Zaño",
                    genre: "Folklore",
                    excerpt: "In the shadowed alleys behind the Astronomical Clock, Master Hanuš polished cogs that measured not minutes, but heartbeats.",
                    coverImageName: "thumb_metamorphosis",
                    readingTimeMinutes: 4,
                    rating: 4.9,
                    readsCount: "1.2k reads",
                    badgeText: "FOLKLORE • 4 min read"
                )
            ]
        }
        
        reloadPinnedQuotes()
        reloadReadingStats()
    }
    
    func reloadReadingStats() {
        self.readingStats = PersistenceService.shared.fetchReadingStats()
    }
    
    func reloadPinnedQuotes() {
        let loaded = PersistenceService.shared.fetchAllPinnedAnnotations()
        if loaded.isEmpty {
            let defaultQuote = Annotation(
                storyId: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                storyTitle: "De Oratore",
                storyAuthor: "Marcus Tullius Cicero",
                utf16StartOffset: 0,
                utf16EndOffset: 51,
                selectedText: "A room without books is like a body without a soul.",
                note: "Foundational literary ethos",
                color: .terracotta,
                isPinnedToJournal: true
            )
            self.pinnedQuotes = [defaultQuote]
        } else {
            self.pinnedQuotes = loaded
        }
    }
    
    // MARK: - Cloud Synchronization Pipeline (Plan 05)
    func syncWithCloudBackend() async {
        isCloudSyncActive = true
        defer { isCloudSyncActive = false }
        
        do {
            // 1. Fetch live remote stories from FastAPI
            let remoteStories = try await apiService.fetchStories(genre: nil, search: nil)
            self.isBackendReachable = true
            
            if self.stories.isEmpty {
                self.stories = remoteStories
                for story in remoteStories {
                    PersistenceService.shared.saveStory(story)
                }
            } else {
                for remote in remoteStories {
                    if let idx = stories.firstIndex(where: { $0.id == remote.id }) {
                        stories[idx].isBookmarked = stories[idx].isBookmarked || remote.isBookmarked
                        stories[idx].coverImageUrl = remote.coverImageUrl
                        stories[idx].totalChapters = remote.totalChapters
                        stories[idx].contentFormat = remote.contentFormat
                        stories[idx].sourceProvider = remote.sourceProvider
                        if remote.isTaleOfTheDay { stories[idx].isTaleOfTheDay = true }
                        if remote.isCuratorSpotlight { stories[idx].isCuratorSpotlight = true }
                    } else {
                        stories.append(remote)
                        PersistenceService.shared.saveStory(remote)
                    }
                }
            }
            
            // 2. Fetch live dynamic categories/genres from backend
            if let liveGenres = try? await apiService.fetchGenres(), !liveGenres.isEmpty {
                self.genres = liveGenres
            }
            
            // 3. Fetch live trending authors from backend/Open Library
            if let liveWriters = try? await apiService.fetchTopAuthors(), !liveWriters.isEmpty {
                self.writers = liveWriters
            }
            
            // 4. Fetch live update feed (Tale of the Day, Curator Spotlight)
            if let feed = try? await apiService.fetchUpdateFeed() {
                if let totd = feed.taleOfTheDay {
                    for i in 0..<stories.count {
                        stories[i].isTaleOfTheDay = (stories[i].id == totd.id)
                    }
                }
                if let curator = feed.curatorSpotlight {
                    for i in 0..<stories.count {
                        stories[i].isCuratorSpotlight = (stories[i].id == curator.id)
                    }
                }
            }
            
            // 5. Bidirectional shelf sync using Last-Write-Wins
            let shelfItems = stories.map { story in
        ShelfSyncItem(
            storyId: story.id,
            readingProgress: Double(story.progressPercent) / 100.0,
            isBookmarked: story.isBookmarked,
            isCompleted: story.isCompleted,
            updatedAtUtc: story.createdAtUtc
        )
    }
    let reconciled = try await apiService.syncShelf(deviceId: persistentDeviceId, items: shelfItems)
            for item in reconciled {
                if let idx = stories.firstIndex(where: { $0.id == item.storyId }) {
                    stories[idx].isBookmarked = item.isBookmarked
                    stories[idx].isCompleted = item.isCompleted
                    stories[idx].progressPercent = Int(item.readingProgress * 100.0)
                }
            }
        } catch {
            // Offline-First Invariant: Operates seamlessly on local SwiftData/SQLite
            self.isBackendReachable = false
        }
    }
    
    /// Loads authentic chapters on demand for the active reading story
    func fetchChapters(for story: Story) async -> [Chapter] {
        if let existing = story.chapters, !existing.isEmpty {
            return existing
        }
        do {
            let fetched = try await apiService.fetchChapters(for: story.id)
            if let idx = stories.firstIndex(where: { $0.id == story.id }) {
                stories[idx].chapters = fetched
                stories[idx].totalChapters = max(1, fetched.count)
            }
            if activeReaderStory?.id == story.id {
                activeReaderStory?.chapters = fetched
                activeReaderStory?.totalChapters = max(1, fetched.count)
            }
            return fetched
        } catch {
            return story.chapters ?? []
        }
    }

    
    func fetchGutenbergPublicStories(topic: String? = nil, search: String? = nil) async {
        do {
            let fetched = try await apiService.fetchGutenbergStories(topic: topic, search: search)
            for book in fetched {
                if !stories.contains(where: { $0.id == book.id }) {
                    stories.append(book)
                    PersistenceService.shared.saveStory(book)
                }
            }
        } catch {
            // Graceful fallback to offline local stories
        }
    }
    
    // MARK: - Actions
    func toggleBookmark(for story: Story) {
        if let idx = stories.firstIndex(where: { $0.id == story.id }) {
            stories[idx].isBookmarked.toggle()
        }
        if let idx = profileStories.firstIndex(where: { $0.id == story.id }) {
            profileStories[idx].isBookmarked.toggle()
        }
        _ = PersistenceService.shared.toggleBookmark(storyId: story.id)
        
        Task { [weak self] in
            guard let self = self else { return }
            _ = try? await self.apiService.toggleBookmark(storyId: story.id)
        }
    }
    
    func updateProgress(for storyId: UUID, page: Int, totalPages: Int) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].currentPage = page
            stories[idx].totalPages = totalPages
            let pct = min(100, max(0, Int((Double(page) / Double(max(1, totalPages))) * 100)))
            stories[idx].progressPercent = pct
            if pct >= 100 {
                stories[idx].isCompleted = true
            }
            PersistenceService.shared.updateProgress(
                storyId: storyId,
                progressPercent: pct,
                isCompleted: pct >= 100,
                page: page,
                totalPages: totalPages
            )
            reloadReadingStats()
            
            let currentBookmarked = stories[idx].isBookmarked
            Task { [weak self] in
                guard let self = self else { return }
                let item = ShelfSyncItem(
                    storyId: storyId,
                    readingProgress: Double(pct) / 100.0,
                    isBookmarked: currentBookmarked,
                    isCompleted: pct >= 100,
                    updatedAtUtc: Date()
                )
                _ = try? await self.apiService.syncShelf(deviceId: self.persistentDeviceId, items: [item])
            }
        }
    }
    
    func logReadingSession(for story: Story, seconds: Int) {
        PersistenceService.shared.logReadingSession(
            storyId: story.id,
            storyTitle: story.title,
            seconds: seconds,
            isCompleted: story.isCompleted
        )
        reloadReadingStats()
    }
    
    func markAsFinished(storyId: UUID) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].isCompleted = true
            stories[idx].progressPercent = 100
            let pages = stories[idx].totalPages
            PersistenceService.shared.updateProgress(
                storyId: storyId,
                progressPercent: 100,
                isCompleted: true,
                page: pages,
                totalPages: pages
            )
            reloadReadingStats()
            
            Task { [weak self] in
                guard let self = self else { return }
                let item = ShelfSyncItem(
                    storyId: storyId,
                    readingProgress: 1.0,
                    isBookmarked: self.stories[idx].isBookmarked,
                    isCompleted: true,
                    updatedAtUtc: Date()
                )
                _ = try? await self.apiService.syncShelf(deviceId: self.persistentDeviceId, items: [item])
            }
        }
    }
    
    func removeFromShelf(storyId: UUID) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].isBookmarked = false
            _ = PersistenceService.shared.toggleBookmark(storyId: storyId)
            
            Task { [weak self] in
                guard let self = self else { return }
                let item = ShelfSyncItem(
                    storyId: storyId,
                    readingProgress: Double(self.stories[idx].progressPercent) / 100.0,
                    isBookmarked: false,
                    isCompleted: self.stories[idx].isCompleted,
                    updatedAtUtc: Date()
                )
                _ = try? await self.apiService.syncShelf(deviceId: self.persistentDeviceId, items: [item])
            }
        }
    }
    
    // MARK: - Marginalia & Annotations (Plan 02)
    func loadAnnotations(for storyId: UUID) {
        self.activeStoryAnnotations = PersistenceService.shared.fetchAnnotations(for: storyId)
    }
    
    func addAnnotation(
        story: Story,
        text: String,
        startOffset: Int,
        endOffset: Int,
        color: HighlightColor,
        note: String? = nil,
        pinToJournal: Bool = false
    ) {
        let annotation = Annotation(
            storyId: story.id,
            storyTitle: story.title,
            storyAuthor: story.author,
            utf16StartOffset: startOffset,
            utf16EndOffset: endOffset,
            selectedText: text,
            note: note,
            color: color,
            isPinnedToJournal: pinToJournal
        )
        activeStoryAnnotations.append(annotation)
        PersistenceService.shared.saveAnnotation(annotation)
        if pinToJournal {
            reloadPinnedQuotes()
        }
    }
    
    func deleteAnnotation(id: UUID, storyId: UUID) {
        activeStoryAnnotations.removeAll(where: { $0.id == id })
        PersistenceService.shared.deleteAnnotation(id: id)
        reloadPinnedQuotes()
    }
    
    func togglePinQuote(for annotation: Annotation) {
        var updated = annotation
        updated.isPinnedToJournal.toggle()
        PersistenceService.shared.saveAnnotation(updated)
        if let idx = activeStoryAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            activeStoryAnnotations[idx] = updated
        }
        reloadPinnedQuotes()
    }
    
    func clearUserStateOnSignOut() {
        UserDefaults.standard.removeObject(forKey: "fable_device_id")
        self.stories = []
        self.profileStories = []
        self.pinnedQuotes = []
        self.readingStats = PersistenceService.ReadingStatsSummary(storiesReadCount: 0, totalMinutesRead: 0, streakDays: 0)
        self.syncWithPersistence()
    }
}
