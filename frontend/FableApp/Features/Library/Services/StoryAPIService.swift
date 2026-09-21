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
        case storyId, readingProgress, isBookmarked, isCompleted, updatedAtUtc
        case story_id, reading_progress, is_bookmarked, is_completed, updated_at_utc
    }
    
    public init(storyId: UUID, readingProgress: Double, isBookmarked: Bool, isCompleted: Bool, updatedAtUtc: Date = Date()) {
        self.storyId = storyId
        self.readingProgress = readingProgress
        self.isBookmarked = isBookmarked
        self.isCompleted = isCompleted
        self.updatedAtUtc = updatedAtUtc
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.storyId = try (container.decodeIfPresent(UUID.self, forKey: .storyId)
            ?? container.decode(UUID.self, forKey: .story_id))
        self.readingProgress = try (container.decodeIfPresent(Double.self, forKey: .readingProgress)
            ?? container.decode(Double.self, forKey: .reading_progress))
        self.isBookmarked = try (container.decodeIfPresent(Bool.self, forKey: .isBookmarked)
            ?? container.decode(Bool.self, forKey: .is_bookmarked))
        self.isCompleted = try (container.decodeIfPresent(Bool.self, forKey: .isCompleted)
            ?? container.decode(Bool.self, forKey: .is_completed))
        self.updatedAtUtc = try (container.decodeIfPresent(Date.self, forKey: .updatedAtUtc)
            ?? container.decode(Date.self, forKey: .updated_at_utc))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(storyId, forKey: .storyId)
        try container.encode(readingProgress, forKey: .readingProgress)
        try container.encode(isBookmarked, forKey: .isBookmarked)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(updatedAtUtc, forKey: .updatedAtUtc)
    }
}

public struct ShelfSyncPayload: Codable {
    public let deviceId: UUID
    public let items: [ShelfSyncItem]
    
    enum CodingKeys: String, CodingKey {
        case deviceId, items
        case device_id
    }
    
    public init(deviceId: UUID, items: [ShelfSyncItem]) {
        self.deviceId = deviceId
        self.items = items
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.deviceId = try (container.decodeIfPresent(UUID.self, forKey: .deviceId)
            ?? container.decode(UUID.self, forKey: .device_id))
        self.items = try container.decode([ShelfSyncItem].self, forKey: .items)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(items, forKey: .items)
    }
}

public struct ShelfSyncResponse: Codable {
    public let status: String
    public let reconciledItems: [ShelfSyncItem]
    public let serverTimeUtc: Date
    
    enum CodingKeys: String, CodingKey {
        case status
        case reconciledItems, serverTimeUtc
        case reconciled_items, server_time_utc
    }
    
    public init(status: String = "ok", reconciledItems: [ShelfSyncItem], serverTimeUtc: Date) {
        self.status = status
        self.reconciledItems = reconciledItems
        self.serverTimeUtc = serverTimeUtc
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "ok"
        self.reconciledItems = try (container.decodeIfPresent([ShelfSyncItem].self, forKey: .reconciledItems)
            ?? container.decode([ShelfSyncItem].self, forKey: .reconciled_items))
        self.serverTimeUtc = try (container.decodeIfPresent(Date.self, forKey: .serverTimeUtc)
            ?? container.decode(Date.self, forKey: .server_time_utc))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(reconciledItems, forKey: .reconciledItems)
        try container.encode(serverTimeUtc, forKey: .serverTimeUtc)
    }
}

public struct AuthUserDTO: Codable {
    public let id: UUID
    public let email: String
    public let name: String
    public let avatarImageName: String?
    public let avatarImageUrl: String?
    public let createdAtUtc: Date
}

public struct AuthTokenResponse: Codable {
    public let accessToken: String
    public let tokenType: String
    public let user: AuthUserDTO
}

