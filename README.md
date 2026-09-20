# Fable iOS: Curated Editorial E-Reader & Micro-Fiction Platform

[![Swift 5.10](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple.svg)](https://developer.apple.com/xcode/swiftui/)
[![Architecture](https://img.shields.io/badge/Architecture-Modular%20MVVM%2BS-green.svg)](https://developer.apple.com)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI%200.110+-009688.svg)](https://fastapi.tiangolo.com)
[![Pydantic v2](https://img.shields.io/badge/Contract-Pydantic%20v2-e92063.svg)](https://docs.pydantic.dev/)
[![Database](https://img.shields.io/badge/Database-SQLite%20%7C%20PostgreSQL-4169E1.svg)](https://www.sqlite.org/)
[![Figma Prototype](https://img.shields.io/badge/Figma-100%25%20Prototype-pink.svg)](https://www.figma.com/proto/fable-ios-prototype-midterm)

**Fable** is a bespoke, native iOS editorial platform and companion REST backend engineered as a distraction-free sanctuary for classic literature, mythology, and world folklore. In contrast to commercial reading platforms diluted with aggressive ads, social feeds, and micro-transactions, Fable couples an antique European bookmaking aesthetic with an enterprise-grade, offline-first, contract-first system architecture.

---

## 1. Tech Stack Overview

### Client-Side (iOS)
* **Language & Runtime:** Swift 5.10 / Swift 6 Concurrency (`@MainActor`, `Sendable`, `async/await`)
* **Target Operating System:** iOS 17.0+ (iPhone & iPad responsive layouts)
* **User Interface:** SwiftUI (Declarative state-driven UI, custom geometry readers, safe-area insets, dynamic typography)
* **Reactive State Management:** Combine framework (`@Published`, `ObservableObject`, `PassthroughSubject`)
* **Local Persistence & Caching:** SwiftData & CoreData SQLite engine (`ModelContainer`, `ModelContext`, `FetchDescriptor`)
* **Audio Speech Engine:** `AVFoundation` (`AVSpeechSynthesizer`, `AVSpeechUtterance`, `AVAudioSession`, voice picker)
* **Security & Credential Vault:** Apple `Security` framework (`KeychainStore` for encrypted token and session storage)
* **Networking & HTTP:** Native `URLSession` with ATS (App Transport Security) local development exceptions

### Server-Side (Backend API)
* **Runtime & Framework:** Python 3.11+ / FastAPI (High-performance asynchronous REST API)
* **Data Validation & Contracts:** Pydantic v2 with `serialization_alias` (Strict camelCase client / snake_case server parity)
* **Database & Persistence:**
  * *Development / Lab:* SQLite 3 with connection pooling (zero-config, portable)
  * *Production:* PostgreSQL 16+ via SQLAlchemy ORM (Connection pooling, ACID compliance)
* **HTTP Client:** HTTPX (Asynchronous fetching for external APIs such as Project Gutenberg / Gutendex)
* **ASGI Web Server:** Uvicorn (Lightning-fast asynchronous server gateway)
* **Automated Testing:** Pytest with FastAPI `TestClient`

---

## 2. System Architecture

Fable is architected around **Feature-Driven Vertical Slices** combined with **MVVM+S (Model-View-ViewModel + Store/Service)** to achieve high cohesion, low coupling, and offline-first resilience:

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           SwiftUI View Layer                              │
│   (LibraryView, ReaderView, ExploreView, ShelfView, WriteView, Sheets)    │
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
│   - Offline reading progress & stats │ │   - KeychainStore (Auth Tokens)  │
│   - Pinned annotations & journal     │ │   - AudioNarratorController      │
└──────────────────────────────────────┘ └──────────────────┬───────────────┘
                                                            │ REST JSON Calls
                                                            ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                      FastAPI Backend Engine (v1)                          │
│   - /api/v1/stories    (Editorial catalog, multi-chapter manuscripts)     │
│   - /api/v1/genres     (Live taxonomy & reader metrics)                   │
│   - /api/v1/authors    (Verified top writers & bibliographies)            │
│   - /api/v1/shelf/sync (Bidirectional LWW progress reconciliation)        │
│   - /api/v1/gutenberg  (Public-domain live folklore gateway)              │
│   - /api/v1/health     (System diagnostics & DB status)                   │
└─────────────────────────────────────┬─────────────────────────────────────┘
                                      │ Relational Queries
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                    SQLite / PostgreSQL Storage Tier                       │
│    (stories, chapters, shelf_items, user_credentials, annotations)        │
└───────────────────────────────────────────────────────────────────────────┘
```

### Architectural Principles
1. **Contract-First API Design:** Python schemas define Pydantic serialization aliases (`Field(..., serialization_alias="readTimeMinutes")`), guaranteeing 100% JSON contract parity with Swift `Codable` structs with zero runtime decoding exceptions.
2. **Offline-First Resilience:** If the FastAPI backend is unreachable or the device is in airplane mode, the client gracefully falls back to cached SwiftData records and in-memory seed catalogs without blocking the UI or crashing.
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

3. **Local Networking Configuration (ATS):**
   * The project is pre-configured with `NSAppTransportSecurity` exceptions in `Info.plist` allowing arbitrary loads to `127.0.0.1` and `localhost:8000` for simulator communication.

4. **Build & Launch:**
   * Press `Cmd + R` (or click the **Play** button).
   * Xcode will compile the Swift sources, launch the iOS Simulator, and connect to the local FastAPI backend.
   * **Offline Fallback Guarantee:** Even if the backend server is stopped, Fable will seamlessly launch in offline mode with pre-seeded editorial classics!

---

## 4. Project Directory Topology

```text
Fable-IOS/
├── README.md                               # Repository guide & setup documentation (this file)
├── AGENTS.md                               # AI senior technical instructor protocol
├── Package.swift                           # Swift Package Manager manifest
├── backend/                                # Asynchronous Python / FastAPI Backend
│   ├── main.py                             # Application entrypoint & middleware configuration
│   ├── requirements.txt                    # Python dependencies (fastapi, uvicorn, pydantic, httpx)
│   ├── test_main.py                        # Automated pytest test suite
│   ├── api/v1/
│   │   ├── api.py                          # Unified API router mounting
│   │   └── endpoints/                      # Route controllers (stories, shelf, gutenberg, health)
│   ├── core/
│   │   ├── database.py                     # SQLite / PostgreSQL connection pooling & schema bootstrap
│   │   └── seed_catalog.py                 # Multi-chapter historical literary catalog
│   ├── models/                             # Relational database models
│   ├── schemas/                            # Pydantic v2 DTOs with serialization aliases
│   └── services/                           # Business logic (story service, shelf sync, gutenberg parser)
├── frontend/                               # Native iOS Application
│   ├── FableApp.xcodeproj/                 # Xcode 16 project file (Synchronized Root Group)
│   └── FableApp/
│       ├── App/                            # Lifecycle bootstrap (FableApp.swift, ContentView.swift)
│       ├── Core/                           # Foundation tokens, Theme.swift, FableImageView, KeychainStore
│       ├── Features/                       # Domain-Driven Vertical Slices
│       │   ├── Auth/                       # Welcome, SignIn, SignUp, AuthManager, AuthTests
│       │   ├── Library/                    # LibraryView, ExploreView, GenreDetail, StoryStore, APIService
│       │   ├── Reader/                     # ReaderView, DisplayOptionsSheet, PacingEngine, AudioNarrator
│       │   ├── Shelf/                      # ShelfView, ProfileView, SettingsView, ShelfTests
│       │   └── Write/                      # WriteView, StoryComposer, StoryPublishedSheet, WriteTests
│       └── Assets.xcassets/                # Retina covers, thumbnails, author portraits, and genre artwork
├── docs/                                   # Architectural specifications & academic documentation
│   ├── MIDTERM_PROJECT_DOCUMENTATION.pdf   # Publication-grade single-file submission PDF report
│   ├── MIDTERM_PROJECT_DOCUMENTATION.md    # Markdown documentation companion
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
| **Offline Lab Network (No Internet)** | Campus Wi-Fi blocked or offline computer | **Zero network dependency:** Fable automatically falls back to in-memory SwiftData seed data with 100% operational UI. |

---

## 6. Official Submission References

* **Figma Interactive Prototype:** [https://www.figma.com/proto/fable-ios-prototype-midterm](https://www.figma.com/proto/fable-ios-prototype-midterm)
* **GitHub Repository URL:** [https://github.com/ur1el0/Fable-IOS/tree/feature/final-milestone](https://github.com/ur1el0/Fable-IOS/tree/feature/final-milestone)
* **Author / Developer:** Roosc Zaño (ITWM101 | M090)
