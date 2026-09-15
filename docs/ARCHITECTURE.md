# FABLE: iOS Architecture & Technical Specification

**Application:** Fable (Curated Micro-Narrative & Editorial E-Reader)  
**Target Platform:** Native iOS (iOS 17.0+, iPhone 14/15/16 / Pro / Pro Max)  
**Development Environment:** Xcode 15 / 16 (macOS, Mac Lab Environment)  
**Language & UI Framework:** Swift 5.9+ / Swift 6, SwiftUI  
**Architectural Pattern:** Strict Model–View–Controller (MVC)  
**Local Persistence Strategy (Final):** SQLite / SwiftData (Local on-device storage)  
**Backend Service Strategy (Final):** FastAPI (Python, lightweight, auto-generating OpenAPI)  
**Milestone:** Midterm Submission (Demonstrating >50% Functional & Interface Implementation)

---

## 1. Executive Summary & Architectural Vision

**Fable** is a native iOS creative writing and serial micro-narrative reading application engineered for high typographical elegance and distraction-free reading. Designed for folklore, mythology, speculative fiction, and serialized creative shorts, Fable couples an editorial, bookish visual identity with a responsive, offline-first client architecture.

### 1.1 Architectural Constraints & Engineering Realities
1. **Academic Mac Lab Environment:** Development, testing, and grading occur in a Mac lab using Xcode. The application must compile cleanly, run predictably on the iOS Simulator (iPhone 15/16 / Pro / Pro Max), and have **zero external server dependencies** during midterm grading.
2. **CRUD E-Reader Scope:** At its core, Fable is a **focused CRUD application**:
   - **Create:** Draft and publish new story manuscripts with genre classification, synopsis, and reading time estimation (`WriteView`).
   - **Read:** Discover stories through curated feeds, search, and consume longform content on a customizable editorial reading surface (`LibraryView`, `ExploreView`, `ReaderView`).
   - **Update:** Track reading progress, toggle bookmarks, update active reading statuses, and configure reader appearance preferences (`ShelfView`, `DisplayOptionsSheet`).
   - **Delete:** Remove stories from personal shelf collections or discard drafts.
3. **Strict Model–View–Controller (MVC) Compliance:** Every component in the codebase is categorized strictly into **Model** (data structs and value types), **View** (declarative SwiftUI layout and event capturing), or **Controller** (centralized business logic and mutable state management).

---

## 2. High-Level System Architecture & Topology

```
┌────────────────────────────────────────────────────────────────────────┐
│                              VIEW LAYER                                │
│                   (Declarative SwiftUI Interface)                      │
│                                                                        │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌────────────┐  │
│  │   StoryLibraryView    │  │      ExploreView      │  │ ReaderView │  │
│  │     (LibraryView)     │  │   (GenreDetailView)   │  │(StoryReader│  │
│  └───────────┬───────────┘  └───────────┬───────────┘  └─────┬──────┘  │
│              │                          │                    │         │
│  ┌───────────┴───────────┐  ┌───────────┴───────────┐        │         │
│  │       WriteView       │  │       ShelfView       │        │         │
│  │  (StoryComposerView)  │  │   (StoryShelfView)    │        │         │
│  └───────────┬───────────┘  └───────────┬───────────┘        │         │
└──────────────┼──────────────────────────┼────────────────────┼─────────┘
               │                          │                    │
               │ User Interaction Events  │ Observes Published │
               │ (taps, inputs, toggles)  │ Observable State   │
               ▼                          ▼                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                           CONTROLLER LAYER                             │
│                  (Business Logic & State Coordination)                 │
│                                                                        │
│     ┌────────────────────────────────────────────────────────────┐     │
│     │            StoryStore / StoryController                    │     │
│     │  --------------------------------------------------------  │     │
│     │  - stories: [Story]               (Published Collection)   │     │
│     │  - activeReaderStory: Story?      (Active Manuscript)      │     │
│     │  - readerPreferences: Typography  (Appearance State)       │     │
│     │  - draftManuscript: DraftState    (Authoring State)        │     │
│     │  --------------------------------------------------------  │     │
│     │  + publishStory(draft)            [CRUD: Create]           │     │
│     │  + filteredStories(genre, query)  [CRUD: Read]             │     │
│     │  + toggleBookmark(storyId)        [CRUD: Update]           │     │
│     │  + updateProgress(storyId, pct)   [CRUD: Update]           │     │
│     │  + removeBookmark(storyId)        [CRUD: Delete]           │     │
│     └──────────────┬──────────────────────────────┬──────────────┘     │
└────────────────────┼──────────────────────────────┼────────────────────┘
                     │                              │
                     ▼                              ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────┐
│       MIDTERM DATA STRATEGY          │  │     FINAL DATA STRATEGY      │
│  - In-memory mock repository         │  │  - Local Device: SQLite /    │
│  - 10+ Seed stories with covers      │  │    SwiftData persistence     │
│  - Zero network dependency in Lab    │  │  - Optional Remote Sync:     │
│  - 100% Offline functional guarantee │  │    FastAPI (Python, OpenAPI) │
└──────────────────────────────────────┘  └──────────────────────────────┘
```

