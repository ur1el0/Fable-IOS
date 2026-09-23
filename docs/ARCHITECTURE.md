# FABLE: iOS Architecture & Technical Specification

**Application:** Fable (Curated Micro-Narrative & Editorial E-Reader)  
**Target Platform:** Native iOS (iOS 17.0+, iPhone 14/15/16 / Pro / Pro Max)  
**Development Environment:** Xcode 15 / 16 (macOS, Mac Lab Environment)  
**Language & UI Framework:** Swift 5.9+ / Swift 6, SwiftUI  
**Architectural Pattern:** Strict Model–View–Controller (MVC)  
**Local Persistence Strategy (Final):** SQLite / SwiftData (Local on-device storage)  
**Backend Service Strategy (Final):** FastAPI (Python, lightweight, auto-generating OpenAPI)  
**Milestone:** Final Capstone Submission (100% Fully Functional Implementation & Distributed Architecture)

---

## 1. Executive Summary & Architectural Vision

**Fable** is a native iOS creative writing, literature, and graphic manga reading application engineered for typographical elegance, distraction-free consumption, and offline-first reliability. Designed for curated world folklore, classical literature, and serialized graphic novels, Fable couples a modern visual identity (Electric Indigo palette, responsive typography) with an enterprise-grade, distributed client-server architecture.

### 1.1 Architectural Constraints & Engineering Realities
1. **Academic Mac Lab Environment:** Development, testing, and grading occur in a Mac lab using Xcode. The application compiles cleanly with 0 warnings, runs predictably on the iOS Simulator (iPhone 15/16 Pro), and possesses **offline-first determinism** with zero hard failure when disconnected from the backend.
2. **Multi-Format Reading & CRUD Scope:**
   - **Create:** Draft, preview, and publish original stories with genre tagging, synopsis, and live word counting (`WriteView`).
   - **Read (Prose & Manga):** Multi-format reading engines supporting continuous vertical Webtoon scroll, horizontal swipe pagination (`MangaReaderView`), and responsive typography-customizable literature reading (`ReaderView`).
   - **Update:** Live progress synchronization, bookmark toggles, dynamic chapter pacing recalibration, and reader appearance options (`DisplayOptionsSheet`).
   - **Delete:** Remove shelf items and purge local reading history.
3. **Strict Model–View–Controller (MVC) + Store Compliance:** Complete separation of concerns:
   - **Model:** Immutable value types, codable DTOs, and serialization contracts.
   - **View:** Declarative SwiftUI components with strict boundary clipping and zero raw network operations.
   - **Controller / Store:** Centralized business logic, state machines (`AudioNarratorController`, `StoryController`, `AuthManager`), and persistence abstraction.

---

## 2. High-Level System Architecture & Topology

```
┌────────────────────────────────────────────────────────────────────────┐
│                              VIEW LAYER                                │
│                   (Declarative SwiftUI Interface)                      │
│                                                                        │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌────────────┐  │
│  │      LibraryView      │  │      ExploreView      │  │ ReaderView │  │
│  │ (Multi-Format Feed)   │  │   (GenreDetailView)   │  │(MangaReader│  │
│  └───────────┬───────────┘  └───────────┬───────────┘  └─────┬──────┘  │
│              │                          │                    │         │
│  ┌───────────┴───────────┐  ┌───────────┴───────────┐        │         │
│  │       WriteView       │  │       ShelfView       │        │         │
│  │  (StoryComposerView)  │  │(SystemDiagnosticsSheet│        │         │
│  └───────────┬───────────┘  └───────────┬───────────┘        │         │
└──────────────┼──────────────────────────┼────────────────────┼─────────┘
               │                          │                    │
               │ User Interaction Events  │ Observes Published │
               │ (taps, inputs, toggles)  │ Observable State   │
               ▼                          ▼                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      CONTROLLER & STORE LAYER                          │
│                  (Business Logic & State Coordination)                 │
│                                                                        │
│     ┌────────────────────────────────────────────────────────────┐     │
│     │               StoryStore / StoryController                 │     │
│     │  --------------------------------------------------------  │     │
│     │  - stories: [Story]               (Published Catalog)      │     │
│     │  - activeReaderStory: Story?      (Active Manuscript)      │     │
│     │  - activeChapter: Chapter?        (Sequential Chapter)     │     │
│     │  - userStats: UserReadingStats    (Pure Living Analytics)  │     │
│     │  - isLiveBackendEnabled: Bool     (FastAPI Cloud Switch)   │     │
│     │  --------------------------------------------------------  │     │
│     │  + publishStory(draft)            [CRUD: Create]           │     │
│     │  + fetchChapters(story)           [CRUD: Read Multi-Chap]  │     │
│     │  + toggleBookmark(storyId)        [CRUD: Update]           │     │
│     │  + updateProgress(storyId, pct)   [CRUD: Update]           │     │
│     │  + syncWithCloudBackend()         [Cloud Reconciliation]   │     │
│     └──────────────┬──────────────────────────────┬──────────────┘     │
└────────────────────┼──────────────────────────────┼────────────────────┘
                     │                              │
                     ▼                              ▼
┌──────────────────────────────────────┐  ┌──────────────────────────────┐
│       LOCAL PERSISTENCE ENGINE       │  │     FASTAPI BACKEND TIER     │
│  - SwiftData / SQLite ModelContainer │  │  - Python 3.11+ / FastAPI    │
│  - KeychainStore (Auth tokens)       │  │  - Multi-tenant shelf sync   │
│  - Pure Zero-Baseline Analytics      │  │  - 22 Pytest Automated Cases │
│  - 100% Offline functional guarantee │  │  - Interactive Swagger /docs │
└──────────────────────────────────────┘  └──────────────────────────────┘
```

