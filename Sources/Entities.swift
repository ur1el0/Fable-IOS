import Foundation
import SwiftData

@Model
public final class StoryEntity {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var author: String
    public var genreRaw: String
    public var chapter: String
    public var synopsis: String
    public var content: String
    public var readTimeMinutes: Int
    public var readingProgress: Double
    public var isBookmarked: Bool
    public var isCompleted: Bool
    public var createdAtUtc: Date
    public var updatedAtUtc: Date
    
    @Relationship(deleteRule: .cascade, inverse: \AnnotationEntity.story)
    public var annotations: [AnnotationEntity] = []
    
    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        genreRaw: String,
        chapter: String = "",
        synopsis: String,
        content: String,
        readTimeMinutes: Int,
        readingProgress: Double = 0.0,
        isBookmarked: Bool = false,
        isCompleted: Bool = false,
        createdAtUtc: Date = Date(),
        updatedAtUtc: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.genreRaw = genreRaw
        self.chapter = chapter
        self.synopsis = synopsis
        self.content = content
        self.readTimeMinutes = readTimeMinutes
        self.readingProgress = min(1.0, max(0.0, readingProgress))
        self.isBookmarked = isBookmarked
        self.isCompleted = isCompleted
        self.createdAtUtc = createdAtUtc
        self.updatedAtUtc = updatedAtUtc
    }
}

@Model
public final class AnnotationEntity {
    @Attribute(.unique) public var id: UUID
    public var utf16StartOffset: Int
    public var utf16EndOffset: Int
    public var highlightedText: String
    public var note: String?
    public var styleRaw: String
    public var isPinnedToJournal: Bool
    public var createdAtUtc: Date
    
    public var story: StoryEntity?
    
    public init(
        id: UUID = UUID(),
        utf16StartOffset: Int,
        utf16EndOffset: Int,
        highlightedText: String,
        note: String? = nil,
        styleRaw: String = "terracotta",
        isPinnedToJournal: Bool = false,
        createdAtUtc: Date = Date(),
        story: StoryEntity? = nil
    ) {
        self.id = id
        self.utf16StartOffset = utf16StartOffset
        self.utf16EndOffset = utf16EndOffset
        self.highlightedText = highlightedText
        self.note = note
        self.styleRaw = styleRaw
        self.isPinnedToJournal = isPinnedToJournal
        self.createdAtUtc = createdAtUtc
        self.story = story
    }
}