---

## 3. Detailed Architectural Layer Separation

### 3.1 Model Layer (`Sources/Models.swift`)
The Model layer represents pure business entities, value objects, and styling configurations. Models are completely isolated from SwiftUI view logic and controllers.
- **Type Safety & Protocols:** Conforms to `Identifiable`, `Codable`, and `Equatable`.
- **Key Entities:**
  - `Story`: Core entity containing unique `id: UUID`, `title: String`, `author: String`, `genre: Genre`, `synopsis: String`, `content: String`, `readTimeMinutes: Int`, `isBookmarked: Bool`, `isCompleted: Bool`, and `readingProgress: Double`.
  - `Genre`: Strongly-typed enum representing supported narrative styles (*Folklore*, *Mythology*, *Gothic*, *Speculative*, *Classic Fiction*, etc.).
  - `Author`: Literary contributor entity with name, bio, follower metrics, and avatar asset identifier.
  - `UserReadingStats`: Tracks reader engagement (*Stories Read*, *Minutes Logged*, *Consecutive Days Streak*).
  - `ReaderTheme` & `ReaderFont`: Configurable appearance value objects for custom typography rendering.

### 3.2 Controller Layer (`Sources/StoryStore.swift` & `Sources/Controllers/StoryController.swift`)
The Controller acts as the single source of truth for the application state.
- **State Management:** Employs `@ObservableObject` with `@Published` properties (and Apple's Swift 5.9+ `@Observable` macro in `StoryController`) to notify subscriber views of mutations.
- **Separation of Concerns:** Views **never mutate collections directly**. All mutations (adding a new story, toggling a bookmark, incrementing reading progress) must be requested through explicit controller methods.
- **In-Memory Mock Repository (Midterm):** Built-in seed data loader populating 10+ richly crafted stories with cover art, full-length content, and genre metadata. This provides immediate, realistic data without requiring asynchronous network setup for midterm grading.
- **Local SQLite / SwiftData Adapter (Final):** Bridges controller mutations directly to local device SQLite storage so drafts and reading logs survive app termination.

### 3.3 View Layer (`Sources/Views/`)
The View layer is purely declarative, composed of lightweight structs conforming to `SwiftUI.View`.
- **No Direct Business Logic:** Views handle layout, animation, and user gesture dispatching. When a user presses "Publish", the view merely captures form values and delegates the actual creation to `store.publishStory(...)`.
- **Reusable Component Hierarchy:**
  - Container Shell: `ContentView` hosting the custom persistent 4-tab bar (`FableTab`).
  - Screen Views: `LibraryView`, `ExploreView`, `ReaderView`, `WriteView`, `ShelfView`.
  - Modal Sheets: `DisplayOptionsSheet`, `StoryPublishedSheet`, `GenreDetailView`, `ProfileView`, `SettingsView`.
  - Leaf Components: `FableImageView` (resilient asset loader with fallback symbols), category pills, and progress rings.

---

## 4. End-to-End CRUD Data Flow Specification

| Operation | Trigger View | Controller Method | Model Mutation | UI State Update |
|---|---|---|---|---|
| **CREATE** | `WriteView` ("Publish" tap) | `store.publishStory()` | Instantiates `Story` with UUID, prepends to `store.stories` | Clears draft, displays `StoryPublishedSheet`, switches to `LibraryView` |
| **READ** | `LibraryView` / `ReaderView` | `store.filteredRecentStories` | Non-mutating read of `stories` array based on active filter | Re-renders story cards, displays full manuscript in `ReaderView` |
| **UPDATE** | `ReaderView` / `ShelfView` | `store.toggleBookmark(story:)` | Inverts `story.isBookmarked` property | Updates heart/bookmark icon color and shelf list immediately |
| **UPDATE** | `ReaderView` (Scroll gesture) | `store.updateReadingProgress()` | Adjusts `story.readingProgress` (0.0 to 1.0) | Re-draws progress ring and reading progress bar |
| **DELETE** | `ShelfView` (Remove button) | `store.removeStory(id:)` | Removes story from `stories` array | Animates row deletion from the Shelf list |

---

## 5. Navigation Architecture & "Hero Demo" Flow

The verified grading journey demonstrates 100% of the required CRUD interactions:

```
[1. Launch: LibraryView]
       │
       ├─► Tap "Folklore" filter pill (Tests reactive category filtering)
       │
       ├─► Tap "The Clockmaker of Prague" Hero Card
       │       │
       │       ▼
       │   [2. ReaderView Modal Presentation]
       │       │
       │       ├─► Tap "Display Options" (Opens DisplayOptionsSheet)
       │       │     └── Switch font to SF Mono, theme to Sepia (Verifies typography engine)
       │       │
       │       ├─► Scroll through manuscript (Verifies live progress calculation)
       │       │
       │       └─► Tap "Bookmark" icon (Updates bookmark status in controller)
       │
       ▼
[3. Switch to Tab 2: WriteView]
       │
       ├─► Fill in Title: "The Balete Tree of Baler"
       ├─► Select Genre: "Folklore"
       ├─► Type synopsis and body manuscript
       │
       └─► Tap "Publish" (Triggers StoryPublishedSheet & validates word count/read time)
               │
               ▼
[4. Switch to Tab 3: ShelfView]
       │
       ├─► Verify newly published story appears under "Bookmarked" collection
       ├─► View 60% and 100% Reading Progress Rings
       └─► Observe dynamic October Reading Stats (Stories Read, Minutes Logged, Streak)
```

---

## 6. Final Project Architecture: FastAPI + Local SQLite

For the final semester submission, the architecture transitions to a decoupled full-stack model without unneeded enterprise complexity:

```
  ┌────────────────────────────────────────────────────────┐
  │                 iOS DEVICE (OFFLINE-FIRST)             │
  │                                                        │
  │   ┌────────────────────────────────────────────────┐   │
  │   │          SwiftUI Views & Controllers           │   │
  │   └───────────────────────┬────────────────────────┘   │
  │                           │                            │
  │                           ▼                            │
  │   ┌────────────────────────────────────────────────┐   │
  │   │       Local SQLite Persistence (SwiftData)     │   │
  │   │     - Offline reading cached locally           │   │
  │   │     - Drafts saved automatically               │   │
  │   │     - Reading progress & streaks logged        │   │
  │   └───────────────────────┬────────────────────────┘   │
  └───────────────────────────┼────────────────────────────┘
                              │
                              │ Async Background Sync (URLSession)
                              ▼
  ┌────────────────────────────────────────────────────────┐
  │             LIGHTWEIGHT BACKEND: FASTAPI               │
  │                   (Python 3.11+)                       │
  │                                                        │
  │   - Clean REST Endpoints: /api/stories, /api/shelf     │
  │   - Pydantic v2 Type Safety & Schema Validation        │
  │   - Automatic OpenAPI / Swagger UI (/docs)             │
  │   - SQLite / PostgreSQL Backend Persistence            │
  └────────────────────────────────────────────────────────┘
```

### Why FastAPI over ASP.NET Core:
1. **Simplicity:** A single `main.py` with Pydantic models provides complete REST API parity in ~150 lines of clear Python code.
2. **Auto-Generated OpenAPI:** Instant, interactive Swagger documentation at `/docs` simplifies client verification.
3. **Low Resource Footprint:** Lightweight to run locally or containerize without complex SDK installations in academic environments.