---

## 3. Detailed Architectural Layer Separation

### 3.1 Model Layer (`frontend/FableApp/Features/Library/Models/`)
The Model layer represents pure business entities, value objects, and styling configurations. Models are completely isolated from SwiftUI view logic and controllers.
- **Type Safety & Protocols:** Conforms to `Identifiable`, `Codable`, and `Equatable`.
- **Key Entities:**
  - `Story`: Core entity containing unique `id: UUID`, `title: String`, `author: String`, `genre: Genre`, `contentFormat: ContentFormat` (`.prose`, `.manga`), `sourceProvider: SourceProvider` (`.gutenberg`, `.standardEbooks`, `.mangadex`), `synopsis: String`, `content: String`, `chapters: [Chapter]`, `readTimeMinutes: Int`, `isBookmarked: Bool`, `isCompleted: Bool`, `readingProgress: Double`, and `coverImageUrl: String?`.
  - `Chapter`: Sequential reading unit with `id: String`, `title: String`, `chapterNumber: Int`, `content: String`, and `pageUrls: [String]` (sequential graphic panel URLs for manga).
  - `ContentFormat`: Explicit format discriminator (`.prose`, `.manga`).
  - `SourceProvider`: Catalog source provenance (`.gutenberg`, `.standardEbooks`, `.mangadex`).
  - `UserReadingStats`: Pure zero-baseline living analytics derived without artificial stat floors.
  - `ReaderTheme` & `ReaderFont`: Configurable appearance value objects for custom typography rendering.

### 3.2 Controller & Service Layer (`frontend/FableApp/Features/`)
- **`StoryStore` & `StoryController`:** Coordinate state mutations, catalog search, format filtering, and bidirectional cloud synchronization with Last-Write-Wins (LWW) conflict resolution.
- **`AudioNarratorController`:** `AVSpeechSynthesizer` state machine orchestrating text-to-speech audio, voice audition, and active chapter tracking.
- **`AuthManager` & `KeychainStore`:** Manage multi-tenant session tokens, BCrypt registration/login requests, and encrypted keychain storage.
- **`PacingEngine`:** Dynamic word tokenization and zoom-invariant reading speed calculation.

### 3.3 View Layer (`frontend/FableApp/Features/`)
The View layer is purely declarative, composed of lightweight structs conforming to `SwiftUI.View`.
- **Reusable Component Hierarchy:**
  - `ContentView`: Application container hosting authentication flow and persistent tab routing.
  - `LibraryView`: Multi-format discovery feed with format filtering chips (All, Novels, Manga).
  - `MangaReaderView`: Cinema-black graphic reader supporting Webtoon vertical scrolling and horizontal swipe pagination.
  - `ReaderView`: Adaptive literature reader with TOC modal and audio narration bar.
  - `VoiceSelectionSheet`: Interactive modal for auditioning regional speech synthesizer voices.
  - `SystemDiagnosticsSheet`: Interactive on-device diagnostics sheet executing `AppHealthTests`.
  - `FableImageView`: Asset loader and procedural fallback renderer enforcing strict `.clipped()` anti-overlap geometry.

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