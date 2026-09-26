import Foundation
import SwiftData

@Model
public final class StoryEntity {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var author: String
    public var genreRaw: String
    public var contentFormatRaw: String?
    public var sourceProviderRaw: String?
    public var chapter: String
    public var synopsis: String
    public var content: String
    public var readTimeMinutes: Int
    public var readingProgress: Double
    public var currentPage: Int = 1
    public var totalPages: Int = 1
    public var coverImageName: String?
    public var heroImageName: String?
    public var coverImageUrl: String?
    public var providerId: String?
    public var providerDownloadCount: Int?
    @Attribute(.externalStorage) public var cachedChaptersData: Data?
    public var lastReadChapterId: String?
    public var lastReadChapterNumber: Int?
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
        contentFormatRaw: String? = nil,
        sourceProviderRaw: String? = nil,
        chapter: String = "",
        synopsis: String,
        content: String,
        readTimeMinutes: Int,
        readingProgress: Double = 0.0,
        currentPage: Int = 1,
        totalPages: Int = 1,
        coverImageName: String? = nil,
        heroImageName: String? = nil,
        coverImageUrl: String? = nil,
        providerId: String? = nil,
        providerDownloadCount: Int? = nil,
        cachedChaptersData: Data? = nil,
        lastReadChapterId: String? = nil,
        lastReadChapterNumber: Int? = nil,
        isBookmarked: Bool = false,
        isCompleted: Bool = false,
        createdAtUtc: Date = Date(),
        updatedAtUtc: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.genreRaw = genreRaw
        self.contentFormatRaw = contentFormatRaw
        self.sourceProviderRaw = sourceProviderRaw
        self.chapter = chapter
        self.synopsis = synopsis
        self.content = content
        self.readTimeMinutes = readTimeMinutes
        self.readingProgress = min(1.0, max(0.0, readingProgress))
        self.currentPage = max(1, currentPage)
        self.totalPages = max(1, totalPages)
        self.coverImageName = coverImageName
        self.heroImageName = heroImageName
        self.coverImageUrl = coverImageUrl
        self.providerId = providerId
        self.providerDownloadCount = providerDownloadCount
        self.cachedChaptersData = cachedChaptersData
        self.lastReadChapterId = lastReadChapterId
        self.lastReadChapterNumber = lastReadChapterNumber
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

@Model
public final class ReadingLogEntity {
    @Attribute(.unique) public var id: UUID
    public var storyId: UUID
    public var storyTitle: String
    public var secondsRead: Int
    public var date: Date
    public var isCompleted: Bool

    public init(
        id: UUID = UUID(),
        storyId: UUID,
        storyTitle: String,
        secondsRead: Int,
        date: Date = Date(),
        isCompleted: Bool = false
    ) {
        self.id = id
        self.storyId = storyId
        self.storyTitle = storyTitle
        self.secondsRead = secondsRead
        self.date = date
        self.isCompleted = isCompleted
    }
}
