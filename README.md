# Fable iOS: Curated Multi-Format Literature & Graphic Manga Platform

[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple.svg)](https://developer.apple.com/xcode/swiftui/)
[![Architecture](https://img.shields.io/badge/Architecture-Modular%20MVVM%2BS-green.svg)](https://developer.apple.com)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI%200.110+-009688.svg)](https://fastapi.tiangolo.com)
[![Pydantic v2](https://img.shields.io/badge/Contract-Pydantic%20v2-e92063.svg)](https://docs.pydantic.dev/)
[![Database](https://img.shields.io/badge/Database-SQLite-4169E1.svg)](https://www.sqlite.org/)
[![Pytest](https://img.shields.io/badge/Tests-35%2F35%20Passing-brightgreen.svg)](https://pytest.org)
[![Multi-Format](https://img.shields.io/badge/Format-Prose%20%7C%20Manga-indigo.svg)](https://developer.apple.com)
[![Figma Prototype](https://img.shields.io/badge/Figma-100%25%20Prototype-pink.svg)](https://www.figma.com/proto/fable-ios-prototype-midterm)

**Fable** is a bespoke, native iOS multi-format reading platform and companion REST backend engineered as a distraction-free sanctuary for classic literature, folklore, and serialized graphic novels/manga. In contrast to commercial reading platforms diluted with aggressive ads, social feeds, and micro-transactions, Fable couples an Electric Indigo modern aesthetic with an enterprise-grade, offline-first, contract-first system architecture.

---

## 1. Tech Stack Overview

### Client-Side (iOS)
* **Language & Runtime:** Swift 5.10 / Swift 6 Concurrency (`@MainActor`, `Sendable`, `async/await`)
* **Target Operating System:** iOS 17.0+ (iPhone & iPad responsive layouts)
* **User Interface:** SwiftUI (Declarative state-driven UI, custom geometry readers, safe-area insets, dynamic typography)
* **Reading Engines:**
  * *Prose Engine:* Typographical customizer (font family, theme, line spacing), Table of Contents modal, pacing velocity estimator.
  * *Graphic Manga Engine:* Cinema-black `MangaReaderView` with continuous vertical Webtoon scrolling and horizontal swipe pagination.
* **Reactive State Management:** Combine framework (`@Published`, `ObservableObject`, `PassthroughSubject`)
* **Local Persistence & Caching:** SwiftData & CoreData SQLite engine (`ModelContainer`, `ModelContext`, `FetchDescriptor`)
* **Audio Speech Engine:** `AVFoundation` (`AVSpeechSynthesizer`, `AVSpeechUtterance`, regional `AVSpeechSynthesisVoice` audition sheet)
* **Security & Credential Vault:** Apple `Security` framework (`KeychainStore` for encrypted token and session storage)
* **Diagnostics Suite:** Built-in `AppHealthTests` and on-device `SystemDiagnosticsSheet` verifying layout clipping and live ingestion contracts.
* **Networking & HTTP:** Native `URLSession` with ATS enabled; development API base URL is configurable

### Server-Side (Backend API)
* **Runtime & Framework:** Python 3.11+ / FastAPI (High-performance asynchronous REST API)
* **Data Validation & Contracts:** Pydantic v2 with `serialization_alias` (Strict camelCase client / snake_case server parity)
* **Database & Persistence:** SQLite 3 with additive schema initialization and account-scoped shelf, reading-session, and user records.
* **HTTP Client:** HTTPX for live Gutendex/Project Gutenberg and Open Library requests.
* **Security:** Salted PBKDF2-HMAC-SHA256 password hashes, SHA-256 digests of random bearer tokens, 30-day session expiry, and server-side logout revocation.
* **ASGI Web Server:** Uvicorn.
* **Automated Testing:** Pytest with FastAPI `TestClient` (35 backend tests passing in the container).

---

## 2. System Architecture

Fable is architected around **Feature-Driven Vertical Slices** combined with **MVVM+S (Model-View-ViewModel + Store/Service)** to achieve high cohesion, low coupling, and offline-first resilience:

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           SwiftUI View Layer                              │
│   (LibraryView, ReaderView, MangaReaderView, ExploreView, ShelfView)      │
└─────────────────────────────────────┬─────────────────────────────────────┘
                                      │ User Gestures & Property Bindings
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                    @MainActor Central ViewModel Tier                      │
│                    (StoryStore.swift / AuthManager.swift)                 │
└──────────────────┬─────────────────────────────────────┬──────────────────┘
                   │ Reactive @Published Mutations       │ Asynchronous I/O
                   ▼                                     ▼
┌──────────────────────────────────────┐ ┌──────────────────────────────────┐
│        Local Persistence Layer       │ │      Service Abstraction         │
│   (SwiftData / PersistenceService)   │ │    (StoryAPIServiceProtocol)     │
│   - In-memory cache fallback         │ │   - StoryAPIService Client       │
│   - Pure zero-baseline analytics     │ │   - KeychainStore (Auth Tokens)  │
│   - Pinned annotations & journal     │ │   - AudioNarratorController      │
└──────────────────────────────────────┘ └──────────────────┬───────────────┘
                                                            │ REST JSON Calls
                                                            ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                      FastAPI Backend Engine (v1)                          │
│   - /api/v1/auth       (Registration, login, profile, logout, stats)     │
│   - /api/v1/auth/me/stats (Account reading totals and active streak)     │
│   - /api/v1/stories    (Multi-format catalog, prose & manga chapters)     │
│   - /api/v1/genres     (Live taxonomy & reader metrics)                   │
│   - /api/v1/authors/top(Verified top creators & avatar URLs)              │
│   - /api/v1/updates    (Live chapter updates & editorial highlights)      │
│   - /api/v1/shelf      (Bearer-protected account shelf read and sync)    │
│   - /api/v1/auth/me/reading-sessions (Idempotent reading events)          │
│   - /api/v1/health     (System diagnostics & DB status)                   │
└─────────────────────────────────────┬─────────────────────────────────────┘
                                      │ Relational Queries
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                       SQLite Storage Tier                                 │
│ (stories, chapters, account_shelf_items, reading_sessions, user_sessions) │
└───────────────────────────────────────────────────────────────────────────┘
```

### Architectural Principles
1. **Contract-First API Design:** Python schemas define camelCase Pydantic serialization aliases that match Swift `Codable` contracts; backend tests cover the serialized response shapes.
2. **Offline-First Resilience:** When the backend is unreachable, the client uses previously cached SwiftData stories, chapters, discovery metadata, images, shelf state, and queued reading sessions. A fresh install has no bundled story catalog.
3. **Decoupled Service Boundary:** SwiftUI views never execute raw network requests. All data fetching, caching, and mutations flow through protocol-abstracted services.

---

## 3. How to Set Up and Run

### Prerequisites
* **macOS:** macOS Sonoma (14.0+) or Sequoia (15.0+)
* **Xcode:** Xcode 15.4 or Xcode 16.0+
* **Python:** Python 3.11 or higher
* **Git:** Git 2.39+

---

### Step A: Setting Up & Starting the Backend API

1. **Navigate to the Repository Root:**
   ```bash
   cd Fable-IOS
   ```

2. **Create and Activate a Python Virtual Environment:**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```

3. **Install Dependencies:**
   ```bash
   pip install --upgrade pip
   pip install -r backend/requirements.txt
   ```

4. **Execute Backend Verification Tests:**
   ```bash
   pytest backend/test_main.py -v
   ```
   *(All tests must pass, verifying health checks, serialization contracts, chapter extraction, and sync logic).*

5. **Start the FastAPI Development Server:**
   ```bash
   cd backend
   uvicorn main:app --reload --host 127.0.0.1 --port 8000
   ```
   * **API Base URL:** `http://127.0.0.1:8000/api/v1`
   * **Interactive Swagger UI:** Open your browser and navigate to `http://127.0.0.1:8000/docs`
   * **Health Check:** `curl http://127.0.0.1:8000/api/v1/health`

---

### Step B: Setting Up & Running the iOS Client (SwiftUI)

1. **Open the Project in Xcode:**
   ```bash
   open frontend/FableApp.xcodeproj
   ```
   *(Or launch Xcode ➔ **File** ➔ **Open...** ➔ Select `frontend/FableApp.xcodeproj`).*

2. **Select Target Scheme & Run Destination:**
   * In the top Xcode toolbar, confirm the active scheme is set to **FableApp**.
   * Select an iOS Simulator running **iOS 17.0+** (e.g., **iPhone 16 Pro** or **iPhone 15 Pro**).

3. **Configure the API URL:**
   * The `FABLE_API_BASE_URL` Xcode build setting is exposed through the generated Info.plist. It defaults to `http://127.0.0.1:8000/api/v1` for the iOS Simulator.
   * For a physical device, set it to the development machine's LAN address, such as `http://192.168.1.20:8000/api/v1`, and bind FastAPI to `0.0.0.0`. For release builds, use the deployed HTTPS API URL.
   * ATS allows local networking for development and keeps arbitrary HTTP loads disabled.

4. **Build & Launch:**
   * Press `Cmd + R` (or click the **Play** button).
   * With the backend reachable, Fable discovers provider catalog entries and user-published stories. When offline, it uses previously cached provider metadata, images, chapters, and account-specific drafts; a fresh install has no bundled story catalog.

---

## 4. Project Directory Topology

```text
Fable-IOS/
├── README.md                               # Repository guide & setup documentation (this file)
├── AGENTS.md                               # AI senior technical instructor protocol
├── Package.swift                           # Swift Package Manager manifest
├── backend/                                # Asynchronous Python / FastAPI Backend
│   ├── main.py                             # Application entrypoint & middleware configuration
│   ├── requirements.txt                    # Python dependencies (FastAPI, Uvicorn, Pydantic, HTTPX, pytest)
│   ├── test_main.py                        # Backend contract and service tests (35 passing)
│   ├── api/v1/
│   │   ├── api.py                          # Unified API router mounting
│   │   └── endpoints/                      # Route controllers (auth, stories, shelf, gutenberg, health)
│   ├── core/
│   │   └── database.py                     # SQLite connection and additive schema bootstrap
│   ├── models/                             # Data models
│   ├── schemas/                            # Pydantic v2 DTOs with serialization aliases
│   └── services/                           # Business logic (story service, shelf sync, gutenberg parser)
├── frontend/                               # Native iOS Application
│   ├── FableApp.xcodeproj/                 # Xcode 16 project file (Synchronized Root Group)
│   └── FableApp/
│       ├── App/                            # Lifecycle bootstrap (FableApp.swift, ContentView.swift)
│       ├── Core/                           # Foundation tokens, FableTheme, FableImageView, KeychainStore
│       ├── Features/                       # Domain-Driven Vertical Slices
│       │   ├── Auth/                       # Welcome, SignIn, SignUp, AuthManager, AuthTests
│       │   ├── Library/                    # LibraryView, ExploreView, GenreDetail, StoryStore, APIService, AppHealthTests
│       │   ├── Reader/                     # ReaderView, MangaReaderView, DisplayOptionsSheet, VoiceSelectionSheet, AudioNarrator
│       │   ├── Shelf/                      # ShelfView, ProfileView, SettingsView, SystemDiagnosticsSheet, ShelfTests
│       │   └── Write/                      # WriteView, StoryComposer, StoryPublishedSheet, WriteTests
│       └── Assets.xcassets/                # App icon and accent color; editorial images come from providers
├── docs/                                   # Architectural specifications & academic documentation
│   ├── final_milestone/                    # Capstone ADRs, multi-format architecture, master progress log
│   ├── FINAL_MILESTONE_PROGRESS.md         # Comprehensive milestone progression audit
│   ├── DATA_SOURCES_AND_API_STRATEGY.md    # Multi-format gateway pattern & API contracts
│   ├── ARCHITECTURE.md                     # System architecture & vertical slice design
│   ├── SYSTEM_DESIGN.md                    # Critical system design & 5 pillars specification
│   ├── FIGMA.md                            # Complete Figma frame inventory & interaction matrix
│   └── MAC_LAB_RUNBOOK.md                  # Step-by-step computer lab verification runbook
└── prototype_reference/                    # High-resolution screenshots of all 10 prototype screens
```

---

## 5. Lab Troubleshooting & Consistency Guarantees

| Issue Encountered | Root Cause | Resolution |
|---|---|---|
| **Xcode defaults to "My Mac" destination** | Xcode auto-selected Mac Catalyst or macOS destination | Click the target dropdown at the top of Xcode ➔ Choose `iOS Simulators` ➔ `iPhone 16 Pro`. |
| **Simulator fails to connect to `127.0.0.1:8000`** | FastAPI server is not running in terminal | In terminal, ensure virtual environment is active and run `uvicorn main:app --reload --port 8000`. |
| **Old cached build artifacts fail** | Previous user left stale build cache | Press `Shift + Cmd + K` (**Product** ➔ **Clean Build Folder**), then press `Cmd + B` to rebuild. |
| **Offline Lab Network (No Internet)** | Campus Wi-Fi blocked or offline computer | Fable reads previously cached stories, chapters, images, and per-account shelf data. A first launch without network has no catalog to display. |

---

## 6. Official Submission References

* **Figma Interactive Prototype:** [https://www.figma.com/proto/fable-ios-prototype-midterm](https://www.figma.com/proto/fable-ios-prototype-midterm)
* **GitHub Repository URL:** [Fable-IOS](https://github.com/ur1el0/Fable-IOS/tree/feature/live-data-and-button-wiring)
* **Author / Developer:** Roosc Zaño (ITWM101 | M090)
