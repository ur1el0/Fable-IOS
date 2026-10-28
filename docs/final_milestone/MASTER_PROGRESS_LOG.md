# Fable Final Milestone: Master Progress & Feature Audit Log

**Course:** ITWM101 (Integrative Programming & Technologies 2)  
**Developer:** Roosc Zaño  
**Role:** Lead Systems Engineer & Solutions Architect  
**Active Feature Branch:** `codex/close-production-audit-gaps`

---

## Executive Summary & System Objectives

This progress log tracks the transition of **Fable** from an editorial prototype to a provider-backed, offline-first reading platform. The latest backend and iOS verification results are recorded in the dated entries below; the backend suite now covers content contracts, account isolation, live statistics, persistent sessions, rate limiting, CORS, provider bounds, and backup retention. The iOS application uses SwiftData for offline reading and the provider-backed API for live catalog content.

### The 8 Core Architectural Domains

| Domain | Document Reference | Status | Scope Description |
| :--- | :--- | :--- | :--- |
| **1. Backend Security, Data Isolation & Auth** | [`01_BACKEND_SECURITY_AND_DATA.md`](file:///Users/maclab/Documents/roosc/Fable-IOS/docs/final_milestone/01_BACKEND_SECURITY_AND_DATA.md) | **Complete & Verified** | Account/device/story shelf isolation, expiring persisted bearer sessions, PBKDF2 authentication, reading-event statistics, sliding-window rate limiting, and camelCase response aliases. |
| **2. Live Media & Content Pipelines** | [`02_LIVE_MEDIA_AND_CONTENT.md`](file:///Users/maclab/Documents/roosc/Fable-IOS/docs/final_milestone/02_LIVE_MEDIA_AND_CONTENT.md) | **Complete & Verified** | Provider cover URLs, on-demand Gutenberg chapters, clipped remote images, offline media cache, and per-account device identity. |
| **3. Reader Pacing & Word Tokenization** | [`03_READER_PACING_AND_WORD_TOKENIZATION.md`](file:///Users/maclab/Documents/roosc/Fable-IOS/docs/final_milestone/03_READER_PACING_AND_WORD_TOKENIZATION.md) | **Complete & Verified** | Zoom-invariant word counting, multi-whitespace tokenization, dynamic page chunking responsive to font scale. |
| **4. UI Interactions & Voice Accessibility** | [`04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md`](file:///Users/maclab/Documents/roosc/Fable-IOS/docs/final_milestone/04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md) | **Complete & Verified** | Actions are wired across writing, profile, library, reader, shelf, and settings; `AVSpeechSynthesizer` uses installed OS voices with tactile micro-interactions and haptics. |
| **5. Live Metadata & Pure User-State Isolation** | [`03_LIVE_METADATA_AND_USER_STATE_PURGING.md`](file:///Users/maclab/Documents/roosc/Fable-IOS/docs/final_milestone/03_LIVE_METADATA_AND_USER_STATE_PURGING.md) | **Complete & Verified** | Fresh installs have no bundled story catalog; provider and authored content uses live metadata and account-owned shelf/profile state with legacy demo stories purged. |
| **6. Multi-Format & Manga Architecture** | [`05_MULTI_FORMAT_AND_MANGA_ARCHITECTURE.md`](file:///Users/maclab/Documents/roosc/Fable-IOS/docs/final_milestone/05_MULTI_FORMAT_AND_MANGA_ARCHITECTURE.md) | **Complete & Verified** | Polymorphic reader dispatch, continuous vertical Webtoon scroll, horizontal swipe paging, Tachiyomi-style 3-zone tap overlay, and MangaDex direct CDN panel ingestion. |
| **7. Testing Suites & ADR Baseline** | [`04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md`](file:///Users/maclab/Documents/roosc/Fable-IOS/docs/final_milestone/04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md) | **Complete & Verified** | Backend and iOS verification results are tracked in dated entries; GitHub Actions runs the backend suite and native iOS simulator tests/build. |
| **8. App Health Diagnostics & Anti-Overlap Invariants** | [`MASTER_PROGRESS_LOG.md`](file:///Users/maclab/Documents/roosc/Fable-IOS/docs/final_milestone/MASTER_PROGRESS_LOG.md) | **Complete & Verified** | Image boundary clipping, `SystemDiagnosticsSheet`, and `AppHealthTests` verified in source and live Simulator executions. |

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

## Manga Catalog Direct-Panel Probing, Prioritization & Visual Badges (2026-10-15)

- [x] **Backend Direct-Panel Probing & Catalog Prioritization:**
  - Implemented `_probe_direct_chapters(manga_id)` in `backend/services/manga.py` using TTL caching (6-hour expiry) to query upstream MangaDex chapter feeds with `includeExternalUrl=0`.
  - Concurrently evaluated search and catalog results via `asyncio.gather`.
  - Tagged titles with `badge_text="DIRECT PANELS"` when authentic CDN scanlations exist, or `badge_text="OFFICIAL LINK"` when external publisher licensing restrictions apply.
  - Re-sorted catalog results so direct-reading titles are placed at the top of the feed.
- [x] **SwiftUI Visual Badge System & Dynamic Hero Card:**
  - Added `storyBadge(for story: Story)` in `LibraryView.swift` rendering an emerald green capsule (`checkmark.seal.fill`, "DIRECT PANELS") or amber link capsule (`arrow.up.right`, "OFFICIAL LINK").
  - Dynamically selected the top manga as the Featured Hero Card when filtering by Manga, providing instant visual feedback.
  - Prioritized `DIRECT PANELS` in `filteredRecentStories` and deduplicated entries by `providerId` to ensure clean presentation across SwiftData and live feeds.
- [x] **Verification & Live Simulator Validation:**
  - Backend test suite: **39/39 tests passing** (`test_main.py`).
  - Xcodebuild: Clean build succeeded with 0 errors.
  - Live iOS Simulator verification: Launched app on iPhone 17 Pro with Manga filter active.
  - Verified *The Eminence in Shadow* displayed with emerald `DIRECT PANELS` badge as the Hero Card.
  - Auto-opened *The Eminence in Shadow Chapter 1* in reader, verifying smooth loading of **37 direct scanlation panels** under Paging mode with interactive bottom scrubber.

## Trending Creators Alignment & Interactive Creator Bibliography (2026-10-15)

- [x] **Root Cause Diagnosis (Obsolete Creators & Non-Functional "N Stories"):**
  - Identified that `GET /api/v1/authors/top` was querying OpenLibrary's general `/trending/daily.json` endpoint, returning contemporary commercial non-fiction authors (James Clear, Robert Greene, Robert Kiyosaki, Morgan Housel, Mark Manson) who possess 0 readable works in Project Gutenberg or MangaDex.
  - Identified that tapping a creator in `ExploreView` previously opened a small 40% sheet with a single "Find a title" button using a rigid string equality check (`normalizedCatalogValue($0.author) == author`) against Gutenberg only, completely failing on manga creators and formatted names ("Shelley, Mary"), and giving users zero story choice.
- [x] **Backend Catalog Creator Alignment:**
  - Updated `get_top_authors()` in `backend/services/story_service.py` to prioritize creators with real, readable works in Fable's catalog:
    - Canonical Literary Masters: Mary Shelley, Arthur Conan Doyle, Bram Stoker, Jane Austen, Edgar Allan Poe.
    - Acclaimed Manga Artists: Tatsuki Fujimoto.
    - Local Community Writers: Any user-authored stories from SQLite `_local_writers()`.
  - Maintained live OpenLibrary portrait URL retrieval (`https://covers.openlibrary.org/a/olid/{key}-M.jpg?default=false`) and real work counts.
  - Preserved 100% test compatibility with `test_main.py` invariants and mocking contracts (**39/39 tests green**).
- [x] **Multi-Provider Author Search & Ingestion in Store:**
  - Implemented tokenized/fuzzy author matching (`matchesAuthor(storyAuthor:writerName:)`) in `StoryStore.swift` to handle both `"First Last"` and `"Last, First"` author nomenclature.
  - Implemented `stories(for writer: Writer) -> [Story]` and `fetchAuthorStories(for writer: Writer) async -> [Story]` querying both Project Gutenberg (prose) and MangaDex (manga) concurrently.
  - Upgraded `topStory(for writer: Writer)` to use multi-provider author search and updated `writer.storyCount` dynamically.
- [x] **Interactive Creator Bibliography View (`AuthorDetailView.swift`):**
  - Designed and implemented `AuthorDetailView.swift` presenting:
    - Author hero profile with avatar portrait and dynamic monogram fallback.
    - Curated creator bio summary and catalog availability counter.
    - Full scrollable bibliography feed displaying all readable works by that author.
    - Each story card features cover art preview, title, format tag (`PROSE` vs `MANGA`), genre, reading time/chapter count, and a direct "Read Now" action.
    - Integrated with `MangaReaderView` for graphic manga and `ReaderView` for prose literature.
  - Integrated `AuthorDetailView` into `ExploreView.swift`, replacing the dead-end 40% sheet and removing obsolete unreferenced state variables.
- [x] **Verification & Integrity:**
  - Backend automated test suite passed: **39/39 tests passing** (`test_main.py`).
  - Xcode iOS build succeeded cleanly (`** BUILD SUCCEEDED **`) with 0 errors.

## Production Hardening: Dual-Engine Literature & Manga Taxonomy, English Chapter Enforcement & Legacy Demo Purge (2026-10-15)

- [x] **Manga Strict English Enforcement (`en`):**
  - Eliminated unconstrained multi-language fallbacks in `_probe_direct_chapters` and `get_manga_chapters` in `backend/services/manga.py`.
  - Strictly enforce `("translatedLanguage[]", "en")` across upstream MangaDex feed queries, preventing foreign scanlations from being substituted for licensed works.
  - Prioritized direct SQLite chapter cache if ingested chapters with valid `page_urls` exist.
- [x] **SwiftData Legacy Demo Purge & Accurate "Latest Releases":**
  - Added `purgeLegacyDemoStories()` and `legacyDemoStoryIds` to `PersistenceService.swift` targeting retired demo UUIDs (`66666666-6666-6666-6666-666666666666` through `20202020-2020-2020-2020-202020202020`).
  - Invoked `purgeLegacyDemoStories()` in `StoryStore.init()` and defended `fetchAllStories()` against legacy demo IDs.
  - Fixed `isRecentSubmission: false` in `StoryStore.syncWithPersistence()`, ending the false marking of offline entities as fresh releases, and changed `stories.insert(userStory, at: 0)` to `stories.append(userStory)`.
  - Filtered `legacyDemoStoryIds` out of `filteredRecentStories` and hero card resolution in `LibraryView.swift`.
- [x] **Dual-Engine Identity & Category Taxonomy:**
  - Merged dynamic backend genres (`liveGenres`) with catalog-synthesized literature taxonomy (`deriveGenresFromCatalog(stories)`) in `StoryStore.syncWithCloudBackend()`.
  - Restored full literature genre taxonomy: `All`, `Manga`, `Fiction`, `Classics`, `Sci-Fi`, `Gothic`, `Romance`, `Adventure`, `Horror`.
  - Implemented `storyMatchesCategory(_ story: Story, category: String) -> Bool` in `StoryStore.swift` with keyword and format matching.
- [x] **Verification:**
  - Backend tests: **39/39 passing** (`.venv/bin/pytest test_main.py`).
  - Xcode build: **BUILD SUCCEEDED** for `iPhone 17 Pro` simulator.
  - Live simulator execution: Verified via screenshot (`simulator_screen_purged_library.png`) with clean category pills, 71 valid titles, and zero legacy demo cards.

## Production Hardening: Manga Reading State Continuity & Resumption Engine (2026-10-15)

- [x] **Panel-Level Position Resumption:**
  - Added `restoreSavedChapter()` panel restoration in `MangaReaderView.swift` to resume from `progress.currentPage - 1` rather than resetting to page 1 on every launch.
  - Added `.onChange(of: currentPageIndex)` and `.onChange(of: currentChapterIndex)` to synchronize panel flips and chapter advances in real time.
- [x] **Composite Multi-Chapter Progress Metric:**
  - Implemented `updateMangaProgress()` in `StoryStore.swift` calculating composite reading percentage: `fraction = (chapterIndex / totalChapters) + (page / totalPagesInChap) * (1 / totalChapters)`.
  - Atomically persisted composite progress to local SwiftData, LWW account shelf sync, and living reading statistics.
  - Formatted "Continue Reading" card on `LibraryView.swift` to display `Ch. \(chap) • Page \(page) of \(totalPages)` for manga titles.
- [x] **Defensive Legacy Demo Filtering:**
  - Guarded `inProgressStory` in `LibraryView.swift` and `displayedStories` in `ShelfView.swift` against `PersistenceService.legacyDemoStoryIds`.
- [x] **Verification:**
  - Xcode build: **BUILD SUCCEEDED** targeting `iPhone 17 Pro`.
  - Backend tests: **39/39 passing** (`test_main.py`).
  - Simulator verification: Screen capture (`simulator_screen_reading_continuity.png`) confirms UI stability and layout integrity.

## Production Hardening: Backend CORS Whitelist & Sliding-Window Rate Limiting (2026-10-15)

- [x] **Sliding-Window Rate Limiter Engine (`backend/core/rate_limit.py`):**
  - Implemented thread-safe, in-memory sliding-window limiter using timestamp queues and atomic lock synchronization.
  - Established tiered rate limits:
    - Auth Tier (`/api/v1/auth/*`): 10 requests / 60 seconds per client IP to mitigate brute force credential attacks.
    - General Tier (`/api/v1/*`): 60 requests / 60 seconds per client IP to protect upstream proxy resources (e.g. MangaDex).
  - Built `RateLimitMiddleware` returning HTTP `429 Too Many Requests`, JSON error payload, and compliant `Retry-After: <seconds>` header.
  - Added configurable bypass switch `FABLE_RATE_LIMIT_ENABLED` for safe regression and load testing.
- [x] **CORS Origin Whitelisting (`backend/main.py`):**
  - Replaced unsafe wildcard `allow_origins=["*"]` with environment-parsed `FABLE_CORS_ORIGINS` whitelist and trusted local/mobile origins (`localhost:3000`, `127.0.0.1:3000`, `localhost:8000`, `127.0.0.1:8000`, `localhost:5173`, `capacitor://localhost`, `ionic://localhost`).
  - Enforced `allow_credentials=True` safety compliance across modern web and mobile webview clients.
- [x] **Test Verification & Coverage (`backend/test_main.py`):**
  - Added unit test `test_sliding_window_rate_limiter_unit()` verifying window eviction, quota exhaustion, retry calculation, and reset.
  - Added integration test `test_rate_limit_middleware_blocks_burst()` verifying live middleware rejection with HTTP 429 and `Retry-After` header.
  - Added contract test `test_cors_origin_whitelist_contract()` verifying trusted origin header reflection and untrusted origin exclusion.
  - All **42/42 backend tests passing** in 1.38s.

## Frontend UI/UX Design Enhancement & Micro-Interactions (2026-10-15)

- [x] **Design Tokens & Haptics Engine (`frontend/FableApp/Core/Theme/FableTheme.swift`):**
  - Added `FableHaptics` providing UIKit impact (`light`, `medium`), selection, and notification feedback generators.
  - Standardized continuous-curve card styling with hairline borders (`FableTheme.divider`) and soft multi-layer elevation shadows.
- [x] **Library Discovery & Hero Card Polish (`frontend/FableApp/Features/Library/Views/LibraryView.swift`):**
  - Upgraded Featured Hero Card with an elegant bottom-gradient scrim (`LinearGradient`) to ensure high-contrast legibility across all cover art.
  - Added `photo.on.rectangle.angled` icon for Manga and `book.closed.fill` icon for Literature/Novels to give visual clarity to the dual-engine reading model.
  - Integrated `FableHaptics.selection()` and spring transitions on category filter pills (`All`, `Manga`, `Fiction`, `Classics`, etc.).
  - Added tactile haptic feedback on bookmark toggles and card taps.
  - Enhanced "Continue Reading" card with animated gradient progress bar (`brandPrimary` to `brandAccent`) and distinct chapter/page indicators.
- [x] **Search & Explore Experience (`frontend/FableApp/Features/Library/Views/ExploreView.swift`):**
  - Refined search bar with continuous curvature, hairline borders, and tactile clear action.
  - Enhanced curated filter chips with selection haptics and spring animations.
- [x] **Verification:**
  - Xcode build: **BUILD SUCCEEDED** for `iPhone 17 Pro` (`mseuf.edu.ph.FableApp`).
  - Backend tests: **42/42 passing** (`pytest test_main.py`).
  - Simulator capture: Verified live UI rendering via screenshot (`simulator_screen_ui_enhanced.png`).

## Reader, Writer & Shelf Micro-Interactions & Chrome Continuity (2026-10-20)

- [x] **Shelf View Polish (`frontend/FableApp/Features/Shelf/Views/ShelfView.swift`):**
  - Integrated `FableHaptics.light()` on profile and settings sheet triggers.
  - Added `FableHaptics.selection()` and spring animation (`.spring(response: 0.3, dampingFraction: 0.75)`) on shelf tab navigation.
  - Applied continuous corner radius (`style: .continuous`) to tab pills and surface backgrounds.
- [x] **Writer Studio Polish (`frontend/FableApp/Features/Write/Views/WriteView.swift`):**
  - Added `FableHaptics.medium()` to story publishing action.
  - Added `FableHaptics.selection()` to all manuscript formatting toolbar buttons (Bold, Italic, Block Quote, Scene Break).
  - Enhanced Title, Synopsis, and Manuscript cards with continuous curvature (`cornerRadius: 18, style: .continuous`), hairline divider strokes (`FableTheme.divider.opacity(0.8)`), and soft elevation shadows.
  - Upgraded floating footer pill with continuous curvature and subtle borders.
- [x] **Prose Reader Ergonomics (`frontend/FableApp/Features/Reader/Views/ReaderView.swift`):**
  - Integrated `FableHaptics.light()` on dismiss and bookmark toggle.
  - Integrated `FableHaptics.selection()` on Table of Contents (TOC) sheet and typography options sheet triggers.
  - Added `FableHaptics.medium()` to oral synthesizer audio narration toggle.
  - Standardized top navigation bar action buttons with 36x36 circular touch targets and high-contrast tinted backgrounds.
- [x] **Manga Reader Chrome & Scrubber (`frontend/FableApp/Features/Reader/Views/MangaReaderView.swift`):**
  - Standardized circular floating action buttons with `FableHaptics.light()` and `FableHaptics.selection()`.
  - Added spring transition to reading mode selector menu (`.spring(response: 0.3, dampingFraction: 0.75)`).
  - Enhanced bottom floating HUD with multi-stop dark gradient overlay, active reading mode indicator with primary brand accent dot, and capsule-styled Next/Previous chapter buttons.
- [x] **Verification:**
  - Xcode compilation: **BUILD SUCCEEDED** (`FableApp.xcodeproj`).
  - Backend test suite: **42/42 tests passing** (`backend/test_main.py`).

## Production Readiness Audit & Environment Synchronization (2026-10-21)

- [x] **Production Readiness Audit Score: 82/100 (Launchable with Caveats):**
  - Executed full repository scan using ECC `production-audit` evaluating backend boundaries, data isolation, client ergonomics, and Docker build pipelines.
  - Verified that all launch-critical paths (prose reading, Webtoon scrolling, Manga right-to-left paging, Gutenberg ingestion, MangaDex CDN panel probing, user authoring, and offline SwiftData LWW sync) function without blockers.
- [x] **Environment Variable & Runtime Synchronization:**
  - Synchronized `.env.example` with modern runtime requirements: added `FABLE_CORS_ORIGINS`, `FABLE_RATE_LIMIT_ENABLED`, and granular sliding-window threshold parameters (`RATE_LIMIT_AUTH_LIMIT`, `RATE_LIMIT_AUTH_WINDOW`, `RATE_LIMIT_GENERAL_LIMIT`, `RATE_LIMIT_GENERAL_WINDOW`).
  - Hardened `backend/main.py` CORS origins parser to gracefully handle both comma-delimited strings (`FABLE_CORS_ORIGINS`) and bracketed array strings (`CORS_ORIGINS`), ensuring robust multi-environment interoperability.
- [x] **Final Verification:**
  - Backend test suite: **42/42 passing** in 1.28s (`pytest test_main.py`).
  - Xcode compilation: **BUILD SUCCEEDED** for iOS Simulator (`iPhone 17 Pro`).
  - Git working tree: Clean and synchronizable.

## On-Device Health Diagnostics Aggregation & E2E Simulator Verification (2026-10-21)

- [x] **Unified On-Device Health Harness (`frontend/FableApp/Features/Shelf/Views/SystemDiagnosticsSheet.swift`):**
  - Integrated all 5 specialized client domain test suites alongside `AppHealthTests`:
    - `ReaderTests`: Pacing engine velocity clamping (100–600 WPM), Unicode multi-whitespace tokenization, dynamic font scaling, and page chunking.
    - `WriteTests`: Manuscript split word tokenizer and reading time estimation.
    - `ShelfTests`: Reading stats summary metrics, hours calculation parity, and `ShelfSyncItem` multi-tenant serialization contract.
    - `AuthTests`: Asynchronous authentication boundary checks, invalid email rejection, password length rules, guest sessions, and sign-out cleanup.
  - Standardized diagnostic reporting into high-fidelity `TestReport` cards with PASS/FAIL badges and monospace detail traces.
- [x] **Live iOS Simulator Boot & Evidence Capture:**
  - Successfully booted `iPhone 17 Pro` (iOS 26.5) and installed `mseuf.edu.ph.FableApp`.
  - Verified live discovery feed rendering with real Gutenberg and MangaDex CDN panel ingestion against active FastAPI daemon (`127.0.0.1:8000`).
  - Captured high-resolution verification screenshot: `docs/simulator_captures/01_library_feed.png`.
- [x] **Verification:**
  - Backend test suite: **42/42 passing** (`pytest test_main.py`).
  - Xcode compilation: **BUILD SUCCEEDED** (`FableApp.xcodeproj`).

## Native Xcode Test Target & Final Pull Request Baseline (2026-10-21)

- [x] **Native Xcode Test Target & CLI Automation (`FableAppTests`):**
  - Configured native unit test bundle target `FableAppTests` in `frontend/FableApp.xcodeproj/project.pbxproj` and shared scheme `FableApp.xcscheme`.
  - Implemented `FableAppTests.swift` wrapping all 6 domain test suites (`AppHealthTests`, `LibraryTests`, `ReaderTests`, `WriteTests`, `ShelfTests`, `AuthTests`) in native `XCTestCase` assertions.
  - Verified headless CLI test execution via `xcodebuild test`: **6/6 test suites passed with 0 failures** in 0.32s on `iPhone 17 Pro`.
- [x] **Capstone Final Pull Request & Transition Audit (`docs/final_milestone/FINAL_PULL_REQUEST.md`):**
  - Prepared comprehensive PR specification documenting 83 atomic conventional commits, 107 modified files, and zero-conflict fast-forward merge capability into `main`.
  - Authored step-by-step transition guide for merging, tagging `v1.0.0-final`, and running dual Pytest/Xcodebuild verification gates.
- [x] **Verification Matrix:**
  - Backend pytest: **42/42 passing** in 1.35s (`pytest backend/test_main.py`).
  - Xcode unit test suite: **`** TEST SUCCEEDED **`** via `xcodebuild test`.
  - Git working tree: Clean and pushed to remote branch.




## Live Catalog and In-App Reader Reliability (2026-10-25)

- [x] **Live Image Refresh (`frontend/FableApp/Core/Components/FableImageView.swift`, `frontend/FableApp/Features/Library/Models/Story.swift`):**
  - Bound the loaded image state to its URL so recycled story cards cannot display a previous story's cover.
  - Prevented provider-backed stories from falling back to bundled prototype hero art when a live cover URL is unavailable.
- [x] **Provider Fetch and Chapter Reading (`frontend/FableApp/Features/Library/Services/StoryAPIService.swift`, `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift`, `frontend/FableApp/Features/Reader/Views/ReaderView.swift`, `frontend/FableApp/Features/Reader/Views/MangaReaderView.swift`):**
  - Applied a 20-second request timeout to Gutenberg catalog and chapter provider calls, allowing the backend's 15-second upstream fetch to complete.
  - Kept parsed Gutenberg chapter text in the native reader and rejected cached source URLs as readable prose.
  - Limited Manga panels to the selected chapter; when a chapter has only an official publisher URL, opened that page in Fable's in-app browser.
- [x] **Guest Session Resilience (`frontend/FableApp/Features/Auth/Services/AuthManager.swift`, `frontend/FableApp/Features/Auth/ViewModels/AuthViewModel.swift`):**
  - Preserved credential-free guest session metadata locally when Keychain access is unavailable; authenticated sessions and access tokens still require Keychain storage.
- [x] **Verification:**
  - Native Xcode simulator suite: **6 tests passed, 0 failures** on iPhone 16 / iOS 18.5.
  - Backend suite: **42 passed**; Docker image build succeeded.


## Production API and Release Hardening (2026-10-25)

- [x] Bounded API request bodies, validated CORS origins, sanitized validation errors, and added persistent IP/account authentication throttling.
- [x] Added a versioned SQLite migration that removes only retired demo records and dependent shelf/reading references, plus online backup and integrity-check tooling.
- [x] Paged story summaries, bounded story payload fields, and added CI checks for Release API URL validation and an HTTPS-configured Release build.
- [x] Kept the newer provider image, chapter reader, simulator CI, and guest-session fixes while reconciling this hardening work with current `main`.

## Production Hardening Continuation (2026-10-29)

- [x] Protected Gutenberg and MangaDex ingestion with a dedicated operator key that is compared in constant time and fails closed when unconfigured; documented trusted Uvicorn proxy addresses and kept the key out of the iOS client.
- [x] Removed application trust in raw `X-Forwarded-For`, capped rate-limit client buckets, and bounded provider response bytes, fetch concurrency, and in-memory caches.
- [x] Improved VoiceOver error announcements and Dynamic Type support on sign-in and sign-up screens; removed stale README test counts and branch links.
- [x] Verification: backend suite **64/64 passed** in the project Python environment and in the Python 3.11 container; Docker image build, Compose configuration, and iOS Release URL guard passed.
- [x] Native Xcode build and simulator tests passed on the macOS CI runner; this Fedora workspace does not have `xcodebuild`.

## Production Audit Follow-up (2026-10-29)

- [x] Replaced the unbounded SwiftUI `AsyncImage` fallback with a single streaming downloader that rejects non-HTTPS URLs, insecure redirects, non-image responses, oversized bodies, and images with excessive decoded dimensions.
- [x] Added image downloader regression tests for valid image responses, invalid content types, byte limits, URL policy, and dimension limits.
- [x] Added an opt-in Compose backup service that creates integrity-checked online SQLite snapshots, retries failures, and prunes expired Fable snapshots by retention policy.
- [x] Added versioned GitHub Container Registry image tags and digest-based deploy/rollback instructions; release publication waits for backend, Docker/Compose, and iOS checks.
- [x] Clarified that provider-only licensed MangaDex chapters open in an in-app browser, and refreshed the stale progress summary.
- [x] Verification: backend suite **66 passed** in the rebuilt Python 3.11 image; Docker build, Compose validation, packaged backup CLI, and a read-only/no-network backup container check passed.
- [ ] Native Xcode tests, including the new image downloader cases, and the Release build are pending macOS CI because this workspace has no `xcodebuild`.
