import SwiftUI

enum ReaderFont: String, CaseIterable, Identifiable {
    case serif = "Serif"
    case sans = "Sans"
    case mono = "Mono"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .serif: return "Source Serif 4"
        case .sans: return "SF Pro"
        case .mono: return "SF Mono"
        }
    }
    
    func font(size: CGFloat) -> Font {
        switch self {
        case .serif: return .system(size: size, design: .serif)
        case .sans: return .system(size: size, design: .default)
        case .mono: return .system(size: size, design: .monospaced)
        }
    }
}

enum ReaderTheme: String, CaseIterable, Identifiable {
    case white = "White"
    case sepia = "Sepia"
    case charcoal = "Charcoal"
    case oled = "OLED"
    
    var id: String { rawValue }
    
    var backgroundColor: Color {
        switch self {
        case .white: return .white
        case .sepia: return FableTheme.sepiaBackground
        case .charcoal: return FableTheme.charcoalBackground
        case .oled: return FableTheme.oledBackground
        }
    }
    
    var textColor: Color {
        switch self {
        case .white: return FableTheme.deepCharcoal
        case .sepia: return FableTheme.sepiaText
        case .charcoal: return FableTheme.charcoalText
        case .oled: return FableTheme.oledText
        }
    }
    
    var swatchColor: Color {
        switch self {
        case .white: return .white
        case .sepia: return Color(red: 0.93, green: 0.86, blue: 0.77)
        case .charcoal: return Color(red: 0.22, green: 0.22, blue: 0.22)
        case .oled: return .black
        }
    }
}

enum ReaderLineSpacing: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case normal = "Normal"
    case spacious = "Spacious"
    
    var id: String { rawValue }
    
    var points: CGFloat {
        switch self {
        case .compact: return 4
        case .normal: return 8
        case .spacious: return 14
        }
    }
}

struct Story: Identifiable, Hashable {
    let id: UUID
    var title: String
    var author: String
    var genre: String
    var excerpt: String
    var paragraphs: [String]
    var coverImageName: String?
    var heroImageName: String?
    var readingTimeMinutes: Int
    var totalPages: Int
    var currentPage: Int
    var progressPercent: Int
    var rating: Double
    var savesCount: String
    var readsCount: String
    var isTaleOfTheDay: Bool
    var isRecentSubmission: Bool
    var isSaved: Bool
    var isFinished: Bool
    var isCuratorSpotlight: Bool
    var badgeText: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        genre: String,
        excerpt: String,
        paragraphs: [String] = [],
        coverImageName: String? = nil,
        heroImageName: String? = nil,
        readingTimeMinutes: Int = 4,
        totalPages: Int = 5,
        currentPage: Int = 1,
        progressPercent: Int = 0,
        rating: Double = 4.9,
        savesCount: String = "1.2k",
        readsCount: String = "1.2k",
        isTaleOfTheDay: Bool = false,
        isRecentSubmission: Bool = false,
        isSaved: Bool = true,
        isFinished: Bool = false,
        isCuratorSpotlight: Bool = false,
        badgeText: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.genre = genre
        self.excerpt = excerpt
        self.paragraphs = paragraphs
        self.coverImageName = coverImageName
        self.heroImageName = heroImageName
        self.readingTimeMinutes = readingTimeMinutes
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.progressPercent = progressPercent
        self.rating = rating
        self.savesCount = savesCount
        self.readsCount = readsCount
        self.isTaleOfTheDay = isTaleOfTheDay
        self.isRecentSubmission = isRecentSubmission
        self.isSaved = isSaved
        self.isFinished = isFinished
        self.isCuratorSpotlight = isCuratorSpotlight
        self.badgeText = badgeText
    }
}

struct GenreCategory: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var storyCount: Int
    var readersCount: String
    var description: String
    var imageName: String
}

struct Writer: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var avatarImageName: String
    var storyCount: Int
    var rating: Double
}
