# Fable Final Milestone: Master Progress & Feature Audit Log

**Course:** ITWM101 (Integrative Programming & Technologies 2)  
**Developer:** Roosc Zaño  
**Role:** Lead Systems Engineer & Solutions Architect  
**Active Feature Branch:** `feature/live-data-and-button-wiring`

---

## Executive Summary & System Objectives

This progress log tracks the transition of **Fable** from an editorial prototype to a provider-backed, offline-first reading platform. The backend has 36 passing container tests covering content contracts, account isolation, live statistics, and persistent sessions. The iOS changes are implemented but cannot be compiled or run in this Fedora workspace because Swift and Xcode are unavailable. An approved startup migration removes the twelve exact legacy demo story IDs and their chapters from existing SQLite databases on the next backend start.

### The 8 Core Architectural Domains

| Domain | Document Reference | Status | Scope Description |
| :--- | :--- | :--- | :--- |
| **1. Backend Security, Data Isolation & Auth** | [`01_BACKEND_SECURITY_AND_DATA.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/01_BACKEND_SECURITY_AND_DATA.md) | **Complete** | Account/device/story shelf isolation, expiring persisted bearer sessions, PBKDF2 authentication, reading-event statistics, and camelCase response aliases. |
| **2. Live Media & Content Pipelines** | [`02_LIVE_MEDIA_AND_CONTENT.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/02_LIVE_MEDIA_AND_CONTENT.md) | **Complete** | Provider cover URLs, on-demand Gutenberg chapters, clipped remote images, offline media cache, and per-account device identity. |
| **3. Reader Pacing & Word Tokenization** | [`03_READER_PACING_AND_WORD_TOKENIZATION.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/03_READER_PACING_AND_WORD_TOKENIZATION.md) | **Complete** | Zoom-invariant word counting, multi-whitespace tokenization, dynamic page chunking responsive to font scale. |
| **4. UI Interactions & Voice Accessibility** | [`04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md) | **Implemented; device check pending** | Actions are wired across writing, profile, library, reader, shelf, and settings; `AVSpeechSynthesizer` uses installed OS voices. |
| **5. Live Metadata & Pure User-State Isolation** | [`03_LIVE_METADATA_AND_USER_STATE_PURGING.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/03_LIVE_METADATA_AND_USER_STATE_PURGING.md) | **Startup cleanup migration committed** | Fresh installs have no bundled story catalog; provider and authored content uses live metadata and account-owned shelf/profile state. |
| **6. Multi-Format & Manga Architecture** | [`05_MULTI_FORMAT_AND_MANGA_ARCHITECTURE.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/05_MULTI_FORMAT_AND_MANGA_ARCHITECTURE.md) | **Complete** | Polymorphic reader dispatch, continuous vertical Webtoon scroll, horizontal swipe paging, manga panel ingestion pipeline. |
| **7. Testing Suites & ADR Baseline** | [`04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md) | **Backend verified; iOS run pending** | 36/36 backend tests pass in Docker. Swift build, Swift tests, and device diagnostics require Xcode and remain unrun here. |
| **8. App Health Diagnostics & Anti-Overlap Invariants** | [`MASTER_PROGRESS_LOG.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/MASTER_PROGRESS_LOG.md) | **Implemented; device check pending** | Image boundary clipping, `SystemDiagnosticsSheet`, and `AppHealthTests` are in source; execution requires Xcode. |

---

## Master Feature & Button Audit Matrix

