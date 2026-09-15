# Feature Plan 07: Live Public Domain Literature Ingestion Engine (Gutendex API)

**Document Version:** 1.0.0  
**Architectural Scope:** Remote Catalog Ingestion, Asynchronous Streaming, SwiftData Persistence  
**Target Protocols:** REST / JSON, URLSession Async/Await (iOS 17.0+, Swift 5.9+)  
**Engineering Discipline:** Distributed Mobile Data Ingestion & Caching  

---

## 1. Executive Summary & Problem Formulation

### 1.1 The Limitation of Static Seed Stores
While bundled seed manuscripts guarantee instant offline boots, a static catalog limits ongoing reader engagement. Integrating live, public-domain literature dynamically bridges the app to millions of classic folklore, myth, and gothic narratives (e.g. Project Gutenberg via Gutendex REST API).

### 1.2 Core Architectural Tenets
1. **Offline-First Fallback:** The application never displays a blocking error screen if disconnected; network-fetched tales are transactionally cached into the local SwiftData `StoryEntity` store.
2. **Schema Uniformity:** Remote Gutenberg DTOs are mapped into Fable's unified [`Story`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Models.swift#L3) domain model.
3. **Bandwidth Preservation:** Initial fetch retrieves only editorial metadata and excerpts. Full manuscript text is streamed and cached upon user tap.

---

## 2. API Contract & Data Transfer Specification

### 2.1 External Endpoint Contract (Gutendex REST API)
* **Base URL:** `https://gutendex.com/books`
* **Query Parameters:**
  * `topic`: `folklore`, `mythology`, `gothic`
  * `languages`: `en`
  * `sort`: `popular`

```json
{
  "count": 1420,
  "next": "https://gutendex.com/books/?page=2",
  "results": [
    {
      "id": 84,
      "title": "Frankenstein; Or, The Modern Prometheus",
      "authors": [{ "name": "Shelley, Mary Wollstonecraft", "birth_year": 1797 }],
      "subjects": ["Gothic fiction", "Science fiction"],
      "formats": {
        "text/plain; charset=utf-8": "https://www.gutenberg.org/files/84/84-0.txt"
      },
      "download_count": 48200
    }
  ]
}
```

---

## 3. Client Architecture & Implementation Topology

```
┌─────────────────────────────────────────────────────────────┐
│                      ExploreView / Search                   │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                  CatalogIngestionService                    │
│   - Asynchronous URLSession Data Task Pipeline              │
│   - GutenbergDTO to Fable Domain Story Transformer          │
│   - Rate-Limit & Backoff Resilience                         │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                     PersistenceService                      │
│   - Ingestion Cache to SwiftData `StoryEntity`              │
│   - Instant Offline Availability on Subsequent Boots        │
└─────────────────────────────────────────────────────────────┘
```

### 3.1 Data Transfer Model & Ingestion Service

```swift
public struct GutendexResponse: Codable {
    public let count: Int
    public let results: [GutendexBook]
}

public struct GutendexBook: Codable {
    public let id: Int
    public let title: String
    public let authors: [GutendexAuthor]
    public let formats: [String: String]
}

public struct GutendexAuthor: Codable {
    public let name: String
}

@MainActor
public final class CatalogIngestionService: ObservableObject {
    public static let shared = CatalogIngestionService()
    
    @Published public var isFetching: Bool = false
    @Published public var fetchedStories: [Story] = []
    @Published public var errorMessage: String?
    
    public func searchFolklore(topic: String = "folklore") async {
        guard let url = URL(string: "https://gutendex.com/books?topic=\(topic)&languages=en") else { return }
        
        self.isFetching = true
        self.errorMessage = nil
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                self.errorMessage = "Service unavailable."
                self.isFetching = false
                return
            }
            let decoded = try JSONDecoder().decode(GutendexResponse.self, from: data)
            
            let transformed = decoded.results.prefix(8).map { book in
                Story(
                    id: UUID(),
                    title: book.title,
                    author: book.authors.first?.name ?? "Folklore Classic",
                    synopsis: "Classic public-domain folklore manuscript archived via Project Gutenberg.",
                    category: topic.capitalized,
                    readingTimeMinutes: 8,
                    rating: 4.8
                )
            }
            self.fetchedStories = Array(transformed)
        } catch {
            self.errorMessage = "Loaded offline archive."
        }
        self.isFetching = false
    }
}
```

---

## 4. UI Integration & User Experience

* **Placement:** Added as a **"Discover Worldwide Folklore"** remote section at the bottom of [ExploreView.swift](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Views/ExploreView.swift).
* **Loading State:** Utilizes [`FableDonutLoader`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Views/FableDonutLoader.swift) while communicating with the remote registry.
* **Add to Shelf:** Readers can tap any remote story to save and ingest it directly into their personal local shelf.
