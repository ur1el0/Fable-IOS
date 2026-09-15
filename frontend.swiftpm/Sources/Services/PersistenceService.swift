import Foundation
import SwiftData
import SwiftUI

@MainActor
public final class PersistenceService {
    public static let shared = PersistenceService()
    
    public let container: ModelContainer
    public var context: ModelContext {
        container.mainContext
    }
    
    public init() {
        // Guarantee Application Support directory exists to prevent CoreData recovery warnings
        if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !FileManager.default.fileExists(atPath: appSupportURL.path) {
                try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        do {
            let schema = Schema([
                StoryEntity.self,
                AnnotationEntity.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error)")
        }
    }
    
    // Seed initial folklore stories if database is empty on cold launch
    public func seedInitialDataIfNeeded(seedStories: [Story]) {
        var descriptor = FetchDescriptor<StoryEntity>()
        descriptor.fetchLimit = 1
        
        do {
            let count = try context.fetchCount(descriptor)
            if count == 0 {
                for story in seedStories {
                    let entity = StoryEntity(
                        id: story.id,
                        title: story.title,
                        author: story.author,
                        genreRaw: story.genre.rawValue,
                        chapter: "Chapter I",
                        synopsis: story.synopsis,
                        content: story.content,
                        readTimeMinutes: story.readTimeMinutes,
                        readingProgress: Double(story.progressPercent) / 100.0,
                        isBookmarked: story.isBookmarked,
                        isCompleted: story.isCompleted,
                        createdAtUtc: story.createdAtUtc,
                        updatedAtUtc: Date()
                    )
                    context.insert(entity)
                }
                try context.save()
            }
        } catch {
            print("Failed to seed initial stories: \(error)")
        }
    }
    
    // Fetch all persistent stories
    public func fetchAllStories() -> [StoryEntity] {
        let descriptor = FetchDescriptor<StoryEntity>(
            sortBy: [SortDescriptor(\.createdAtUtc, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("Failed to fetch stories: \(error)")
            return []
        }
    }
    
    // Insert or update manuscript
    public func saveStory(_ story: Story) {
        let targetId = story.id
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == targetId }
        )
        descriptor.fetchLimit = 1
        
        do {
            let matches = try context.fetch(descriptor)
            if let existing = matches.first {
                existing.title = story.title
                existing.author = story.author
                existing.genreRaw = story.genre.rawValue
                existing.synopsis = story.synopsis
                existing.content = story.content
                existing.readTimeMinutes = story.readTimeMinutes
                existing.readingProgress = Double(story.progressPercent) / 100.0
                existing.isBookmarked = story.isBookmarked
                existing.isCompleted = story.isCompleted
                existing.updatedAtUtc = Date()
            } else {
                let newEntity = StoryEntity(
                    id: story.id,
                    title: story.title,
                    author: story.author,
                    genreRaw: story.genre.rawValue,
                    chapter: "Chapter I",
                    synopsis: story.synopsis,
                    content: story.content,
                    readTimeMinutes: story.readTimeMinutes,
                    readingProgress: Double(story.progressPercent) / 100.0,
                    isBookmarked: story.isBookmarked,
                    isCompleted: story.isCompleted,
                    createdAtUtc: story.createdAtUtc,
                    updatedAtUtc: Date()
                )
                context.insert(newEntity)
            }
            try context.save()
        } catch {
            print("Failed to save story: \(error)")
        }
    }
    
    // Update progress
    public func updateProgress(storyId: UUID, progressPercent: Int, isCompleted: Bool) {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(descriptor).first {
                entity.readingProgress = min(1.0, max(0.0, Double(progressPercent) / 100.0))
                entity.isCompleted = isCompleted || progressPercent >= 100
                entity.updatedAtUtc = Date()
                try context.save()
            }
        } catch {
            print("Failed to update progress: \(error)")
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
    public func deleteStory(storyId: UUID) {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(descriptor).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            print("Failed to delete story: \(error)")
        }
    }
    
    // MARK: - Annotation / Marginalia Methods
    
    public func fetchAnnotations(for storyId: UUID) -> [Annotation] {
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let storyEntity = try context.fetch(descriptor).first {
                return storyEntity.annotations.map { entity in
                    Annotation(
                        id: entity.id,
                        storyId: storyId,
                        storyTitle: storyEntity.title,
                        storyAuthor: storyEntity.author,
                        utf16StartOffset: entity.utf16StartOffset,
                        utf16EndOffset: entity.utf16EndOffset,
                        selectedText: entity.highlightedText,
                        note: entity.note,
                        color: HighlightColor(rawValue: entity.styleRaw) ?? .terracotta,
                        isPinnedToJournal: entity.isPinnedToJournal,
                        createdAt: entity.createdAtUtc
                    )
                }
            }
        } catch {
            print("Failed to fetch annotations: \(error)")
        }
        return []
    }
    
    public func saveAnnotation(_ annotation: Annotation) {
        let storyId = annotation.storyId
        var descriptor = FetchDescriptor<StoryEntity>(
            predicate: #Predicate { $0.id == storyId }
        )
        descriptor.fetchLimit = 1
        
        do {
            guard let storyEntity = try context.fetch(descriptor).first else { return }
            
            // Check if annotation exists
            if let existing = storyEntity.annotations.first(where: { $0.id == annotation.id }) {
                existing.highlightedText = annotation.selectedText
                existing.note = annotation.note
                existing.styleRaw = annotation.color.rawValue
                existing.isPinnedToJournal = annotation.isPinnedToJournal
            } else {
                let newEntity = AnnotationEntity(
                    id: annotation.id,
                    utf16StartOffset: annotation.utf16StartOffset,
                    utf16EndOffset: annotation.utf16EndOffset,
                    highlightedText: annotation.selectedText,
                    note: annotation.note,
                    styleRaw: annotation.color.rawValue,
                    isPinnedToJournal: annotation.isPinnedToJournal,
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
    
    public func deleteAnnotation(id: UUID) {
        var descriptor = FetchDescriptor<AnnotationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        
        do {
            if let entity = try context.fetch(descriptor).first {
                context.delete(entity)
                try context.save()
            }
        } catch {
            print("Failed to delete annotation: \(error)")
        }
    }
    
    public func fetchAllPinnedAnnotations() -> [Annotation] {
        let descriptor = FetchDescriptor<AnnotationEntity>(
            predicate: #Predicate { $0.isPinnedToJournal == true },
            sortBy: [SortDescriptor(\.createdAtUtc, order: .reverse)]
        )
        
        do {
            let entities = try context.fetch(descriptor)
            return entities.map { entity in
                Annotation(
                    id: entity.id,
                    storyId: entity.story?.id ?? UUID(),
                    storyTitle: entity.story?.title ?? "Fable Manuscript",
                    storyAuthor: entity.story?.author ?? "Unknown Author",
                    utf16StartOffset: entity.utf16StartOffset,
                    utf16EndOffset: entity.utf16EndOffset,
                    selectedText: entity.highlightedText,
                    note: entity.note,
                    color: HighlightColor(rawValue: entity.styleRaw) ?? .terracotta,
                    isPinnedToJournal: entity.isPinnedToJournal,
                    createdAt: entity.createdAtUtc
                )
            }
        } catch {
            print("Failed to fetch pinned annotations: \(error)")
            return []
        }
    }
}
