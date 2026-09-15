# FABLE: Architectural Feature Enhancement Plans

**Document Version:** 1.0.0  
**Discipline:** Enterprise Mobile Systems Engineering  
**Platform:** Native iOS 17.0+ (Swift 5.9+, SwiftUI, Xcode 15/16)  
**Architecture Pattern:** Strict Model–View–Controller (MVC) + Offline-First Repository  

---

## 1. Executive Summary & Enhancement Scope

This directory contains formal, critical system design and technical implementation plans for the five core feature enhancements of **Fable**. These enhancements elevate the project from a basic in-memory CRUD prototype into an authentic, publication-grade editorial e-reading and manuscript publishing ecosystem.

All plans are formulated under **strict critical system design tenets**:
1. **Asset-Decoupled Visual Invariant:** Zero external binary bitmap dependencies; visual representations use procedural geometry, parchment fills, hairline borders, and serif monograms.
2. **Offline-First Determinism:** The client functions with 100% feature parity without internet connectivity.
3. **Rigorous Concurrency & Thread Isolation:** Strict separation between UI main-thread rendering (`@MainActor`) and background persistence/sync tasks (`@ModelActor` / async background tasks).
4. **Negligible Heap Footprint:** Designed for micro-narratives (<5,000 words per story) ensuring total resident application memory remains strictly under **25 MB**.
5. **No Blind Source Code Edits:** All specifications provide complete architectural contracts, mathematical algorithms, data schemas, and test plans for the developer to inspect, learn from, and implement.

---

## 2. Feature Enhancement Matrix

| Plan File | Architectural Module | Primary Capability | Key Design Invariant |
|---|---|---|---|
| **[`01_PERSISTENCE_SWIFTDATA_SQLITE.md`](./01_PERSISTENCE_SWIFTDATA_SQLITE.md)** | Local Persistence Engine | SwiftData & SQLite on-device database | Zero data loss on cold boot; seamless migration from in-memory seed store |
| **[`02_MARGINALIA_AND_ANNOTATIONS.md`](./02_MARGINALIA_AND_ANNOTATIONS.md)** | Text Interaction & Journaling | Character-accurate highlights & saved quotes | UTF-16 offset range anchoring; instant synchronization with Shelf Journal quote cards |
| **[`03_PAGINATION_AND_PACING_ENGINE.md`](./03_PAGINATION_AND_PACING_ENGINE.md)** | Pagination & Reading Velocity | Authentic page-turning & adaptive WPM tracker | Dynamic word tokenization; remaining chapter time recalculation based on actual reader pacing |
| **[`04_ORAL_FOLKLORE_AUDIO_SYNTHESIZER.md`](./04_ORAL_FOLKLORE_AUDIO_SYNTHESIZER.md)** | Audio Narration & Accessibility | Native text-to-speech audio reader (`AVSpeechSynthesizer`) | Lock-screen `MPNowPlaying` metadata; sentence-level highlighting synchronization; zero audio clipping |
| **[`05_FASTAPI_CLOUD_SYNC_PIPELINE.md`](./05_FASTAPI_CLOUD_SYNC_PIPELINE.md)** | Distributed Cloud Synchronization | Minimalist FastAPI backend & SQLite cloud sync | Contract-first OpenAPI pipeline; Last-Write-Wins (LWW) conflict resolution; zero enterprise bloat |

---

## 3. High-Level Dependency & Execution Topology

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER (SwiftUI)                    │
│                                                                        │
│  [LibraryView]     [ExploreView]     [ReaderView]     [ShelfView]      │
│         ▲                 ▲                ▲                ▲          │
│         │                 │                │                │          │
│         │        ┌────────┴────────┐  ┌────┴─────┐   ┌──────┴──────┐   │
│         │        │ Pagination / WPM│  │Marginalia│   │Audio Controls│   │
│         │        │    (Plan 03)    │  │ (Plan 02)│   │  (Plan 04)  │   │
│         │        └────────┬────────┘  └────┬─────┘   └──────┬──────┘   │
└─────────┼─────────────────┼────────────────┼────────────────┼──────────┘
          │                 │                │                │
          ▼                 ▼                ▼                ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       CONTROLLER & REPOSITORY LAYER                    │
│                                                                        │
│   ┌──────────────────────────────────────────────────────────────┐     │
│   │                 StoryStore / StoryController                 │     │
│   │   - Active Reading State Machine                             │     │
│   │   - Speech Synthesis Queue Manager                           │     │
│   │   - In-Memory Cache + Compound Predicate Filter              │     │
│   └──────────────┬───────────────────────────────┬───────────────┘     │
└──────────────────┼───────────────────────────────┼─────────────────────┘
                   │                               │
                   ▼ (Local CRUD)                  ▼ (Async Sync)
┌──────────────────────────────────────┐  ┌──────────────────────────────┐
│       LOCAL PERSISTENCE ENGINE       │  │    CLOUD SYNC PIPELINE       │
│              (Plan 01)               │  │          (Plan 05)           │
│  - SwiftData / SQLite ModelContainer │  │  - FastAPI Lightweight Sync │
│  - StoryEntity, AnnotationEntity     │  │  - Pydantic v2 DTO Contract  │
│  - Zero Network Required             │  │  - LWW Conflict Resolution   │
└──────────────────────────────────────┘  └──────────────────────────────┘
```

---

## 4. Implementation Phasing Strategy

To ensure manageable, incremental progress aligned with our technical instructor pacing protocol:

1. **Phase 1: Local Persistence (Plan 01)** — Replace ephemeral in-memory variables with persistent SwiftData/SQLite storage so authored stories, progress, and bookmarks survive app restarts.
2. **Phase 2: Marginalia & Quotes (Plan 02)** — Allow readers to select manuscript text, assign highlights, and populate the Shelf reading quote card.
3. **Phase 3: Pagination & Pacing (Plan 03)** — Implement viewport-based page segmentation and the live WPM velocity tracker for remaining chapter reading time.
4. **Phase 4: Oral Folklore Audio (Plan 04)** — Integrate `AVSpeechSynthesizer` for native voice narration, speech progress tracking, and accessibility audio.
5. **Phase 5: Cloud Synchronization (Plan 05)** — Wire up the optional FastAPI backend for multi-device sync and remote backup.
