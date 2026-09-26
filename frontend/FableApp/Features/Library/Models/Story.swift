import SwiftUI

public enum ReaderFont: String, CaseIterable, Identifiable, Codable {
    case serif = "Serif"
    case sans = "Sans"
    case mono = "Mono"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .serif: return "Source Serif 4"
        case .sans: return "SF Pro"
        case .mono: return "SF Mono"
        }
    }
    
    public func font(size: CGFloat) -> Font {
        switch self {
        case .serif: return .system(size: size, design: .serif)
        case .sans: return .system(size: size, design: .default)
        case .mono: return .system(size: size, design: .monospaced)
        }
    }
}

public enum ReaderTheme: String, CaseIterable, Identifiable, Codable {
    case white = "White"
    case sepia = "Sepia"
    case charcoal = "Charcoal"
    case oled = "OLED"
    
    public var id: String { rawValue }
    
    public var backgroundColor: Color {
        switch self {
        case .white: return .white
        case .sepia: return FableTheme.sepiaBackground
        case .charcoal: return FableTheme.charcoalBackground
        case .oled: return FableTheme.oledBackground
        }
    }
    
    public var textColor: Color {
        switch self {
        case .white: return FableTheme.deepCharcoal
        case .sepia: return FableTheme.sepiaText
        case .charcoal: return FableTheme.charcoalText
        case .oled: return FableTheme.oledText
        }
    }
    
    public var swatchColor: Color {
        switch self {
        case .white: return .white
        case .sepia: return Color(red: 0.93, green: 0.86, blue: 0.77)
        case .charcoal: return Color(red: 0.22, green: 0.22, blue: 0.22)
        case .oled: return .black
        }
    }
}

public enum ReaderLineSpacing: String, CaseIterable, Identifiable, Codable {
    case compact = "Compact"
    case normal = "Normal"
    case spacious = "Spacious"
    
    public var id: String { rawValue }
    
    public var points: CGFloat {
        switch self {
        case .compact: return 4
        case .normal: return 8
        case .spacious: return 14
        }
    }
}

public enum ContentFormat: String, Codable, CaseIterable, Identifiable {
    case prose = "PROSE"
    case manga = "MANGA"

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .prose: return "Novel"
        case .manga: return "Manga"
        }
    }
}

public enum SourceProvider: String, Codable, CaseIterable, Identifiable {
    case gutenberg = "GUTENBERG"
    case standardEbooks = "STANDARD_EBOOKS"
    case mangadex = "MANGADEX"
    case fableOriginal = "FABLE_ORIGINAL"

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .gutenberg: return "Project Gutenberg"
        case .standardEbooks: return "Standard Ebooks"
        case .mangadex: return "MangaDex"
        case .fableOriginal: return "Fable Original"
        }
    }
}

public struct Genre: RawRepresentable, Codable, Hashable, Identifiable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var id: String { rawValue }

    public static let all = Genre(rawValue: "All")
    public static let manga = Genre(rawValue: "Manga")
    public static let folklore = Genre(rawValue: "Folklore")
    public static let urbanLegend = Genre(rawValue: "Urban Legend")
    public static let mythology = Genre(rawValue: "Mythology")
    public static let horror = Genre(rawValue: "Horror")
    public static let speculative = Genre(rawValue: "Speculative")
    public static let gothic = Genre(rawValue: "Gothic")
    public static let classic = Genre(rawValue: "Classic")
    public static let classicFiction = Genre(rawValue: "Classic Fiction")
    public static let classicMystery = Genre(rawValue: "Classic Mystery")
    public static let darkFantasy = Genre(rawValue: "Dark Fantasy")
    public static let unspecified = Genre(rawValue: "")

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct Chapter: Identifiable, Hashable, Codable {
    public let id: UUID
    public let storyId: UUID
    public let chapterNumber: Int
    public var title: String
    public var content: String
    public var wordCount: Int
    public let createdAtUtc: Date
    public var pageUrls: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case storyId
        case chapterNumber
        case title
        case content
        case wordCount
        case createdAtUtc
        case pageUrls
    }

    public init(
        id: UUID = UUID(),
        storyId: UUID,
        chapterNumber: Int,
        title: String,
        content: String = "",
        wordCount: Int = 0,
        createdAtUtc: Date = Date(),
        pageUrls: [String] = []
    ) {
        self.id = id
        self.storyId = storyId
        self.chapterNumber = chapterNumber
        self.title = title
        self.content = content
        self.wordCount = wordCount == 0 ? content.components(separatedBy: .whitespacesAndNewlines).filter({ !$0.isEmpty }).count : wordCount
        self.createdAtUtc = createdAtUtc
        self.pageUrls = pageUrls
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.storyId = try container.decodeIfPresent(UUID.self, forKey: .storyId) ?? UUID()
        self.chapterNumber = try container.decodeIfPresent(Int.self, forKey: .chapterNumber) ?? 1
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount) ?? 0
        self.createdAtUtc = try container.decodeIfPresent(Date.self, forKey: .createdAtUtc) ?? Date()
        self.pageUrls = try container.decodeIfPresent([String].self, forKey: .pageUrls) ?? []
    }
}

