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

public enum Genre: String, Codable, CaseIterable, Identifiable {
    case all = "All"
    case manga = "Manga"
    case folklore = "Folklore"
    case urbanLegend = "Urban Legend"
    case mythology = "Mythology"
    case horror = "Horror"
    case speculative = "Speculative"
    case gothic = "Gothic"
    case classic = "Classic"
    case classicFiction = "Classic Fiction"
    case classicMystery = "Classic Mystery"
    case darkFantasy = "Dark Fantasy"

    public var id: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let match = Genre(rawValue: raw) {
            self = match
        } else {
            let lower = raw.lowercased()
            if lower.contains("manga") || lower.contains("comic") { self = .manga }
            else if lower.contains("folk") { self = .folklore }
            else if lower.contains("urban") { self = .urbanLegend }
            else if lower.contains("myth") { self = .mythology }
            else if lower.contains("horror") { self = .horror }
            else if lower.contains("gothic") { self = .gothic }
            else if lower.contains("speculative") || lower.contains("sci-fi") { self = .speculative }
            else if lower.contains("fantasy") { self = .darkFantasy }
            else { self = .all }
        }
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
    public var rating: Double
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
        if let url = coverImageUrl, !url.isEmpty {
            return url
        }
        return coverImageName
    }

    public var paragraphs: [String] {
        let split = content.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return split.isEmpty ? (synopsis.isEmpty ? [] : [synopsis]) : split
    }

    enum CodingKeys: String, CodingKey {
        case id, title, author, genre, synopsis, content, readTimeMinutes, isBookmarked, isCompleted, createdAtUtc
        case coverImageName, heroImageName, coverImageUrl, totalPages, currentPage, progressPercent, rating, savesCount, readsCount
        case isTaleOfTheDay, isRecentSubmission, isCuratorSpotlight, badgeText, totalChapters, chapters
        case contentFormat, sourceProvider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.author = try container.decode(String.self, forKey: .author)
        self.genre = try container.decodeIfPresent(Genre.self, forKey: .genre) ?? .folklore
        self.synopsis = try container.decodeIfPresent(String.self, forKey: .synopsis) ?? ""
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.readTimeMinutes = try container.decodeIfPresent(Int.self, forKey: .readTimeMinutes) ?? 5
        self.isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        self.isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        self.createdAtUtc = try container.decodeIfPresent(Date.self, forKey: .createdAtUtc) ?? Date()

        self.coverImageName = try container.decodeIfPresent(String.self, forKey: .coverImageName)
        self.heroImageName = try container.decodeIfPresent(String.self, forKey: .heroImageName)
        self.coverImageUrl = try container.decodeIfPresent(String.self, forKey: .coverImageUrl)
        self.totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 5
        self.currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage) ?? 1
        self.progressPercent = try container.decodeIfPresent(Int.self, forKey: .progressPercent) ?? 0
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating) ?? 4.9
        self.savesCount = try container.decodeIfPresent(String.self, forKey: .savesCount) ?? "1.2k"
        self.readsCount = try container.decodeIfPresent(String.self, forKey: .readsCount) ?? "1.2k"
        self.isTaleOfTheDay = try container.decodeIfPresent(Bool.self, forKey: .isTaleOfTheDay) ?? false
        self.isRecentSubmission = try container.decodeIfPresent(Bool.self, forKey: .isRecentSubmission) ?? false
        self.isCuratorSpotlight = try container.decodeIfPresent(Bool.self, forKey: .isCuratorSpotlight) ?? false
        self.badgeText = try container.decodeIfPresent(String.self, forKey: .badgeText)
        self.totalChapters = try container.decodeIfPresent(Int.self, forKey: .totalChapters) ?? 1
        self.chapters = try container.decodeIfPresent([Chapter].self, forKey: .chapters)
        self.contentFormat = try container.decodeIfPresent(ContentFormat.self, forKey: .contentFormat) ?? .prose
        self.sourceProvider = try container.decodeIfPresent(SourceProvider.self, forKey: .sourceProvider) ?? .fableOriginal
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
        sourceProvider: SourceProvider = .fableOriginal
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
        self.totalPages = max(1, readTimeMinutes)
        self.currentPage = 1
        self.progressPercent = isCompleted ? 100 : 0
        self.rating = 4.9
        self.savesCount = "1.2k"
        self.readsCount = "1.2k"
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
        readingTimeMinutes: Int = 4,
        totalPages: Int = 5,
        currentPage: Int = 1,
        progressPercent: Int = 0,
        rating: Double = 4.9,
        savesCount: String = "1.2k",
        readsCount: String = "1.2k",
        isTaleOfTheDay: Bool = false,
        isRecentSubmission: Bool = false,
        isSaved: Bool = false,
        isFinished: Bool = false,
        isCuratorSpotlight: Bool = false,
        badgeText: String? = nil,
        contentFormat: ContentFormat = .prose,
        sourceProvider: SourceProvider = .fableOriginal,
        chapters: [Chapter]? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.genre = Genre(rawValue: genre) ?? {
            let lower = genre.lowercased()
            if lower.contains("manga") || lower.contains("comic") { return .manga }
            if lower.contains("folk") { return .folklore }
            if lower.contains("myth") { return .mythology }
            if lower.contains("horror") || lower.contains("gothic") { return .horror }
            if lower.contains("urban") { return .urbanLegend }
            return .folklore
        }()
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
        if let url = imageUrl, !url.isEmpty {
            return url
        }
        return imageName
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
    public var rating: Double
    
    public var effectiveAvatar: String {
        if let url = avatarImageUrl, !url.isEmpty {
            return url
        }
        return avatarImageName
    }
    
    public init(id: UUID = UUID(), name: String, avatarImageName: String, avatarImageUrl: String? = nil, storyCount: Int, rating: Double) {
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

    /// Pre-configured seed profile for default authoring
    public static let defaultUser = UserSession(
        name: "Roosc Zaño",
        handle: "@zanoroosc",
        email: "roosc-zano@fable.app",
        bio: "Writer of quiet lore, archivist of dusk folklore, and collector of vintage horology tales.",
        avatarName: "avatar_roosc",
        isGuest: false
    )

    /// Ephemeral session for guest exploration
    public static let guestUser = UserSession(
        name: "Guest Reader",
        handle: "@reader",
        email: "guest@fable.local",
        bio: "Exploring the curated folklore manuscripts as a guest.",
        avatarName: nil,
        isGuest: true
    )
}

