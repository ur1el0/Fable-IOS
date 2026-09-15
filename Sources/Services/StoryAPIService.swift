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

public struct ShelfSyncItem: Codable, Equatable {
    public let storyId: UUID
    public let readingProgress: Double
    public let isBookmarked: Bool
    public let isCompleted: Bool
    public let updatedAtUtc: Date
    
    enum CodingKeys: String, CodingKey {
        case storyId = "story_id"
        case readingProgress = "reading_progress"
        case isBookmarked = "is_bookmarked"
        case isCompleted = "is_completed"
        case updatedAtUtc = "updated_at_utc"
    }
    
    public init(storyId: UUID, readingProgress: Double, isBookmarked: Bool, isCompleted: Bool, updatedAtUtc: Date = Date()) {
        self.storyId = storyId
        self.readingProgress = readingProgress
        self.isBookmarked = isBookmarked
        self.isCompleted = isCompleted
        self.updatedAtUtc = updatedAtUtc
    }
}

public struct ShelfSyncPayload: Codable {
    public let deviceId: UUID
    public let items: [ShelfSyncItem]
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case items
    }
    
    public init(deviceId: UUID, items: [ShelfSyncItem]) {
        self.deviceId = deviceId
        self.items = items
    }
}

public struct ShelfSyncResponse: Codable {
    public let status: String
    public let reconciledItems: [ShelfSyncItem]
    public let serverTimeUtc: Date
    
    enum CodingKeys: String, CodingKey {
        case status
        case reconciledItems = "reconciled_items"
        case serverTimeUtc = "server_time_utc"
    }
}

public protocol StoryAPIServiceProtocol: Sendable {
    func fetchStories(genre: String?, search: String?, since: Date?) async throws -> [Story]
    func createStory(_ request: CreateStoryRequest) async throws -> Story
    func syncShelf(deviceId: UUID, items: [ShelfSyncItem]) async throws -> [ShelfSyncItem]
    func toggleBookmark(storyId: UUID) async throws -> Bool
}

public extension StoryAPIServiceProtocol {
    func fetchStories(genre: String? = nil, search: String? = nil) async throws -> [Story] {
        try await fetchStories(genre: genre, search: search, since: nil)
    }
}

public final class StoryAPIService: StoryAPIServiceProtocol {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "http://127.0.0.1:8000/api/v1")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        self.session = URLSession(configuration: config)
    }

    public func fetchStories(genre: String? = nil, search: String? = nil, since: Date? = nil) async throws -> [Story] {
        var components = URLComponents(url: baseURL.appendingPathComponent("stories"), resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = []
        if let genre, genre != "All" { queryItems.append(URLQueryItem(name: "genre", value: genre)) }
        if let search, !search.isEmpty { queryItems.append(URLQueryItem(name: "search", value: search)) }
        if let since {
            let formatter = ISO8601DateFormatter()
            queryItems.append(URLQueryItem(name: "since", value: formatter.string(from: since)))
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        guard let targetURL = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: targetURL)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Supports both raw array and paged responses
        if let directList = try? decoder.decode([Story].self, from: data) {
            return directList
        }
        
        struct PagedStoryWrapper: Codable {
            let items: [Story]
        }
        if let wrapped = try? decoder.decode(PagedStoryWrapper.self, from: data) {
            return wrapped.items
        }
        
        return try decoder.decode([Story].self, from: data)
    }

    public func createStory(_ request: CreateStoryRequest) async throws -> Story {
        let url = baseURL.appendingPathComponent("stories")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Story.self, from: data)
    }

    public func syncShelf(deviceId: UUID, items: [ShelfSyncItem]) async throws -> [ShelfSyncItem] {
        let url = baseURL.appendingPathComponent("shelf").appendingPathComponent("sync")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ShelfSyncPayload(deviceId: deviceId, items: items)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(payload)
        
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(ShelfSyncResponse.self, from: data)
        return result.reconciledItems
    }

    public func toggleBookmark(storyId: UUID) async throws -> Bool {
        let item = ShelfSyncItem(storyId: storyId, readingProgress: 0.0, isBookmarked: true, isCompleted: false, updatedAtUtc: Date())
        let reconciled = try await syncShelf(deviceId: UUID(), items: [item])
        return reconciled.first?.isBookmarked ?? true
    }
}