public struct UpdateFeed: Codable {
    public let taleOfTheDay: Story?
    public let curatorSpotlight: Story?
    public let recentSubmissions: [Story]
    public let totalStories: Int
    public let timestampUtc: Date

    enum CodingKeys: String, CodingKey {
        case taleOfTheDay
        case curatorSpotlight
        case recentSubmissions
        case totalStories
        case timestampUtc
    }
}

public struct Story: Identifiable, Hashable, Codable {
    public let id: UUID
    public var title: String
    public var author: String
    public var genre: Genre
    public var synopsis: String
    public var content: String
    public var readTimeMinutes: Int
    public var isBookmarked: Bool
    public var isCompleted: Bool
    public var createdAtUtc: Date

    // Prototype presentation fields
    public var coverImageName: String?
    public var heroImageName: String?
    public var coverImageUrl: String?
    public var totalPages: Int
    public var currentPage: Int
    public var progressPercent: Int
    public var rating: Double?
    public var providerDownloadCount: Int?
    public var savesCount: String
    public var readsCount: String
    public var isTaleOfTheDay: Bool
    public var isRecentSubmission: Bool
    public var isCuratorSpotlight: Bool
    public var badgeText: String?
    public var totalChapters: Int
    public var chapters: [Chapter]?
    public var contentFormat: ContentFormat
    public var sourceProvider: SourceProvider
    public var providerId: String?
    public var lastReadChapterId: String?
    public var lastReadChapterNumber: Int?

    // Convenience accessors
    public var excerpt: String {
        get { synopsis }
        set { synopsis = newValue }
    }

    public var readingTimeMinutes: Int {
        get { readTimeMinutes }
        set { readTimeMinutes = newValue }
    }

    public var isSaved: Bool {
        get { isBookmarked }
        set { isBookmarked = newValue }
    }

    public var isFinished: Bool {
        get { isCompleted }
        set { isCompleted = newValue }
    }

    public var effectiveCoverImage: String? {
        guard let url = coverImageUrl, !url.isEmpty else { return nil }
        return url
    }

    public var paragraphs: [String] {
        let split = content.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return split.isEmpty ? (synopsis.isEmpty ? [] : [synopsis]) : split
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, genre, synopsis, content, readTimeMinutes, isBookmarked, isCompleted, createdAtUtc
        case coverImageName, heroImageName, coverImageUrl, totalPages, currentPage, progressPercent, rating, providerDownloadCount, savesCount, readsCount
        case isTaleOfTheDay, isRecentSubmission, isCuratorSpotlight, badgeText, totalChapters, chapters
        case contentFormat, sourceProvider, providerId, lastReadChapterId, lastReadChapterNumber
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.author = try container.decode(String.self, forKey: .author)
        self.genre = try container.decodeIfPresent(Genre.self, forKey: .genre) ?? .unspecified
        self.synopsis = try container.decodeIfPresent(String.self, forKey: .synopsis) ?? ""
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.readTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .readTimeMinutes) ?? 0
        self.isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        self.isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        self.createdAtUtc = try container.decodeIfPresent(Date.self, forKey: .createdAtUtc) ?? Date()