| Feature / UI Component | Original State (Midterm) | Final Milestone Target | Status | Implementation File(s) |
| :--- | :--- | :--- | :--- | :--- |
| **Shelf Sync API** | Unauthenticated device-only records | Bearer-authenticated isolation `(owner_user_id, device_id, story_id)` with UTC LWW | **Complete** | `backend/services/shelf_sync.py`, `backend/core/database.py` |
| **User Authentication** | Hardcoded profile data and process-local token lookup | PBKDF2 hashes, persisted hashed bearer sessions, 30-day expiry, logout revocation | **Complete** | `backend/services/auth_service.py`, `backend/api/v1/endpoints/auth.py` |
| **Device ID Persistence** | Shared device identifier across accounts | Per-account `UserDefaults` device UUID and offline shelf snapshot | **Complete** | `Features/Library/ViewModels/StoryStore.swift` |
| **Story Covers & Avatars** | Title-specific local art and duplicate demo images | Provider URLs, clipped remote rendering, neutral SF Symbol placeholders, URL-keyed offline image cache | **Complete** | `Features/Library/Models/Story.swift`, `Core/Components/FableImageView.swift`, `Core/Services/DiskImageCache.swift` |
| **Frontend Topology** | Flat technical layering (`Views/`, `ViewModels/`) | Feature-driven vertical slices (`App/`, `Core/`, `Features/{Auth,Library,Reader,Shelf,Write}`) | **Complete** | `frontend/FableApp/Features/`, `frontend/FableApp/Core/`, `frontend/FableApp/App/` |
| **Word Count Accuracy** | `split(separator: " ")` (fails on tabs/newlines) | Regex/tokenized whitespace counter invariant to zoom level | **Complete** | `Features/Reader/Services/PacingEngine.swift`, `Features/Reader/Views/ReaderView.swift` |
| **Reader Zoom / Font Size** | Initial render only, inconsistent pagination | Dynamic pagination recalculated upon pinch/slider change | **Complete** | `Features/Reader/Views/ReaderView.swift`, `Features/Reader/Views/DisplayOptionsSheet.swift` |
| **Audio Voice Selector** | Hardcoded `en-US` default voice | Dynamic system voice picker querying available speech engines | **Complete** | `Features/Reader/Services/AudioNarratorController.swift`, `VoiceSelectionSheet.swift` |
| **Audio Narrator Target** | Always read Chapter 1 | Narration dynamically bound to active displayed chapter | **Complete** | `Features/Reader/Services/AudioNarratorController.swift`, `Features/Reader/Views/ReaderView.swift` |
| **Shelf Remove Button** | Visual only or local array remove | Synchronized removal / bookmark toggle synced to backend | **Complete** | `Features/Shelf/Views/ShelfView.swift`, `Features/Library/ViewModels/StoryStore.swift` |
| **Profile Stats & Edit** | Device-wide totals and placeholder text | Account-scoped live completed, minutes, and streak statistics; profile updates sync with backend | **Complete** | `Features/Shelf/Views/ProfileView.swift`, `Features/Auth/ViewModels/AuthViewModel.swift` |

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
  - [x] Step 2.5: Realign frontend into feature-driven vertical slices and remove title-specific bundled artwork; the asset catalog retains only app icon and accent color.
- [x] **Milestone 3: Reader Pacing, Tokenization & Zoom Invariance**
  - [x] Step 3.1: Zoom-invariant word tokenization in `PacingEngine.swift`.
  - [x] Step 3.2: Dynamic page recalculation on font size changes in `ReaderView.swift`.
  - [x] Step 3.3: Unit test suite for pacing engine calculations.
- [x] **Milestone 4: Interactive UI Bindings & Audio Narration**
  - [x] Step 4.1: System voice picker for `AVSpeechSynthesizer`.
  - [x] Step 4.2: Dynamic chapter narration binding in `AudioNarratorController`.
  - [x] Step 4.3: Full interactive button pass across all views.
- [x] **Milestone 5: Live Metadata & Pure User-State Isolation** (See [`03_LIVE_METADATA_AND_USER_STATE_PURGING.md`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/docs/final_milestone/03_LIVE_METADATA_AND_USER_STATE_PURGING.md))
  - [x] Step 5.1: Backend metadata enrichment from live provider responses; the embedded catalog module was subsequently removed.
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
  - [x] Step 8.5: Backend test suite expansion for that milestone; the current expanded suite has 35 passing tests.

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
- The 12 retired catalog IDs and their chapter rows are removed by the approved startup cleanup migration; it does not match by title and preserves authored stories.
- The Swift build and diagnostics remain unrun because this Fedora workspace has no Swift/Xcode toolchain.

## Provider-Backed iOS Catalog (2026-09-26)

- [x] Removed bundled story, genre, author, guest-profile, quote, and sample-stat defaults; fresh installs load live provider data and preserve only the SwiftData cache for offline reading.
- [x] Discovery genre and author payloads are cached locally after a successful fetch so they remain available offline.
- [x] Removed content-specific image sets and title/author keyed artwork; cover and profile images now render HTTPS provider images or neutral SF Symbol placeholders, with clipped bounds.
- [x] Library genre filters follow server metadata and empty catalog/discovery states are explicit and retryable.
- [x] Removed fabricated default profile names, biographies, handles, and verification badges.
- [x] Existing SQLite databases remove only the 12 retired demo story UUIDs and their chapters during backend startup; no deployed database was reachable from this workspace.
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


