# Fable Architecture Plan: Tachiyomi-Inspired Manga Reader & Server-Side Ingestion

**Document:** `06_TACHIYOMI_MANGA_READER_AND_INGESTION_ARCHITECTURE.md`  
**Author:** Senior Technical Instructor & Enterprise Solutions Architect  
**Audience:** Developer / Capstone Student  
**Target Branch:** `fix/build-and-test-integrity`  
**Status:** Approved Architectural Blueprint (Phase 1 & Phase 2 Active; Phase 3 Deferred)  
**Date:** 2026-10-15  

---

## 1. Executive Summary & Design Rationale

During system architecture review, the integration of **Tachiyomi** (the premier open-source Android manga ecosystem) was evaluated for adaptation within **Fable iOS**. 

### 1.1 Reverse Engineering Analysis (REA Toolkit Evaluation)
* **Assessment:** The proposal to install binary reverse engineering toolkits (e.g. REA / Ghidra / Hopper) to decompile Tachiyomi binaries was formally rejected.
* **Technical Justification:** Tachiyomi and its modern community forks (Mihon) are licensed under **Apache 2.0** with 100% public, human-authored Kotlin repositories. Decompiling compiled Android DEX/Smali binaries introduces synthetic compiler artifacts, lost variable mappings, and reverse-engineering overhead. Direct architectural extraction from open-source repositories provides full fidelity without binary analysis noise.

### 1.2 Cross-Platform Architecture Strategy
Tachiyomi is an Android application written in Kotlin, relying on Android Jetpack, Views/Compose, and SQLDelight. Fable iOS is a native **Swift 5.10 / SwiftUI** client on iOS 17+ backed by a **FastAPI Python 3.11** backend. Rather than attempting brittle cross-compilation or client-side web scraping (which risks rejection under Apple App Store Review Guideline 2.5.2), we extract Tachiyomi's battle-tested patterns into native, decoupled subsystems.

---

## 2. Architecture Scope & Phased Implementation

The integration roadmap is divided into three architectural phases:

```
┌──────────────────────────────────────────────────────────────────────────┐
│              Fable Manga Subsystem Implementation Roadmap                │
└────────────────────────────────────┬─────────────────────────────────────┘
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         ▼                                                       ▼
┌─────────────────────────────────┐             ┌─────────────────────────────────┐
│     Phase 1: Native Reader      │             │    Phase 2: Backend Gateway     │
│   (SwiftUI / iOS 17+ Engine)    │             │   (FastAPI Ingestion Engine)    │
│  - Right-to-Left (RTL) Paging   │             │  - Server-Side Manga Proxy      │
│  - Configurable 3-Zone Taps     │             │  - Pydantic DTO Contract Parity │
│  - Landscape Dual-Page Spreads  │             │  - In-Memory / File Response    │
│  - Cinema-Black Color Inversion │             │    Rate-Limit Cache             │
│  - Interactive Page Scrubber    │             │  - Resilient CDN Panel Failover │
└─────────────────────────────────┘             └─────────────────────────────────┘
                                     │
                                     ▼
                        ┌─────────────────────────┐
                        │   Phase 3: (Deferred)   │
                        │  Offline Download Queue │
                        │  - Background Session   │
                        │  - Storage Quota / Evict│
                        └─────────────────────────┘
```

---

## 3. Phase 1: Advanced Native Manga Reader Engine (Client-Side)