        self.coverImageName = try container.decodeIfPresent(String.self, forKey: .coverImageName)
        self.heroImageName = try container.decodeIfPresent(String.self, forKey: .heroImageName)
        self.coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        self.totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 0
        self.currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage) ?? 1
        self.progressPercent = try container.decodeIfPresent(Int.self, forKey: .progressPercent) ?? 0
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        self.providerDownloadCount = try container.decodeIfPresent(Int.self, forKey: .providerDownloadCount)
        self.savesCount = try container.decodeIfPresent(String.self, forKey: .savesCount) ?? "0"
        self.readsCount = try container.decodeIfPresent(String.self, forKey: .readsCount) ?? "0"
        self.isTaleOfTheDay = try container.decodeIfPresent(Bool.self, forKey: .isTaleOfTheDay) ?? false
        self.isRecentSubmission = try container.decodeIfPresent(Bool.self, forKey: .isRecentSubmission) ?? false
        self.isCuratorSpotlight = try container.decodeIfPresent(Bool.self, forKey: .isCuratorSpotlight) ?? false
        self.badgeText = try container.decodeIfPresent(String.self, forKey: .badgeText)
        self.totalChapters = try container.decodeIfPresent(Int.self, forKey: .totalChapters) ?? 0
        self.chapters = try container.decodeIfPresent([Chapter].self, forKey: .chapters)
        self.contentFormat = try container.decodeIfPresent(ContentFormat.self, forKey: .contentFormat) ?? .prose
        self.sourceProvider = try container.decodeIfPresent(SourceProvider.self, forKey: .sourceProvider) ?? .fableOriginal
        self.providerId = try container.decodeIfPresent(String.self, forKey: .providerId)
        self.lastReadChapterId = try container.decodeIfPresent(String.self, forKey: .lastReadChapterId)
        self.lastReadChapterNumber = try container.decodeIfPresent(Int.self, forKey: .lastReadChapterNumber)
    }

    // Architecture Contract Initializer (ARCHITECTURE.md Section 3.1 & 7.2)
    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        genre: Genre,
        synopsis: String,
        content: String,
        readTimeMinutes: Int,
        isBookmarked: Bool = false,
        isCompleted: Bool = false,
        createdAtUtc: Date = Date(),
        contentFormat: ContentFormat = .prose,
        sourceProvider: SourceProvider = .fableOriginal,
        providerId: String? = nil,
        lastReadChapterId: String? = nil,
        lastReadChapterNumber: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.genre = genre
        self.synopsis = synopsis
        self.content = content
        self.readTimeMinutes = readTimeMinutes
        self.isBookmarked = isBookmarked
        self.isCompleted = isCompleted
        self.createdAtUtc = createdAtUtc
        self.totalPages = max(0, readTimeMinutes)
        self.currentPage = 1
        self.progressPercent = isCompleted ? 100 : 0
        self.rating = nil
        self.providerDownloadCount = nil
        self.savesCount = "0"
        self.readsCount = "0"
        self.isTaleOfTheDay = false
        self.isRecentSubmission = true
        self.isCuratorSpotlight = false
        self.badgeText = nil
        self.coverImageName = nil
        self.heroImageName = nil
        self.coverImageUrl = nil
        self.totalChapters = 1
        self.chapters = nil
        self.contentFormat = contentFormat
        self.sourceProvider = sourceProvider
        self.providerId = providerId
        self.lastReadChapterId = lastReadChapterId
        self.lastReadChapterNumber = lastReadChapterNumber
    }

    // Full Prototype Initializer
    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        genre: String,
        excerpt: String,
        paragraphs: [String] = [],
        coverImageName: String? = nil,
        heroImageName: String? = nil,
        coverImageUrl: String? = nil,
        readingTimeMinutes: Int = 0,
        totalPages: Int = 0,
        currentPage: Int = 1,
        progressPercent: Int = 0,
        rating: Double? = nil,
        providerDownloadCount: Int? = nil,
        savesCount: String = "0",
        readsCount: String = "0",
        isTaleOfTheDay: Bool = false,
        isRecentSubmission: Bool = false,
        isSaved: Bool = false,
        isFinished: Bool = false,
        isCuratorSpotlight: Bool = false,
        badgeText: String? = nil,
        contentFormat: ContentFormat = .prose,
        sourceProvider: SourceProvider = .fableOriginal,
        providerId: String? = nil,
        chapters: [Chapter]? = nil,
        lastReadChapterId: String? = nil,
        lastReadChapterNumber: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.genre = Genre(rawValue: genre)
        self.synopsis = excerpt
        self.content = paragraphs.joined(separator: "\n\n")
        self.readTimeMinutes = readingTimeMinutes
        self.isBookmarked = isSaved
        self.isCompleted = isFinished
        self.createdAtUtc = Date()
        self.coverImageName = coverImageName
        self.heroImageName = heroImageName
        self.coverImageUrl = coverImageUrl
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.progressPercent = progressPercent
        self.rating = rating
        self.providerDownloadCount = providerDownloadCount
        self.savesCount = savesCount
        self.readsCount = readsCount
        self.isTaleOfTheDay = isTaleOfTheDay
        self.isRecentSubmission = isRecentSubmission
        self.isCuratorSpotlight = isCuratorSpotlight
        self.badgeText = badgeText
        self.totalChapters = max(1, chapters?.count ?? 1)
        self.chapters = chapters
        self.contentFormat = contentFormat
        self.sourceProvider = sourceProvider
        self.providerId = providerId
        self.lastReadChapterId = lastReadChapterId
        self.lastReadChapterNumber = lastReadChapterNumber
    }
}