## Persistent Bearer Sessions (2026-09-26)

- [x] Replaced process-local bearer lookup with SHA-256 token digests stored in SQLite, 30-day expiry, and expired-session cleanup.
- [x] Added authenticated logout revocation and connected iOS sign-out to the endpoint.
- [x] Added restart-state and revocation coverage.
- [x] Docker backend suite passed: 34 tests.


## Restoring Saved Gutenberg Titles Across Devices (2026-09-26)

- [x] Added a provider-ID metadata lookup so an authenticated shelf can resolve saved Gutenberg titles outside the first discovery page.
- [x] Shelf restore applies account-owned progress to the live provider story; chapters and covers continue loading from Gutenberg metadata and source text.
- [x] Added live metadata endpoint coverage. Docker backend suite passed: 35 tests at this historical checkpoint.
- iOS implementation still awaits an Xcode build and device diagnostics, unavailable in this Fedora workspace.


## Account Isolation and Interaction Audit (2026-09-26)

- [x] Local highlights and pinned quotes now carry an optional account owner and are filtered on read, update, and delete; switching accounts clears active annotations before loading that account's journal. Existing ownerless annotations remain available only to a signed-out local session.
- [x] Scanned SwiftUI button closures for empty application actions. The remaining empty Cancel closures are system alert/sheet dismiss actions; the visible feature controls dispatch to navigation, persistence, API, editor, reader, or settings operations.
- [x] `git diff --check` passes. Backend suite remains at 35 passing tests in Docker.
- [ ] iOS build, Swift tests, and on-device `AppHealthTests` remain unverified because this workspace has no Swift or Xcode toolchain.
- [x] Added an exact-UUID startup cleanup for those story/chapter rows; authored stories with similar names are preserved. The repo has no local persistent database, so existing deployed SQLite files will be cleaned on their next backend start.


## Approved Legacy Catalog Cleanup and Bounded Image Cache (2026-09-26)

- [x] Backend startup deletes chapters and stories only for the 12 UUIDs from the retired bundled demo catalog. The migration is transactional, repeat-safe, and title-independent; user-authored works and reading-session history are preserved.
- [x] Added regression coverage proving all twelve records and their chapters are removed while a user-authored work with a matching title remains. Docker suite passed: 36 tests.
- [x] Manga image disk cache now serializes file operations and evicts oldest files above 256 MiB; Settings still exposes cache usage and clear actions.
- The configured local database file is absent; cleanup for any existing hosted database takes effect on the next backend deployment/start.
- [x] iOS runtime validation completed on macOS with Xcode 26.6.


## Mac Lab iOS Build and Integrity Fixes (2026-10-15)

- [x] Restored `continueAsGuest()` on `AuthManager` to allow guest session generation in `AuthTests`.
- [x] Added explicit memberwise initializer to `LocalShelfState` in `StoryStore.swift` to resolve suppression of default initializer when custom initializers are present.
- [x] Aligned `Story` initializer parameter order in `StoryStore.swift`.
- [x] Scoped `liveBook` and `mangaStory` variables in `LibraryTests.swift` so multi-format and live provider contract assertions compile and pass cleanly.
- [x] Clean compilation verified via `xcodebuild -scheme FableApp -destination 'generic/platform=iOS Simulator'` with 0 errors.
- [x] Backend automated suite verified with 36/36 tests passing in isolated Python virtual environment.

## Live Media Resilience and Procedural Visual Fallback Engine (2026-10-15)

