import Foundation

public struct CreateStoryRequest: Codable {
    public let title: String
    public let genre: String
    public let chapter: String?
    public let synopsis: String
    public let content: String
    public let readTimeMinutes: Int
    public let contentFormat: String?

    public init(
        title: String,
        genre: String,
        chapter: String? = nil,
        synopsis: String,
        content: String,
        readTimeMinutes: Int,
        contentFormat: String? = "PROSE"
    ) {
        self.title = title
        self.genre = genre
        self.chapter = chapter
        self.synopsis = synopsis
        self.content = content
        self.readTimeMinutes = readTimeMinutes
        self.contentFormat = contentFormat
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

public struct APIRequestError: Error, LocalizedError {
    public let message: String

    public var errorDescription: String? { message }
}

public struct AuthUserDTO: Codable {
    public let id: UUID
    public let email: String
    public let name: String
    public let handle: String
    public let bio: String
    public let avatarImageName: String?
    public let avatarImageUrl: String?
    public let createdAtUtc: Date
}

public struct ReadingSessionRequest: Codable, Sendable {
    public let id: UUID
    public let storyId: UUID
    public let secondsRead: Int
    public let readAtUtc: Date
    public let isCompleted: Bool

    public init(id: UUID = UUID(), storyId: UUID, secondsRead: Int, readAtUtc: Date = Date(), isCompleted: Bool) {
        self.id = id
        self.storyId = storyId
        self.secondsRead = secondsRead
        self.readAtUtc = readAtUtc
        self.isCompleted = isCompleted
    }
}

public struct ReadingStatsDTO: Codable, Sendable {
    public let storiesReadCount: Int
    public let totalMinutesRead: Int
    public let streakDays: Int
}

public struct ProfileUpdateRequest: Codable {
    public let name: String
    public let handle: String
    public let bio: String

    public init(name: String, handle: String, bio: String) {
        self.name = name
        self.handle = handle
        self.bio = bio
    }
}

public struct AuthTokenResponse: Codable {
    public let accessToken: String
    public let tokenType: String
    public let user: AuthUserDTO
}

public protocol StoryAPIServiceProtocol: Sendable {
    func fetchStories(genre: String?, search: String?, since: Date?) async throws -> [Story]
    func createStory(_ request: CreateStoryRequest, token: String) async throws -> Story
    func fetchMyStories(token: String) async throws -> [Story]
    func syncShelf(deviceId: UUID, token: String, items: [ShelfSyncItem]) async throws -> [ShelfSyncItem]
    func fetchShelf(deviceId: UUID, token: String) async throws -> [ShelfSyncItem]
    func fetchGutenbergStories(topic: String?, search: String?) async throws -> [Story]
    func fetchGutenbergStory(providerId: String) async throws -> Story
    func fetchChapters(for storyId: UUID, sourceProvider: String, providerId: String?) async throws -> [Chapter]
    func fetchGenres() async throws -> [GenreCategory]
    func fetchTopAuthors() async throws -> [Writer]
    func fetchUpdateFeed() async throws -> UpdateFeed
    func register(email: String, password: String, name: String, handle: String) async throws -> AuthTokenResponse
    func login(email: String, password: String) async throws -> AuthTokenResponse
    func fetchCurrentUser(token: String) async throws -> AuthUserDTO
    func updateProfile(_ request: ProfileUpdateRequest, token: String) async throws -> AuthUserDTO
    func recordReadingSession(_ request: ReadingSessionRequest, token: String) async throws
    func fetchReadingStats(token: String) async throws -> ReadingStatsDTO
    func logout(token: String) async throws
}

public extension StoryAPIServiceProtocol {
    func fetchChapters(for storyId: UUID) async throws -> [Chapter] {
        try await fetchChapters(for: storyId, sourceProvider: "", providerId: nil)
    }

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

    public init(baseURL: URL? = nil) {
        let infoBaseURL = Bundle.main.object(forInfoDictionaryKey: "FABLE_API_BASE_URL") as? String
        let configuredBaseURL = ProcessInfo.processInfo.environment["FABLE_API_BASE_URL"] ?? infoBaseURL
        self.baseURL = baseURL
            ?? configuredBaseURL.flatMap { URL(string: $0) }
            ?? URL(string: "http://127.0.0.1:8000/api/v1")!
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0
        self.session = URLSession(configuration: config)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let detail = payload?["detail"] as? String
            throw APIRequestError(message: detail ?? "The server could not complete the request.")
        }
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

    public func createStory(_ request: CreateStoryRequest, token: String) async throws -> Story {
        let url = baseURL.appendingPathComponent("stories")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Story.self, from: data)
    }

    public func fetchMyStories(token: String) async throws -> [Story] {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("me").appendingPathComponent("stories")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Story].self, from: data)
    }

    public func syncShelf(deviceId: UUID, token: String, items: [ShelfSyncItem]) async throws -> [ShelfSyncItem] {
        let url = baseURL.appendingPathComponent("shelf").appendingPathComponent("sync")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
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

    public func fetchGutenbergStory(providerId: String) async throws -> Story {
        guard let gutenbergId = Int(providerId), gutenbergId > 0 else { throw URLError(.badURL) }
        let url = baseURL
            .appendingPathComponent("public")
            .appendingPathComponent("gutenberg")
            .appendingPathComponent(String(gutenbergId))
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Story.self, from: data)
    }

    public func fetchChapters(for storyId: UUID, sourceProvider: String = "", providerId: String? = nil) async throws -> [Chapter] {
        let url: URL
        if sourceProvider == "GUTENBERG", let providerId {
            guard let gutenbergId = Int(providerId), gutenbergId > 0 else {
                throw URLError(.badURL)
            }
            url = baseURL
                .appendingPathComponent("public")
                .appendingPathComponent("gutenberg")
                .appendingPathComponent(String(gutenbergId))
                .appendingPathComponent("chapters")
        } else if sourceProvider == "GUTENBERG" {
            throw URLError(.badURL)
        } else {
            url = baseURL
                .appendingPathComponent("stories")
                .appendingPathComponent(storyId.uuidString)
                .appendingPathComponent("chapters")
        }
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

    public func fetchShelf(deviceId: UUID, token: String) async throws -> [ShelfSyncItem] {
        var components = URLComponents(url: baseURL.appendingPathComponent("shelf"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "deviceId", value: deviceId.uuidString)]
        guard let targetURL = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: targetURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ShelfSyncItem].self, from: data)
    }

    public func register(email: String, password: String, name: String, handle: String = "") async throws -> AuthTokenResponse {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "email": email,
            "password": password,
            "name": name,
            "handle": handle
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthTokenResponse.self, from: data)
    }

    public func recordReadingSession(_ request: ReadingSessionRequest, token: String) async throws {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("me").appendingPathComponent("reading-sessions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        urlRequest.httpBody = try encoder.encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)
    }

    public func fetchReadingStats(token: String) async throws -> ReadingStatsDTO {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("me").appendingPathComponent("stats")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(ReadingStatsDTO.self, from: data)
    }

    public func logout(token: String) async throws {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("logout")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    public func updateProfile(_ request: ProfileUpdateRequest, token: String) async throws -> AuthUserDTO {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("me")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        try validateResponse(response, data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthUserDTO.self, from: data)
    }

    public func fetchCurrentUser(token: String) async throws -> AuthUserDTO {
        let url = baseURL.appendingPathComponent("auth").appendingPathComponent("me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AuthUserDTO.self, from: data)
    }
}

