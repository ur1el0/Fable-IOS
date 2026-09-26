# Fable Final Milestone: Master Progress & Feature Audit Log

**Course:** ITWM101 (Integrative Programming & Technologies 2)  
**Developer:** Roosc Zaño  
**Role:** Lead Systems Engineer & Solutions Architect  
**Active Feature Branch:** `feature/production-hardening`

---

## Executive Summary & System Objectives

The Final Milestone transforms **Fable** from an editorial prototype into a fully production-grade, end-to-end integrated micro-fiction reading platform. All cosmetic dummy actions, hardcoded placeholders, and static assumptions are systematically replaced with live contracts, multi-tenant persistence, resilient media pipelines, and accessible audio engines.

### The 8 Core Architectural Domains

| Domain | Document Reference | Status | Scope Description |
| :--- | :--- | :--- | :--- |
| **1. Backend Security, Data Isolation & Auth** | [`01_BACKEND_SECURITY_AND_DATA.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/01_BACKEND_SECURITY_AND_DATA.md) | **Complete** | Multi-tenant compound keys, UTC datetime normalization, PBKDF2 authentication, Swift-parity JSON serialization aliases. |
| **2. Live Media & Content Pipelines** | [`02_LIVE_MEDIA_AND_CONTENT.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/02_LIVE_MEDIA_AND_CONTENT.md) | **Complete** | Async remote image loading for covers and author avatars, Gutendex live ingestion, resilient vector fallbacks, persistent device identity. |
| **3. Reader Pacing & Word Tokenization** | [`03_READER_PACING_AND_WORD_TOKENIZATION.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/03_READER_PACING_AND_WORD_TOKENIZATION.md) | **Complete** | Zoom-invariant word counting, multi-whitespace tokenization, dynamic page chunking responsive to font scale. |
| **4. UI Interactions & Voice Accessibility** | [`04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md) | **Complete** | 100% interactive button bindings, `AVSpeechSynthesizer` voice selector sheet, active chapter narration state machine. |
| **5. Live Metadata & Pure User-State Isolation** | [`03_LIVE_METADATA_AND_USER_STATE_PURGING.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/03_LIVE_METADATA_AND_USER_STATE_PURGING.md) | **Complete** | Elimination of artificial seed bookmarks & stat floors; live official author portraits, high-res genre banners, Gutenberg covers, and authentic empty states. |
| **6. Multi-Format & Manga Architecture** | [`05_MULTI_FORMAT_AND_MANGA_ARCHITECTURE.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/05_MULTI_FORMAT_AND_MANGA_ARCHITECTURE.md) | **Complete** | Polymorphic reader dispatch, continuous vertical Webtoon scroll, horizontal swipe paging, manga panel ingestion pipeline. |
| **7. Testing Suites & ADR Baseline** | [`04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md) | **Complete** | 22/22 pytest automated backend suite, Swift unit tests, ADR documentation, and academic lab reproducibility. |
| **8. App Health Diagnostics & Anti-Overlap Invariants** | [`MASTER_PROGRESS_LOG.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/MASTER_PROGRESS_LOG.md) | **Complete** | Image boundary clipping guarantees, on-device `SystemDiagnosticsSheet`, and `AppHealthTests` automated verification contract. |

---

## Master Feature & Button Audit Matrix

