# Fable: Live Data Sources & API Integration Strategy

**Document Purpose:** Architectural blueprint defining where live data originates, how the mobile client fetches and synchronizes content, and the integration trade-offs between dedicated cloud backends and public literary APIs.

---

## 1. Executive Overview

In the Fable iOS ecosystem, transitioning from mock seed data to a live network architecture requires defining the **source of truth** for manuscripts, user collections, and community publications.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DATA SOURCE LANDSCAPE                           │
├──────────────────────────────┬─────────────────────────────────────────┤
│ 1. Dedicated Cloud Backend   │ • Custom editorial curation             │
│    (FastAPI + SQLite/Postgres)│ • Live user-generated stories (WriteView)│
│                              │ • Multi-device Shelf & Progress Sync    │
├──────────────────────────────┼─────────────────────────────────────────┤
│ 2. Public Literary APIs      │ • Project Gutenberg REST API (Gutendex) │
│    (Gutendex / Open Library) │ • Millions of public-domain classics    │
│                              │ • Zero backend hosting maintenance      │
├──────────────────────────────┼─────────────────────────────────────────┤
│ 3. Enterprise Hybrid Pattern │ • FastAPI as intelligent API gateway    │
│    (Recommended Architecture)│ • Blends custom shorts with public books│
│                              │ • Local offline-first SQLite cache      │
└──────────────────────────────┴─────────────────────────────────────────┘
```

---

## 2. Source 1: Dedicated Fable Cloud Backend (The Commercial Standard)

This architecture mirrors consumer reading platforms like **Medium, Substack, and Wattpad**, where the application communicates with its own first-party REST API.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FABLE CLOUD BACKEND (FastAPI)                   │
│                                                                        │
│   ┌───────────────────────┐             ┌──────────────────────────┐   │
│   │ Curated Stories Table │             │ User-Published Manuscripts│   │
│   │ (Folklore, Mythology) │             │ (Submitted via WriteView)│   │
│   └───────────┬───────────┘             └────────────┬─────────────┘   │
│               │                                      │                 │
│               └──────────────────┬───────────────────┘                 │
│                                  ▼                                     │
│                     SQLite / PostgreSQL Database                       │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ HTTP GET /api/v1/stories
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     FABLE iOS CLIENT (SwiftUI)                         │
│                                                                        │
│   - Fetches active catalog live over Wi-Fi / Cellular                  │
│   - When author writes in WriteView ➔ POSTs live to server             │
│   - Readers instantly discover the new story in their feed             │
└────────────────────────────────────────────────────────────────────────┘
```

### Key Characteristics
1. **Curated Editorial Catalog:** The backend database contains the initial seed of historical folklore, mythology, and editorial shorts (e.g. *The Clockmaker of Prague*, *The Loom of Arachne*, *Maria Makiling*).
2. **User-Generated Content (UGC):** When a user crafts a story in `WriteView` and taps **Publish**, the app sends an HTTP `POST /api/v1/stories` request. The backend validates and persists the story, making it instantly discoverable for other users.
3. **Data Integrity & Exact Formatting:** Because we define the database schema, all fields (chapter numbers, reading time, excerpt, full body text) match the iOS view models with 100% accuracy.

---

## 3. Source 2: Public External Web APIs (Real Internet Databases)

If the goal is to access a vast, pre-existing library of real-world literature without manual data entry, public REST APIs provide instant access to thousands of public-domain works.

### A. Gutendex (Project Gutenberg REST API)
- **Base Endpoint:** `https://gutendex.com/books`
- **Filtering by Topic:**
  - Folklore: `https://gutendex.com/books?topic=folklore`
  - Mythology: `https://gutendex.com/books?topic=mythology`
  - Gothic/Horror: `https://gutendex.com/books?topic=ghost_stories`
- **Authentication:** None required (100% free and open public service).
- **Available Fields:** Title, author names, birth/death dates, bookshelves, cover image URLs, and full-text `.txt` / `.epub` download links.
- **Example Classics:** *Grimm's Fairy Tales*, *Dracula*, *Frankenstein*, *The Odyssey*, *The Legend of Sleepy Hollow*.

### B. Open Library Books API (Internet Archive)
- **Base Endpoint:** `https://openlibrary.org/subjects/folklore.json`
- **What It Provides:** Real-time metadata for millions of published editions, author bibliographies, and ISBN cover lookups.

---

## 4. Source 3: The Enterprise Hybrid Gateway Pattern (Recommended)

The most resilient and scalable architecture combines both models using an **API Gateway Pattern**:

```
                       ┌───────────────────────────────┐
                       │    Fable iOS Client (App)     │
                       └──────────────┬────────────────┘
                                      │ HTTP / JSON
                                      ▼
                       ┌───────────────────────────────┐
                       │   FastAPI Gateway (backend/)  │
                       └──────┬─────────────────┬──────┘
                              │                 │
               ┌──────────────┴──────┐   ┌──────┴──────────────┐
               ▼                     │   ▼                     │
    ┌──────────────────────┐         │ ┌─────────────────────┐ │
    │ Internal Fable DB    │         │ │ Gutendex Public API │ │
    │ - Editorial Shorts   │         │ │ - Infinite Classics │ │
    │ - User Publications  │         │ │ - Public Domain Books││
    │ - Shelf Progress     │         │ └─────────────────────┘ │
    └──────────────────────┘         └─────────────────────────┘
```

### Why the Hybrid Pattern Wins:
1. **Reliability & Caching:** The FastAPI service queries Gutendex or Open Library, normalizes the messy external data into Fable's clean `StoryDTO` format, and caches results in SQLite. The mobile app only talks to a single, predictable API.
2. **Infinite Content + Community Publishing:** Readers get access to an endless catalog of classic literature while still being able to write, publish, and bookmark original community stories.
3. **Offline-First Resilience:** Even if external services or campus Wi-Fi fluctuate, cached stories and local SwiftData storage keep the app fully functional.

---

## 5. Mobile Client Implementation (MVC Data Flow)

In the iOS client, fetching live data follows a clean three-layer separation of concerns:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. Network Layer (Services/StoryAPIService.swift)                     │
│    - Executes async URLSession requests                                │
│    - Decodes JSON payload into strongly-typed [Story] models           │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ async / await
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 2. Controller Layer (Controllers/StoryController.swift)               │
│    - Coordinates state mutations                                      │
│    - Updates @Published var stories: [Story]                          │
│    - Manages loading states, error handling, and offline fallbacks     │
└──────────────────────────────────┬─────────────────────────────────────┘
                                   │ Reactive State Binding
                                   ▼
┌────────────────────────────────────────────────────────────────────────┐
│ 3. Presentation Layer (Views/LibraryView.swift)                       │
│    - Triggers load via .task { await controller.loadStories() }       │
│    - Automatically re-renders feed upon state mutation                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Implementation Roadmap

To activate live fetching:

1. **Step 1: Start the Local Backend Server**
   ```bash
   cd backend
   python3 -m uvicorn main:app --reload --port 8000
   ```
2. **Step 2: Populate the Database**
   Seed the SQLite database with the full 10-story editorial suite or configure the Gutendex crawler.
3. **Step 3: Enable Live Networking in iOS**
   In `frontend/FableApp/Controllers/StoryController.swift`, set:
   ```swift
   public var isLiveBackendEnabled: Bool = true
   ```
4. **Step 4: Verify Live Feed in iOS Simulator**
   Launch the app (`Cmd + R`); the feed will now dynamically pull from the live HTTP endpoint.