extension Story {
    public static let defaultSeedStories: [Story] = [
        Story(
            title: "Dracula",
            author: "Bram Stoker",
            genre: "Gothic",
            excerpt: "The castle is on the very edge of a terrible precipice. A stone falling from the window would fall a thousand feet without touching anything.",
            paragraphs: [
                "Before the sun had set, we reached the Bistritz pass. The grey of the evening had begun to fall, and the shadows of the mountains seemed to close in around us with every mile. The horses began to strain against the harness as the road turned sharply upward into the deep pine forests of Transylvania.",
                "\"The castle is on the very edge of a terrible precipice,\" the driver whispered, crossing himself as the wolves began their low, distant howling down in the valley below. \"A stone falling from the window would fall a thousand feet without touching anything.\"",
                "The wind grew colder, piercing through my woollen mantle with icy teeth. Far above, perched jaggedly upon a fang of rock, the black battlements rose against a sky bruised with indigo and blood orange.",
                "I could hear the wolves getting closer. Their choruses echoed through the gorge like a choir of starved spirits. And then, at the crest of the winding road, a tall figure in a heavy cape stepped into the lantern light..."
            ],
            coverImageName: "cover_dracula",
            heroImageName: "hero_castle",
            coverImageUrl: "https://www.gutenberg.org/cache/epub/345/pg345.cover.medium.jpg",
            readingTimeMinutes: 4,
            totalPages: 5,
            currentPage: 1,
            progressPercent: 0,
            rating: 4.95,
            isTaleOfTheDay: true,
            isSaved: false,
            sourceProvider: .gutenberg
        ),
        Story(
            title: "The Legend of Sleepy Hollow",
            author: "Washington Irving",
            genre: "Folklore",
            excerpt: "A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere.",
            paragraphs: [
                "A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere. Some say that the place was bewitched by a High German doctor, during the early days of the settlement; others, that an old Indian chief, the prophet or wizard of his tribe, held his powwows there before the country was discovered by Master Hendrick Hudson.",
                "Certain it is, the place still continues under the sway of some bewitching power, that holds a spell over the minds of the good people, causing them to walk in a continual reverie. They are given to all kinds of marvelous beliefs, are subject to trances and visions, and frequently see strange sights, and hear music and voices in the air."
            ],
            coverImageName: "thumb_sleepy",
            heroImageName: "cover_sleepy_featured",
            coverImageUrl: "https://www.gutenberg.org/cache/epub/41/pg41.cover.medium.jpg",
            readingTimeMinutes: 4,
            totalPages: 24,
            currentPage: 1,
            progressPercent: 0,
            rating: 4.95,
            isSaved: false,
            isCuratorSpotlight: true,
            sourceProvider: .gutenberg
        ),
        Story(
            title: "The Metamorphosis",
            author: "Franz Kafka",
            genre: "Classic Fiction",
            excerpt: "One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin.",
            paragraphs: [
                "One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin.",
                "He lay on his armour-like back, and if he lifted his head a little he could see his brown belly, slightly domed and divided by arches into stiff sections."
            ],
            coverImageName: "thumb_metamorphosis",
            coverImageUrl: "https://www.gutenberg.org/cache/epub/5200/pg5200.cover.medium.jpg",
            readingTimeMinutes: 5,
            totalPages: 8,
            currentPage: 1,
            progressPercent: 0,
            isRecentSubmission: true,
            isSaved: false,
            sourceProvider: .gutenberg
        ),
        Story(
            title: "The Tell-Tale Heart",
            author: "Edgar Allan Poe",
            genre: "Gothic",
            excerpt: "True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad?",
            paragraphs: [
                "True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad? The disease had sharpened my senses — not destroyed — not dulled them.",
                "Above all was the sense of hearing acute. I heard all things in the heaven and in the earth. I heard many things in hell. How, then, am I mad? Hearken! and observe how healthily — how calmly I can tell you the whole story."
            ],
            coverImageName: "thumb_tell_tale",
            coverImageUrl: "https://www.gutenberg.org/cache/epub/2148/pg2148.cover.medium.jpg",
            readingTimeMinutes: 3,
            totalPages: 4,
            currentPage: 1,
            progressPercent: 0,
            isRecentSubmission: true,
            isSaved: false,
            sourceProvider: .gutenberg
        ),
        Story(
            title: "The Legend of Maria Makiling",
            author: "Jose Rizal",
            genre: "Folklore",
            excerpt: "She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient woods...",
            paragraphs: [
                "She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient woods...",
                "Her voice was like the murmur of crystal water over white pebbles, and her step was as light as the dewdrop falling upon a leaf at dawn."
            ],
            coverImageName: "thumb_maria_makiling",
            coverImageUrl: "https://www.gutenberg.org/cache/epub/38269/pg38269.cover.medium.jpg",
            readingTimeMinutes: 4,
            totalPages: 6,
            currentPage: 1,
            progressPercent: 0,
            isRecentSubmission: true,
            isSaved: false,
            sourceProvider: .gutenberg
        ),
        Story(
            title: "Rip Van Winkle",
            author: "Washington Irving",
            genre: "Folklore",
            excerpt: "Whoever has made a voyage up the Hudson must remember the Kaatskill mountains...",
            paragraphs: [
                "Whoever has made a voyage up the Hudson must remember the Kaatskill mountains. They are a dismembered branch of the great Appalachian family, and are seen away to the west of the river, swelling up to a noble height, and lording it over the surrounding country."
            ],
            coverImageName: "thumb_rip_van_winkle",
            coverImageUrl: "https://www.gutenberg.org/cache/epub/2048/pg2048.cover.medium.jpg",
            readingTimeMinutes: 4,
            totalPages: 6,
            currentPage: 1,
            progressPercent: 0,
            isRecentSubmission: true,
            isSaved: false,
            sourceProvider: .gutenberg
        ),
        Story(
            id: UUID(uuidString: "10101010-1010-1010-1010-101010101010") ?? UUID(),
            title: "Chainsaw Devil: Special Edition",
            author: "Tatsuki Fujimoto",
            genre: "Manga",
            excerpt: "In a gritty neon metropolis where human fears manifest as living devils, an indebted hunter fights for survival alongside his faithful devil companion.",
            paragraphs: [],
            coverImageName: "cover_dracula",
            heroImageName: "hero_dracula",
            coverImageUrl: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=800&auto=format&fit=crop",
            readingTimeMinutes: 8,
            totalPages: 4,
            currentPage: 1,
            progressPercent: 0,
            rating: 4.95,
            isRecentSubmission: true,
            isSaved: false,
            badgeText: "MANGA",
            contentFormat: .manga,
            sourceProvider: .mangadex,
            chapters: [
                Chapter(
                    storyId: UUID(uuidString: "10101010-1010-1010-1010-101010101010") ?? UUID(),
                    chapterNumber: 1,
                    title: "Chapter 1: The Contract",
                    content: "",
                    wordCount: 0,
                    pageUrls: [
                        "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=800&auto=format&fit=crop",
                        "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=800&auto=format&fit=crop",
                        "https://images.unsplash.com/photo-1578632767115-351597cf2477?q=80&w=800&auto=format&fit=crop",
                        "https://images.unsplash.com/photo-1534447677768-be436bb09401?q=80&w=800&auto=format&fit=crop"
                    ]
                )
            ]
        ),
        Story(
            id: UUID(uuidString: "20202020-2020-2020-2020-202020202020") ?? UUID(),
            title: "The Metamorphosis",
            author: "Franz Kafka",
            genre: "Classic Fiction",
            excerpt: "One morning, Gregor Samsa woke from uneasy dreams to find himself transformed into a monstrous insect.",
            paragraphs: [
                "One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a horrible vermin."
            ],
            coverImageName: "cover_metamorphosis",
            heroImageName: "cover_metamorphosis",
            coverImageUrl: "https://standardebooks.org/ebooks/franz-kafka/the-metamorphosis/david-wyllie/downloads/cover.jpg",
            readingTimeMinutes: 7,
            totalPages: 8,
            currentPage: 1,
            progressPercent: 0,
            rating: 4.9,
            isCuratorSpotlight: true,
            badgeText: "STANDARD EBOOKS",
            contentFormat: .prose,
            sourceProvider: .standardEbooks
        )
    ]
}