- [x] Restored and upgraded procedural multi-tier visual fallback engine in `FableImageView.swift` with semantic `title:` resolution.
- [x] Implemented dynamic monogram avatars with initials extraction and author-themed color palettes for Open Library creators (e.g. James Clear, Robert Greene, J.K. Rowling, Bram Stoker, Jane Austen).
- [x] Implemented foil-stamped, genre-coded book covers with iconography and embossing borders during network in-flight load and offline fallback states.
- [x] Configured zero-flicker remote image loading: placeholders render immediately with no blank gray boxes, cross-fading into live JPEGs as soon as `DiskImageCache` or `URLSession` completes download.
- [x] Configured custom `User-Agent` and 15.0s timeout in `DiskImageCache.swift` to prevent bot-detection throttles and CDN timeouts on Project Gutenberg and Open Library image servers.
- [x] Increased Gutenberg proxy timeout in `backend/services/gutenberg.py` from 8.0s to 15.0s to accommodate campus Wi-Fi network latency.
- [x] Implemented catalog-derived live genre synthesis in `StoryStore.swift` so that newly registered accounts immediately see categorized genres (Fiction, Classics, Gothic, Romance, Adventure, Horror) with accurate live counts even before any user-created stories are published to SQLite.
- [x] Upgraded `GenreDetailView.swift` with resilient multi-facet genre matching and semantic title passing.
- [x] Verified 100% clean Xcode compilation (`** BUILD SUCCEEDED **`) on iOS Simulator platform.
- [x] Verified full backend suite: 36/36 tests passing in `backend/test_main.py`.

## Unconstrained Global Book Search (2026-10-15)

- [x] Removed unintended `default="folklore"` parameter assignment in `backend/api/v1/endpoints/gutenberg.py`, switching topic query default to `None`.
- [x] Verified unconstrained global searches (e.g. *Sherlock Holmes*, *Dracula*, *Moby Dick*, *Frankenstein*) return live catalog records from Gutenberg gateway.
- [x] Maintained 100% test pass rate: 36/36 tests passing in `backend/test_main.py`.

## MangaDex Live Manga Search and Ingestion Gateway (2026-10-15)

- [x] Implemented `fetchMangaStories(search:)` in `StoryAPIService.swift` connecting to MangaDex public API for titles, cover art, and author credits.
- [x] Connected `fetchChapters` to MangaDex `@at-home` panel servers for `sourceProvider == "MANGADEX"`, streaming sequential high-resolution panel URLs to `MangaReaderView`.
- [x] Aggregated search pipeline in `StoryStore.swift` to query both Project Gutenberg (prose classics) and MangaDex (graphic novels/manga) simultaneously on user search queries.
- [x] Seeded initial catalog sync with top trending manga titles alongside public literature.
- [x] Clean compilation verified via Xcode (`** BUILD SUCCEEDED **`) on iOS Simulator target.
- [x] Backend test suite verified: 36/36 tests passing in `backend/test_main.py`.

## Tachiyomi Manga Architecture & Ingestion Strategy (2026-10-15)

- [x] Evaluated and rejected binary reverse engineering (REA) in favor of direct open-source pattern extraction from Tachiyomi's Apache 2.0 codebase.
- [x] Formulated comprehensive 3-phase architectural blueprint in `docs/final_milestone/06_TACHIYOMI_MANGA_READER_AND_INGESTION_ARCHITECTURE.md`.
- [x] Scoped active milestones: Phase 1 (SwiftUI advanced reader with RTL, tap zones, and page scrubbing) and Phase 2 (FastAPI server-side proxy and ingestion engine).
- [x] Scoped deferred milestone: Phase 3 (background offline download queue and disk quota management).

## MangaDex Licensed External Publisher Chapters & Tier-3 Reader Resilience (2026-10-15)

- [x] Identified MangaDex API distinction between community scanlations (`pages > 0`, `@at-home` CDN) and officially licensed simulpub releases (e.g., Square Enix *Manga UP*, Shueisha *MANGA Plus*, where `pages == 0` and `externalUrl` contains the reading link).
- [x] Enhanced `StoryAPIService.swift` to extract `externalUrl` into `Chapter.content` and avoid redundant, failing `@at-home` CDN requests for licensed titles.
- [x] Upgraded `MangaReaderView.swift` to present an interactive **Official Licensed Publisher Card** with cover art preview, publisher badge, and a direct `Link` button opening the official chapter on Manga UP/MangaPlus/Viz Media.
- [x] Enforced Tier-3 cover art preview fallback when direct panel images are absent, preventing dead-end blank reader screens.
- [x] Verified zero regressions: Xcode iOS build succeeded and backend pytest suite passed (36/36 tests green).

## Tachiyomi Manga Ingestion & Advanced Reader Engine Implementation (2026-10-15)

