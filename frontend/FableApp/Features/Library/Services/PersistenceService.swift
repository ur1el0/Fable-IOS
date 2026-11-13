import Foundation
import SwiftData
import SwiftUI

@MainActor
public final class PersistenceService {
    public static let shared = PersistenceService()
    
    public let container: ModelContainer
    public private(set) var didRecoverStoreByReset: Bool = false
    public private(set) var isUsingInMemoryFallback: Bool = false

    public var context: ModelContext {
        container.mainContext
    }

    public static var defaultSchema: Schema {
        Schema([
            StoryEntity.self,
            AnnotationEntity.self,
            ReadingLogEntity.self,
            ShelfItemEntity.self
        ])
    }

    public struct ResilientContainerResult {
        public let container: ModelContainer
        public let didRecoverByReset: Bool
        public let isInMemoryFallback: Bool
    }

    private static func removeSQLiteStoreArtifacts(at storeURL: URL) {
        let fileManager = FileManager.default
        let candidateURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
        for url in candidateURLs where fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func defaultStoreURLs() -> [URL] {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return []
        }
        return [appSupportURL.appendingPathComponent("default.store")]
    }

    public static func makeResilientContainer(
        schema: Schema? = nil,
        storeURL: URL? = nil,
        isStoredInMemoryOnly: Bool = false,
        containerBuilder: ((Schema, ModelConfiguration) throws -> ModelContainer)? = nil
    ) -> ResilientContainerResult {
        let resolvedSchema = schema ?? Self.defaultSchema
        let build: (Schema, ModelConfiguration) throws -> ModelContainer = containerBuilder ?? { schema, configuration in
            try ModelContainer(for: schema, configurations: [configuration])
        }

        if let storeURL {
            let parent = storeURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: parent.path) {
                try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)
            }
        } else if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !FileManager.default.fileExists(atPath: appSupportURL.path) {
                try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
            }
        }

        if isStoredInMemoryOnly {
            let memoryConfig = ModelConfiguration(schema: resolvedSchema, isStoredInMemoryOnly: true)
            if let memoryContainer = try? build(resolvedSchema, memoryConfig) {
                return ResilientContainerResult(container: memoryContainer, didRecoverByReset: false, isInMemoryFallback: true)
            }
        }

        let persistentConfig: ModelConfiguration = {
            if let storeURL {
                return ModelConfiguration(schema: resolvedSchema, url: storeURL)
            }
            return ModelConfiguration(schema: resolvedSchema, isStoredInMemoryOnly: false)
        }()

        do {
            let container = try build(resolvedSchema, persistentConfig)
            return ResilientContainerResult(container: container, didRecoverByReset: false, isInMemoryFallback: false)
        } catch {
            print("Primary SwiftData ModelContainer load failed (\(error)). Attempting local store reset.")
            let targets = storeURL.map { [$0] } ?? defaultStoreURLs()
            for targetURL in targets {
                removeSQLiteStoreArtifacts(at: targetURL)
            }

            do {
                let recoveredContainer = try build(resolvedSchema, persistentConfig)
                return ResilientContainerResult(container: recoveredContainer, didRecoverByReset: true, isInMemoryFallback: false)
            } catch {
                print("Recovered persistent SwiftData ModelContainer failed (\(error)). Falling back to in-memory store.")
                let fallbackConfig = ModelConfiguration(schema: resolvedSchema, isStoredInMemoryOnly: true)
                do {
                    let memoryContainer = try build(resolvedSchema, fallbackConfig)
                    return ResilientContainerResult(container: memoryContainer, didRecoverByReset: true, isInMemoryFallback: true)
                } catch {
                    preconditionFailure("Unable to initialize even an in-memory SwiftData ModelContainer: \(error)")
                }
            }
        }
    }

    public init(storeURL: URL? = nil, isStoredInMemoryOnly: Bool = false) {
        let result = Self.makeResilientContainer(
            schema: Self.defaultSchema,
            storeURL: storeURL,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        self.container = result.container
        self.didRecoverStoreByReset = result.didRecoverByReset
        self.isUsingInMemoryFallback = result.isInMemoryFallback
    }

    public static let legacyDemoStoryIds: Set<UUID> = [
        UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
        UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
        UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
        UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
        UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
        UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
        UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
        UUID(uuidString: "10101010-1010-1010-1010-101010101010")!,
        UUID(uuidString: "20202020-2020-2020-2020-202020202020")!,
        UUID(uuidString: "e1a10001-0000-0000-0000-000000000001")!,
        UUID(uuidString: "e1a10002-0000-0000-0000-000000000002")!,
        UUID(uuidString: "e1a10003-0000-0000-0000-000000000003")!,
        UUID(uuidString: "e1a10004-0000-0000-0000-000000000004")!
    ]

    public func purgeLegacyDemoStories() {
        do {
            let entities = try context.fetch(FetchDescriptor<StoryEntity>())
            var purged = false
            for entity in entities {
                if Self.legacyDemoStoryIds.contains(entity.id) {
                    context.delete(entity)
                    purged = true
                }
            }
            if purged {
                try context.save()
            }
        } catch {
            print("Failed to purge legacy demo stories: \(error)")
        }
    }
    
    // Fetch all persistent stories
    public func fetchAllStories() -> [StoryEntity] {
        let descriptor = FetchDescriptor<StoryEntity>(
            sortBy: [SortDescriptor(\.createdAtUtc, order: .reverse)]
        )
        do {
            let entities = try context.fetch(descriptor)
            return entities.filter { !Self.legacyDemoStoryIds.contains($0.id) }
        } catch {
            print("Failed to fetch stories: \(error)")
            return []
        }
    }
    
    private func encodedChapters(_ chapters: [Chapter]?) -> Data? {
        guard let chapters, !chapters.isEmpty else { return nil }
        return try? JSONEncoder().encode(chapters)
    }

    @discardableResult
    private func upsertStoryEntity(_ story: Story) throws -> StoryEntity {
        let targetId = story.id
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == targetId }
        )
        descriptor.fetchLimit = 1

        let matches = try context.fetch(descriptor)
        if let existing = matches.first {
            existing.title = story.title
            existing.author = story.author
            existing.genreRaw = story.genre.rawValue
            existing.contentFormatRaw = story.contentFormat.rawValue
            existing.sourceProviderRaw = story.sourceProvider.rawValue
            existing.synopsis = story.synopsis
            existing.content = story.content
            existing.readTimeMinutes = story.readTimeMinutes
            existing.readingProgress = min(1.0, max(0.0, Double(story.progressPercent) / 100.0))
            existing.currentPage = max(1, story.currentPage)
            existing.totalPages = max(1, story.totalPages)
            existing.coverImageName = story.coverImageName
            existing.heroImageName = story.heroImageName
            existing.coverImageUrl = story.coverImageUrl
            if let providerId = story.providerId { existing.providerId = providerId }
            if let ownerUserId = story.ownerUserId { existing.ownerUserId = ownerUserId }
            if let providerDownloadCount = story.providerDownloadCount {
                existing.providerDownloadCount = providerDownloadCount
            }
            if let chapters = story.chapters, !chapters.isEmpty {
                existing.cachedChaptersData = encodedChapters(chapters)
            }
            existing.lastReadChapterId = story.lastReadChapterId
            existing.lastReadChapterNumber = story.lastReadChapterNumber
            existing.isBookmarked = story.isBookmarked
            existing.isCompleted = story.isCompleted
            existing.updatedAtUtc = Date()
            return existing
        }

        let newEntity = StoryEntity(
            id: story.id,
            title: story.title,
            author: story.author,
            genreRaw: story.genre.rawValue,
            contentFormatRaw: story.contentFormat.rawValue,
            sourceProviderRaw: story.sourceProvider.rawValue,
            chapter: "",
            synopsis: story.synopsis,
            content: story.content,
            readTimeMinutes: story.readTimeMinutes,
            readingProgress: Double(story.progressPercent) / 100.0,
            currentPage: story.currentPage,
            totalPages: story.totalPages,
            coverImageName: story.coverImageName,
            heroImageName: story.heroImageName,
            coverImageUrl: story.coverImageUrl,
            providerId: story.providerId,
            ownerUserId: story.ownerUserId,
            providerDownloadCount: story.providerDownloadCount,
            cachedChaptersData: encodedChapters(story.chapters),
            lastReadChapterId: story.lastReadChapterId,
            lastReadChapterNumber: story.lastReadChapterNumber,
            isBookmarked: story.isBookmarked,
            isCompleted: story.isCompleted,
            createdAtUtc: story.createdAtUtc,
            updatedAtUtc: Date()
        )
        context.insert(newEntity)
        return newEntity
    }

    // Insert or update manuscript
    public func saveStory(_ story: Story) {
        do {
            _ = try upsertStoryEntity(story)
            try context.save()
        } catch {
            print("Failed to save story: \(error)")
        }
    }

    public func fetchStory(id: UUID) -> Story? {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let entity = try? context.fetch(descriptor).first,
              !Self.legacyDemoStoryIds.contains(entity.id) else {
            return nil
        }

        let chapters = cachedChapters(storyId: entity.id)
        let format = ContentFormat(rawValue: entity.contentFormatRaw ?? "PROSE") ?? .prose
        let provider = SourceProvider(rawValue: entity.sourceProviderRaw ?? "FABLE_ORIGINAL") ?? .fableOriginal
        return Story(
            id: entity.id,
            title: entity.title,
            author: entity.author,
            genre: entity.genreRaw,
            excerpt: entity.synopsis,
            paragraphs: entity.content.isEmpty ? [] : [entity.content],
            coverImageName: entity.coverImageName,
            heroImageName: entity.heroImageName,
            coverImageUrl: entity.coverImageUrl,
            readingTimeMinutes: entity.readTimeMinutes,
            totalPages: max(1, entity.totalPages),
            currentPage: max(1, entity.currentPage),
            progressPercent: Int(entity.readingProgress * 100.0),
            rating: nil,
            providerDownloadCount: entity.providerDownloadCount,
            isRecentSubmission: false,
            isSaved: entity.isBookmarked,
            isFinished: entity.isCompleted,
            contentFormat: format,
            sourceProvider: provider,
            providerId: entity.providerId,
            ownerUserId: entity.ownerUserId,
            chapters: chapters.isEmpty ? nil : chapters,
            lastReadChapterId: entity.lastReadChapterId,
            lastReadChapterNumber: entity.lastReadChapterNumber
        )
    }
    
    public func cachedChapters(storyId: UUID) -> [Chapter] {
        let descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        guard
            let entity = try? context.fetch(descriptor).first,
            let data = entity.cachedChaptersData
        else {
            return []
        }
        return (try? JSONDecoder().decode([Chapter].self, from: data)) ?? []
    }

    public func saveCachedChapters(_ chapters: [Chapter], storyId: UUID) {
        guard !chapters.isEmpty else { return }
        let descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        do {
            guard let entity = try context.fetch(descriptor).first else { return }
            entity.cachedChaptersData = try JSONEncoder().encode(chapters)
            entity.updatedAtUtc = Date()
            try context.save()
        } catch {
            print("Failed to cache story chapters: \(error)")
        }
    }

    // Update progress
    public func updateProgress(storyId: UUID, progressPercent: Int, isCompleted: Bool, page: Int = 1, totalPages: Int = 1) {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(descriptor).first {
                entity.readingProgress = min(1.0, max(0.0, Double(progressPercent) / 100.0))
                entity.isCompleted = isCompleted || progressPercent >= 100
                entity.currentPage = max(1, page)
                entity.totalPages = max(1, totalPages)
                entity.updatedAtUtc = Date()
                try context.save()
            }
        } catch {
            print("Failed to update progress: \(error)")
        }
    }
    
    public func updateReadingProgress(storyId: UUID, chapterId: String, chapterNumber: Int) {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1

        do {
            guard let entity = try context.fetch(descriptor).first else { return }
            entity.lastReadChapterId = chapterId
            entity.lastReadChapterNumber = chapterNumber
            entity.updatedAtUtc = Date()
            try context.save()
        } catch {
            print("Failed to update chapter progress: \(error)")
        }
    }

    public func setBookmark(storyId: UUID, isBookmarked: Bool) {
        let targetId = storyId
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == targetId }
        )
        descriptor.fetchLimit = 1
        do {
            guard let entity = try context.fetch(descriptor).first else { return }
            entity.isBookmarked = isBookmarked
            entity.updatedAtUtc = Date()
            try context.save()
        } catch {
            print("Failed to update bookmark state: \(error)")
        }
    }

    // Toggle bookmark
    public func toggleBookmark(storyId: UUID) -> Bool {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(descriptor).first {
                entity.isBookmarked.toggle()
                entity.updatedAtUtc = Date()
                try context.save()
                return entity.isBookmarked
            }
        } catch {
            print("Failed to toggle bookmark: \(error)")
        }
        return false
    }
    
    // Delete story
    public func deleteStory(storyId: UUID, onlyIfUnannotated: Bool = false) {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(descriptor).first {
                if onlyIfUnannotated && !entity.annotations.isEmpty {
                    return
                }
                context.delete(entity)
                try context.save()
            }
        } catch {
            print("Failed to delete story: \(error)")
        }
    }
    
    // MARK: - Annotation / Marginalia Methods

    private func annotationModel(from entity: AnnotationEntity, storyEntity: StoryEntity) -> Annotation {
        Annotation(
            id: entity.id,
            storyId: storyEntity.id,
            storyTitle: storyEntity.title,
            storyAuthor: storyEntity.author,
            chapterNumber: entity.chapterNumber,
            utf16StartOffset: entity.utf16StartOffset,
            utf16EndOffset: entity.utf16EndOffset,
            selectedText: entity.highlightedText,
            note: entity.note,
            color: HighlightColor(rawValue: entity.styleRaw) ?? .terracotta,
            isPinnedToJournal: entity.isPinnedToJournal,
            createdAt: entity.createdAtUtc
        )
    }

    public func clearCachedChapters(storyId: UUID) {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        do {
            guard let entity = try context.fetch(descriptor).first,
                  entity.cachedChaptersData != nil else { return }
            entity.cachedChaptersData = nil
            entity.updatedAtUtc = Date()
            try context.save()
        } catch {
            print("Failed to clear cached story chapters: \(error)")
        }
    }

    public func hasAnyAnnotations(for storyId: UUID) -> Bool {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        guard let storyEntity = try? context.fetch(descriptor).first else {
            return false
        }
        return !storyEntity.annotations.isEmpty
    }

    public func fetchAnnotations(for storyId: UUID, ownerUserId: UUID?) -> [Annotation] {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let storyEntity = try context.fetch(descriptor).first {
                return storyEntity.annotations
                    .filter { $0.ownerUserId == ownerUserId }
                    .map { annotationModel(from: $0, storyEntity: storyEntity) }
            }
        } catch {
            print("Failed to fetch annotations: \(error)")
        }
        return []
    }
    
    public func saveAnnotation(_ annotation: Annotation, ownerUserId: UUID?, storyFallback: Story? = nil) {
        let storyId = annotation.storyId
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            let storyEntity: StoryEntity
            if let fetched = try context.fetch(descriptor).first {
                storyEntity = fetched
            } else if let storyFallback {
                storyEntity = try upsertStoryEntity(storyFallback)
            } else {
                return
            }
            
            if let existing = storyEntity.annotations.first(where: { $0.id == annotation.id }) {
                guard existing.ownerUserId == ownerUserId else { return }
                existing.chapterNumber = annotation.chapterNumber
                existing.highlightedText = annotation.selectedText
                existing.note = annotation.note
                existing.styleRaw = annotation.color.rawValue
                existing.isPinnedToJournal = annotation.isPinnedToJournal
            } else {
                let newEntity = AnnotationEntity(
                    id: annotation.id,
                    chapterNumber: annotation.chapterNumber,
                    utf16StartOffset: annotation.utf16StartOffset,
                    utf16EndOffset: annotation.utf16EndOffset,
                    highlightedText: annotation.selectedText,
                    note: annotation.note,
                    styleRaw: annotation.color.rawValue,
                    isPinnedToJournal: annotation.isPinnedToJournal,
                    ownerUserId: ownerUserId,
                    createdAtUtc: annotation.createdAt,
                    story: storyEntity
                )
                storyEntity.annotations.append(newEntity)
                context.insert(newEntity)
            }
            try context.save()
        } catch {
            print("Failed to save annotation: \(error)")
        }
    }
    
    public func deleteAnnotation(id: UUID, ownerUserId: UUID?) {
        var descriptor = FetchDescriptor<AnnotationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(descriptor).first, entity.ownerUserId == ownerUserId {
                context.delete(entity)
                try context.save()
            }
        } catch {
            print("Failed to delete annotation: \(error)")
        }
    }
    
    public func fetchAllPinnedAnnotations(ownerUserId: UUID?) -> [Annotation] {
        let descriptor = FetchDescriptor<AnnotationEntity>(
            predicate: #Predicate { $0.isPinnedToJournal == true },
            sortBy: [SortDescriptor(\.createdAtUtc, order: .reverse)]
        )
        
        do {
            let entities = try context.fetch(descriptor).filter { $0.ownerUserId == ownerUserId }
            return entities.compactMap { entity in
                guard let storyEntity = entity.story else { return nil }
                return annotationModel(from: entity, storyEntity: storyEntity)
            }
        } catch {
            print("Failed to fetch pinned annotations: \(error)")
            return []
        }
    }
    
    // MARK: - Reading Session & Analytics Logging
    
    public struct ReadingStatsSummary {
        public let storiesReadCount: Int
        public let totalMinutesRead: Int
        public let streakDays: Int
        
        public init(storiesReadCount: Int, totalMinutesRead: Int, streakDays: Int) {
            self.storiesReadCount = storiesReadCount
            self.totalMinutesRead = totalMinutesRead
            self.streakDays = streakDays
        }
    }
    
    public func logReadingSession(
        id: UUID = UUID(),
        storyId: UUID,
        storyTitle: String,
        seconds: Int,
        ownerUserId: UUID,
        isCompleted: Bool
    ) {
        guard seconds >= 3 else { return }
        let log = ReadingLogEntity(
            id: id,
            storyId: storyId,
            storyTitle: storyTitle,
            secondsRead: seconds,
            date: Date(),
            ownerUserId: ownerUserId,
            isCompleted: isCompleted
        )
        context.insert(log)
        try? context.save()
    }
    
    public func fetchReadingStats(ownerUserId: UUID) -> ReadingStatsSummary {
        let descriptor = FetchDescriptor<ReadingLogEntity>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            let logs = try context.fetch(descriptor).filter { $0.ownerUserId == ownerUserId }
            let totalLoggedSeconds = logs.reduce(0) { $0 + $1.secondsRead }
            let completedStoryIDs = Set(logs.filter(\.isCompleted).map(\.storyId))
            let calendar = Calendar.current
            let activeDays = Set(logs.compactMap { calendar.startOfDay(for: $0.date) })
            var streakStart = calendar.startOfDay(for: Date())
            if !activeDays.contains(streakStart),
               let yesterday = calendar.date(byAdding: .day, value: -1, to: streakStart),
               activeDays.contains(yesterday) {
                streakStart = yesterday
            }
            var streakDays = 0
            while activeDays.contains(streakStart) {
                streakDays += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: streakStart) else { break }
                streakStart = previousDay
            }

            return ReadingStatsSummary(
                storiesReadCount: completedStoryIDs.count,
                totalMinutesRead: totalLoggedSeconds / 60,
                streakDays: streakDays
            )
        } catch {
            return ReadingStatsSummary(storiesReadCount: 0, totalMinutesRead: 0, streakDays: 0)
        }
    }

    // MARK: - SwiftData Shelf State (IOS-02)

    public struct ShelfStateRecord: Codable, Equatable {
        public let storyId: UUID
        public let readingProgress: Double
        public let isBookmarked: Bool
        public let isCompleted: Bool
        public let currentPage: Int
        public let totalPages: Int
        public let lastReadChapterId: String?
        public let lastReadChapterNumber: Int?
        public let updatedAtUtc: Date

        public init(
            storyId: UUID,
            readingProgress: Double,
            isBookmarked: Bool,
            isCompleted: Bool,
            currentPage: Int,
            totalPages: Int,
            lastReadChapterId: String?,
            lastReadChapterNumber: Int?,
            updatedAtUtc: Date
        ) {
            self.storyId = storyId
            self.readingProgress = readingProgress
            self.isBookmarked = isBookmarked
            self.isCompleted = isCompleted
            self.currentPage = currentPage
            self.totalPages = totalPages
            self.lastReadChapterId = lastReadChapterId
            self.lastReadChapterNumber = lastReadChapterNumber
            self.updatedAtUtc = updatedAtUtc
        }
    }

    public func fetchShelfStates(ownerKey: String) -> [UUID: ShelfStateRecord] {
        let descriptor = FetchDescriptor<ShelfItemEntity>(
            predicate: #Predicate { $0.ownerKey == ownerKey }
        )
        do {
            let entities = try context.fetch(descriptor)
            var result: [UUID: ShelfStateRecord] = [:]
            for entity in entities {
                result[entity.storyId] = ShelfStateRecord(
                    storyId: entity.storyId,
                    readingProgress: entity.readingProgress,
                    isBookmarked: entity.isBookmarked,
                    isCompleted: entity.isCompleted,
                    currentPage: entity.currentPage,
                    totalPages: entity.totalPages,
                    lastReadChapterId: entity.lastReadChapterId,
                    lastReadChapterNumber: entity.lastReadChapterNumber,
                    updatedAtUtc: entity.updatedAtUtc
                )
            }
            return result
        } catch {
            print("Failed to fetch shelf states: \(error)")
            return [:]
        }
    }

    private func apply(_ record: ShelfStateRecord, to entity: ShelfItemEntity) {
        entity.readingProgress = min(1.0, max(0.0, record.readingProgress))
        entity.isBookmarked = record.isBookmarked
        entity.isCompleted = record.isCompleted
        entity.currentPage = max(1, record.currentPage)
        entity.totalPages = max(1, record.totalPages)
        entity.lastReadChapterId = record.lastReadChapterId
        entity.lastReadChapterNumber = record.lastReadChapterNumber
        entity.updatedAtUtc = record.updatedAtUtc
    }

    private func makeShelfEntity(ownerKey: String, storyId: UUID, record: ShelfStateRecord) -> ShelfItemEntity {
        ShelfItemEntity(
            ownerKey: ownerKey,
            storyId: storyId,
            readingProgress: record.readingProgress,
            isBookmarked: record.isBookmarked,
            isCompleted: record.isCompleted,
            currentPage: record.currentPage,
            totalPages: record.totalPages,
            lastReadChapterId: record.lastReadChapterId,
            lastReadChapterNumber: record.lastReadChapterNumber,
            updatedAtUtc: record.updatedAtUtc
        )
    }

    public func upsertShelfState(_ record: ShelfStateRecord, ownerKey: String) {
        let compositeKey = "\(ownerKey)::\(record.storyId.uuidString.lowercased())"
        var descriptor = FetchDescriptor<ShelfItemEntity>(
            predicate: #Predicate { $0.compositeKey == compositeKey }
        )
        descriptor.fetchLimit = 1
        do {
            if let existing = try context.fetch(descriptor).first {
                apply(record, to: existing)
            } else {
                context.insert(makeShelfEntity(ownerKey: ownerKey, storyId: record.storyId, record: record))
            }
            try context.save()
        } catch {
            print("Failed to upsert shelf state: \(error)")
        }
    }

    public func replaceShelfStates(_ records: [UUID: ShelfStateRecord], ownerKey: String) {
        let descriptor = FetchDescriptor<ShelfItemEntity>(
            predicate: #Predicate { $0.ownerKey == ownerKey }
        )
        do {
            let existing = try context.fetch(descriptor)
            var existingByStoryId = Dictionary(uniqueKeysWithValues: existing.map { ($0.storyId, $0) })

            for (storyId, record) in records {
                if let entity = existingByStoryId.removeValue(forKey: storyId) {
                    apply(record, to: entity)
                } else {
                    context.insert(makeShelfEntity(ownerKey: ownerKey, storyId: storyId, record: record))
                }
            }

            for staleEntity in existingByStoryId.values {
                context.delete(staleEntity)
            }
            try context.save()
        } catch {
            print("Failed to replace shelf states: \(error)")
        }
    }

    @discardableResult
    public func migrateLegacyShelfStatesIfNeeded(
        ownerKey: String,
        legacyStorageKey: String,
        defaults: UserDefaults = .standard
    ) -> [UUID: ShelfStateRecord] {
        var currentStates = fetchShelfStates(ownerKey: ownerKey)
        guard let legacyData = defaults.data(forKey: legacyStorageKey) else {
            return currentStates
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let legacyMap = try? decoder.decode([String: ShelfStateRecord].self, from: legacyData) {
            var didMerge = false
            for (idString, record) in legacyMap {
                guard let uuid = UUID(uuidString: idString) else { continue }
                if let existing = currentStates[uuid] {
                    if record.updatedAtUtc > existing.updatedAtUtc {
                        currentStates[uuid] = record
                        didMerge = true
                    }
                } else {
                    currentStates[uuid] = record
                    didMerge = true
                }
            }
            if didMerge {
                replaceShelfStates(currentStates, ownerKey: ownerKey)
            }
        }
        defaults.removeObject(forKey: legacyStorageKey)
        return currentStates
    }

    // MARK: - Account Deletion Cleanup (DOM-01)

    public func deleteAccountData(ownerUserId: UUID) {
        let ownerKey = ownerUserId.uuidString.lowercased()
        do {
            let storyEntities = try context.fetch(FetchDescriptor<StoryEntity>())
            for entity in storyEntities where entity.ownerUserId == ownerUserId {
                context.delete(entity)
            }

            let annotationEntities = try context.fetch(FetchDescriptor<AnnotationEntity>())
            for entity in annotationEntities where entity.ownerUserId == ownerUserId {
                context.delete(entity)
            }

            let logEntities = try context.fetch(FetchDescriptor<ReadingLogEntity>())
            for entity in logEntities where entity.ownerUserId == ownerUserId {
                context.delete(entity)
            }

            let shelfEntities = try context.fetch(
                FetchDescriptor<ShelfItemEntity>(predicate: #Predicate { $0.ownerKey == ownerKey })
            )
            for entity in shelfEntities {
                context.delete(entity)
            }

            try context.save()
        } catch {
            print("Failed to delete account persistence data: \(error)")
        }
    }
}
