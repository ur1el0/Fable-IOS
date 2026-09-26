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
    @Published var readingStats: PersistenceService.ReadingStatsSummary = PersistenceService.ReadingStatsSummary(storiesReadCount: 0, totalMinutesRead: 0, streakDays: 0)
    
    // Writing Draft
    @Published var draftTitle: String = ""
    @Published var draftGenre: String = "Folklore"
    @Published var draftChapter: String = "Chapter I"
    @Published var draftSynopsis: String = ""
    @Published var draftManuscript: String = ""
    
    // These collections populate from the server; cached stories remain available offline.
    @Published var genres: [GenreCategory] = []
    
    @Published var writers: [Writer] = []
    
    // User Profile Stories
    @Published var profileStories: [Story] = []
    
    init() {
        loadReaderPreferences()
        restoreDiscoveryCache()
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
            readingTimeMinutes: max(1, draftWordCount / 150),
            totalPages: 1,
            currentPage: 1,
            progressPercent: 0,
            rating: 0,
            isRecentSubmission: true
        )
        stories.insert(newStory, at: 0)
        profileStories.insert(newStory, at: 0)
        isStoryPublished = true
        if hapticFeedback {
            HapticManager.notification(type: .success)
        }
        
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
        // Hydrate and reconcile from SQLite
        let persisted = PersistenceService.shared.fetchAllStories()
        if !persisted.isEmpty {
            for entity in persisted {
                let provider = SourceProvider(rawValue: entity.sourceProviderRaw ?? "FABLE_ORIGINAL") ?? .fableOriginal
                if provider != .fableOriginal && (entity.providerId?.isEmpty ?? true) {
                    continue
                }

                if let idx = stories.firstIndex(where: { $0.id == entity.id }) {
                    stories[idx].isBookmarked = entity.isBookmarked
                    stories[idx].isCompleted = entity.isCompleted
                    stories[idx].progressPercent = Int(entity.readingProgress * 100.0)
                    stories[idx].currentPage = max(1, entity.currentPage)
                    stories[idx].totalPages = max(1, entity.totalPages)
                    stories[idx].coverImageName = nil
                    stories[idx].heroImageName = nil
                    stories[idx].coverImageUrl = validCoverImageURL(entity.coverImageUrl)
                    stories[idx].providerId = entity.providerId
                    stories[idx].providerDownloadCount = entity.providerDownloadCount
                    stories[idx].contentFormat = ContentFormat(rawValue: entity.contentFormatRaw ?? "PROSE") ?? .prose
                    stories[idx].sourceProvider = SourceProvider(rawValue: entity.sourceProviderRaw ?? "FABLE_ORIGINAL") ?? .fableOriginal
                    let cachedChapters = PersistenceService.shared.cachedChapters(storyId: entity.id)
                    if !cachedChapters.isEmpty { stories[idx].chapters = cachedChapters }
                    stories[idx].lastReadChapterId = entity.lastReadChapterId
                    stories[idx].lastReadChapterNumber = entity.lastReadChapterNumber
                } else {
                    let userStory = Story(
                        id: entity.id,
                        title: entity.title,
                        author: entity.author,
                        genre: entity.genreRaw,
                        excerpt: entity.synopsis,
                        paragraphs: [entity.content],
                        contentFormat: ContentFormat(rawValue: entity.contentFormatRaw ?? "PROSE") ?? .prose,
                        sourceProvider: provider,
                        providerId: entity.providerId,
                        providerDownloadCount: entity.providerDownloadCount,
                        chapters: PersistenceService.shared.cachedChapters(storyId: entity.id),
                        coverImageName: nil,
                        heroImageName: nil,
                        coverImageUrl: validCoverImageURL(entity.coverImageUrl),
                        readingTimeMinutes: entity.readTimeMinutes,
                        totalPages: max(1, entity.totalPages),
                        currentPage: max(1, entity.currentPage),
                        progressPercent: Int(entity.readingProgress * 100.0),
                        rating: 0,
                        isRecentSubmission: true,
                        isSaved: entity.isBookmarked,
                        isFinished: entity.isCompleted,
                        lastReadChapterId: entity.lastReadChapterId,
                        lastReadChapterNumber: entity.lastReadChapterNumber
                    )
                    stories.insert(userStory, at: 0)
                    if let session = AuthManager.shared.currentSession,
                       !session.isGuest,
                       normalizedCatalogValue(userStory.author) == normalizedCatalogValue(session.name) {
                        profileStories.insert(userStory, at: 0)
                    }
                }
            }
        }
        
        reloadPinnedQuotes()
        reloadReadingStats()
    }
    
    func reloadReadingStats() {
        self.readingStats = PersistenceService.shared.fetchReadingStats()
    }
    
    func reloadPinnedQuotes() {
        self.pinnedQuotes = PersistenceService.shared.fetchAllPinnedAnnotations()
    }
    
    private func restoreDiscoveryCache() {
        if let data = UserDefaults.standard.data(forKey: "fable_cached_genres"),
           let cached = try? JSONDecoder().decode([GenreCategory].self, from: data) {
            genres = cached
        }
        if let data = UserDefaults.standard.data(forKey: "fable_cached_writers"),
           let cached = try? JSONDecoder().decode([Writer].self, from: data) {
            writers = cached
        }
    }

    private func persistDiscoveryCache<Value: Encodable>(_ values: Value, key: String) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Cloud Synchronization Pipeline (Plan 05)
    func syncWithCloudBackend() async {
        isCloudSyncActive = true
        defer { isCloudSyncActive = false }
        
        do {
            // 1. Fetch live remote stories from FastAPI
            let remoteStories = try await apiService.fetchStories(genre: nil, search: nil)
            self.isBackendReachable = true
            
            var synchronizedStoryIds = Set<UUID>()
            for remote in remoteStories {
                if remote.sourceProvider != .fableOriginal && (remote.providerId?.isEmpty ?? true) {
                    continue
                }
                if let index = liveStoryIndex(matching: remote, excluding: synchronizedStoryIds) {
                    synchronizedStoryIds.insert(stories[index].id)
                    stories[index].isBookmarked = stories[index].isBookmarked || remote.isBookmarked
                    stories[index].coverImageUrl = validCoverImageURL(remote.coverImageUrl)
                    if remote.contentFormat == .manga {
                        stories[index].coverImageName = nil
                        stories[index].heroImageName = nil
                    }
                    stories[index].totalChapters = remote.totalChapters
                    stories[index].contentFormat = remote.contentFormat
                    stories[index].sourceProvider = remote.sourceProvider
                    if let downloadCount = remote.providerDownloadCount { stories[index].providerDownloadCount = downloadCount }
                    if let providerId = remote.providerId { stories[index].providerId = providerId }
                    if remote.isTaleOfTheDay { stories[index].isTaleOfTheDay = true }
                    if remote.isCuratorSpotlight { stories[index].isCuratorSpotlight = true }
                    PersistenceService.shared.saveStory(stories[index])
                } else {
                    var fetchedStory = remote
                    fetchedStory.coverImageUrl = validCoverImageURL(remote.coverImageUrl)
                    if fetchedStory.contentFormat == .manga {
                        fetchedStory.coverImageName = nil
                        fetchedStory.heroImageName = nil
                    }
                    stories.append(fetchedStory)
                    synchronizedStoryIds.insert(fetchedStory.id)
                    PersistenceService.shared.saveStory(fetchedStory)
                }
            }

            await fetchGutenbergPublicStories(topic: "fiction", search: nil)
            
            // 2. Fetch live dynamic categories/genres from backend
            if let liveGenres = try? await apiService.fetchGenres() {
                self.genres = liveGenres
                persistDiscoveryCache(liveGenres, key: "fable_cached_genres")
            }
            
            // 3. Fetch live trending authors from backend/Open Library
            if let liveWriters = try? await apiService.fetchTopAuthors() {
                self.writers = liveWriters
                persistDiscoveryCache(liveWriters, key: "fable_cached_writers")
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
    
    private func liveStoryIndex(matching remote: Story, excluding matchedIds: Set<UUID>) -> Int? {
        if let exactIndex = stories.firstIndex(where: { $0.id == remote.id && !matchedIds.contains($0.id) }) {
            return exactIndex
        }

        let remoteTitle = normalizedCatalogValue(remote.title)
        let remoteAuthor = normalizedCatalogValue(remote.author)
        let matchingCatalogStories = stories.indices.filter { index in
            let story = stories[index]
            return !matchedIds.contains(story.id)
                && normalizedCatalogValue(story.title) == remoteTitle
                && normalizedCatalogValue(story.author) == remoteAuthor
        }
        return matchingCatalogStories.first(where: { stories[$0].sourceProvider == remote.sourceProvider })
            ?? matchingCatalogStories.first
    }

    private func normalizedCatalogValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func validCoverImageURL(_ value: String?) -> String? {
        guard
            let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            let url = URL(string: value),
            url.scheme?.lowercased() == "https",
            let host = url.host?.lowercased(),
            host != "images.unsplash.com"
        else {
            return nil
        }
        return url.absoluteString
    }

    /// Loads authentic chapters on demand for the active reading story
    func fetchChapters(for story: Story) async -> [Chapter] {
        if let existing = story.chapters, !existing.isEmpty {
            return existing
        }
        let cached = PersistenceService.shared.cachedChapters(storyId: story.id)
        if !cached.isEmpty {
            return cached
        }
        do {
            let fetched = try await apiService.fetchChapters(for: story.id, sourceProvider: story.sourceProvider.rawValue, providerId: story.providerId)
            if let idx = stories.firstIndex(where: { $0.id == story.id }) {
                stories[idx].chapters = fetched
                stories[idx].totalChapters = max(1, fetched.count)
            }
            if activeReaderStory?.id == story.id {
                activeReaderStory?.chapters = fetched
                activeReaderStory?.totalChapters = max(1, fetched.count)
            }
            let updatedStory = stories.first(where: { $0.id == story.id }) ?? story
            PersistenceService.shared.saveStory(updatedStory)
            PersistenceService.shared.saveCachedChapters(fetched, storyId: story.id)
            return fetched
        } catch {
            return []
        }
    }

    
    func fetchGutenbergPublicStories(topic: String? = nil, search: String? = nil) async {
        do {
            let fetched = try await apiService.fetchGutenbergStories(topic: topic, search: search)
            for book in fetched {
                if let index = stories.firstIndex(where: { $0.id == book.id }) {
                    stories[index].synopsis = book.synopsis
                    stories[index].coverImageUrl = validCoverImageURL(book.coverImageUrl)
                    stories[index].contentFormat = book.contentFormat
                    stories[index].sourceProvider = book.sourceProvider
                    stories[index].providerId = book.providerId
                    stories[index].providerDownloadCount = book.providerDownloadCount
                    stories[index].totalChapters = max(stories[index].chapters?.count ?? 0, book.totalChapters)
                    PersistenceService.shared.saveStory(stories[index])
                } else {
                    var liveBook = book
                    liveBook.coverImageUrl = validCoverImageURL(book.coverImageUrl)
                    stories.append(liveBook)
                    PersistenceService.shared.saveStory(liveBook)
                }
            }
        } catch {
            // Keep the last persisted catalog available when the provider cannot be reached.
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
        if hapticFeedback {
            HapticManager.notification(type: .success)
        }
        
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
    
    func updateReadingProgress(for storyId: UUID, chapterId: String, chapterNumber: Int) {
        if let index = stories.firstIndex(where: { $0.id == storyId }) {
            stories[index].lastReadChapterId = chapterId
            stories[index].lastReadChapterNumber = chapterNumber
        }

        if let profileIndex = profileStories.firstIndex(where: { $0.id == storyId }) {
            profileStories[profileIndex].lastReadChapterId = chapterId
            profileStories[profileIndex].lastReadChapterNumber = chapterNumber
        }

        PersistenceService.shared.updateReadingProgress(
            storyId: storyId,
            chapterId: chapterId,
            chapterNumber: chapterNumber
        )
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
