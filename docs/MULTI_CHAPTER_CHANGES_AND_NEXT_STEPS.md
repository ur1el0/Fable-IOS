# Multi-Chapter Catalog & Cache Remediation — Summary of Changes and Next Steps

- **Status:** Merged to `main` (PRs #41–#45); follow-up completion on `fix/catalog-validation-and-windows-finish`
- **Live Hosted Backend:** `https://fable-api-cbo8.onrender.com` *(Render + Neon PostgreSQL, verified live)*
- **Remote Repository:** `https://github.com/ur1el0/Fable-IOS.git`
- **Related Plan:** [`docs/plans/07_MULTI_CHAPTER_CATALOG_AND_CACHE_REMEDIATION.md`](./plans/07_MULTI_CHAPTER_CATALOG_AND_CACHE_REMEDIATION.md)

---

## 1. Problem Addressed

1. **Single-chapter Project Gutenberg books:** Default Gutenberg browsing previously surfaced newest-first (`-gutenberg_id`) short stories/pamphlets, Python 3.9 cross-event-loop async primitives could fail on concurrent fetches, and several multi-chapter formatting styles (centered/indented headings, italic spelled-out numerals, `STAVE` headers, nested `PART` + Roman subchapters, and `Contents`-listed unnumbered headings) collapsed into a single `"Chapter I: The Complete Tale"` entry.
2. **Single-provider bottleneck:** Added **Standard Ebooks** (`https://standardebooks.org`) as a second open-source catalog provider serving structured semantic XHTML chapters.
3. **Stale client SwiftData cache:** Previously cached single-chapter fallback books and unengaged pulp catalog cards stayed persisted on iOS instead of refreshing cleanly once the backend parsers improved.

---

## 2. Changes Implemented on `feat/plans-01-04-remediation`

| Commit | Conventional Commit Title | Files Changed | Summary |
|---|---|---|---|
| `14a7c8c` | `docs(plans): add multi-chapter catalog and cache remediation plan` | `docs/plans/07_MULTI_CHAPTER_CATALOG_AND_CACHE_REMEDIATION.md`, `docs/plans/README.md` | Documented `CACHE-01`, `CACHE-02`, `PG-PARSE-01`, `PG-CAT-01`, and `SE-POLISH-01` root causes and remediation plan. |
| `f3952ca` | `fix(gutenberg): prioritize classic books, deduplicate editions, and expand chapter parser` | `backend/services/text_parser.py`, `backend/services/gutenberg.py` | Expanded chapter header and `Contents`-guided unnumbered chapter splitting (`GID=42` -> 10 chapters), fixed `PART` TOC leaks and nested Roman subchapters (`GID=24` -> 30 chapters), ranked classics first in `_search_gutenberg_catalog`, cleaned MARC `$b` title artifacts via `_clean_gutenberg_title`, deduplicated editions, and switched module-level locks/semaphores to loop-scoped `_loop_primitive`. |
| `75f3008` | `feat(standard-ebooks): add open-source XHTML catalog and chapter endpoints` | `backend/services/standard_ebooks.py`, `backend/api/v1/endpoints/standard_ebooks.py`, `backend/api/v1/api.py` | Added Standard Ebooks catalog & semantic XHTML chapter parsing behind `GET /api/v1/public/standard-ebooks` and `GET /api/v1/public/standard-ebooks/chapters`. |
| `1c3a91b` | `test(providers): cover Gutenberg parser edge cases and Standard Ebooks API` | `backend/test_main.py`, `backend/test_provider_http.py`, `backend/test_provider_services.py` | Added unit and HTTP tests covering Gutenberg parser variants, MARC cleanup, edition deduplication, and Standard Ebooks endpoints/headings. |
| `3554c8a` | `feat(library): integrate Standard Ebooks and self-heal external chapter caches` | `ProviderCatalogStatus.swift`, `PersistenceService.swift`, `StoryAPIService.swift`, `StoryStore.swift`, `ReaderView.swift` | Integrated Standard Ebooks into iOS catalog/reader loading, added versioned external chapter cache invalidation (`currentExternalChapterParserVersion = 2`), and pruned unengaged stale provider cards while keeping offline fallback and user-engaged books intact. |
| `5d0952a` | `test(library): cover Standard Ebooks decoding and cache invalidation policies` | `frontend/FableAppTests/StorySummaryDecodingTests.swift`, `frontend/FableAppTests/PlanFeaturesRegressionTests.swift` | Added XCTest coverage for Standard Ebooks DTO decoding, cache invalidation rules, and stale catalog pruning. |

---

## 3. Verification Recorded Before Push

- **Backend unit/integration tests (`cd backend && ../.venv/bin/pytest`):** `124 passed, 6 skipped in 11.17s`
- **Live local FastAPI smoke checks (`http://127.0.0.1:8001`):**
  - `/api/v1/health` -> `{"status":"healthy","database":"connected",...}`
  - `gutenberg?topic=fiction` -> 12 books; `gutenberg/42/chapters` -> 10 chapters; `gutenberg/24/chapters` -> 30 chapters
  - `standard-ebooks?topic=fiction` -> 12 books; `standard-ebooks/chapters?book_id=fyodor-dostoevsky/crime-and-punishment/constance-garnett` -> 40 chapters
- **iOS unit tests (`xcodebuild test` on `iPhone 17 Pro` Simulator `299D40A3-700A-47EF-890D-B5624E935D03`):** `Executed 37 tests, with 0 failures` (`** TEST SUCCEEDED **`)
- **Release config & build validation (`scripts/validate_ios_release_config.sh` + Release Simulator `xcodebuild build`):**
  - Positive HTTPS URL check (`FABLE_API_BASE_URL=https://api.example.com/api/v1`) passed (`exit 0`).
  - Negative guard checks (`http://127.0.0.1:8000/api/v1`, `https://127.1/api/v1`, and empty `FABLE_API_BASE_URL`) rejected as required by `.github/workflows/ci.yml`.
  - Release Simulator build succeeded (`** BUILD SUCCEEDED **`).
- **Live Simulator launch (`mseuf.edu.ph.FableApp`, PID `30319`):** Confirmed `Live Cloud` connected cleanly to the local backend and rendered Featured `Pride and Prejudice`, `Continue Reading`, and a `STANDARD EBOOKS` card on the Library screen.

---

## 4. Current Deployment Status & Remaining Non-Windows Items

Previous dashboard and PR blockers from the Fedora session have now been resolved:

- **PRs #41–#45 Merged to `main`:** Security hardening (Plan 06, PR #41), simulator captures (PR #42), Standard Ebooks & fresh Gutenberg discovery (`feat/fresh-gutenberg-discovery`, PR #43), and Render/UptimeRobot `/api/v1/live` `GET`/`HEAD` liveness probes (PR #44 & PR #45) are all on `main`.
- **Hosted Backend Verified Live (`https://fable-api-cbo8.onrender.com`):**
  - `GET /api/v1/live` -> `200 OK` (`{"status":"alive"}`)
  - `GET /api/v1/health` -> `200 OK` (`{"status":"healthy","database":"connected",...}`)
  - `GET /api/v1/public/standard-ebooks?topic=fiction` -> `200 OK` (live catalog entries)
  - `GET /api/v1/public/gutenberg?topic=fiction` -> `200 OK` (12 deduplicated classics)

Remaining actions require macOS/Xcode or release signing credentials rather than Windows development:

1. **GitHub Actions CI & macOS Verification:** Verify the `fix/catalog-validation-and-windows-finish` branch via `ci.yml` (`postgres:16`, Python `3.9` & `3.11`, Docker build, and `macos-15` `xcodebuild test` / Release build) or locally on macOS (`xcodebuild` is unavailable on Windows).
2. **Release iOS Archive / TestFlight:** When building a Release archive on macOS, pass `FABLE_API_BASE_URL=https://fable-api-cbo8.onrender.com/api/v1`.
3. **Optional Operator Credentials:** Configure SMTP credentials if testing live password-reset email delivery against Render.

---

## 5. Follow-Up Completion Applied on `fix/catalog-validation-and-windows-finish`

Consolidated all unmerged Fedora branch work (`fix/catalog-validation-followup`, `origin/docs/simulator-captures-multi-chapter`, and `origin/fix/final-ui-ci-and-docs`) onto `main` alongside Windows verification fixes:

- **Standard Ebooks Subtitle Hygiene (`SE-POLISH-01`, [`backend/services/standard_ebooks.py`](../backend/services/standard_ebooks.py)):** Normalized parenthetical/bracketed heading subtitles (e.g., `"I: Jonathan Harker’s Journal (Kept in shorthand.)"`) while preserving the `origin/main` empty-`<main>` fallback.
- **Opt-In Live Upstream Chapter Regressions ([`backend/test_provider_live.py`](../backend/test_provider_live.py), [`backend/test_provider_services.py`](../backend/test_provider_services.py)):** Added `FABLE_RUN_LIVE_PROVIDER_TESTS=1` checks verifying Project Gutenberg (`GID=42` *Dr. Jekyll and Mr. Hyde*, `GID=24` *O Pioneers!*) and Standard Ebooks (*Dracula*, *Crime and Punishment*).
- **Gutenberg Taxonomy, Author Hygiene & Search Priority ([`backend/services/gutenberg.py`](../backend/services/gutenberg.py), [`backend/test_provider_services.py`](../backend/test_provider_services.py)):** Added `_normalize_gutenberg_genre` for compound LCSH tags, excluded collective placeholder authors (`various`, `anonymous`, `unknown`) from `get_gutenberg_authors`, and prioritized English editions in `_search_gutenberg_catalog`.
- **Manga Readable-Panel Availability Probe ([`backend/services/manga.py`](../backend/services/manga.py), [`backend/test_main.py`](../backend/test_main.py)):** Added `_get_manga_chapter_page_urls` and bounded `@at-home/server` verification (`MANGA_MAX_DIRECT_PROBES_PER_SEARCH = 19`) on search with updated mocks.
- **Windows SQLite Backup Fix & Test Guard ([`scripts/sqlite_backup.py`](../scripts/sqlite_backup.py), [`backend/test_main.py`](../backend/test_main.py)):** Wrapped `sqlite3.connect` handles in `contextlib.closing(...)` so snapshot files unlock cleanly before temporary directory cleanup on Windows (`WinError 32`), and guarded the POSIX `0o600` `st_mode` check when `sys.platform == "win32"`.
- **iOS Discovery, Hero, Reader, Write & Settings Polish ([`frontend/`](../frontend/FableApp)):** Unified category matching via `StoryStore.storyMatchesCategory`, filtered placeholder authors (cache version `3`), added `displayStoryCount`/`pluralizedCount`, deduplicated the featured hero from `Browse Library` while preserving `origin/main` `New on Gutenberg` / `Reader Favorites` shelves and unknown chapter count copy, compacted `ReaderView` navbar into a `Menu`, docked `ReaderView`/`WriteView` HUD pills outside scroll viewports, updated `"artists"` to `"authors"` in `SettingsView`, and added regression tests in [`PlanFeaturesRegressionTests.swift`](../frontend/FableAppTests/PlanFeaturesRegressionTests.swift).
- **Release Workflow Parity, Captures & Docs ([`.github/workflows/release-container.yml`](../.github/workflows/release-container.yml), [`docs/simulator_captures/`](./simulator_captures/README.md)):** Synced the `https://127.1/api/v1` loopback guard and XCTest signing flags with `ci.yml`, imported refreshed captures + `30_api_openapi_docs.png` + `ENDPOINT_VERIFICATION.md` from `6334c8b`, and updated project docs.
