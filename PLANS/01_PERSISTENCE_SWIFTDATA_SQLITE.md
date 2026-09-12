# Feature Plan 01: Zero-Loss Local Persistence Engine (SwiftData & SQLite)

**Document Version:** 1.0.0  
**Architectural Scope:** On-Device Persistence, Transactional Repository, Data Invariants  
**Target Framework:** Apple SwiftData / SQLite (iOS 17.0+, Swift 5.9+)  
**Engineering Discipline:** Enterprise Mobile Systems Architecture  

---

## 1. Executive Problem Statement & Architectural Rationale

### 1.1 The Vulnerability of Ephemeral State
In the midterm prototype, the application maintains state exclusively within an in-memory collection (`StoryStore.stories: [Story]`). While this fulfills the zero-external-dependency requirement for basic grading, it introduces critical production vulnerabilities:
- **Process Termination Data Loss:** Any stories authored in `WriteView`, updated scroll positions in `ReaderView`, and bookmarked toggles are permanently lost when iOS terminates the process or when the simulator is restarted.
- **Memory Growth with Scale:** Unbounded in-memory arrays risk unbounded memory growth if hundreds of stories or user drafts accumulate.

### 1.2 The Architectural Solution: SwiftData with SQLite Underlay
We replace the volatile array with Apple's native **SwiftData** framework, backed by a persistent local **SQLite** store on the physical device or simulator:
1. **Zero External Server Dependency:** 100% offline, zero Docker bloat, zero cloud latency.
2. **ACID Transaction Safety:** Atomic commits for manuscript publishing, ensuring half-written drafts never corrupt the local database.
3. **Reactive UI Synchronization:** SwiftUI views automatically re-render via `@Query` or the centralized `@Observable` controller layer.
4. **Deterministic Seeding Invariant:** On cold boot, the engine inspects the local database; if empty, it transactionally populates the 10+ folklore seed tales in $<50\text{ ms}$.

---

## 2. Domain Model & Schema Specification

```
┌─────────────────────────────────────────────────────────────┐
│                        StoryEntity                          │
├─────────────────────────────────────────────────────────────┤
│ - id: UUID (Primary Key, Indexed)                           │
│ - title: String                                             │
│ - author: String                                            │
│ - genreRaw: String                                          │
│ - chapter: String                                           │
│ - synopsis: String                                          │
│ - content: String                                           │
│ - readTimeMinutes: Int                                      │
│ - readingProgress: Double (Clamped [0.0, 1.0])              │
│ - isBookmarked: Bool                                        │
│ - isCompleted: Bool                                         │
│ - createdAtUtc: Date                                        │
│ - updatedAtUtc: Date                                        │
│                                                             │
│ + annotations: [AnnotationEntity] (Cascade Delete)          │
└─────────────────────────────────────────────────────────────┘
                               │ 1
                               │
                               │ *
┌──────────────────────────────▼──────────────────────────────┐
│                      AnnotationEntity                       │
├─────────────────────────────────────────────────────────────┤
│ - id: UUID (Primary Key)                                    │
│ - utf16StartOffset: Int                                     │
│ - utf16EndOffset: Int                                       │
│ - highlightedText: String                                   │
│ - note: String?                                             │
│ - style: HighlightStyle (Terracotta, Amber, Sage)           │
│ - createdAt: Date                                           │
└─────────────────────────────────────────────────────────────┘
```

### 2.1 Entity Code Contracts

```swift
import Foundation
import SwiftData

@Model
public final class StoryEntity {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var author: String
    public var genreRaw: String
    public var chapter: String
    public var synopsis: String
    public var content: String
    public var readTimeMinutes: Int
    public var readingProgress: Double
    public var isBookmarked: Bool
    public var isCompleted: Bool
    public var createdAtUtc: Date
    public var updatedAtUtc: Date
    
    @Relationship(deleteRule: .cascade, inverse: \AnnotationEntity.story)
    public var annotations: [AnnotationEntity] = []
    
    public init(
        id: UUID = UUID(),
        title: String,
        author: String,
        genreRaw: String,
        chapter: String = "",
        synopsis: String,
        content: String,
        readTimeMinutes: Int,
        readingProgress: Double = 0.0,
        isBookmarked: Bool = false,
        isCompleted: Bool = false,
        createdAtUtc: Date = Date(),
        updatedAtUtc: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.genreRaw = genreRaw
        self.chapter = chapter
        self.synopsis = synopsis
        self.content = content
        self.readTimeMinutes = readTimeMinutes
        self.readingProgress = min(1.0, max(0.0, readingProgress))
        self.isBookmarked = isBookmarked
        self.isCompleted = isCompleted
        self.createdAtUtc = createdAtUtc
        self.updatedAtUtc = updatedAtUtc
    }
}
```

---

## 3. Concurrency & Repository Architecture

To maintain a responsive 60/120 FPS interface, all database mutations are encapsulated behind a dedicated repository conforming to the **Actor Model** or isolated on `@MainActor`:

```swift
public protocol StoryRepositoryProtocol: Sendable {
    func fetchStories(matching genre: String?, query: String?) async throws -> [Story]
    func fetchStory(id: UUID) async throws -> Story?
    func saveStory(_ story: Story) async throws
    func updateProgress(id: UUID, progress: Double, isCompleted: Bool) async throws
    func toggleBookmark(id: UUID) async throws -> Bool
    func deleteStory(id: UUID) async throws
}
```

### 3.1 Initial Seeding Invariant Logic
```swift
@MainActor
public final class DatabaseBootstrapper {
    public static func initializeAndSeed(context: ModelContext) throws {
        var descriptor = FetchDescriptor<StoryEntity>()
        descriptor.fetchLimit = 1
        let existingCount = try context.fetchCount(descriptor)
        
        guard existingCount == 0 else { return }
        
        // Populate pre-configured folklore tales atomically
        for seed in SeedData.stories {
            let entity = StoryEntity(
                id: seed.id,
                title: seed.title,
                author: seed.author,
                genreRaw: seed.genre.rawValue,
                chapter: seed.chapter,
                synopsis: seed.synopsis,
                content: seed.content,
                readTimeMinutes: seed.readTimeMinutes,
                readingProgress: seed.readingProgress,
                isBookmarked: seed.isBookmarked,
                isCompleted: seed.isCompleted
            )
            context.insert(entity)
        }
        try context.save()
    }
}
```

---

## 4. Verification & Testing Plan

### 4.1 Automated Unit Tests
1. **`test_cold_boot_seeding_creates_exactly_seed_count()`**: Verify that an empty SQLite container initializes with exactly the seed stories.
2. **`test_publish_persists_across_context_reset()`**: Insert a new manuscript, discard the in-memory `ModelContext`, re-fetch from SQLite, and assert exact title and manuscript equality.
3. **`test_progress_clamping_invariant()`**: Pass `-0.5` and `1.8` as progress; assert that values are strictly clamped to `0.0` and `1.0`.
4. **`test_cascade_delete_removes_annotations()`**: Delete a story and verify all related `AnnotationEntity` records are purged from SQLite.

### 4.2 Manual Verification Runbook (Simulator)
1. Launch app in iPhone 16 Pro simulator.
2. Navigate to **Write** tab; enter Title `"The Obsidian Spire"`, select `"Gothic"`, enter 100 words, and tap **Publish**.
3. Verify the story appears at index 0 of the Library feed.
4. Press `Cmd + Shift + H` twice in the simulator, swipe up to **kill the app process**.
5. Relaunch the app from the home screen.
6. **Pass Criteria:** `"The Obsidian Spire"` remains visible at index 0 with identical metadata.
