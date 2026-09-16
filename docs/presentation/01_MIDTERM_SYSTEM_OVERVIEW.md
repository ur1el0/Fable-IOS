# Fable iOS: Midterm System Overview & Compliance Audit

**Project Title:** Fable — Offline-First Ambient Literary Reading & Community Publishing Platform  
**Evaluation Milestone:** Midterm Capstone Defense ($\ge 50\%$ Functional Implementation)  
**Author / Presenter:** Roosc Zaño (`@zanoroosc`)  
**Repository Branch:** `feature/midterm-presentation` (Baseline: `v0.5.0-midterm`)  
**Target Environment:** iOS 17.0+ (SwiftUI, SwiftData, AVFoundation) & Python 3.9+ (FastAPI, SQLite3)  

---

## 1. Executive Summary & Problem Statement

### 1.1 The Problem
Modern digital reading applications suffer from three critical architectural shortcomings:
1. **Cloud Dependence & Connectivity Fragility:** Most modern reading apps fail or degrade severely when network connectivity drops or latency spikes on mobile cellular connections.
2. **Distraction-Heavy Interfaces:** Bloated social media feeds, intrusive banners, and complex navigation detract from the meditative, atmospheric act of deep reading.
3. **Loss of Oral Storytelling Heritage:** Classical literature and regional folklore were historically spoken traditions. Contemporary readers lack native, immersive oral accompaniment tightly synchronized with the text.

### 1.2 The Solution: Fable
**Fable** is an offline-first iOS literary reading sanctuary and community publishing platform crafted for deep immersion. It combines:
- An **offline-first local persistence architecture** that operates with 100% feature parity without requiring a live server connection during reading.
- An **ambient reader engine** with dynamic physical book pagination, marginalia quote highlighting, and an **AVFoundation oral folklore speech synthesizer**.
- A **lightweight synchronization tier** powered by Python FastAPI and SQLite, employing Last-Write-Wins (LWW) conflict resolution for multi-device sync.

---

## 2. Midterm Requirements Compliance Audit

The capstone syllabus requires a **minimum 50% functional and interface completion** for the midterm presentation. Fable has achieved approximately **85% completion of total planned features**, completely satisfying every evaluation criterion.

### 2.1 Compliance Matrix

| Syllabus Requirement | Target | Achieved in Midterm | Verification / Evidence |
|---|:---:|:---:|---|
| **Interface Completion** | $\ge 50\%$ | **100% (10 of 10 Screens)** | All primary user journeys are fully interactive in the iOS Simulator. |
| **Academic Mac Lab Ready** | 100% | **100%** | Zero external server dependencies required for grading; built-in seed database and in-memory mock repository load instantly on boot. |
| **Local Persistence Engine** | Required | **Complete** | Native SwiftData backed by on-device SQLite (`PersistenceService.swift`), storing reader preferences and session logs. |
| **Interactive Reader** | Required | **Complete** | Dynamic font sizing, line spacing, theme switching (Parchment, Noir, Classic Cream), and live pagination. |
| **Annotation / Marginalia** | Required | **Complete** | Highlight selection with terracotta/amber colors and one-tap save to personal quote journal. |
| **Audio Accompaniment** | Required | **Complete** | Native `AVSpeechSynthesizer` narration with synchronized spoken paragraph highlighting. |
| **Publishing / Creation** | Required | **Complete** | `WriteView` story composer with live word counter, estimated reading time, and shelf publishing. |
| **Authentication Flow** | Required | **Complete** | Welcome landing, Sign-In, and Sign-Up card interfaces with credential state management. |

---

## 3. Screen-by-Screen Inventory (All 10 Screens)

Fable presents 10 complete, interconnected screens adhering to Apple's Human Interface Guidelines (HIG):

```
                                [WelcomeView]
                                      │
                       ┌──────────────┴──────────────┐
                       ▼                             ▼
                 [SignInView]                  [SignUpView]
                       │                             │
                       └──────────────┬──────────────┘
                                      ▼
                               [ContentView]
                               (Tab Navigation)
      ┌──────────────────┬────────────┴────────────┬──────────────────┐
      ▼                  ▼                         ▼                  ▼
[ExploreView]      [LibraryView]             [ShelfView]        [ProfileView]
      │                  │                         │                  │
      ▼                  ▼                         │                  ▼
[GenreDetailView]   [ReaderView] ◄─────────────────┘           [SettingsView]
                         ▲
                         │
                 [WriteView (Composer)]
```

### Screen Details:

1. **Welcome Landing (`WelcomeView.swift`):**
   - Atmospheric hero branding with serif typography.
   - Smooth transitions into Sign In or Sign Up flows, with a "Continue as Guest" fast-path for immediate evaluator testing.

2. **Sign In Screen (`SignInView.swift`):**
   - Elevated card container with field validation, password visibility toggling, error banners, and keyboard management.

3. **Sign Up Screen (`SignUpView.swift`):**
   - Registration card enforcing password confirmation matching, name capture, and instant session initialization.

4. **Explore Feed (`ExploreView.swift`):**
   - Curated literary showcase featuring "Tale of the Day", "Curator's Spotlight", trending writers horizontal carousel, and folklore category cards.

5. **Library Catalog (`LibraryView.swift`):**
   - Filterable catalog supporting real-time full-text search across titles, synopses, and authors, with genre pill filtering (Folklore, Gothic, Mythology, etc.).

6. **Ambient Reader (`ReaderView.swift`):**
   - Core reading experience featuring pagination, ambient theme selection (Parchment, Noir, Cream), typography sizing, oral folklore audio narration, and marginalia annotation popovers.

7. **Reader Display Options (`DisplayOptionsSheet.swift`):**
   - Bottom sheet allowing real-time adjustment of font sizes, paragraph leading, and dark/light color schemes persisted to local preferences.

8. **Story Composer (`WriteView.swift`):**
   - Full-featured writing workspace with title input, genre picker, chapter selector, synopsis editor, and manuscript body with live word counting and validation.

9. **Personal Shelf (`ShelfView.swift`):**
   - Collection hub displaying "Currently Reading" progress cards, saved bookmarked stories, completed manuscripts, and an excerpted quote deck from reader annotations.

10. **Reader Profile & Settings (`ProfileView.swift` & `SettingsView.swift`):**
    - Reader statistics dashboard (reading streak days, total minutes read, books completed), account tier badge, cache management, and theme defaults.

---

## 4. The 5 Core Technical Pillars

| Pillar | Technical Mechanism | Academic Significance |
|---|---|---|
| **1. Persistence Engine** | SwiftData + SQLite | Replaces legacy volatile state with structured relational caching, schema versioning, and zero-latency retrieval. |
| **2. Marginalia & Highlights** | Text range indexing & Quote Journal | Bridges passive consumption and active scholarship by persisting excerpted highlights to the user's shelf. |
| **3. Pacing Engine** | Algorithmic WPM velocity tracking | Calculates dynamic reading velocity and chunks raw manuscripts into physical book-style pages. |
| **4. Oral Audio Synthesizer** | Native `AVFoundation` speech engine | Implements accessibility-first oral storytelling with speech delegate synchronization. |
| **5. Cloud Synchronization** | FastAPI + SQLite + LWW protocol | Implements distributed systems conflict resolution using UTC timestamps for multi-device sync. |

---

## 5. Summary for Grading Evaluation

The midterm prototype is **fully self-contained, stable, and functionally complete**. Evaluators can launch the app in Xcode, browse the full 10-story curated catalog, adjust reader settings, highlight text, listen to speech narration, create new stories, and inspect persistent reader analytics with zero configuration or external network setup.