public struct GenreCategory: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var storyCount: Int
    public var readersCount: String
    public var description: String
    public var imageName: String
    public var imageUrl: String?
    
    public var effectiveImage: String {
        guard let url = imageUrl, !url.isEmpty else { return "" }
        return url
    }
    
    public init(id: UUID = UUID(), name: String, storyCount: Int, readersCount: String, description: String, imageName: String, imageUrl: String? = nil) {
        self.id = id
        self.name = name
        self.storyCount = storyCount
        self.readersCount = readersCount
        self.description = description
        self.imageName = imageName
        self.imageUrl = imageUrl
    }
}

public struct Writer: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var avatarImageName: String
    public var avatarImageUrl: String?
    public var storyCount: Int
    public var rating: Double?
    
    public var effectiveAvatar: String {
        guard let url = avatarImageUrl, !url.isEmpty else { return "" }
        return url
    }
    
    public init(id: UUID = UUID(), name: String, avatarImageName: String, avatarImageUrl: String? = nil, storyCount: Int, rating: Double? = nil) {
        self.id = id
        self.name = name
        self.avatarImageName = avatarImageName
        self.avatarImageUrl = avatarImageUrl
        self.storyCount = storyCount
        self.rating = rating
    }
}

public enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case terracotta
    case amber
    case sage
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .terracotta: return "Terracotta"
        case .amber: return "Amber"
        case .sage: return "Sage"
        }
    }
    
    public var displayColor: Color {
        switch self {
        case .terracotta: return Color(red: 0.624, green: 0.235, blue: 0.086).opacity(0.28)
        case .amber:      return Color(red: 0.851, green: 0.604, blue: 0.306).opacity(0.32)
        case .sage:       return Color(red: 0.482, green: 0.549, blue: 0.494).opacity(0.32)
        }
    }
}

public struct Annotation: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public let storyId: UUID
    public var storyTitle: String
    public var storyAuthor: String
    public let utf16StartOffset: Int
    public let utf16EndOffset: Int
    public let selectedText: String
    public var note: String?
    public var color: HighlightColor
    public var isPinnedToJournal: Bool
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        storyId: UUID,
        storyTitle: String = "",
        storyAuthor: String = "",
        utf16StartOffset: Int,
        utf16EndOffset: Int,
        selectedText: String,
        note: String? = nil,
        color: HighlightColor = .terracotta,
        isPinnedToJournal: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.storyId = storyId
        self.storyTitle = storyTitle
        self.storyAuthor = storyAuthor
        self.utf16StartOffset = utf16StartOffset
        self.utf16EndOffset = utf16EndOffset
        self.selectedText = selectedText
        self.note = note
        self.color = color
        self.isPinnedToJournal = isPinnedToJournal
        self.createdAt = createdAt
    }
}

// MARK: - User & Authentication Domain Models

public struct UserSession: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var handle: String
    public var email: String
    public var bio: String
    public var avatarName: String?
    public var isGuest: Bool
    public var joinedDate: Date

    public init(
        id: UUID = UUID(),
        name: String,
        handle: String,
        email: String,
        bio: String = "",
        avatarName: String? = nil,
        isGuest: Bool = false,
        joinedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.handle = handle
        self.email = email
        self.bio = bio
        self.avatarName = avatarName
        self.isGuest = isGuest
        self.joinedDate = joinedDate
    }

    public static func guest() -> UserSession {
        UserSession(name: "Guest", handle: "", email: "", isGuest: true)
    }
}