| Feature / UI Component | Original State (Midterm) | Final Milestone Target | Status | Implementation File(s) |
| :--- | :--- | :--- | :--- | :--- |
| **Shelf Sync API** | Single-tenant overwrite (`story_id` PK) | Multi-tenant isolation `(device_id, story_id)` with UTC normalization | **Complete** | `backend/services/shelf_sync.py`, `backend/core/database.py` |
| **User Authentication** | Hardcoded profile data | PBKDF2 hash, JWT/Bearer token, register & login endpoints | **Complete** | `backend/services/auth_service.py`, `backend/api/v1/endpoints/auth.py` |
| **Device ID Persistence** | Ephemeral `UUID()` regenerated every sync | Hardware/vendor-backed `UserDefaults` UUID (`fable_device_id`) | **Complete** | `Features/Library/ViewModels/StoryStore.swift` |
| **Story Covers & Avatars** | Local asset catalogs only (`cover_dracula`) | Live URL fetch via `AsyncImage` with procedural fallback + offline asset catalog | **Complete** | `Features/Library/Models/Story.swift`, `Features/Library/Views/ExploreView.swift`, `Features/Shelf/Views/ProfileView.swift`, `Features/Reader/Views/ReaderView.swift` |
| **Frontend Topology** | Flat technical layering (`Views/`, `ViewModels/`) | Feature-driven vertical slices (`App/`, `Core/`, `Features/{Auth,Library,Reader,Shelf,Write}`) | **Complete** | `frontend/FableApp/Features/`, `frontend/FableApp/Core/`, `frontend/FableApp/App/` |
| **Word Count Accuracy** | `split(separator: " ")` (fails on tabs/newlines) | Regex/tokenized whitespace counter invariant to zoom level | **Complete** | `Features/Reader/Services/PacingEngine.swift`, `Features/Reader/Views/ReaderView.swift` |
| **Reader Zoom / Font Size** | Initial render only, inconsistent pagination | Dynamic pagination recalculated upon pinch/slider change | **Complete** | `Features/Reader/Views/ReaderView.swift`, `Features/Reader/Views/DisplayOptionsSheet.swift` |
| **Audio Voice Selector** | Hardcoded `en-US` default voice | Dynamic system voice picker querying available speech engines | **Complete** | `Features/Reader/Services/AudioNarratorController.swift`, `VoiceSelectionSheet.swift` |
| **Audio Narrator Target** | Always read Chapter 1 | Narration dynamically bound to active displayed chapter | **Complete** | `Features/Reader/Services/AudioNarratorController.swift`, `Features/Reader/Views/ReaderView.swift` |
| **Shelf Remove Button** | Visual only or local array remove | Synchronized removal / bookmark toggle synced to backend | **Complete** | `Features/Shelf/Views/ShelfView.swift`, `Features/Library/ViewModels/StoryStore.swift` |
| **Profile Stats & Edit** | Dummy text | Live stats calculated from SwiftData/backend shelf items | **Complete** | `Features/Shelf/Views/ProfileView.swift`, `Features/Auth/ViewModels/AuthViewModel.swift` |

---

## Step-by-Step Milestone Roadmap

- [x] **Milestone 1: Backend Security, Isolation & Authentication Contract**
  - [x] Step 1.1: Database schema upgrade (multi-tenant `shelf_items`, indexed `users` table).
  - [x] Step 1.2: Pydantic v2 DTO contract parity with camelCase Swift serialization aliases.
  - [x] Step 1.3: Update `shelf_sync.py` to enforce `device_id` isolation and timezone-aware comparison.
  - [x] Step 1.4: Add `GET /shelf` endpoint in `shelf.py` with device filtering.
  - [x] Step 1.5: Implement `auth_service.py` and `api/v1/endpoints/auth.py` (register, login, me).
  - [x] Step 1.6: Execute automated test suite (`pytest`) and commit atomically.
- [x] **Milestone 2: Live Content, Remote Media & Vertical Slice Architecture**
  - [x] Step 2.1: Implement remote image loading and cached rendering in SwiftUI (`effectiveCoverImage`, `effectiveAvatar`, `effectiveImage`).
  - [x] Step 2.2: Establish persistent device identifier (`fable_device_id`) in `UserDefaults`.
  - [x] Step 2.3: Upgrade `StoryAPIService` with dual camelCase/snake_case decoding and auth endpoints.
  - [x] Step 2.4: Eliminate raw `coverImageName` calls across `ExploreView`, `ProfileView`, `LibraryView`, and `ReaderView`.
  - [x] Step 2.5: Realign frontend into feature-driven vertical slices (`App`, `Core`, `Features/{Auth,Library,Reader,Shelf,Write}`) and integrate authentic asset catalog from `main`.
- [x] **Milestone 3: Reader Pacing, Tokenization & Zoom Invariance**
  - [x] Step 3.1: Zoom-invariant word tokenization in `PacingEngine.swift`.
  - [x] Step 3.2: Dynamic page recalculation on font size changes in `ReaderView.swift`.
  - [x] Step 3.3: Unit test suite for pacing engine calculations.
- [x] **Milestone 4: Interactive UI Bindings & Audio Narration**
  - [x] Step 4.1: System voice picker for `AVSpeechSynthesizer`.
  - [x] Step 4.2: Dynamic chapter narration binding in `AudioNarratorController`.
  - [x] Step 4.3: Full interactive button pass across all views.
