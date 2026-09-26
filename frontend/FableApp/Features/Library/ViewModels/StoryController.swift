import Foundation
import Observation

@Observable
public final class StoryController {
    public var stories: [Story] = []
    public var selectedGenre: Genre = .all
    public var searchText: String = ""
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    // Live REST API Mode enabled
    public var isLiveBackendEnabled: Bool = true
    private let apiService: StoryAPIServiceProtocol

    public init(
        apiService: StoryAPIServiceProtocol = StoryAPIService(),
        isLiveBackendEnabled: Bool = true
    ) {
        self.apiService = apiService
        self.isLiveBackendEnabled = isLiveBackendEnabled
        
        Task { [weak self] in
            await self?.refreshStories()
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
            let genreFilter = selectedGenre == .all ? nil : selectedGenre.rawValue
            let fetched = try await apiService.fetchStories(genre: genreFilter, search: searchText)
            self.stories = fetched
        } catch {
            self.errorMessage = "Failed to load stories: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

