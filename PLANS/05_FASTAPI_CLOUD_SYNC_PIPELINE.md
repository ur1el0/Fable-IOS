# Feature Plan 05: Minimalist FastAPI Cloud Sync Pipeline

**Document Version:** 1.0.0  
**Architectural Scope:** Distributed Multi-Device Synchronization, Delta Updates, Conflict Resolution  
**Backend Stack:** Python 3.11+ / FastAPI / Pydantic v2 / SQLite  
**Client Stack:** Swift 5.9+ / URLSession Async-Await / SwiftData  

---

## 1. Executive Problem Statement & Architectural Rationale

### 1.1 The Pitfalls of Backend Bloat
Legacy architectures often default to bulky microservices (e.g. ASP.NET Core, Docker Compose, MSSQL), which require extensive setup, heavy memory overhead, and complicated local certificate provisioning. In an educational or agile setting, this creates unnecessary points of failure.

### 1.2 The FastAPI Solution
**FastAPI** delivers a high-performance, asynchronous REST backend in a single, elegant Python codebase:
- **Zero Configuration Overhead:** Starts in $<1\text{ s}$ with `uvicorn main:app --reload`.
- **Contract-First OpenAPI Pipeline:** Interactive Swagger documentation automatically served at `/docs`.
- **Offline-First Resilience:** The iOS client treats the backend as an **optional sync tier**. If the server is unreachable, the client operates in local-only mode with zero user-facing errors.

---

## 2. API Contract & Data Transfer Objects (DTO)

```
┌────────────────────────────────────────────────────────┐
│             FASTAPI REST API ENDPOINT SPEC             │
├──────────────────────┬─────────┬───────────────────────┤
│ Endpoint             │ Method  │ Purpose               │
├──────────────────────┼─────────┼───────────────────────┤
│ /api/v1/stories      │ GET     │ Delta sync stories    │
│ /api/v1/stories      │ POST    │ Publish new story     │
│ /api/v1/shelf/sync   │ POST    │ Bidirectional sync    │
│ /api/v1/health       │ GET     │ System health check   │
└──────────────────────┴─────────┴───────────────────────┘
```

### 2.1 Pydantic v2 Schema Contract (`schemas.py`)
```python
from datetime import datetime
from uuid import UUID
from pydantic import BaseModel, Field

class StoryDTO(BaseModel):
    id: UUID
    title: str = Field(..., min_length=1, max_length=120)
    author: str = Field(..., min_length=1, max_length=80)
    genre: str
    chapter: str = ""
    synopsis: str
    content: str
    read_time_minutes: int
    created_at_utc: datetime
    updated_at_utc: datetime

class ShelfSyncItemDTO(BaseModel):
    story_id: UUID
    reading_progress: float = Field(..., ge=0.0, le=1.0)
    is_bookmarked: Bool
    is_completed: Bool
    updated_at_utc: datetime

class ShelfSyncPayload(BaseModel):
    device_id: UUID
    items: list[ShelfSyncItemDTO]
```

---

## 3. Conflict Resolution Strategy: Last-Write-Wins (LWW)

To resolve concurrent mutations between the physical iPhone and the remote server without complex distributed consensus protocols, Fable uses **Last-Write-Wins (LWW)** anchored to ISO 8601 UTC timestamps:

$$\text{ResolvedState} = \begin{cases} 
\text{ClientState}, & \text{if } t_{\text{client}} > t_{\text{server}} \\
\text{ServerState}, & \text{if } t_{\text{server}} \ge t_{\text{client}}
\end{cases}$$

```
Client (iPhone)                                        FastAPI Server
      │                                                       │
      │ 1. POST /api/v1/shelf/sync (progress=0.75, t=10:14)   │
      ├──────────────────────────────────────────────────────►│
      │                                                       │ Compares t_client vs t_server
      │                                                       │ t_client is newer -> updates DB
      │ 2. 200 OK (reconciled_items)                          │
      │◄──────────────────────────────────────────────────────┤
      ▼ Updates local SwiftData                               ▼
```

---

## 4. Swift Client Integration (`StoryAPIService.swift`)

```swift
public actor StoryAPIService {
    private let baseURL: URL
    private let session: URLSession
    
    public init(baseURL: URL = URL(string: "http://127.0.0.1:8000/api/v1")!) {
        self.baseURL = baseURL
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0 // Fast fail if server offline
        self.session = URLSession(configuration: config)
    }
    
    public func fetchStories(since: Date? = nil) async throws -> [Story] {
        var components = URLComponents(url: baseURL.appendingPathComponent("stories"), resolvingAgainstBaseURL: true)!
        if let since = since {
            components.queryItems = [URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since))]
        }
        
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Story].self, from: data)
    }
}
```

---

## 5. Verification & Testing Plan

### 5.1 Automated Backend Tests (Pytest)
1. **`test_publish_story_creates_record()`**: Send POST payload; assert response status is 201 and record exists in SQLite.
2. **`test_lww_conflict_resolution_favors_newer_timestamp()`**: Send an update with an older timestamp than the database; assert that the database record is not overwritten.

### 5.2 Client-Server Integration Test
1. Start FastAPI server locally: `uvicorn main:app --port 8000`.
2. Author story on iPhone Simulator.
3. Verify `/api/v1/stories` in browser (`http://localhost:8000/docs`) shows newly authored story immediately.
4. Disconnect Wi-Fi on Mac; author second story.
5. **Pass Criteria:** App functions flawlessly offline; synchronizes queued story upon network restoration.