extension GenreCategory {
    public static let defaultCategories: [GenreCategory] = [
        GenreCategory(
            name: "Manga",
            storyCount: 520,
            readersCount: "34.8k",
            description: "Visual graphic serialized narratives, high-contrast dynamic action panels, and modern serialized storytelling.",
            imageName: "genre_folklore",
            imageUrl: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=800&auto=format&fit=crop"
        ),
        GenreCategory(
            name: "Folklore",
            storyCount: 248,
            readersCount: "18.4k",
            description: "Timeless fables, oral legends, and cultural allegories passed through generations of oral history and regional myth.",
            imageName: "genre_folklore",
            imageUrl: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=800&auto=format&fit=crop"
        ),
        GenreCategory(
            name: "Mythology",
            storyCount: 312,
            readersCount: "22.1k",
            description: "Ancient pantheons, cosmic sagas, and heroic epic narratives from classical civilizations across the globe.",
            imageName: "genre_mythology",
            imageUrl: "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?q=80&w=800&auto=format&fit=crop"
        ),
        GenreCategory(
            name: "Gothic",
            storyCount: 185,
            readersCount: "9.8k",
            description: "Atmospheric hauntings, crumbling estates, and romantic dread exploring the psychological depths of human melancholy.",
            imageName: "genre_gothic",
            imageUrl: "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?q=80&w=800&auto=format&fit=crop"
        ),
        GenreCategory(
            name: "Classic Mystery",
            storyCount: 185,
            readersCount: "14.2k",
            description: "Whodunits, deductive puzzles, and atmospheric investigations through gaslit cobblestones and locked rooms.",
            imageName: "genre_mystery",
            imageUrl: "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?q=80&w=800&auto=format&fit=crop"
        )
    ]
}

