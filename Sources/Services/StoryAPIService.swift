import Foundation

public struct CreateStoryRequest: Codable {
    public let title: String
    public let author: String
    public let genre: String
    public let synopsis: String
    public let content: String
    public let readTimeMinutes: Int
    
    public init(title: String, author: String, genre: String, synopsis: String, content: String, readTimeMinutes: Int) {
        self.title = title
        self.author = author
        self.genre = genre
        self.synopsis = synopsis
        self.content = content
        self.readTimeMinutes = readTimeMinutes
    }
}

public struct PagedResult<T: Codable>: Codable {
    public let items: [T]
    public let pageNumber: Int
    public let pageSize: Int
    public let totalCount: Int
    public let hasNextPage: Bool
    
    public init(items: [T], pageNumber: Int, pageSize: Int, totalCount: Int, hasNextPage: Bool) {
        self.items = items
        self.pageNumber = pageNumber
        self.pageSize = pageSize
        self.totalCount = totalCount
        self.hasNextPage = hasNextPage
    }
}

public protocol StoryAPIServiceProtocol: Sendable {
    func fetchStories(genre: String?, search: String?) async throws -> [Story]
    func createStory(_ request: CreateStoryRequest) async throws -> Story
    func toggleBookmark(storyId: UUID) async throws -> Bool
}

public final class StoryAPIService: StoryAPIServiceProtocol {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://localhost:8080/api/v1")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func fetchStories(genre: String? = nil, search: String? = nil) async throws -> [Story] {
        var components = URLComponents(url: baseURL.appendingPathComponent("stories"), resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = []
        if let genre, genre != "All" { queryItems.append(URLQueryItem(name: "genre", value: genre)) }
        if let search, !search.isEmpty { queryItems.append(URLQueryItem(name: "search", value: search)) }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        guard let targetURL = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: targetURL)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let paged = try decoder.decode(PagedResult<Story>.self, from: data)
        return paged.items
    }

    public func createStory(_ request: CreateStoryRequest) async throws -> Story {
        let url = baseURL.appendingPathComponent("stories")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Story.self, from: data)
    }

    public func toggleBookmark(storyId: UUID) async throws -> Bool {
        let url = baseURL.appendingPathComponent("shelf").appendingPathComponent(storyId.uuidString).appendingPathComponent("toggle-bookmark")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct BookmarkResponse: Codable {
            let storyId: UUID
            let isBookmarked: Bool
        }
        let res = try JSONDecoder().decode(BookmarkResponse.self, from: data)
        return res.isBookmarked
    }
}