### 3.1 Objectives
Transform [`MangaReaderView.swift`](file:///Users/maclab/Documents/roosc/Fable-IOS/frontend/FableApp/Features/Reader/Views/MangaReaderView.swift) from a baseline two-mode viewer into an ergonomic reading engine matching commercial and open-source standards.

### 3.2 Reading Modes Specification
1. **Vertical Webtoon (`.webtoon`):**  
   Continuous vertical scroll with zero interstitial padding between sequential panels, hardware-accelerated lazy loading via `LazyVStack`.
2. **Left-to-Right Paging (`.pagedLTR`):**  
   Standard Western comic pagination using horizontal gestures (`TabView` with page styling).
3. **Right-to-Left Paging (`.pagedRTL`):**  
   Traditional Japanese tankōbon reading order. Swiping right-to-left advances to the next panel; tapping the left screen margin advances, while tapping the right margin navigates back.

### 3.3 Three-Zone Tap Navigation Model
To eliminate accidental menu toggling while reading:
* **Left Margin (0% - 30% width):** Previous page in LTR; Next page in RTL.
* **Center Region (30% - 70% width):** Toggle overlay chrome (navigation bar, scrubber, and settings).
* **Right Margin (70% - 100% width):** Next page in LTR; Previous page in RTL.

### 3.4 Responsive Dual-Page Spreads (iPad & Landscape)
* On iPad or horizontal iPhone orientations (`horizontalSizeClass == .regular`), calculate panel aspect ratio.
* When two consecutive portrait panels are detected, render them side-by-side as a unified spread, honoring manga reading order (Page 2 on left, Page 1 on right in RTL mode).

### 3.5 Reading Accessibility & Panel Shaders
* **Color Filter Shaders:** Inverted ink mode (black linework becomes white on deep OLED black for minimal eye fatigue in pitch-dark environments).
* **Interactive Bottom Scrubber:** Floating capsule slider displaying current page versus total pages (`Page X of Y`), with instant drag scrubbing and haptic feedback on page change.

---

## 4. Phase 2: Server-Driven Manga Ingestion Architecture (Backend-Side)

### 4.1 Objectives
Shield the iOS client from rate-limiting, scraping breakages, and App Store compliance issues by centralizing manga catalog discovery and chapter resolution inside the FastAPI backend.

### 4.2 Architectural Design & Contract-First Endpoints

```
┌────────────────────┐     REST / JSON     ┌────────────────────┐     HTTPS GET     ┌────────────────────┐
│   Fable iOS App    │ ◄─────────────────► │  FastAPI Backend   │ ◄───────────────► │ External Providers │
│ (URLSessionClient) │   /api/v1/manga/*   │  (Cache & Proxy)   │                   │ (MangaDex / Open)  │
└────────────────────┘                     └─────────┬──────────┘                   └────────────────────┘
                                                     │
                                                     ▼
                                           ┌────────────────────┐
                                           │   SQLite / Redis   │
                                           │  Manifest Storage  │
                                           └────────────────────┘
```

1. **`GET /api/v1/manga/search?q={query}&page={page}`**  
   Searches upstream manga aggregators, standardizing external responses into Fable's unified `Story` schema.
2. **`GET /api/v1/manga/{mangaId}/chapters`**  
   Returns sorted chapter list with translation group metadata, chapter index numbers, and publication dates.
3. **`GET /api/v1/manga/chapter/{chapterId}/pages`**  
   Resolves high-resolution panel image URLs from upstream CDN nodes with server-side caching to prevent HTTP 429 (Too Many Requests).

### 4.3 App Store Compliance & Security
* **Guideline 2.5.2 Compliance:** Eliminates any client-side dynamic JavaScript/Kotlin evaluation engines. All external schema mapping occurs securely on the server.
* **Rate-Limit Throttling & Caching:** Upstream providers (such as MangaDex) enforce strict 5 req/s limits. The backend caches chapter manifests in SQLite/memory with a 6-hour TTL, cutting external egress by >85%.

---

## 5. Phase 3: Offline Chapter Download Queue & Disk Management (Deferred)

*Status: Postponed by developer directive to follow Phase 1 and Phase 2.*

### Future Technical Requirements:
* Background asset downloading leveraging iOS `URLSessionConfiguration.background(withIdentifier:)`.
* Persistent download job queue indexed in SQLite/SwiftData.
* Storage management UI in [`SettingsView.swift`](file:///Users/maclab/Documents/roosc/Fable-IOS/frontend/FableApp/Features/Shelf/Views/SettingsView.swift) displaying total downloaded manga storage (MB/GB) with selective chapter deletion and automated cache eviction policies.

---

## 6. Execution Order & Verification Gates

```text
[Step 1: Document Architecture Blueprint & Update Progress Log]
                               |
                               ▼
[Step 2: Phase 1 - Enhance MangaReaderView with RTL, Tap Zones & Scrubber]
                               |
                               ▼
[Step 3: Phase 1 Verification - Xcode Simulator Build & Reader Unit Tests]
                               |
                               ▼
[Step 4: Phase 2 - Implement FastAPI Manga Ingestion Router & Pydantic DTOs]
                               |
                               ▼
[Step 5: Phase 2 Verification - Pytest Automated Test Suite & Live Contract Test]
```

Every step follows the **6-stage lifecycle**:
1. Concept & Rationale
2. Pause & Confirm
3. Apply Code Changes
4. Run Verification (Xcode / Pytest)
5. Concise Conventional Git Commit & Manifest Output
6. Update Progress Log