- [x] **Backend Manga Ingestion & Proxy Service (Phase 2):**
  - Implemented `backend/services/manga.py` featuring upstream MangaDex API querying, deterministic UUID5 generation (`MANGA_NAMESPACE`), and in-memory TTL caching (10-minute cache window) to protect against upstream 5 req/s rate limits.
  - Implemented `backend/api/v1/endpoints/manga.py` providing endpoints: `GET /api/v1/public/manga`, `GET /api/v1/public/manga/{manga_id}`, `GET /api/v1/public/manga/{manga_id}/chapters`, and `POST /api/v1/stories/ingest/manga/{manga_id}`.
  - Registered manga router in `backend/api/v1/api.py` and exported through `backend/services/__init__.py`.
  - Added full test coverage in `backend/test_main.py` verifying search, metadata resolution, CDN panel extraction, and SQLite library ingestion (**39/39 tests passing**).
- [x] **Client-Side Routing through Backend Proxy:**
  - Upgraded `StoryAPIService.swift` (`fetchMangaStories` and `fetchMangaChapters`) to route through Fable's FastAPI proxy cache first, with automatic fallback to direct upstream calls if the backend is unreachable.
- [x] **Advanced Native Manga Reader Engine (Phase 1):**
  - Added traditional Japanese Right-to-Left reading mode (`.rightToLeft = "Manga (RTL)"`) to `MangaReadingMode` with native `.environment(\.layoutDirection)` swipe handling.
  - Implemented Tachiyomi-style **3-Zone Tap Navigation**: Left 30% advances/backtracks by mode, Center 40% toggles chrome overlay, Right 30% advances/backtracks by mode, complete with haptic feedback.
  - Implemented interactive bottom **Page Scrubber Slider** with live `Page X of Y` position reporting and smooth drag seeking.
  - Implemented night reading **Ink Inversion Filter** (`isInvertedColor` with `.applyColorInvert()`) for high-contrast OLED reading.
  - Upgraded top navigation chrome with a reading mode selection Menu and ink inversion toggle button.
  - Expanded `ReaderTests.swift` verifying `.rightToLeft` enum, icon bindings, and case completeness.
  - Verified 100% clean compilation via `xcodebuild` (`** BUILD SUCCEEDED **`) on iOS Simulator.

## Stale Chapter Cache Invalidation Guard & TLS 1.3 Upstream Resilience (2026-10-15)

- [x] **Backend TLS 1.3 Upstream Handshake Resilience:**
  - Resolved Python 3.9's macOS system `LibreSSL 2.8.3` handshake incompatibility with Cloudflare on `api.mangadex.org` (`tlsv1 alert protocol version`).
  - Implemented `_fetch_json_with_fallback` in `backend/services/manga.py`, automatically routing requests through macOS native `/usr/bin/curl` with full TLS 1.3 support whenever LibreSSL fails.
  - Relaxed `ChapterDTO` schema validation in `backend/schemas/schemas.py` to allow `chapter_number >= 0` to accommodate prologue and extra chapters.
- [x] **Client-Side Stale Cache Invalidation Guards:**
  - Added cache usability validation in `StoryStore.swift` (`fetchChapters`) and `MangaReaderView.swift` (`loadMangaChapters`).
  - Stale cached chapter sets containing zero image panels and no external links are now automatically bypassed and re-fetched live from the backend proxy.
  - Upgraded `externalChapterURL` in `MangaReaderView.swift` to search all available chapters for external licensed links if `currentChapter` is unset.
  - Verified 100% clean compilation via `xcodebuild` (`** BUILD SUCCEEDED **`) and backend test suite green (39/39 passing).

## Direct Manga CDN Panel Resolution & Chapter Deduplication (2026-10-15)

- [x] **Direct Panel Resolution Filtering (`includeExternalUrl=0`):**
  - Updated `backend/services/manga.py` and `frontend/FableApp/Features/Library/Services/StoryAPIService.swift` to include `includeExternalUrl=0` in MangaDex chapter feed queries.
  - Eliminated 0-page official publisher redirects (VIZ Media, MANGA Plus) from intercepting chapter slots when direct community scanlation panels exist.
  - Added resilient fallback: if a title exclusively possesses official publisher links and zero scanlations, queries fall back dynamically to preserve external links.
