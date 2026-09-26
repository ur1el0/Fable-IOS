import Foundation
import Observation

@Observable
@MainActor
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
        PersistenceService.shared.setBookmark(storyId: story.id, isBookmarked: stories[index].isBookmarked)

        if isLiveBackendEnabled,
           let session = AuthManager.shared.currentSession,
           !session.isGuest,
           let token = KeychainStore.shared.readAccessToken() {
            let deviceId: UUID = {
                let key = "fable_device_id_\(session.id.uuidString)"
                if let saved = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: saved) {
                    return uuid
                }
                let newId = UUID()
                UserDefaults.standard.set(newId.uuidString, forKey: key)
                return newId
            }()
            let item = ShelfSyncItem(
                storyId: story.id,
                readingProgress: Double(story.progressPercent) / 100.0,
                isBookmarked: stories[index].isBookmarked,
                isCompleted: story.isCompleted,
                updatedAtUtc: Date()
            )
            Task {
                _ = try? await apiService.syncShelf(deviceId: deviceId, token: token, items: [item])
            }
        }
    }

    public func addStory(
        title: String,
        genre: Genre,
        synopsis: String,
        content: String,
        readTimeMinutes: Int
    ) async throws -> Story {
        guard let session = AuthManager.shared.currentSession, !session.isGuest,
              let token = KeychainStore.shared.readAccessToken() else {
            throw APIRequestError(message: "Sign in to publish a story.")
        }

        let request = CreateStoryRequest(
            title: title,
            genre: genre.rawValue,
            synopsis: synopsis,
            content: content,
            readTimeMinutes: max(1, readTimeMinutes)
        )
        let createdStory = try await apiService.createStory(request, token: token)
        stories.insert(createdStory, at: 0)
        PersistenceService.shared.saveStory(createdStory)
        return createdStory
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

