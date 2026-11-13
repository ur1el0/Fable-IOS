# Multi-Chapter Catalog & Cache Remediation — Summary of Changes and Next Steps

**Branch:** `feat/plans-01-04-remediation` (`origin/feat/plans-01-04-remediation`)  
**Remote Repository:** `https://github.com/ur1el0/Fable-IOS.git`  
**Related Plan:** [`docs/plans/07_MULTI_CHAPTER_CATALOG_AND_CACHE_REMEDIATION.md`](./plans/07_MULTI_CHAPTER_CATALOG_AND_CACHE_REMEDIATION.md)

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

## 4. What to Do Next (Manual Dashboard Steps)

These remaining actions require GitHub or Render web authentication / owner access (`gh`, `render`, `brew`, and API tokens are not configured in this local environment):

1. **Open the GitHub Pull Request & trigger CI:**
   - Open `https://github.com/ur1el0/Fable-IOS/pull/new/feat/plans-01-04-remediation` (targeting `main`).
   - Opening the PR triggers all 4 jobs defined in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml):
     - `backend-verification` (Python `3.9` and `3.11`)
     - `postgres-verification` (`postgres:16`)
     - `docker-build-verification`
     - `ios-verification` (`iPhone 16` / `iOS 18.5`)
2. **Merge the PR into `main`:**
   - Once all CI checks pass cleanly, merge the PR into `main` (per [`AGENTS.md`](../AGENTS.md), do not push directly to `main` bypassing PR CI).
3. **Resume / Redeploy the Render Backend & Verify Neon DB:**
   - As checked at handoff time, `https://fable-api.onrender.com/api/v1/health` returns **HTTP `503`** (`Service Suspended` — *"This service has been suspended by its owner."*).
   - Open the Render Dashboard and resume `fable-api` or re-apply [`render.yaml`](../render.yaml) following [`docs/RENDER_NEON_DEPLOYMENT.md`](./RENDER_NEON_DEPLOYMENT.md) with your Neon pooled `DATABASE_URL` and `FABLE_INGESTION_API_KEY`.
   - After deployment passes health checks, verify:
     - `https://<service-name>.onrender.com/api/v1/health` reports `healthy` and `database: connected`
     - `https://<service-name>.onrender.com/api/v1/public/standard-ebooks?topic=fiction` returns non-empty Standard Ebooks titles
     - Any iOS Release archive uses `FABLE_API_BASE_URL=https://<service-name>.onrender.com/api/v1`