- [x] **Milestone 5: Live Metadata & Pure User-State Isolation** (See [`03_LIVE_METADATA_AND_USER_STATE_PURGING.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/03_LIVE_METADATA_AND_USER_STATE_PURGING.md))
  - [x] Step 5.1: Backend live metadata enrichment (`avatar_image_url`, `image_url`, and Maria Makiling cover URL in `story_service.py` & `seed_catalog.py`).
  - [x] Step 5.2: Domain & Persistence zero-baseline calibration (`isSaved = false`, `progressPercent = 0` in `Story.swift`; removal of `max(12, ...)` stat floors in `PersistenceService.swift`).
  - [x] Step 5.3: Frontend Shelf & Profile empty state views (removal of `prefix(3)` and `prefix(2)` fallbacks; branded empty state cards).
  - [x] Step 5.4: LibraryView "Continue Reading" fallback purge (only show card when an actual tale is in progress).
  - [x] Step 5.5: Multi-user session reset and device ID isolation (`AuthViewModel.shared.logout()`, `clearUserStateOnSignOut()`).
  - [x] Step 5.6: Verification pass (21/21 pytest pass, clean test DB isolation).

- [x] **Milestone 6: Multi-Format Content Architecture & Modern Identity Pivot**
  - [x] Step 6.1: Backend schema evolution (`content_format`, `source_provider`, `page_urls`) with automated SQLite migration and seed catalog enrichment (`Manga` + `Standard Ebooks`).
  - [x] Step 6.2: Swift domain models parity (`ContentFormat`, `SourceProvider`, `Genre.manga`, `Chapter.pageUrls` with safe Decodable fallbacks).
  - [x] Step 6.3: Visual identity modernization (`FableTheme` Electric Indigo palette, clean sans-serif typography, removal of antique book styling).
  - [x] Step 6.4: Polymorphic reader routing and `MangaReaderView` engine (Webtoon continuous vertical scroll, horizontal page-flipping, pinch-to-zoom).
  - [x] Step 6.5: End-to-end view modernization pass across `ExploreView`, `GenreDetailView`, `WriteView`, `StoryPublishedSheet`, `ProfileView`, `WelcomeView`, `SignInView`, `SignUpView`, and `ContentView`.
  - [x] Step 6.6: Backend provider parity in `gutenberg.py` and automated test verification (21/21 pytest passing).

- [x] **Milestone 7: Architectural Verification, Testing Suite & ADR Documentation**
  - [x] Step 7.1: Multi-format Swift unit tests in `LibraryTests.swift` (legacy payload fallback decoding, manga and source provider decoding, chapter `pageUrls` array extraction, catalog diversity).
  - [x] Step 7.2: Reader engine tests in `ReaderTests.swift` (`MangaReadingMode` icons, panel resolution hierarchy, reader format dispatch, font/theme invariants).
  - [x] Step 7.3: Architectural documentation and ADR for UI interactions and audio accessibility (`04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md`).
  - [x] Step 7.4: Architectural documentation and ADR for multi-format content and manga architecture (`05_MULTI_FORMAT_AND_MANGA_ARCHITECTURE.md`).
  - [x] Step 7.5: Academic Mac lab runbook updated with Final Capstone Grading Demo Path (`MAC_LAB_RUNBOOK.md`).

- [x] **Milestone 8: App Health Diagnostics, Anti-Overlap Invariants & On-Device Verification**
  - [x] Step 8.1: Strict boundary clipping enforcement in `FableImageView.swift` across all image phases and root container.
  - [x] Step 8.2: Creation of `AppHealthTests.swift` validating chapter updates, feed ingestion, live genres, top creators, accurate living analytics, and media bounding invariants.
  - [x] Step 8.3: Interactive `SystemDiagnosticsSheet.swift` and Settings trigger for on-device and simulator verification.
  - [x] Step 8.4: Integration of `AppHealthTests` into `LibraryTests.swift` (Test 9).
  - [x] Step 8.5: Backend test suite expansion in `test_main.py` verifying live contracts and image URLs (22/22 pytest passing).

## Production Hardening Enhancements (2026-09-26)

- [x] Added a multi-stage Python 3.11 backend image that installs runtime dependencies, runs as the non-root `fableuser`, and checks `/api/v1/health`.
- [x] Added Docker Compose configuration with a persistent SQLite bind mount and environment-file loading.
- [x] Added GitHub Actions backend-test and Docker-build verification jobs.
- [x] Removed duplicate Figma configuration from `.env.example` and documented runtime and Docker ownership settings.
- [x] Added `test_env_db_path_override` to verify the database path can be overridden through `FABLE_DB_PATH`.

## Offline Manga Panel Cache (2026-09-26)

- [x] Added an actor-isolated SHA-256 disk cache with an in-memory image cache, compressed image storage, and bounded asynchronous URL prefetching.
- [x] Manga reader prefetches the active and next chapter; remote images render from cache first with network and procedural fallbacks clipped to their view bounds.
- Device diagnostics were not run in this Fedora workspace because `xcodebuild`, `xcrun`, and the Swift compiler are unavailable.

## Chapter Progress & Haptic Feedback (2026-09-26)

- [x] Added optional chapter ID and chapter number fields to Story with legacy Codable fallback.
- [x] Persisted the chapter cursor in optional SwiftData fields and hydrated it into local story state.
- [x] Prose and manga readers restore by chapter ID, then chapter number, and save chapter changes locally.
- [x] Added a main-actor haptic manager and wired bookmark, publish, reading-mode, and chapter-navigation feedback to the existing haptics preference.
- [x] Extended LibraryTests with legacy fallback and saved chapter decoding assertions.
- The iOS test suite and on-device diagnostics were not run in this Fedora workspace because swiftc, xcodebuild, and xcrun are unavailable.

## Official Live Cover Precedence (2026-09-26)

- [x] Live story responses now reconcile with offline catalog entries by ID or normalized title and author, then persist fetched HTTPS cover URLs in SwiftData for cached offline display.
- [x] Reader and library covers prefer the fetched cover URL; image views remain clipped and retain bundled or procedural offline fallbacks.
- [x] Legacy Unsplash demo covers and manga panels are filtered from existing backend rows and cached client state; a story cover is no longer used as a manga panel.
- [x] Removed the duplicate Sleepy Hollow image asset and removed demo image URLs from default genre, author, and manga fixtures.
- [x] Backend suite passed: 24 tests. iOS compilation and on-device diagnostics remain unavailable in this Fedora workspace because Xcode and the Swift compiler are not installed.

## Live Gutenberg Chapter Retrieval (2026-09-26)

- [x] Added optional providerId to the Story API contract for live catalog entries.
- [x] Added an on-demand chapter endpoint that fetches and parses the original Project Gutenberg text with stable chapter identifiers.
- [x] Fixed chapter parsing when a chapter heading immediately follows the Gutenberg start marker.
- [x] Backend Docker build and test suite passed: 25 tests.
- [ ] iOS provider routing and offline chapter persistence remain in the next implementation slice.

## iOS Live Book Chapters and Offline Persistence (2026-09-26)

- [x] Swift Story decodes and stores the live provider identifier with backward-compatible optional decoding.
- [x] Gutenberg chapter requests use the provider-specific endpoint; cached chapters are returned before network requests.
- [x] Chapter content and provider metadata persist in optional SwiftData fields, with chapter data stored externally to the primary SQLite row.
- [x] Added internal diagnostics for provider ID decoding and chapter serialization round trips.
- [x] Source diff passed whitespace validation.
- The Swift diagnostics and iOS build could not run in this Fedora workspace because Swift and Xcode are unavailable.

## Backend Live Catalog and Source-Backed Metrics (2026-09-26)

- [x] Removed the embedded backend seed catalog; fresh databases now start empty and remain empty across restarts until content is fetched or authored.
- [x] Gutenberg discovery returns provider metadata, official provider covers, provider download counts, and no synopsis-as-content or fabricated rating.
- [x] Gutenberg ingestion uses provider metadata and stable book/chapter identifiers; re-ingestion updates matching rows by stable ID.
- [x] Genre title and reader totals come from story and shelf records; author work counts and portraits come from Open Library; unavailable ratings remain null.
- [x] Update feeds no longer promote arbitrary stories as editorial picks, user DTOs no longer default to a bundled avatar, and API story DTOs omit local asset names.
- [x] Swift models accept missing ratings, persist provider download counts, and avoid showing a fake rating in explore cards.
- [x] Backend container build and test suite passed: 28 tests.
- Existing databases may still contain the 12 old demo story rows. They have not been deleted or modified; automatic review rejected destructive cleanup, and explicit approval for removing only those rows is pending.
- The Swift build and diagnostics remain unrun because this Fedora workspace has no Swift/Xcode toolchain.

## Provider-Backed iOS Catalog (2026-09-26)

- [x] Removed bundled story, genre, author, guest-profile, quote, and sample-stat defaults; fresh installs load live provider data and preserve only the SwiftData cache for offline reading.
- [x] Discovery genre and author payloads are cached locally after a successful fetch so they remain available offline.
- [x] Removed content-specific image sets and title/author keyed artwork; cover and profile images now render HTTPS provider images or neutral SF Symbol placeholders, with clipped bounds.
- [x] Library genre filters follow server metadata and empty catalog/discovery states are explicit and retryable.
- [x] Removed fabricated default profile names, biographies, handles, and verification badges.
- [ ] Legacy records already stored on backend instances are unchanged pending the requested approval for removing the 12 old demo rows.
- Source diff passed whitespace checks. iOS compilation and on-device diagnostics remain unavailable here because Swift and Xcode are not installed.

## Preserve Live Genre Contract (2026-09-26)

- [x] Replaced the closed genre enum decoder with a raw-value Codable model so server-supplied genres remain intact.
- [x] Missing legacy genre values remain unspecified instead of becoming a fabricated category.
- [x] Explore filtering and authoring suggestions use live genre metadata; authors may enter a genre when offline metadata is unavailable.
- Added diagnostic assertions for arbitrary genre decoding. Swift/Xcode compilation remains unavailable in this environment.

## Server-Backed User Profiles (2026-09-26)

- [x] Added additive SQLite handle and biography columns for existing user databases.
- [x] Registration persists the submitted handle; authenticated `PATCH /auth/me` updates name, handle, and biography and returns the canonical profile.
- [x] Added positive profile update and unauthenticated rejection coverage.
- [x] Docker backend suite passed: 29 tests.

## Authenticated Story Publishing and Ownership (2026-09-26)

- [x] Story creation now requires a bearer session and assigns the author and owner from the authenticated account.
- [x] Creation payloads reject extra fields so callers cannot submit server-owned authorship or provider identity.
- [x] Added an authenticated `/auth/me/stories` endpoint with database-level owner filtering.
- [x] Added tests for unauthenticated rejection, spoofed author rejection, and account-isolated published-story listings.
- [x] Docker backend suite passed: 31 tests.


## Account-Scoped Shelf Synchronization (2026-09-26)

- [x] Added account-owned shelf records keyed by user, device, and story while preserving legacy rows without exposing them through authenticated endpoints.
- [x] Required bearer authentication for shelf reads and writes and scoped every query to the authenticated user.
- [x] Public save, reader, and genre-reader totals now count authenticated accounts rather than caller-controlled device identifiers.
- [x] Added API coverage for unauthenticated rejection and same-device cross-account isolation.
- [x] Docker backend suite passed: 32 tests.
- [ ] iOS shelf requests are being updated to send the active server token; this environment cannot compile Swift because the Swift/Xcode toolchain is unavailable.


## Authenticated Reading Statistics and Shelf Privacy (2026-09-26)

- [x] Added an idempotent authenticated reading-session endpoint and per-account statistics endpoint.
- [x] Backend totals count completed works, logged minutes, and consecutive UTC reading days from persisted session events.
- [x] Shelf reads/writes and public save/read aggregates are isolated by authenticated account; public story DTOs no longer expose record-level bookmark/completion flags.
- [x] Added coverage for session de-duplication, account isolation, unauthenticated rejection, and DTO privacy.
- [x] Docker backend suite passed: 33 tests.
- [x] iOS now queues offline reading events per account, fetches the live totals, and scopes offline logs and shelf snapshots to each account.
- [x] Writer toolbar actions apply formatting to selected manuscript text and have an on-device interaction diagnostic.
- The iOS diagnostic and simulator/device build remain unrun in this Fedora workspace because Swift and Xcode are unavailable.