extension Writer {
    public static let defaultWriters: [Writer] = [
        Writer(
            name: "Bram Stoker",
            avatarImageName: "author_kuang",
            avatarImageUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Bram_Stoker_1906.jpg/440px-Bram_Stoker_1906.jpg",
            storyCount: 14,
            rating: 4.9
        ),
        Writer(
            name: "Washington Irving",
            avatarImageName: "author_yarros",
            avatarImageUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Washington_Irving_by_John_Wesley_Jarvis%2C_1809.jpg/440px-Washington_Irving_by_John_Wesley_Jarvis%2C_1809.jpg",
            storyCount: 9,
            rating: 4.8
        ),
        Writer(
            name: "Edgar Allan Poe",
            avatarImageName: "author_klune",
            avatarImageUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Edgar_Allan_Poe_2_edit.jpg/440px-Edgar_Allan_Poe_2_edit.jpg",
            storyCount: 16,
            rating: 4.9
        ),
        Writer(
            name: "Franz Kafka",
            avatarImageName: "author_kuang",
            avatarImageUrl: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/Franz_Kafka%2C_1923.jpg/440px-Franz_Kafka%2C_1923.jpg",
            storyCount: 14,
            rating: 4.8
        ),
        Writer(
            name: "Tatsuki Fujimoto",
            avatarImageName: "author_roosc",
            avatarImageUrl: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=800&auto=format&fit=crop",
            storyCount: 22,
            rating: 5.0
        )
    ]
}

