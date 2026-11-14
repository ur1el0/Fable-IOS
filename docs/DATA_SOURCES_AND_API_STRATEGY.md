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
1. **Live Public-Domain Catalog:** Fable keeps the catalog snapshot, popular-book, and recently added collections distinct. Popular titles use Gutendex's popularity ordering; new additions come from Project Gutenberg's daily RSS feed and are resolved against official RDF metadata, with entries lacking plain text filtered out. The app does not bundle placeholder provider stories. Cover URLs come from provider metadata, and chapter text is fetched when a reader opens a title.
   - Gutenberg catalog cards use `totalChapters: 0` to mean “not loaded yet.” The reader loads and parses the full text on demand; chapter headings can use numeric, Roman, or spelled-out numbers.
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

### C. Standard Ebooks Integration
- **Source:** Standard Ebooks Public Domain Catalog
- **What It Provides:** Professionally formatted, typography-first public domain editions (e.g. *Frankenstein: The 1818 Text*, *The Metamorphosis*).
- **Format:** Ingested as `ContentFormat.prose` with provenance `SourceProvider.standardEbooks`.

### D. MangaDex Graphic Manga API
- **Base Endpoint:** `https://api.mangadex.org`
- **What It Provides:** High-resolution sequential panel art manifests for graphic novels and manga (e.g. *Chainsaw Devil: Special Edition*).
- **Format:** Ingested as `ContentFormat.manga` with provenance `SourceProvider.mangadex`. Each chapter includes an ordered `pageUrls` array of image URLs consumed by `MangaReaderView`.
- **Known Limitation & Licensing Gaps:** MangaDex feeds can contain chapter gaps and user uploaded scanlations. Fable does not seed third-party scanlation pages into its database; manga remains hidden in the iOS catalog until source continuity and rights can be verified.

---

## 4. Source 3: The Enterprise Hybrid Gateway Pattern (Recommended)

The most resilient and scalable architecture combines all providers using an **API Gateway Pattern**:

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
               ┌──────────────┴──────┐   ┌──────┴──────────────────────────┐
               ▼                     │   ▼                                 ▼
    ┌──────────────────────┐         │ ┌─────────────────────┐   ┌─────────────────────┐
    │ Internal Fable DB    │         │ │ Gutendex Public API │   │ MangaDex Public API │
    │ - Editorial Shorts   │         │ │ - Infinite Classics │   │ - Graphic Manga     │
    │ - User Publications  │         │ │ - Standard Ebooks   │   │ - Sequential Panels │
    │ - Multi-Tenant Shelf │         │ └─────────────────────┘   └─────────────────────┘
    └──────────────────────┘         └─────────────────────────────────────────────────┘
```

### Why the Hybrid Pattern Wins:
1. **Multi-Format Normalization:** The FastAPI gateway standardizes text from Gutenberg/Standard Ebooks and panel URLs from MangaDex into unified `StoryDTO` and `ChapterDTO` models, eliminating client-side decoding fragmentation.
2. **Infinite Content + Community Publishing:** Readers get access to an endless catalog of classic literature and graphic novels while still being able to write, publish, and bookmark original community stories.
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

## 6. Local Provider and Reader Flow

1. Start the backend with `docker compose up -d --build`. Compose maps host port `8001` to container port `8000`; check `http://127.0.0.1:8001/api/v1/health`.
2. The iOS Debug build uses `http://127.0.0.1:8001/api/v1` by default. Use an HTTPS API URL for Release builds.
3. The catalog endpoint returns provider metadata and official cover URLs without downloading every book's text.
4. `ReaderView` requests Gutenberg chapters from `/api/v1/public/gutenberg/{id}/chapters` when a user opens a book. The backend fetches and parses the official plain-text source, then caches chapters for subsequent reads.