- [x] **Smart Chapter Deduplication:**
  - Implemented chapter candidate grouping by `chapter_number`.
  - When multiple translation groups upload releases for the same chapter, the engine selects the candidate with the highest page count (`pages > 0`) and discards duplicate/empty placeholders.
  - Avoids redundant upstream requests to `@at-home` CDN servers for duplicate releases.
- [x] **Fixed Prose ReaderView Compilation:**
  - Implemented missing `turnPageBack()` and `turnPageForward()` helper methods in `ReaderView.swift` for the 3-zone tap overlay.
- [x] **Verification & Live Validation:**
  - Live query verified for *Chainsaw Man* (`/api/v1/public/manga/a77742b1-befd-49a4-bff5-1ad4e6b0ef7b/chapters`): Chapter 1 resolved with **53 direct panels**, Chapter 2 with **26 panels**, Chapter 3 with **24 panels**.
  - Backend pytest test suite passed (39/39 tests green).
  - Xcode compilation verified (`** BUILD SUCCEEDED **`) on iPhone 17 Simulator.

## Prose Book Reader Ergonomics Alignment & Precision Scrubber (2026-10-15)

- [x] **Unified Reading Ergonomics Across Prose & Graphic Media:**
  - Brought Tachiyomi and Kindle e-reader interaction patterns to standard literature and prose books in `ReaderView.swift`.
  - Implemented `@State private var isChromeVisible: Bool = true` toggling top navigation bar and bottom floating HUD pill with matched `.move` and `.opacity` transitions for distraction-free reading.
- [x] **3-Zone Tap Navigation Overlay:**
  - Layered over paginated manuscript view: Left 30% triggers `turnPageBack()`, Center 40% toggles chrome visibility with selection haptics, Right 30% triggers `turnPageForward()`.
- [x] **Interactive Page Scrubber Slider:**
  - Added precision seeking slider to the floating HUD in paginated mode with monospaced page counts (`\(currentPage)` / `\(totalPages)`), smooth drag binding, haptic feedback on page change, and immediate progress persistence to `StoryStore`.
- [x] **Atomic Inter-Chapter Navigation:**
  - Upgraded `turnPageForward()`, `turnPageBack()`, `selectChapter()`, and `loadCurrentChapterPages()` with `startAtLastPage` support.
  - Page turns at chapter boundaries seamlessly advance to the next chapter's first page or reverse to the previous chapter's final page with haptic notifications and live pacing recalculation.
- [x] **Verification & Integrity:**
  - Swift compilation verified via `xcodebuild` on iOS Simulator (`** BUILD SUCCEEDED **`).
  - Backend pytest suite verified: 39/39 tests green.

## Manga Direct CDN Panel Resolution & Live Simulator Verification (2026-10-15)

- [x] **Root Cause Diagnosis (Guided Debugging):**
  - Diagnosed why *Chainsaw Man* was still rendering the VIZ Media redirection card on the booted iOS Simulator:
    1. SwiftData and memory cache guard (`isUsable`) previously accepted external URL strings (`content.starts(with: "http")`) as "usable chapters", locking the reader into the stale VIZ Media metadata without requesting live panels.
    2. The running simulator had not yet re-installed and executed the updated build.
- [x] **Strict Manga Panel Validation:**
  - Updated `isUsable` in `StoryStore.swift` (`syncWithPersistence` and `fetchChapters`) and `MangaReaderView.swift` (`loadMangaChapters`) to enforce `!$0.pageUrls.isEmpty` when `contentFormat == .manga`.
  - Stale 0-page chapters are rejected, forcing the app to fetch authentic panels from the backend proxy.
- [x] **Backend Manga Ingestion:**
  - Ingested *Chainsaw Man* (`a77742b1-befd-49a4-bff5-1ad4e6b0ef7b`) into `backend/fable.sqlite3` with 20 chapters and 70KB of CDN page URLs.
- [x] **Live Simulator Navigation Verification:**
  - Deployed updated build to booted iOS Simulator (iPhone 17 Pro) via `xcrun simctl install booted`.
  - Launched app and navigated directly to *Chainsaw Man*.
  - Verified live rendered screen via screenshot: **53 high-resolution manga panels rendered smoothly** under Webtoon vertical scroll and horizontal paging, with the interactive bottom scrubber reporting `WEBTOON • PAGE 1 OF 53`. Zero redirection cards remain.


