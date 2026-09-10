import Foundation
import Observation

@Observable
public final class StoryController {
    public var stories: [Story] = []
    public var selectedGenre: Genre = .all
    public var searchText: String = ""
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    // Toggle between Midterm Mock Mode and Live REST API Mode
    public var isLiveBackendEnabled: Bool = false
    private let apiService: StoryAPIServiceProtocol

    public init(
        apiService: StoryAPIServiceProtocol = StoryAPIService(),
        isLiveBackendEnabled: Bool = false
    ) {
        self.apiService = apiService
        self.isLiveBackendEnabled = isLiveBackendEnabled
        
        if !isLiveBackendEnabled {
            loadMockStories()
        }
    }

    // Filtered stories computed property
    public var filteredStories: [Story] {
        stories.filter { story in
            let matchesGenre = (selectedGenre == .all || story.genre == selectedGenre)
            let matchesSearch = searchText.isEmpty ||
                story.title.localizedCaseInsensitiveContains(searchText) ||
                story.synopsis.localizedCaseInsensitiveContains(searchText)
            return matchesGenre && matchesSearch
        }
    }

    // Featured hero story
    public var featuredStory: Story? {
        stories.first
    }

    // Shelf collections
    public var bookmarkedStories: [Story] {
        stories.filter { $0.isBookmarked }
    }

    public var completedStories: [Story] {
        stories.filter { $0.isCompleted }
    }

    // Actions
    public func toggleBookmark(for story: Story) {
        guard let index = stories.firstIndex(where: { $0.id == story.id }) else { return }
        stories[index].isBookmarked.toggle()

        if isLiveBackendEnabled {
            Task {
                _ = try? await apiService.toggleBookmark(storyId: story.id)
            }
        }
    }

    public func addStory(
        title: String,
        author: String,
        genre: Genre,
        synopsis: String,
        content: String,
        readTimeMinutes: Int
    ) {
        let newStory = Story(
            id: UUID(),
            title: title,
            author: author.isEmpty ? "Anonymous" : author,
            genre: genre,
            synopsis: synopsis,
            content: content,
            readTimeMinutes: max(1, readTimeMinutes),
            isBookmarked: false,
            isCompleted: false,
            createdAtUtc: Date()
        )

        // Optimistic local insertion
        stories.insert(newStory, at: 0)

        if isLiveBackendEnabled {
            Task {
                let req = CreateStoryRequest(
                    title: title,
                    author: author,
                    genre: genre.rawValue,
                    synopsis: synopsis,
                    content: content,
                    readTimeMinutes: readTimeMinutes
                )
                _ = try? await apiService.createStory(req)
            }
        }
    }

    public func refreshStories() async {
        guard isLiveBackendEnabled else { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetched = try await apiService.fetchStories(genre: selectedGenre.rawValue, search: searchText)
            self.stories = fetched
        } catch {
            self.errorMessage = "Failed to load stories: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // Midterm Seed Data (Aligning with Figma Prototype & ARCHITECTURE.md Section 7.2)
    private func loadMockStories() {
        self.stories = [
            Story(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                title: "The Balete Tree of Baler",
                author: "Danilo Ramos",
                genre: .folklore,
                synopsis: "Centuries-old roots cradle whispers of travelers who wandered past sundown.",
                content: "The ancient balete stood at the boundary between the cultivated rice terraces and the untouched canopy of Aurora. Its aerial roots were thicker than church pillars, twisting around a hollow core that emitted a cool, subterranean draft even in the scorching heat of April. Old man Mateo had warned every child in the barrio: 'When the cicadas abruptly cease their song at twilight, do not look into the hollow.' But Joel was seventeen, armed with modern skepticism and a pocket flashlight...",
                readTimeMinutes: 6,
                isBookmarked: true,
                isCompleted: false
            ),
            Story(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                title: "The Midnight Jeepney",
                author: "Maria Santos",
                genre: .urbanLegend,
                synopsis: "A commuter boards the last ride through Aurora Boulevard and discovers no one is paying with coins.",
                content: "Rain turned Epifanio de los Santos Avenue into a shimmering river of brake lights. It was 1:45 AM when the stainless-steel jeepney rattled to a halt beside the shuttered convenience store. The destination signboard bore no avenue or landmark, merely two words written in fading crimson script: 'SA DULO' (To the End). Sofia hopped onto the rear stirrup, shaking water from her umbrella...",
                readTimeMinutes: 4,
                isBookmarked: false,
                isCompleted: true
            ),
            Story(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                title: "Tears of the Diwata",
                author: "Alon Cruz",
                genre: .mythology,
                synopsis: "When the sacred lake dries, the guardian spirits demand an offering of forgotten songs.",
                content: "Before the miners carved terraces into Mount Makiling, the mountain was known to breathe. Its exhalations were mists scented with wild ginger and damp earth. Maria Makiling sat upon the basalt ridge, her long dark tresses trailing into the emerald waters of Lake Alligator...",
                readTimeMinutes: 8,
                isBookmarked: true,
                isCompleted: true
            ),
            Story(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                title: "Echoes on the Concrete Span",
                author: "R. Zaño",
                genre: .horror,
                synopsis: "Every year on the anniversary of the collapse, the radio picks up transmissions from cars that never made it across.",
                content: "The bridge connecting the two coastal towns had been completed in record time during the boom years of the late seventies. But local fishermen claimed that beneath the fifth pylon, the water never rippled naturally...",
                readTimeMinutes: 5,
                isBookmarked: false,
                isCompleted: false
            ),
            Story(
                id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
                title: "The Clockmaker of Prague",
                author: "M. Vance",
                genre: .folklore,
                synopsis: "In the shadows of the Old Town square, Master Hanuš crafted a horologe that measured not merely hours, but the fading heartbeats of kings.",
                content: "In the shadows of the Old Town square, Master Hanuš crafted a horologe that measured not merely hours, but the fading heartbeats of kings. The councilors came at midnight, their cloaks smelling of damp river fog and sulfur.",
                readTimeMinutes: 4,
                isBookmarked: true,
                isCompleted: false
            )
        ]
    }
}