public protocol StoryAPIServiceProtocol: Sendable {
    func fetchStories(genre: String?, search: String?, since: Date?) async throws -> [Story]
    func createStory(_ request: CreateStoryRequest) async throws -> Story
    func syncShelf(deviceId: UUID, items: [ShelfSyncItem]) async throws -> [ShelfSyncItem]
    func fetchShelf(deviceId: UUID) async throws -> [ShelfSyncItem]
    func toggleBookmark(storyId: UUID) async throws -> Bool
    func fetchGutenbergStories(topic: String?, search: String?) async throws -> [Story]
    func fetchChapters(for storyId: UUID) async throws -> [Chapter]
    func fetchGenres() async throws -> [GenreCategory]
    func fetchTopAuthors() async throws -> [Writer]
    func fetchUpdateFeed() async throws -> UpdateFeed
    func register(email: String, password: String, name: String) async throws -> AuthTokenResponse
    func login(email: String, password: String) async throws -> AuthTokenResponse
    func fetchCurrentUser(token: String) async throws -> AuthUserDTO
}

public extension StoryAPIServiceProtocol {
    func fetchStories(genre: String? = nil, search: String? = nil) async throws -> [Story] {
        try await fetchStories(genre: genre, search: search, since: nil)
    }
    
    func fetchGutenbergStories(topic: String? = nil, search: String? = nil) async throws -> [Story] {
        try await fetchGutenbergStories(topic: topic, search: search)
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
        let deviceId: UUID = {
            let key = "fable_device_id"
            if let saved = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: saved) {
                return uuid
            }
            let newId = UUID()
            UserDefaults.standard.set(newId.uuidString, forKey: key)
            return newId
        }()
        let item = ShelfSyncItem(storyId: storyId, readingProgress: 0.0, isBookmarked: true, isCompleted: false, updatedAtUtc: Date())
        let reconciled = try await syncShelf(deviceId: deviceId, items: [item])
        return reconciled.first?.isBookmarked ?? true
    }

    public func fetchGutenbergStories(topic: String? = nil, search: String? = nil) async throws -> [Story] {
        var components = URLComponents(url: baseURL.appendingPathComponent("public").appendingPathComponent("gutenberg"), resolvingAgainstBaseURL: true)!
        var queryItems: [URLQueryItem] = []
        if let topic, topic != "All" { queryItems.append(URLQueryItem(name: "topic", value: topic)) }
        if let search, !search.isEmpty { queryItems.append(URLQueryItem(name: "search", value: search)) }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        guard let targetURL = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: targetURL)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Story].self, from: data)
    }

    public func fetchChapters(for storyId: UUID) async throws -> [Chapter] {
        let url = baseURL.appendingPathComponent("stories").appendingPathComponent(storyId.uuidString).appendingPathComponent("chapters")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Chapter].self, from: data)
    }

    public func fetchGenres() async throws -> [GenreCategory] {
        let url = baseURL.appendingPathComponent("genres")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([GenreCategory].self, from: data)
    }

    public func fetchTopAuthors() async throws -> [Writer] {
        let url = baseURL.appendingPathComponent("authors").appendingPathComponent("top")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Writer].self, from: data)
    }

    public func fetchUpdateFeed() async throws -> UpdateFeed {
        let url = baseURL.appendingPathComponent("updates")
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UpdateFeed.self, from: data)
    }

    public func fetchShelf(deviceId: UUID) async throws -> [ShelfSyncItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("shelf"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "deviceId", value: deviceId.uuidString)]
        guard let targetURL = components.url else { throw URLError(.badURL) }
        
        let (data, response) = try await session.data(from: targetURL)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ShelfSyncItem].self, from: data)
    }

    public func register(email: String, password: String, name: String) async throws -> AuthTokenResponse {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "email": email,
            "password": password,
            "name": name
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthTokenResponse.self, from: data)
    }

    public func login(email: String, password: String) async throws -> AuthTokenResponse {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "email": email,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthTokenResponse.self, from: data)
    }

    public func fetchCurrentUser(token: String) async throws -> AuthUserDTO {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthUserDTO.self, from: data)
    }
}

