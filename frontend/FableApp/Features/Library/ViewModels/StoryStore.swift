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
    @Published var isPublishingStory: Bool = false
    @Published var publishErrorMessage: String?
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
    @Published var autoArchiveCompletedStories: Bool = false {
        didSet {
            UserDefaults.standard.set(autoArchiveCompletedStories, forKey: "fable_pref_auto_archive_completed")
            if autoArchiveCompletedStories {
                archiveCompletedStories()
            }
        }
    }
    @Published var isPaginatedMode: Bool = false {
        didSet { UserDefaults.standard.set(isPaginatedMode, forKey: "fable_pref_reader_paginated") }
    }

    // Cloud Synchronization Pipeline (Plan 05)
    @Published var isCloudSyncActive: Bool = false
    @Published var isBackendReachable: Bool = false
    private let apiService: StoryAPIServiceProtocol = StoryAPIService()

    public var persistentDeviceId: UUID {
        let ownerKey = AuthManager.shared.currentSession?.id.uuidString ?? "guest"
        let key = "fable_device_id_\(ownerKey)"
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
    @Published var draftTitle: String = "" { didSet { persistWriterDraft() } }
    @Published var draftGenre: String = "" { didSet { persistWriterDraft() } }
    @Published var draftChapter: String = "" { didSet { persistWriterDraft() } }
    @Published var draftSynopsis: String = "" { didSet { persistWriterDraft() } }
    @Published var draftManuscript: String = "" { didSet { persistWriterDraft() } }
    private var isRestoringWriterDraft = false
    private var writerDraftOwnerKey = AuthManager.shared.currentSession?.id.uuidString ?? "guest"
    private var activeShelfOwnerKey = AuthManager.shared.currentSession?.id.uuidString ?? "signed_out"

    private struct LocalShelfState: Codable {
        var readingProgress: Double
        var isBookmarked: Bool
        var isCompleted: Bool
        var currentPage: Int
        var totalPages: Int
        var lastReadChapterId: String?
        var lastReadChapterNumber: Int?
        var updatedAtUtc: Date

        nonisolated static let empty = LocalShelfState(
            readingProgress: 0,
            isBookmarked: false,
            isCompleted: false,
            currentPage: 1,
            totalPages: 1,
            lastReadChapterId: nil,
            lastReadChapterNumber: nil,
            updatedAtUtc: .distantPast
        )

        init(
            readingProgress: Double,
            isBookmarked: Bool,
            isCompleted: Bool,
            currentPage: Int,
            totalPages: Int,
            lastReadChapterId: String?,
            lastReadChapterNumber: Int?,
            updatedAtUtc: Date
        ) {
            self.readingProgress = readingProgress
            self.isBookmarked = isBookmarked
            self.isCompleted = isCompleted
            self.currentPage = currentPage
            self.totalPages = totalPages
            self.lastReadChapterId = lastReadChapterId
            self.lastReadChapterNumber = lastReadChapterNumber
            self.updatedAtUtc = updatedAtUtc
        }

        init(story: Story, updatedAtUtc: Date = Date()) {
            self.readingProgress = Double(story.progressPercent) / 100.0
            self.isBookmarked = story.isBookmarked
            self.isCompleted = story.isCompleted
            self.currentPage = story.currentPage
            self.totalPages = story.totalPages
            self.lastReadChapterId = story.lastReadChapterId
            self.lastReadChapterNumber = story.lastReadChapterNumber
            self.updatedAtUtc = updatedAtUtc
        }

        var isEmpty: Bool {
            readingProgress == 0 && !isBookmarked && !isCompleted
                && lastReadChapterId == nil && lastReadChapterNumber == nil
        }

        func syncItem(storyId: UUID) -> ShelfSyncItem {
            ShelfSyncItem(
                storyId: storyId,
                readingProgress: readingProgress,
                isBookmarked: isBookmarked,
                isCompleted: isCompleted,
                updatedAtUtc: updatedAtUtc
            )
        }

        init(syncItem: ShelfSyncItem, previous: LocalShelfState = .empty) {
            self.readingProgress = syncItem.readingProgress
            self.isBookmarked = syncItem.isBookmarked
            self.isCompleted = syncItem.isCompleted
            self.currentPage = previous.currentPage
            self.totalPages = previous.totalPages
            self.lastReadChapterId = previous.lastReadChapterId
            self.lastReadChapterNumber = previous.lastReadChapterNumber
            self.updatedAtUtc = syncItem.updatedAtUtc
        }
    }

    private struct WriterDraft: Codable {
        let title: String
        let genre: String
        let chapter: String
        let synopsis: String
        let manuscript: String
    }

    // These collections populate from the server; cached stories remain available offline.
    @Published var genres: [GenreCategory] = []

    @Published var writers: [Writer] = []

    // User Profile Stories
    @Published var profileStories: [Story] = []

    init() {
        PersistenceService.shared.purgeLegacyDemoStories()
        loadReaderPreferences()
        restoreDiscoveryCache()
        restoreWriterDraft()
        syncWithPersistence()
        restoreShelfStateForCurrentSession(migrateGuestState: AuthManager.shared.currentSession?.isGuest == true)
        if autoArchiveCompletedStories { archiveCompletedStories() }
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
        self.autoArchiveCompletedStories = UserDefaults.standard.bool(forKey: "fable_pref_auto_archive_completed")
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

    private var writerDraftStorageKey: String {
        "fable_writer_draft_\(writerDraftOwnerKey)"
    }

    private func persistWriterDraft() {
        guard !isRestoringWriterDraft else { return }
        let draft = WriterDraft(
            title: draftTitle,
            genre: draftGenre,
            chapter: draftChapter,
            synopsis: draftSynopsis,
            manuscript: draftManuscript
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: writerDraftStorageKey)
    }

    private func restoreWriterDraft() {
        writerDraftOwnerKey = AuthManager.shared.currentSession?.id.uuidString ?? "guest"
        isRestoringWriterDraft = true
        defer { isRestoringWriterDraft = false }
        guard let data = UserDefaults.standard.data(forKey: writerDraftStorageKey),
              let draft = try? JSONDecoder().decode(WriterDraft.self, from: data) else {
            draftTitle = ""
            draftGenre = ""
            draftChapter = ""
            draftSynopsis = ""
            draftManuscript = ""
            return
        }
        draftTitle = draft.title
        draftGenre = draft.genre
        draftChapter = draft.chapter
        draftSynopsis = draft.synopsis
        draftManuscript = draft.manuscript
    }

    func clearWriterDraft() {
        clearWriterDraft(ownerID: nil)
    }

    private func clearWriterDraft(ownerID: UUID?) {
        let ownerKey = ownerID?.uuidString ?? writerDraftOwnerKey
        UserDefaults.standard.removeObject(forKey: "fable_writer_draft_\(ownerKey)")
        guard ownerKey == writerDraftOwnerKey else { return }
        isRestoringWriterDraft = true
        draftTitle = ""
        draftGenre = ""
        draftChapter = ""
        draftSynopsis = ""
        draftManuscript = ""
        isRestoringWriterDraft = false
    }

    func restoreWriterDraftForCurrentSession() {
        restoreWriterDraft()
    }

    func publishStory() async -> Story? {
        publishErrorMessage = nil
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let genre = draftGenre.trimmingCharacters(in: .whitespacesAndNewlines)
        let chapter = draftChapter.trimmingCharacters(in: .whitespacesAndNewlines)
        let synopsis = draftSynopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        let manuscript = draftManuscript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty, title.unicodeScalars.count <= CreateStoryRequest.maximumTitleLength else {
            publishErrorMessage = "Enter a title with 1 to 120 characters."
            return nil
        }
        guard !genre.isEmpty else {
            publishErrorMessage = "Choose or enter a genre."
            return nil
        }
        guard genre.unicodeScalars.count <= CreateStoryRequest.maximumGenreLength else {
            publishErrorMessage = "Keep the genre to 50 characters or fewer."
            return nil
        }
        guard chapter.unicodeScalars.count <= CreateStoryRequest.maximumChapterLength else {
            publishErrorMessage = "Keep the chapter title to 120 characters or fewer."
            return nil
        }
        guard !synopsis.isEmpty else {
            publishErrorMessage = "Add a synopsis before publishing."
            return nil
        }
        guard synopsis.unicodeScalars.count <= CreateStoryRequest.maximumSynopsisLength else {
            publishErrorMessage = "Keep the synopsis to 2,000 characters or fewer."
            return nil
        }
        guard !manuscript.isEmpty else {
            publishErrorMessage = "Add manuscript text before publishing."
            return nil
        }
        guard manuscript.unicodeScalars.count <= CreateStoryRequest.maximumContentLength else {
            publishErrorMessage = "Keep the manuscript to 50,000 characters or fewer."
            return nil
        }
        guard let session = AuthManager.shared.currentSession, !session.isGuest,
              let token = KeychainStore.shared.readAccessToken() else {
            publishErrorMessage = "Sign in with an account to publish this story online. Your draft is saved on this device."
            return nil
        }

        isPublishingStory = true
        defer { isPublishingStory = false }
        let request = CreateStoryRequest(
            title: title,
            genre: genre,
            chapter: chapter,
            synopsis: synopsis,
            content: manuscript,
            readTimeMinutes: max(1, draftWordCount / 150)
        )

        do {
            let publishedStory = try await apiService.createStory(request, token: token)
            stories.removeAll { $0.id == publishedStory.id }
            stories.insert(publishedStory, at: 0)
            PersistenceService.shared.saveStory(publishedStory)
            if AuthManager.shared.currentSession?.id == session.id {
                profileStories.removeAll { $0.id == publishedStory.id }
                profileStories.insert(publishedStory, at: 0)
                persistProfileStoriesCache(profileStories, for: session.id)
            }
            isStoryPublished = true
            clearWriterDraft(ownerID: session.id)
            if hapticFeedback {
                HapticManager.notification(type: .success)
            }
            return publishedStory
        } catch let error as APIRequestError {
            publishErrorMessage = error.message
            return nil
        } catch {
            publishErrorMessage = "Publishing failed. Your draft remains saved on this device. Check your connection and try again."
            return nil
        }
    }

    private func profileStoriesCacheKey(for userID: UUID) -> String {
        "fable_profile_stories_\(userID.uuidString)"
    }

    private func persistProfileStoriesCache(_ stories: [Story], for userID: UUID) {
        guard let data = try? JSONEncoder().encode(stories) else { return }
        UserDefaults.standard.set(data, forKey: profileStoriesCacheKey(for: userID))
    }

    func loadMyPublishedStories() async {
        guard let session = AuthManager.shared.currentSession, !session.isGuest else {
            profileStories = []
            return
        }
        let cacheKey = profileStoriesCacheKey(for: session.id)
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cachedStories = try? JSONDecoder().decode([Story].self, from: data) {
            profileStories = cachedStories
        }
        guard let token = KeychainStore.shared.readAccessToken() else { return }
        do {
            let ownedStories = try await apiService.fetchMyStories(token: token)
            guard AuthManager.shared.currentSession?.id == session.id else { return }
            profileStories = ownedStories
            persistProfileStoriesCache(ownedStories, for: session.id)
            for story in ownedStories {
                PersistenceService.shared.saveStory(story)
            }
        } catch {
            // Keep the account-scoped last-known author list available offline.
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

                if let idx = stories.firstIndex(where: {
                    $0.id == entity.id || (entity.providerId != nil && !entity.providerId!.isEmpty && $0.providerId == entity.providerId)
                }) {
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
                    let isUsable: Bool
                    if stories[idx].contentFormat == .manga {
                        isUsable = cachedChapters.contains { !$0.pageUrls.isEmpty }
                    } else {
                        isUsable = cachedChapters.contains(where: \.hasReadableText)
                    }
                    if isUsable { stories[idx].chapters = cachedChapters }
                    stories[idx].lastReadChapterId = entity.lastReadChapterId
                    stories[idx].lastReadChapterNumber = entity.lastReadChapterNumber
                } else {
                    let initialCached = PersistenceService.shared.cachedChapters(storyId: entity.id)
                    let format = ContentFormat(rawValue: entity.contentFormatRaw ?? "PROSE") ?? .prose
                    let isUsableInitial = format == .manga
                        ? initialCached.contains { !$0.pageUrls.isEmpty }
                        : initialCached.contains(where: \.hasReadableText)
                    if provider != .fableOriginal
                        && !isUsableInitial
                        && entity.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !entity.isBookmarked
                        && !entity.isCompleted
                        && entity.readingProgress <= 0
                        && entity.lastReadChapterId == nil {
                        continue
                    }
                    let validInitial = isUsableInitial ? initialCached : nil
                    let userStory = Story(
                        id: entity.id,
                        title: entity.title,
                        author: entity.author,
                        genre: entity.genreRaw,
                        excerpt: entity.synopsis,
                        paragraphs: [entity.content],
                        coverImageName: nil,
                        heroImageName: nil,
                        coverImageUrl: validCoverImageURL(entity.coverImageUrl),
                        readingTimeMinutes: entity.readTimeMinutes,
                        totalPages: max(1, entity.totalPages),
                        currentPage: max(1, entity.currentPage),
                        progressPercent: Int(entity.readingProgress * 100.0),
                        rating: nil,
                        providerDownloadCount: entity.providerDownloadCount,
                        isRecentSubmission: false,
                        isSaved: entity.isBookmarked,
                        isFinished: entity.isCompleted,
                        contentFormat: ContentFormat(rawValue: entity.contentFormatRaw ?? "PROSE") ?? .prose,
                        sourceProvider: provider,
                        providerId: entity.providerId,
                        chapters: validInitial,
                        lastReadChapterId: entity.lastReadChapterId,
                        lastReadChapterNumber: entity.lastReadChapterNumber
                    )
                    stories.append(userStory)
                }
            }
        }

        let synthesized = deriveGenresFromCatalog(stories)
        for item in synthesized {
            if !genres.contains(where: { $0.name.caseInsensitiveCompare(item.name) == .orderedSame }) {
                genres.append(item)
            }
        }

        reloadPinnedQuotes()
        reloadReadingStats()
    }

    private var readingStatsCacheKey: String? {
        guard let session = AuthManager.shared.currentSession, !session.isGuest else { return nil }
        return "fable_reading_stats_\(session.id.uuidString)"
    }

    private var pendingReadingSessionsKey: String? {
        guard let session = AuthManager.shared.currentSession, !session.isGuest else { return nil }
        return "fable_pending_reading_sessions_\(session.id.uuidString)"
    }

    func reloadReadingStats() {
        guard let session = AuthManager.shared.currentSession else {
            readingStats = PersistenceService.ReadingStatsSummary(
                storiesReadCount: 0,
                totalMinutesRead: 0,
                streakDays: 0
            )
            return
        }
        let localStats = PersistenceService.shared.fetchReadingStats(ownerUserId: session.id)
        readingStats = localStats
        if let key = readingStatsCacheKey,
           let data = UserDefaults.standard.data(forKey: key),
           let cached = try? JSONDecoder().decode(ReadingStatsDTO.self, from: data) {
            readingStats = PersistenceService.ReadingStatsSummary(
                storiesReadCount: cached.storiesReadCount,
                totalMinutesRead: cached.totalMinutesRead,
                streakDays: cached.streakDays
            )
        }
        guard !session.isGuest else { return }
        Task { [weak self] in await self?.synchronizeReadingStats() }
    }

    private func synchronizeReadingStats() async {
        guard let session = AuthManager.shared.currentSession, !session.isGuest,
              let token = KeychainStore.shared.readAccessToken(),
              let queueKey = pendingReadingSessionsKey else { return }

        var pending = (try? JSONDecoder().decode(
            [ReadingSessionRequest].self,
            from: UserDefaults.standard.data(forKey: queueKey) ?? Data()
        )) ?? []
        while let event = pending.first {
            do {
                try await apiService.recordReadingSession(event, token: token)
                guard AuthManager.shared.currentSession?.id == session.id else { return }
                pending.removeFirst()
                if let data = try? JSONEncoder().encode(pending) {
                    UserDefaults.standard.set(data, forKey: queueKey)
                }
            } catch {
                return
            }
        }

        do {
            let stats = try await apiService.fetchReadingStats(token: token)
            guard AuthManager.shared.currentSession?.id == session.id else { return }
            readingStats = PersistenceService.ReadingStatsSummary(
                storiesReadCount: stats.storiesReadCount,
                totalMinutesRead: stats.totalMinutesRead,
                streakDays: stats.streakDays
            )
            if let key = readingStatsCacheKey, let data = try? JSONEncoder().encode(stats) {
                UserDefaults.standard.set(data, forKey: key)
            }
        } catch {
            // Keep the account-specific statistics cache available offline.
        }
    }

    func reloadPinnedQuotes() {
        self.pinnedQuotes = PersistenceService.shared.fetchAllPinnedAnnotations(
            ownerUserId: AuthManager.shared.currentSession?.id
        )
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
            await AuthManager.shared.syncPendingProfile()
            await loadMyPublishedStories()
            await synchronizeReadingStats()

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
                    if let badge = remote.badgeText { stories[index].badgeText = badge }
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
            await fetchMangaPublicStories(search: nil)

            // 2. Fetch live dynamic categories/genres from backend and merge catalog taxonomy
            let liveGenres = (try? await apiService.fetchGenres()) ?? []
            let synthesized = deriveGenresFromCatalog(stories)
            var mergedGenres = liveGenres
            for item in synthesized {
                if !mergedGenres.contains(where: { $0.name.caseInsensitiveCompare(item.name) == .orderedSame }) {
                    mergedGenres.append(item)
                }
            }
            if !mergedGenres.isEmpty {
                self.genres = mergedGenres
                persistDiscoveryCache(mergedGenres, key: "fable_cached_genres")
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

            // 5. Reconcile account-owned shelf state; guests stay local-only.
            await reconcileShelfWithAccount()
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
        let isUsable = { (chaps: [Chapter]?) -> Bool in
            guard let chaps, !chaps.isEmpty else { return false }
            if story.contentFormat == .manga {
                return chaps.contains { !$0.pageUrls.isEmpty }
            }
            return chaps.contains(where: \.hasReadableText)
        }

        if let existing = story.chapters, isUsable(existing) {
            return existing
        }
        let cached = PersistenceService.shared.cachedChapters(storyId: story.id)
        if isUsable(cached) {
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


    func searchCatalog(query: String) async {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return }

        if let remoteStories = try? await apiService.fetchStories(genre: nil, search: search) {
            for remote in remoteStories where remote.sourceProvider == .fableOriginal || remote.providerId?.isEmpty == false {
                guard !stories.contains(where: { $0.id == remote.id }) else { continue }
                var cached = remote
                cached.coverImageUrl = validCoverImageURL(remote.coverImageUrl)
                cached.coverImageName = nil
                cached.heroImageName = nil
                stories.append(cached)
                PersistenceService.shared.saveStory(cached)
            }
        }
        await fetchGutenbergPublicStories(topic: nil, search: search)
        await fetchMangaPublicStories(search: search)
    }

    func matchesAuthor(storyAuthor: String, writerName: String) -> Bool {
        let sAuthor = normalizedCatalogValue(storyAuthor)
        let wName = normalizedCatalogValue(writerName)
        if sAuthor.isEmpty || wName.isEmpty { return false }
        if sAuthor == wName || sAuthor.contains(wName) || wName.contains(sAuthor) {
            return true
        }
        let parts = writerName.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            let reversed = "\(parts.last ?? ""), \(parts.first ?? "")".lowercased()
            if sAuthor.contains(normalizedCatalogValue(reversed)) {
                return true
            }
            let tokens = parts.map { normalizedCatalogValue($0) }.filter { $0.count > 1 }
            if !tokens.isEmpty && tokens.allSatisfy({ sAuthor.contains($0) }) {
                return true
            }
        }
        return false
    }

    func stories(for writer: Writer) -> [Story] {
        stories
            .filter { matchesAuthor(storyAuthor: $0.author, writerName: writer.name) }
            .sorted { ($0.providerDownloadCount ?? 0) > ($1.providerDownloadCount ?? 0) }
    }

    func fetchAuthorStories(for writer: Writer) async -> [Story] {
        async let gutenbergSearch: () = fetchGutenbergPublicStories(topic: nil, search: writer.name)
        async let mangaSearch: () = fetchMangaPublicStories(search: writer.name)
        _ = await (gutenbergSearch, mangaSearch)

        if let remoteStories = try? await apiService.fetchStories(genre: nil, search: writer.name) {
            for remote in remoteStories where remote.sourceProvider == .fableOriginal || remote.providerId?.isEmpty == false {
                guard !stories.contains(where: { $0.id == remote.id }) else { continue }
                var cached = remote
                cached.coverImageUrl = validCoverImageURL(remote.coverImageUrl)
                cached.coverImageName = nil
                cached.heroImageName = nil
                stories.append(cached)
                PersistenceService.shared.saveStory(cached)
            }
        }

        let matching = stories(for: writer)
        if !matching.isEmpty, let index = writers.firstIndex(where: { $0.id == writer.id }) {
            writers[index].storyCount = max(writers[index].storyCount, matching.count)
        }
        return matching
    }

    func topStory(for writer: Writer) async -> Story? {
        let authorStories = await fetchAuthorStories(for: writer)
        return authorStories.first ?? stories(for: writer).first
    }

    func fetchGutenbergPublicStories(topic: String? = nil, search: String? = nil) async {
        do {
            let fetched = try await apiService.fetchGutenbergStories(topic: topic, search: search)
            for book in fetched {
                if let index = stories.firstIndex(where: { $0.id == book.id }) {
                    stories[index].synopsis = book.synopsis
                    if !book.content.isEmpty {
                        stories[index].content = book.content
                    }
                    if book.readTimeMinutes > 0 {
                        stories[index].readTimeMinutes = book.readTimeMinutes
                    }
                    if let chaps = book.chapters, !chaps.isEmpty {
                        stories[index].chapters = chaps
                        PersistenceService.shared.saveCachedChapters(chaps, storyId: book.id)
                    }
                    stories[index].coverImageUrl = validCoverImageURL(book.coverImageUrl)
                    stories[index].contentFormat = book.contentFormat
                    stories[index].sourceProvider = book.sourceProvider
                    stories[index].providerId = book.providerId
                    stories[index].providerDownloadCount = book.providerDownloadCount
                    stories[index].totalChapters = max(stories[index].chapters?.count ?? 0, book.totalChapters)
                    if stories[index].progressPercent == 0,
                       let savedState = loadShelfStateCache()[stories[index].id.uuidString],
                       !savedState.isEmpty {
                        applyShelfState(savedState, to: &stories[index])
                    }
                    PersistenceService.shared.saveStory(stories[index])
                } else {
                    var liveBook = book
                    liveBook.coverImageUrl = validCoverImageURL(book.coverImageUrl)
                    if let savedState = loadShelfStateCache()[liveBook.id.uuidString] {
                        applyShelfState(savedState, to: &liveBook)
                    }
                    stories.append(liveBook)
                    PersistenceService.shared.saveStory(liveBook)
                    if let chaps = liveBook.chapters, !chaps.isEmpty {
                        PersistenceService.shared.saveCachedChapters(chaps, storyId: liveBook.id)
                    }
                }
            }
        } catch {
            // Keep the last persisted catalog available when the provider cannot be reached.
        }
    }

    func fetchMangaPublicStories(search: String? = nil) async {
        do {
            let fetched = try await apiService.fetchMangaStories(search: search)
            if search == nil && !fetched.isEmpty {
                let validProviderIds = Set(fetched.compactMap(\.providerId))
                stories.removeAll {
                    $0.sourceProvider == .mangadex
                        && !$0.isBookmarked
                        && !$0.isCompleted
                        && ($0.badgeText == "OFFICIAL LINK" || ($0.providerId != nil && !validProviderIds.contains($0.providerId!)))
                }
            }
            for manga in fetched {
                let matchingIndices = stories.indices.filter {
                    stories[$0].id == manga.id ||
                    (manga.providerId != nil && stories[$0].sourceProvider == manga.sourceProvider && stories[$0].providerId == manga.providerId)
                }

                if let firstIdx = matchingIndices.first {
                    stories[firstIdx].title = manga.title
                    stories[firstIdx].author = manga.author
                    stories[firstIdx].synopsis = manga.synopsis
                    stories[firstIdx].coverImageUrl = validCoverImageURL(manga.coverImageUrl)
                    stories[firstIdx].contentFormat = manga.contentFormat
                    stories[firstIdx].sourceProvider = manga.sourceProvider
                    stories[firstIdx].providerId = manga.providerId
                    if let badge = manga.badgeText { stories[firstIdx].badgeText = badge }
                    stories[firstIdx].totalChapters = max(stories[firstIdx].chapters?.count ?? 0, manga.totalChapters)
                    if stories[firstIdx].progressPercent == 0,
                       let savedState = loadShelfStateCache()[stories[firstIdx].id.uuidString],
                       !savedState.isEmpty {
                        applyShelfState(savedState, to: &stories[firstIdx])
                    }
                    PersistenceService.shared.saveStory(stories[firstIdx])

                    if matchingIndices.count > 1 {
                        let dupIds = Set(matchingIndices.dropFirst().map { stories[$0].id })
                        stories.removeAll(where: { dupIds.contains($0.id) })
                    }
                } else {
                    var liveManga = manga
                    liveManga.contentFormat = .manga
                    liveManga.isRecentSubmission = true
                    liveManga.coverImageUrl = validCoverImageURL(manga.coverImageUrl)
                    if let savedState = loadShelfStateCache()[liveManga.id.uuidString] {
                        applyShelfState(savedState, to: &liveManga)
                    }
                    stories.append(liveManga)
                    PersistenceService.shared.saveStory(liveManga)
                }
            }
            let synthesized = deriveGenresFromCatalog(stories)
            for item in synthesized {
                if !genres.contains(where: { $0.name.caseInsensitiveCompare(item.name) == .orderedSame }) {
                    genres.append(item)
                }
            }
        } catch {
            // Keep existing catalog available
        }
    }

    private func deriveGenresFromCatalog(_ catalog: [Story]) -> [GenreCategory] {
        let candidates: [(name: String, matcher: (String) -> Bool)] = [
            ("Manga", { $0.contains("manga") }),
            ("Fiction", { $0.contains("fiction") }),
            ("Classics", { $0.contains("classic") || $0.contains("19th century") || $0.contains("literature") }),
            ("Sci-Fi", { $0.contains("sci-fi") || $0.contains("science fiction") || $0.contains("space") || $0.contains("time") }),
            ("Gothic", { $0.contains("gothic") || $0.contains("vampire") || $0.contains("dracula") || $0.contains("frankenstein") || $0.contains("monster") }),
            ("Romance", { $0.contains("romance") || $0.contains("courtship") || $0.contains("love") || $0.contains("pride") }),
            ("Adventure", { $0.contains("adventure") || $0.contains("voyage") || $0.contains("sea") || $0.contains("journey") }),
            ("Horror", { $0.contains("horror") || $0.contains("ghost") || $0.contains("supernatural") || $0.contains("terror") })
        ]

        var results: [GenreCategory] = []
        for (name, matcher) in candidates {
            let matchingStories = catalog.filter { story in
                let g = (story.genre.rawValue + " " + story.title + " " + story.synopsis).lowercased()
                return matcher(g)
            }
            if !matchingStories.isEmpty {
                results.append(
                    GenreCategory(
                        id: UUID(),
                        name: name,
                        storyCount: matchingStories.count,
                        readersCount: "\(matchingStories.count * 15 + 40)",
                        description: "Curated \(name.lowercased()) works from our digital collection.",
                        imageName: "",
                        imageUrl: nil
                    )
                )
            }
        }
        return results
    }

    public func storyMatchesCategory(_ story: Story, category: String) -> Bool {
        if category == "All" { return true }
        if category == "Manga" {
            return story.contentFormat == .manga || story.genre == .manga || story.sourceProvider == .mangadex
        }
        let lowerCat = category.lowercased()
        let haystack = (story.genre.rawValue + " " + story.title + " " + story.synopsis).lowercased()
        switch lowerCat {
        case "fiction":
            return haystack.contains("fiction") || story.contentFormat == .prose
        case "classics":
            return haystack.contains("classic") || haystack.contains("literature") || haystack.contains("19th century") || story.sourceProvider == .gutenberg
        case "sci-fi":
            return haystack.contains("sci-fi") || haystack.contains("science fiction") || haystack.contains("space") || haystack.contains("time")
        case "gothic":
            return haystack.contains("gothic") || haystack.contains("vampire") || haystack.contains("dracula") || haystack.contains("frankenstein") || haystack.contains("monster")
        case "romance":
            return haystack.contains("romance") || haystack.contains("courtship") || haystack.contains("love") || haystack.contains("pride")
        case "adventure":
            return haystack.contains("adventure") || haystack.contains("voyage") || haystack.contains("sea") || haystack.contains("journey")
        case "horror":
            return haystack.contains("horror") || haystack.contains("ghost") || haystack.contains("supernatural") || haystack.contains("terror")
        default:
            return haystack.contains(lowerCat)
        }
    }

    private var shelfStateStorageKey: String {
        "fable_shelf_state_\(activeShelfOwnerKey)"
    }

    private func loadShelfStateCache() -> [String: LocalShelfState] {
        guard let data = UserDefaults.standard.data(forKey: shelfStateStorageKey),
              let states = try? JSONDecoder().decode([String: LocalShelfState].self, from: data) else {
            return [:]
        }
        return states
    }

    private func saveShelfStateCache(_ states: [String: LocalShelfState]) {
        guard let data = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(data, forKey: shelfStateStorageKey)
    }

    private func persistShelfState(for story: Story, updatedAt: Date = Date()) {
        var states = loadShelfStateCache()
        states[story.id.uuidString] = LocalShelfState(story: story, updatedAtUtc: updatedAt)
        saveShelfStateCache(states)
    }

    private func applyShelfState(_ state: LocalShelfState, to story: inout Story) {
        story.progressPercent = min(100, max(0, Int(state.readingProgress * 100)))
        story.isBookmarked = state.isBookmarked
        story.isCompleted = state.isCompleted
        story.currentPage = max(1, state.currentPage)
        story.totalPages = max(1, state.totalPages)
        story.lastReadChapterId = state.lastReadChapterId
        story.lastReadChapterNumber = state.lastReadChapterNumber
    }

    private func applyShelfStateCache(_ states: [String: LocalShelfState]) {
        for index in stories.indices {
            let state = states[stories[index].id.uuidString] ?? .empty
            applyShelfState(state, to: &stories[index])
            PersistenceService.shared.saveStory(stories[index])
        }
        for index in profileStories.indices {
            let state = states[profileStories[index].id.uuidString] ?? .empty
            applyShelfState(state, to: &profileStories[index])
        }
    }

    private func restoreShelfStateForCurrentSession(migrateGuestState: Bool) {
        if let data = UserDefaults.standard.data(forKey: shelfStateStorageKey),
           let existing = try? JSONDecoder().decode([String: LocalShelfState].self, from: data) {
            applyShelfStateCache(existing)
            return
        }
        guard let session = AuthManager.shared.currentSession else { return }
        if session.isGuest && migrateGuestState {
            var legacyStates: [String: LocalShelfState] = [:]
            for story in stories {
                let state = LocalShelfState(story: story)
                if !state.isEmpty { legacyStates[story.id.uuidString] = state }
            }
            saveShelfStateCache(legacyStates)
        } else {
            applyShelfStateCache([:])
            saveShelfStateCache([:])
        }
    }

    private func storeServerShelfState(_ item: ShelfSyncItem) {
        var states = loadShelfStateCache()
        let state = LocalShelfState(
            syncItem: item,
            previous: states[item.storyId.uuidString] ?? .empty
        )
        states[item.storyId.uuidString] = state
        saveShelfStateCache(states)
        if let index = stories.firstIndex(where: { $0.id == item.storyId }) {
            applyShelfState(state, to: &stories[index])
            PersistenceService.shared.saveStory(stories[index])
        }
        if let index = profileStories.firstIndex(where: { $0.id == item.storyId }) {
            applyShelfState(state, to: &profileStories[index])
        }
    }

    private func syncShelfToAccount(_ items: [ShelfSyncItem]) async -> [ShelfSyncItem]? {
        guard let session = AuthManager.shared.currentSession, !session.isGuest,
              let token = KeychainStore.shared.readAccessToken() else { return nil }
        do {
            let requestSessionID = session.id
            let reconciled = try await apiService.syncShelf(
                deviceId: persistentDeviceId,
                token: token,
                items: items
            )
            guard AuthManager.shared.currentSession?.id == requestSessionID else { return nil }
            for item in reconciled { storeServerShelfState(item) }
            return reconciled
        } catch {
            return nil
        }
    }

    private func gutenbergProviderID(for storyID: UUID) -> String? {
        let compactID = storyID.uuidString.replacingOccurrences(of: "-", with: "")
        guard compactID.prefix(24).allSatisfy({ $0 == "0" }),
              let providerID = UInt32(compactID.suffix(8), radix: 16),
              providerID > 0 else { return nil }
        return String(providerID)
    }

    private func reconcileShelfWithAccount() async {
        guard let session = AuthManager.shared.currentSession, !session.isGuest,
              let token = KeychainStore.shared.readAccessToken() else { return }
        do {
            let remoteItems = try await apiService.fetchShelf(deviceId: persistentDeviceId, token: token)
            guard AuthManager.shared.currentSession?.id == session.id else { return }
            for item in remoteItems where !stories.contains(where: { $0.id == item.storyId }) {
                guard let providerID = gutenbergProviderID(for: item.storyId),
                      let providerStory = try? await apiService.fetchGutenbergStory(providerId: providerID),
                      AuthManager.shared.currentSession?.id == session.id else { continue }
                stories.append(providerStory)
                PersistenceService.shared.saveStory(providerStory)
            }
            let remoteByStory = Dictionary(uniqueKeysWithValues: remoteItems.map { ($0.storyId, $0) })
            var pending: [ShelfSyncItem] = []
            let localStates = loadShelfStateCache()

            for remote in remoteItems {
                if let local = localStates[remote.storyId.uuidString], local.updatedAtUtc > remote.updatedAtUtc {
                    pending.append(local.syncItem(storyId: remote.storyId))
                } else {
                    storeServerShelfState(remote)
                }
            }
            for (storyID, state) in localStates {
                guard let id = UUID(uuidString: storyID), remoteByStory[id] == nil else { continue }
                pending.append(state.syncItem(storyId: id))
            }
            if !pending.isEmpty { _ = await syncShelfToAccount(pending) }
        } catch {
            // Local account cache remains available when shelf synchronization is offline.
        }
    }

    func sessionDidChange() {
        let nextOwner = AuthManager.shared.currentSession?.id.uuidString ?? "signed_out"
        guard nextOwner != activeShelfOwnerKey else { return }
        if activeShelfOwnerKey != "signed_out" {
            var states = loadShelfStateCache()
            for story in stories {
                let previous = states[story.id.uuidString]
                let state = LocalShelfState(story: story, updatedAtUtc: previous?.updatedAtUtc ?? Date())
                if !state.isEmpty || previous != nil { states[story.id.uuidString] = state }
            }
            saveShelfStateCache(states)
        }
        activeShelfOwnerKey = nextOwner
        if AuthManager.shared.currentSession == nil {
            clearVisibleShelfState()
        } else {
            activeStoryAnnotations = []
            restoreShelfStateForCurrentSession(migrateGuestState: false)
            restoreWriterDraft()
            reloadPinnedQuotes()
            reloadReadingStats()
            Task { [weak self] in await self?.syncWithCloudBackend() }
        }
    }

    private func clearVisibleShelfState() {
        for index in stories.indices { applyShelfState(.empty, to: &stories[index]) }
        for index in profileStories.indices { applyShelfState(.empty, to: &profileStories[index]) }
        profileStories = []
        pinnedQuotes = []
        activeStoryAnnotations = []
        readingStats = PersistenceService.ReadingStatsSummary(storiesReadCount: 0, totalMinutesRead: 0, streakDays: 0)
    }

    // MARK: - Actions
    func toggleBookmark(for story: Story) {
        let nextBookmarkState = !(stories.first(where: { $0.id == story.id })?.isBookmarked ?? story.isBookmarked)
        if let idx = stories.firstIndex(where: { $0.id == story.id }) {
            stories[idx].isBookmarked = nextBookmarkState
        }
        if let idx = profileStories.firstIndex(where: { $0.id == story.id }) {
            profileStories[idx].isBookmarked = nextBookmarkState
        }
        PersistenceService.shared.setBookmark(storyId: story.id, isBookmarked: nextBookmarkState)
        let current = stories.first(where: { $0.id == story.id })
            ?? profileStories.first(where: { $0.id == story.id })
            ?? story
        persistShelfState(for: current)
        if hapticFeedback {
            HapticManager.notification(type: .success)
        }

        let item = ShelfSyncItem(
            storyId: story.id,
            readingProgress: Double(current.progressPercent) / 100.0,
            isBookmarked: nextBookmarkState,
            isCompleted: current.isCompleted,
            updatedAtUtc: Date()
        )
        Task { [weak self] in
            guard let self else { return }
            if nextBookmarkState {
                let chaps = await self.fetchChapters(for: current)
                if current.contentFormat == .manga, let firstChap = chaps.first {
                    let urls = firstChap.pageUrls.compactMap { URL(string: $0) }
                    if !urls.isEmpty {
                        await DiskImageCache.shared.prefetch(urls: urls)
                    }
                }
            }
            _ = await self.syncShelfToAccount([item])
        }
    }

    func updateProgress(
        for storyId: UUID,
        page: Int,
        totalPages: Int,
        chapterIndex: Int? = nil,
        totalChapters: Int? = nil,
        chapterId: String? = nil,
        chapterNumber: Int? = nil
    ) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            let safePage = max(1, page)
            let safeTotalPages = max(1, totalPages)
            stories[idx].currentPage = safePage
            stories[idx].totalPages = safeTotalPages
            if let chapterId {
                stories[idx].lastReadChapterId = chapterId
            }
            if let chapterNumber {
                stories[idx].lastReadChapterNumber = chapterNumber
            }

            let safeTotalChaps = max(1, totalChapters ?? stories[idx].chapters?.count ?? stories[idx].totalChapters)
            let resolvedChapIdx = min(
                safeTotalChaps - 1,
                max(0, chapterIndex ?? ((stories[idx].lastReadChapterNumber ?? 1) - 1))
            )
            let pct: Int
            if safeTotalChaps > 1 {
                let fraction = (Double(resolvedChapIdx) / Double(safeTotalChaps))
                    + ((Double(safePage) / Double(safeTotalPages)) * (1.0 / Double(safeTotalChaps)))
                pct = min(100, max(1, Int((fraction * 100.0).rounded())))
            } else {
                pct = min(100, max(1, Int(((Double(safePage) / Double(safeTotalPages)) * 100.0).rounded())))
            }

            stories[idx].progressPercent = pct
            if pct >= 100 {
                stories[idx].isCompleted = true
                if autoArchiveCompletedStories {
                    stories[idx].isBookmarked = false
                    PersistenceService.shared.setBookmark(storyId: storyId, isBookmarked: false)
                }
            }
            PersistenceService.shared.updateProgress(
                storyId: storyId,
                progressPercent: pct,
                isCompleted: pct >= 100,
                page: safePage,
                totalPages: safeTotalPages
            )
            if let chapId = stories[idx].lastReadChapterId,
               let chapNum = stories[idx].lastReadChapterNumber {
                PersistenceService.shared.updateReadingProgress(
                    storyId: storyId,
                    chapterId: chapId,
                    chapterNumber: chapNum
                )
            }
            reloadReadingStats()
            persistShelfState(for: stories[idx])

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
                _ = await self.syncShelfToAccount([item])
            }
        }
    }

    func updateReadingProgress(for storyId: UUID, chapterId: String, chapterNumber: Int) {
        if let index = stories.firstIndex(where: { $0.id == storyId }) {
            stories[index].lastReadChapterId = chapterId
            stories[index].lastReadChapterNumber = chapterNumber
            if stories[index].progressPercent == 0 {
                let totalChaps = max(1, stories[index].chapters?.count ?? stories[index].totalChapters)
                let pct = min(99, max(1, Int(((Double(max(1, chapterNumber)) - 0.5) / Double(totalChaps) * 100.0).rounded())))
                stories[index].progressPercent = pct
                PersistenceService.shared.updateProgress(
                    storyId: storyId,
                    progressPercent: pct,
                    isCompleted: false,
                    page: max(1, stories[index].currentPage),
                    totalPages: max(1, stories[index].totalPages)
                )
            }
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
        if let story = stories.first(where: { $0.id == storyId }) {
            persistShelfState(for: story)
        }
    }

    func updateMangaProgress(
        for storyId: UUID,
        page: Int,
        totalPages: Int,
        chapterIndex: Int,
        totalChapters: Int,
        chapterId: String,
        chapterNumber: Int
    ) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].currentPage = page
            stories[idx].totalPages = totalPages
            stories[idx].lastReadChapterId = chapterId
            stories[idx].lastReadChapterNumber = chapterNumber

            let safeTotalChaps = max(1, totalChapters)
            let safeTotalPages = max(1, totalPages)
            let fraction = (Double(chapterIndex) / Double(safeTotalChaps)) + ((Double(page) / Double(safeTotalPages)) * (1.0 / Double(safeTotalChaps)))
            let pct = min(100, max(1, Int((fraction * 100.0).rounded())))
            stories[idx].progressPercent = pct

            if pct >= 100 {
                stories[idx].isCompleted = true
                if autoArchiveCompletedStories {
                    stories[idx].isBookmarked = false
                    PersistenceService.shared.setBookmark(storyId: storyId, isBookmarked: false)
                }
            }

            PersistenceService.shared.updateProgress(
                storyId: storyId,
                progressPercent: pct,
                isCompleted: pct >= 100,
                page: page,
                totalPages: totalPages
            )
            PersistenceService.shared.updateReadingProgress(
                storyId: storyId,
                chapterId: chapterId,
                chapterNumber: chapterNumber
            )
            reloadReadingStats()
            persistShelfState(for: stories[idx])

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
                _ = await self.syncShelfToAccount([item])
            }
        }
    }

    func logReadingSession(for story: Story, seconds: Int) {
        guard seconds >= 3, let session = AuthManager.shared.currentSession else { return }
        let completed = stories.first(where: { $0.id == story.id })?.isCompleted ?? story.isCompleted
        let event = ReadingSessionRequest(
            storyId: story.id,
            secondsRead: seconds,
            isCompleted: completed
        )
        PersistenceService.shared.logReadingSession(
            id: event.id,
            storyId: story.id,
            storyTitle: story.title,
            seconds: seconds,
            ownerUserId: session.id,
            isCompleted: completed
        )

        if !session.isGuest, let queueKey = pendingReadingSessionsKey {
            var pending = (try? JSONDecoder().decode(
                [ReadingSessionRequest].self,
                from: UserDefaults.standard.data(forKey: queueKey) ?? Data()
            )) ?? []
            pending.append(event)
            if let data = try? JSONEncoder().encode(pending) {
                UserDefaults.standard.set(data, forKey: queueKey)
            }
        }
        reloadReadingStats()
    }

    private func archiveCompletedStories() {
        var updates: [ShelfSyncItem] = []
        for index in stories.indices where stories[index].isCompleted || stories[index].progressPercent >= 100 {
            guard stories[index].isBookmarked else { continue }
            stories[index].isBookmarked = false
            PersistenceService.shared.setBookmark(storyId: stories[index].id, isBookmarked: false)
            persistShelfState(for: stories[index])
            updates.append(ShelfSyncItem(
                storyId: stories[index].id,
                readingProgress: Double(stories[index].progressPercent) / 100.0,
                isBookmarked: false,
                isCompleted: true,
                updatedAtUtc: Date()
            ))
        }
        for index in profileStories.indices where profileStories[index].isCompleted || profileStories[index].progressPercent >= 100 {
            profileStories[index].isBookmarked = false
        }
        guard !updates.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            _ = await self.syncShelfToAccount(updates)
        }
    }

    func markAsFinished(storyId: UUID) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].isCompleted = true
            stories[idx].progressPercent = 100
            if autoArchiveCompletedStories {
                stories[idx].isBookmarked = false
                PersistenceService.shared.setBookmark(storyId: storyId, isBookmarked: false)
            }
            let pages = stories[idx].totalPages
            PersistenceService.shared.updateProgress(
                storyId: storyId,
                progressPercent: 100,
                isCompleted: true,
                page: pages,
                totalPages: pages
            )
            reloadReadingStats()
            persistShelfState(for: stories[idx])

            Task { [weak self] in
                guard let self = self else { return }
                let item = ShelfSyncItem(
                    storyId: storyId,
                    readingProgress: 1.0,
                    isBookmarked: self.stories[idx].isBookmarked,
                    isCompleted: true,
                    updatedAtUtc: Date()
                )
                _ = await self.syncShelfToAccount([item])
            }
        }
    }

    func removeFromShelf(storyId: UUID) {
        if let idx = stories.firstIndex(where: { $0.id == storyId }) {
            stories[idx].isBookmarked = false
            stories[idx].progressPercent = 0
            stories[idx].currentPage = 1
            stories[idx].lastReadChapterId = nil
            stories[idx].lastReadChapterNumber = nil
            PersistenceService.shared.setBookmark(storyId: storyId, isBookmarked: false)
            PersistenceService.shared.updateProgress(
                storyId: storyId,
                progressPercent: 0,
                isCompleted: false,
                page: 1,
                totalPages: max(1, stories[idx].totalPages)
            )
            persistShelfState(for: stories[idx])

            Task { [weak self] in
                guard let self = self else { return }
                let item = ShelfSyncItem(
                    storyId: storyId,
                    readingProgress: 0.0,
                    isBookmarked: false,
                    isCompleted: false,
                    updatedAtUtc: Date()
                )
                _ = await self.syncShelfToAccount([item])
            }
        }
    }

    // MARK: - Marginalia & Annotations (Plan 02)
    func loadAnnotations(for storyId: UUID) {
        self.activeStoryAnnotations = PersistenceService.shared.fetchAnnotations(
            for: storyId,
            ownerUserId: AuthManager.shared.currentSession?.id
        )
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
        PersistenceService.shared.saveAnnotation(
            annotation,
            ownerUserId: AuthManager.shared.currentSession?.id
        )
        if pinToJournal {
            reloadPinnedQuotes()
        }
    }

    func deleteAnnotation(id: UUID, storyId: UUID) {
        activeStoryAnnotations.removeAll(where: { $0.id == id })
        PersistenceService.shared.deleteAnnotation(
            id: id,
            ownerUserId: AuthManager.shared.currentSession?.id
        )
        reloadPinnedQuotes()
    }

    func togglePinQuote(for annotation: Annotation) {
        var updated = annotation
        updated.isPinnedToJournal.toggle()
        PersistenceService.shared.saveAnnotation(
            updated,
            ownerUserId: AuthManager.shared.currentSession?.id
        )
        if let idx = activeStoryAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            activeStoryAnnotations[idx] = updated
        }
        reloadPinnedQuotes()
    }

    func clearUserStateOnSignOut() {
        if activeShelfOwnerKey != "signed_out" {
            var states = loadShelfStateCache()
            for story in stories {
                let previous = states[story.id.uuidString]
                let state = LocalShelfState(story: story, updatedAtUtc: previous?.updatedAtUtc ?? Date())
                if !state.isEmpty || previous != nil { states[story.id.uuidString] = state }
            }
            saveShelfStateCache(states)
        }
        activeShelfOwnerKey = "signed_out"
        clearVisibleShelfState()
    }
}
