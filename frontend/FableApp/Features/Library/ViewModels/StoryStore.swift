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
    @Published var tourExploreFilter: String = "All"
    @Published var tourExploreSearchText: String = ""
    @Published var tourSelectedWriter: Writer?
    @Published var tourShelfTab: String = "Saved"
    @Published var isShowingChapterIndexSheet: Bool = false

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
    @Published private(set) var providerCatalogStatus = ProviderCatalogStatus()
    @Published private(set) var isRefreshingProviderCatalogs = false
    private let apiService: StoryAPIServiceProtocol = StoryAPIService()

    nonisolated static let currentExternalChapterParserVersion = 2
    private static let externalChapterParserVersionsDefaultsKey = "fable_external_chapter_parser_versions_v1"

    private func providerCatalogRefreshKey(_ provider: CatalogProvider) -> String {
        "fable_provider_catalog_last_success_\(provider.rawValue)"
    }

    private func verifiedChapterParserVersion(for storyId: UUID) -> Int {
        let versions = UserDefaults.standard.dictionary(forKey: Self.externalChapterParserVersionsDefaultsKey) as? [String: Int]
        return versions?[storyId.uuidString] ?? 0
    }

    private func markChapterParserVersionVerified(
        for storyId: UUID,
        version: Int = StoryStore.currentExternalChapterParserVersion
    ) {
        var versions = UserDefaults.standard.dictionary(forKey: Self.externalChapterParserVersionsDefaultsKey) as? [String: Int] ?? [:]
        versions[storyId.uuidString] = version
        UserDefaults.standard.set(versions, forKey: Self.externalChapterParserVersionsDefaultsKey)
    }

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

    private func recordProviderCatalogResult(_ provider: CatalogProvider, succeeded: Bool) {
        var status = providerCatalogStatus
        status.record(provider, succeeded: succeeded)
        providerCatalogStatus = status
        if succeeded, let refreshedAt = status.lastSuccessfulRefresh[provider] {
            UserDefaults.standard.set(refreshedAt, forKey: providerCatalogRefreshKey(provider))
        }
    }

    private func restoreProviderCatalogStatus() {
        var refreshedDates: [CatalogProvider: Date] = [:]
        for provider in CatalogProvider.allCases {
            if let date = UserDefaults.standard.object(forKey: providerCatalogRefreshKey(provider)) as? Date {
                refreshedDates[provider] = date
            }
        }
        providerCatalogStatus = ProviderCatalogStatus(lastSuccessfulRefresh: refreshedDates)
    }

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

        nonisolated init(
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

        init(record: PersistenceService.ShelfStateRecord) {
            self.readingProgress = record.readingProgress
            self.isBookmarked = record.isBookmarked
            self.isCompleted = record.isCompleted
            self.currentPage = record.currentPage
            self.totalPages = record.totalPages
            self.lastReadChapterId = record.lastReadChapterId
            self.lastReadChapterNumber = record.lastReadChapterNumber
            self.updatedAtUtc = record.updatedAtUtc
        }

        func record(storyId: UUID) -> PersistenceService.ShelfStateRecord {
            PersistenceService.ShelfStateRecord(
                storyId: storyId,
                readingProgress: readingProgress,
                isBookmarked: isBookmarked,
                isCompleted: isCompleted,
                currentPage: currentPage,
                totalPages: totalPages,
                lastReadChapterId: lastReadChapterId,
                lastReadChapterNumber: lastReadChapterNumber,
                updatedAtUtc: updatedAtUtc
            )
        }
    }

    private struct WriterDraft: Codable {
        let title: String
        let genre: String
        let chapter: String
        let synopsis: String
        let manuscript: String
    }

    /// Feature flag controlling manga catalog visibility on iOS.
    /// Kept false to adhere strictly to Apple App Store copyright guidelines (5.2)
    /// and focus exclusively on open-source books, fables, and original writing.
    public static let isMangaEnabled: Bool = false

    // These collections populate from the server; cached stories remain available offline.
    @Published var genres: [GenreCategory] = []

    @Published var writers: [Writer] = []

    // User Profile Stories
    @Published var profileStories: [Story] = []

    init() {
        PersistenceService.shared.purgeLegacyDemoStories()
        restoreProviderCatalogStatus()
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

        if let validationError = CreateStoryRequest.validateDraftFields(
            title: title,
            genre: genre,
            chapter: chapter,
            synopsis: synopsis,
            content: manuscript,
            requireContent: true
        ) {
            publishErrorMessage = validationError
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
            readTimeMinutes: CreateStoryRequest.estimatedReadTimeMinutes(for: manuscript)
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

    func updatePublishedStory(id: UUID, request: UpdateStoryRequest) async -> Story? {
        guard let session = AuthManager.shared.currentSession, !session.isGuest,
              let token = KeychainStore.shared.readAccessToken() else {
            publishErrorMessage = "Sign in to update your published story."
            return nil
        }

        do {
            var updatedStory = try await apiService.updateStory(id: id, request, token: token)
            if let existingState = loadShelfStateCache()[updatedStory.id.uuidString] {
                applyShelfState(existingState, to: &updatedStory)
            }
            if let idx = stories.firstIndex(where: { $0.id == updatedStory.id }) {
                stories[idx] = updatedStory
            }
            if let idx = profileStories.firstIndex(where: { $0.id == updatedStory.id }) {
                profileStories[idx] = updatedStory
            }
            PersistenceService.shared.saveStory(updatedStory)
            persistProfileStoriesCache(profileStories, for: session.id)
            reloadPinnedQuotes()
            publishErrorMessage = nil
            return updatedStory
        } catch let error as APIRequestError {
            publishErrorMessage = error.message
            return nil
        } catch {
            publishErrorMessage = "Could not update story. Check your connection and try again."
            return nil
        }
    }

    func deletePublishedStory(id: UUID) async -> Bool {
        guard let session = AuthManager.shared.currentSession, !session.isGuest,
              let token = KeychainStore.shared.readAccessToken() else {
            publishErrorMessage = "Sign in to delete your published story."
            return false
        }

        do {
            try await apiService.deleteStory(id: id, token: token)
            stories.removeAll { $0.id == id }
            profileStories.removeAll { $0.id == id }
            if activeStoryAnnotations.contains(where: { $0.storyId == id }) {
                activeStoryAnnotations.removeAll { $0.storyId == id }
            }
            PersistenceService.shared.deleteStory(storyId: id)
            persistProfileStoriesCache(profileStories, for: session.id)
            reloadPinnedQuotes()
            publishErrorMessage = nil
            return true
        } catch let error as APIRequestError {
            publishErrorMessage = error.message
            return false
        } catch {
            publishErrorMessage = "Could not delete story. Check your connection and try again."
            return false
        }
    }

    static func hasUsableCachedChapters(
        _ chapters: [Chapter]?,
        format: ContentFormat,
        allowExternalMangaSource: Bool = false
    ) -> Bool {
        guard let chapters, !chapters.isEmpty else { return false }
        if format == .manga {
            return chapters.contains {
                !$0.pageUrls.isEmpty || (allowExternalMangaSource && $0.externalSourceURL != nil)
            }
        }
        return chapters.contains(where: \.hasReadableText)
    }

    static func shouldInvalidateCachedChapters(
        _ chapters: [Chapter]?,
        sourceProvider: SourceProvider,
        verifiedParserVersion: Int
    ) -> Bool {
        guard sourceProvider == .gutenberg || sourceProvider == .standardEbooks else {
            return false
        }
        guard verifiedParserVersion < currentExternalChapterParserVersion else {
            return false
        }
        guard let chapters, !chapters.isEmpty else {
            return false
        }
        guard chapters.count <= 1 else {
            return false
        }
        let firstChapter = chapters.first
        return firstChapter?.title == "Chapter I: The Complete Tale"
            || (firstChapter?.wordCount ?? 0) >= 1_500
    }

    static func staleUnengagedExternalStoryIDs(
        in stories: [Story],
        provider: SourceProvider,
        liveStoryIDs: Set<UUID>,
        isAnnotatedProvider: (UUID) -> Bool
    ) -> Set<UUID> {
        guard !liveStoryIDs.isEmpty else { return [] }
        var staleIDs = Set<UUID>()
        for story in stories {
            guard story.sourceProvider == provider,
                  story.ownerUserId == nil,
                  !liveStoryIDs.contains(story.id),
                  !story.isBookmarked,
                  !story.isCompleted,
                  story.progressPercent == 0,
                  story.lastReadChapterId == nil,
                  !isAnnotatedProvider(story.id) else {
                continue
            }
            staleIDs.insert(story.id)
        }
        return staleIDs
    }

    static func isLocallyReadable(
        content: String,
        chapters: [Chapter]?,
        format: ContentFormat
    ) -> Bool {
        if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return hasUsableCachedChapters(chapters, format: format)
    }

    static func shouldHydratePersistedStory(
        content: String,
        cachedChapters: [Chapter],
        format: ContentFormat,
        isBookmarked: Bool,
        isCompleted: Bool,
        readingProgress: Double,
        lastReadChapterId: String?
    ) -> Bool {
        if isLocallyReadable(content: content, chapters: cachedChapters, format: format) {
            return true
        }
        return isBookmarked || isCompleted || readingProgress > 0 || lastReadChapterId != nil
    }

    static func staleUnavailableOriginalStoryIDs(
        in stories: [Story],
        remoteStoryIDs: Set<UUID>,
        profileStoryIDs: Set<UUID>,
        cachedChaptersProvider: (UUID) -> [Chapter]
    ) -> Set<UUID> {
        let activeIDs = remoteStoryIDs.union(profileStoryIDs)
        var staleIDs = Set<UUID>()
        for story in stories {
            guard story.sourceProvider == .fableOriginal,
                  !activeIDs.contains(story.id) else {
                continue
            }
            let localChapters = story.chapters ?? cachedChaptersProvider(story.id)
            if !isLocallyReadable(content: story.content, chapters: localChapters, format: story.contentFormat) {
                staleIDs.insert(story.id)
            }
        }
        return staleIDs
    }

    private func syncWithPersistence() {
        // Hydrate and reconcile from SQLite
        let persisted = PersistenceService.shared.fetchAllStories()
        if !persisted.isEmpty {
            for entity in persisted {
                if !Self.isMangaEnabled {
                    let formatRaw = entity.contentFormatRaw ?? ""
                    let providerRaw = entity.sourceProviderRaw ?? ""
                    if formatRaw.caseInsensitiveCompare("manga") == .orderedSame
                        || providerRaw.caseInsensitiveCompare("mangadex") == .orderedSame
                        || entity.genreRaw.caseInsensitiveCompare("manga") == .orderedSame {
                        continue
                    }
                }
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
                    stories[idx].ownerUserId = entity.ownerUserId
                    stories[idx].providerDownloadCount = entity.providerDownloadCount
                    stories[idx].contentFormat = ContentFormat(rawValue: entity.contentFormatRaw ?? "PROSE") ?? .prose
                    stories[idx].sourceProvider = SourceProvider(rawValue: entity.sourceProviderRaw ?? "FABLE_ORIGINAL") ?? .fableOriginal
                    let cachedChapters = PersistenceService.shared.cachedChapters(storyId: entity.id)
                    let verifiedVersion = verifiedChapterParserVersion(for: entity.id)
                    let isStaleChapterCache = Self.shouldInvalidateCachedChapters(
                        cachedChapters,
                        sourceProvider: stories[idx].sourceProvider,
                        verifiedParserVersion: verifiedVersion
                    )
                    if isStaleChapterCache {
                        PersistenceService.shared.clearCachedChapters(storyId: entity.id)
                        stories[idx].chapters = nil
                    } else if Self.hasUsableCachedChapters(cachedChapters, format: stories[idx].contentFormat) {
                        stories[idx].chapters = cachedChapters
                    }
                    stories[idx].lastReadChapterId = entity.lastReadChapterId
                    stories[idx].lastReadChapterNumber = entity.lastReadChapterNumber
                } else {
                    let initialCached = PersistenceService.shared.cachedChapters(storyId: entity.id)
                    let format = ContentFormat(rawValue: entity.contentFormatRaw ?? "PROSE") ?? .prose
                    let verifiedVersion = verifiedChapterParserVersion(for: entity.id)
                    let isStaleInitialCache = Self.shouldInvalidateCachedChapters(
                        initialCached,
                        sourceProvider: provider,
                        verifiedParserVersion: verifiedVersion
                    )
                    if isStaleInitialCache {
                        PersistenceService.shared.clearCachedChapters(storyId: entity.id)
                    }
                    let effectiveCached = isStaleInitialCache ? [] : initialCached
                    let isUsableInitial = Self.hasUsableCachedChapters(effectiveCached, format: format)
                    guard Self.shouldHydratePersistedStory(
                        content: entity.content,
                        cachedChapters: effectiveCached,
                        format: format,
                        isBookmarked: entity.isBookmarked,
                        isCompleted: entity.isCompleted,
                        readingProgress: entity.readingProgress,
                        lastReadChapterId: entity.lastReadChapterId
                    ) else {
                        continue
                    }
                    let validInitial = isUsableInitial ? effectiveCached : nil
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
                        ownerUserId: entity.ownerUserId,
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
        let cacheVersionKey = "fable_discovery_cache_version"
        let currentCacheVersion = 3
        if UserDefaults.standard.integer(forKey: cacheVersionKey) < currentCacheVersion {
            UserDefaults.standard.removeObject(forKey: "fable_cached_genres")
            UserDefaults.standard.removeObject(forKey: "fable_cached_writers")
            UserDefaults.standard.set(currentCacheVersion, forKey: cacheVersionKey)
        }

        if let data = UserDefaults.standard.data(forKey: "fable_cached_genres"),
           let cached = try? JSONDecoder().decode([GenreCategory].self, from: data) {
            genres = Self.isMangaEnabled ? cached : cached.filter { $0.name.caseInsensitiveCompare("manga") != .orderedSame }
        }
        if let data = UserDefaults.standard.data(forKey: "fable_cached_writers"),
           let cached = try? JSONDecoder().decode([Writer].self, from: data) {
            writers = cached.filter { !Self.isExcludedPlaceholderAuthor($0.name) }
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
                if !Self.isMangaEnabled && (remote.contentFormat == .manga || remote.sourceProvider == .mangadex || remote.genre == .manga || remote.genre.rawValue.caseInsensitiveCompare("manga") == .orderedSame) {
                    continue
                }
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
                    if !remote.author.isEmpty { stories[index].author = remote.author }
                    stories[index].totalChapters = remote.totalChapters
                    stories[index].contentFormat = remote.contentFormat
                    stories[index].sourceProvider = remote.sourceProvider
                    if let ownerUserId = remote.ownerUserId { stories[index].ownerUserId = ownerUserId }
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

            let staleOriginalIDs = Self.staleUnavailableOriginalStoryIDs(
                in: stories,
                remoteStoryIDs: synchronizedStoryIds,
                profileStoryIDs: Set(profileStories.map(\.id)),
                cachedChaptersProvider: { PersistenceService.shared.cachedChapters(storyId: $0) }
            )
            if !staleOriginalIDs.isEmpty {
                stories.removeAll { staleOriginalIDs.contains($0.id) }
                for staleID in staleOriginalIDs {
                    PersistenceService.shared.deleteStory(storyId: staleID, onlyIfUnannotated: true)
                }
            }

            await refreshProviderCatalogs()

            // 2. Fetch live dynamic categories/genres from backend and merge catalog taxonomy
            let rawLiveGenres = (try? await apiService.fetchGenres()) ?? []
            let liveGenres = Self.isMangaEnabled ? rawLiveGenres : rawLiveGenres.filter { $0.name.caseInsensitiveCompare("manga") != .orderedSame }
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

            // 3. Fetch authors and catalog work counts from Project Gutenberg.
            if let liveWriters = try? await apiService.fetchTopAuthors() {
                let filteredWriters = liveWriters.filter { !Self.isExcludedPlaceholderAuthor($0.name) }
                self.writers = filteredWriters
                persistDiscoveryCache(filteredWriters, key: "fable_cached_writers")
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
    func fetchChapters(for story: Story) async throws -> [Chapter] {
        let verifiedVersion = verifiedChapterParserVersion(for: story.id)
        var offlineFallbackChapters: [Chapter]? = nil

        if let existing = story.chapters,
           Self.hasUsableCachedChapters(existing, format: story.contentFormat, allowExternalMangaSource: true) {
            if !Self.shouldInvalidateCachedChapters(existing, sourceProvider: story.sourceProvider, verifiedParserVersion: verifiedVersion) {
                return existing
            }
            offlineFallbackChapters = existing
        }
        let cached = PersistenceService.shared.cachedChapters(storyId: story.id)
        if Self.hasUsableCachedChapters(cached, format: story.contentFormat, allowExternalMangaSource: true) {
            if !Self.shouldInvalidateCachedChapters(cached, sourceProvider: story.sourceProvider, verifiedParserVersion: verifiedVersion) {
                return cached
            }
            if offlineFallbackChapters == nil {
                offlineFallbackChapters = cached
            }
        }
        do {
            let fetched = try await apiService.fetchChapters(
                for: story.id,
                sourceProvider: story.sourceProvider.rawValue,
                providerId: story.providerId
            )
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
            if story.sourceProvider == .gutenberg || story.sourceProvider == .standardEbooks {
                markChapterParserVersionVerified(for: story.id)
            }
            return fetched
        } catch {
            if let offlineFallbackChapters {
                return offlineFallbackChapters
            }
            throw error
        }
    }


    func searchCatalog(query: String) async {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !search.isEmpty else { return }

        if let remoteStories = try? await apiService.fetchStories(genre: nil, search: search) {
            for remote in remoteStories where remote.sourceProvider == .fableOriginal || remote.providerId?.isEmpty == false {
                if !Self.isMangaEnabled && (remote.contentFormat == .manga || remote.sourceProvider == .mangadex || remote.genre == .manga || remote.genre.rawValue.caseInsensitiveCompare("manga") == .orderedSame) {
                    continue
                }
                guard !stories.contains(where: { $0.id == remote.id }) else { continue }
                var cached = remote
                cached.coverImageUrl = validCoverImageURL(remote.coverImageUrl)
                cached.coverImageName = nil
                cached.heroImageName = nil
                stories.append(cached)
                PersistenceService.shared.saveStory(cached)
            }
        }
        async let seSearch: () = fetchStandardEbooksPublicStories(topic: nil, search: search)
        async let gutenbergSearch: () = fetchGutenbergPublicStories(topic: nil, search: search)
        _ = await (seSearch, gutenbergSearch)
        if Self.isMangaEnabled {
            await fetchMangaPublicStories(search: search)
        }
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
            .filter { $0.ownerUserId == nil && matchesAuthor(storyAuthor: $0.author, writerName: writer.name) }
            .sorted { ($0.providerDownloadCount ?? 0) > ($1.providerDownloadCount ?? 0) }
    }

    func fetchAuthorStories(for writer: Writer) async -> [Story] {
        if Self.isMangaEnabled {
            async let seSearch: () = fetchStandardEbooksPublicStories(topic: nil, search: writer.name)
            async let gutenbergSearch: () = fetchGutenbergPublicStories(topic: nil, search: writer.name)
            async let mangaSearch: () = fetchMangaPublicStories(search: writer.name)
            _ = await (seSearch, gutenbergSearch, mangaSearch)
        } else {
            async let seSearch: () = fetchStandardEbooksPublicStories(topic: nil, search: writer.name)
            async let gutenbergSearch: () = fetchGutenbergPublicStories(topic: nil, search: writer.name)
            _ = await (seSearch, gutenbergSearch)
        }

        if let remoteStories = try? await apiService.fetchStories(genre: nil, search: writer.name) {
            for remote in remoteStories where remote.sourceProvider == .fableOriginal || remote.providerId?.isEmpty == false {
                if !Self.isMangaEnabled && (remote.contentFormat == .manga || remote.sourceProvider == .mangadex || remote.genre == .manga || remote.genre.rawValue.caseInsensitiveCompare("manga") == .orderedSame) {
                    continue
                }
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

    private func mergePublicProseBooks(
        _ fetched: [Story],
        provider: CatalogProvider,
        replaceUnengagedSnapshot: Bool = false
    ) {
        recordProviderCatalogResult(provider, succeeded: true)
        if replaceUnengagedSnapshot && !fetched.isEmpty {
            let sourceProvider: SourceProvider = provider == .standardEbooks ? .standardEbooks : .gutenberg
            let staleIDs = Self.staleUnengagedExternalStoryIDs(
                in: stories,
                provider: sourceProvider,
                liveStoryIDs: Set(fetched.map(\.id)),
                isAnnotatedProvider: { PersistenceService.shared.hasAnyAnnotations(for: $0) }
            )
            if !staleIDs.isEmpty {
                stories.removeAll { staleIDs.contains($0.id) }
                for staleID in staleIDs {
                    PersistenceService.shared.deleteStory(storyId: staleID, onlyIfUnannotated: true)
                }
            }
        }
        for book in fetched {
            if let index = stories.firstIndex(where: { $0.id == book.id }) {
                stories[index].title = book.title
                if !book.genre.rawValue.isEmpty {
                    stories[index].genre = book.genre
                }
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
                } else if let existingChaps = stories[index].chapters,
                          Self.shouldInvalidateCachedChapters(
                              existingChaps,
                              sourceProvider: book.sourceProvider,
                              verifiedParserVersion: verifiedChapterParserVersion(for: book.id)
                          ) {
                    stories[index].chapters = nil
                    PersistenceService.shared.clearCachedChapters(storyId: book.id)
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
    }

    func fetchStandardEbooksPublicStories(topic: String? = nil, search: String? = nil) async {
        do {
            let fetched = try await apiService.fetchStandardEbooksStories(topic: topic, search: search)
            let isBrowseSnapshot = topic != nil && (search ?? "").isEmpty
            mergePublicProseBooks(fetched, provider: .standardEbooks, replaceUnengagedSnapshot: isBrowseSnapshot)
        } catch {
            recordProviderCatalogResult(.standardEbooks, succeeded: false)
        }
    }

    func fetchGutenbergPublicStories(topic: String? = nil, search: String? = nil) async {
        do {
            let fetched = try await apiService.fetchGutenbergStories(topic: topic, search: search)
            let isBrowseSnapshot = topic != nil && (search ?? "").isEmpty
            mergePublicProseBooks(fetched, provider: .gutenberg, replaceUnengagedSnapshot: isBrowseSnapshot)
        } catch {
            recordProviderCatalogResult(.gutenberg, succeeded: false)
        }
    }

    func fetchMangaPublicStories(search: String? = nil) async {
        do {
            let fetched = try await apiService.fetchMangaStories(search: search)
            recordProviderCatalogResult(.mangaDex, succeeded: true)
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
            recordProviderCatalogResult(.mangaDex, succeeded: false)
        }
    }

    func refreshProviderCatalogs() async {
        guard !isRefreshingProviderCatalogs else { return }
        isRefreshingProviderCatalogs = true
        defer { isRefreshingProviderCatalogs = false }
        async let standardEbooksRefresh: () = fetchStandardEbooksPublicStories(topic: "fiction", search: nil)
        async let gutenbergRefresh: () = fetchGutenbergPublicStories(topic: "fiction", search: nil)
        _ = await (standardEbooksRefresh, gutenbergRefresh)
        if Self.isMangaEnabled {
            await fetchMangaPublicStories(search: nil)
        }
    }

    private func deriveGenresFromCatalog(_ catalog: [Story]) -> [GenreCategory] {
        let genreGroups = Dictionary(grouping: catalog.compactMap { story -> (String, Story)? in
            let name = story.genre.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            if !Self.isMangaEnabled && name.caseInsensitiveCompare("manga") == .orderedSame {
                return nil
            }
            return (name, story)
        }, by: { $0.0.lowercased() })

        return genreGroups.values.compactMap { group in
            guard let first = group.first else { return nil }
            let name = first.0
            return GenreCategory(
                name: name,
                storyCount: group.count,
                readersCount: "",
                description: "",
                imageName: "",
                imageUrl: nil
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func storyMatchesCategory(_ story: Story, category: String) -> Bool {
        if !Self.isMangaEnabled && (story.contentFormat == .manga || story.genre == .manga || story.sourceProvider == .mangadex || story.genre.rawValue.caseInsensitiveCompare("manga") == .orderedSame) {
            return false
        }
        if category == "All" { return true }
        if category == "Manga" {
            guard Self.isMangaEnabled else { return false }
            return story.contentFormat == .manga || story.genre == .manga || story.sourceProvider == .mangadex
        }
        return story.genre.rawValue.localizedCaseInsensitiveCompare(category) == .orderedSame
    }

    public static let excludedPlaceholderAuthors: Set<String> = ["various", "anonymous", "unknown"]

    public static func isExcludedPlaceholderAuthor(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty || excludedPlaceholderAuthors.contains(normalized)
    }

    public func displayStoryCount(for genre: GenreCategory) -> Int {
        let localMatches = stories.filter { storyMatchesCategory($0, category: genre.name) }.count
        return max(genre.storyCount, localMatches)
    }

    public static func pluralizedCount(_ count: Int, singular: String, plural: String? = nil) -> String {
        "\(count) \(count == 1 ? singular : (plural ?? "\(singular)s"))"
    }

    private var shelfStateStorageKey: String {
        "fable_shelf_state_\(activeShelfOwnerKey)"
    }

    private var normalizedShelfOwnerKey: String {
        activeShelfOwnerKey.lowercased()
    }

    private func loadShelfStateCache() -> [String: LocalShelfState] {
        let records = PersistenceService.shared.migrateLegacyShelfStatesIfNeeded(
            ownerKey: normalizedShelfOwnerKey,
            legacyStorageKey: shelfStateStorageKey
        )
        var states: [String: LocalShelfState] = [:]
        for (storyId, record) in records {
            states[storyId.uuidString] = LocalShelfState(record: record)
        }
        return states
    }

    private func saveShelfStateCache(_ states: [String: LocalShelfState]) {
        var records: [UUID: PersistenceService.ShelfStateRecord] = [:]
        for (storyID, state) in states {
            guard let uuid = UUID(uuidString: storyID) else { continue }
            records[uuid] = state.record(storyId: uuid)
        }
        PersistenceService.shared.replaceShelfStates(records, ownerKey: normalizedShelfOwnerKey)
    }

    private func persistShelfState(for story: Story, updatedAt: Date = Date()) {
        let state = LocalShelfState(story: story, updatedAtUtc: updatedAt)
        PersistenceService.shared.upsertShelfState(
            state.record(storyId: story.id),
            ownerKey: normalizedShelfOwnerKey
        )
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
        let existing = loadShelfStateCache()
        if !existing.isEmpty {
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
        }
    }

    private func storeServerShelfState(_ item: ShelfSyncItem) {
        let previous = loadShelfStateCache()[item.storyId.uuidString] ?? .empty
        let state = LocalShelfState(
            syncItem: item,
            previous: previous
        )
        PersistenceService.shared.upsertShelfState(
            state.record(storyId: item.storyId),
            ownerKey: normalizedShelfOwnerKey
        )
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
                let chaps = try? await self.fetchChapters(for: current)
                if current.contentFormat == .manga, let firstChap = chaps?.first {
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
        chapterNumber: Int? = nil,
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
            chapterNumber: chapterNumber,
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
            ownerUserId: AuthManager.shared.currentSession?.id,
            storyFallback: story
        )
        reloadPinnedQuotes()
    }

    func updateAnnotation(
        _ annotation: Annotation,
        story: Story,
        color: HighlightColor,
        note: String?,
        pinToJournal: Bool
    ) {
        var updated = annotation
        updated.color = color
        updated.note = note
        updated.isPinnedToJournal = pinToJournal
        updated.storyTitle = story.title
        updated.storyAuthor = story.author
        if let idx = activeStoryAnnotations.firstIndex(where: { $0.id == annotation.id }) {
            activeStoryAnnotations[idx] = updated
        }
        PersistenceService.shared.saveAnnotation(
            updated,
            ownerUserId: AuthManager.shared.currentSession?.id,
            storyFallback: story
        )
        reloadPinnedQuotes()
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

    func clearDeletedAccountLocalState(userID: UUID) {
        UserDefaults.standard.removeObject(forKey: profileStoriesCacheKey(for: userID))
        UserDefaults.standard.removeObject(forKey: "fable_shelf_state_\(userID.uuidString)")
        clearWriterDraft(ownerID: userID)
        PersistenceService.shared.deleteAccountData(ownerUserId: userID)
        stories.removeAll { $0.ownerUserId == userID }
        activeShelfOwnerKey = "signed_out"
        clearVisibleShelfState()
    }
}
