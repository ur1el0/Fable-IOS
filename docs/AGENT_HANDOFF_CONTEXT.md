# Fable iOS — Agent Handoff & Full Session Context

**Last Updated:** 2026-11-13
**Active Git Branch:** `feat/security-and-architecture-remediation` *(Plan 06 complete; ready for PR review/merge into `main`)*
**Primary Next Task:** Open and merge the PR for `feat/security-and-architecture-remediation` after final verification.

---

## 1. Quick Orientation for Laptop Coding Agents

If you are an AI coding agent picking up this repository on the developer's laptop, read these three files first:
1. **`docs/AGENT_HANDOFF_CONTEXT.md`** *(this file — complete session history, architectural decisions, exact line numbers, and compiler/runtime gotchas)*
2. **[`docs/plans/06_SECURITY_VULNERABILITIES_AND_ARCHITECTURE_REMEDIATION.md`](./plans/06_SECURITY_VULNERABILITIES_AND_ARCHITECTURE_REMEDIATION.md)** *(the 4-phase hardening specification — completed on `feat/security-and-architecture-remediation`)*
3. **[`docs/DATA_SOURCES_AND_API_STRATEGY.md`](./DATA_SOURCES_AND_API_STRATEGY.md)** *(live provider data, on-demand chapter loading, and why Manga is disabled on iOS)*

---

## 2. Chronological Summary of Completed Work on `fix/python39-runtime-compatibility`

| Commit | Summary | Key Files Touched |
|---|---|---|
| `0c9dfc1` | **Unified Multi-Chapter Catalog Seeding & Chapter 1 Guarantee ("Option 3"):** Seeded 40+ books, classic fables, folklore, and literature directly into `data/curated_catalog.json` and SQLite (`backend/core/database.py`). Every catalog work is structured into multi-chapter `StoryChapterDTO` entries guaranteed to start at Chapter 1 (`chapterNumber == 1`). | `data/curated_catalog.json`, `backend/core/database.py`, `scripts/seed_comprehensive_catalog.py`, `backend/services/gutenberg.py`, `backend/tests/test_api_v1.py` |
| `f0f9c2a` | **Documented Upstream Manga Chapter Gaps & Licensing Risks:** Recorded in `docs/DATA_SOURCES_AND_API_STRATEGY.md` (Section 6) why MangaDex community scanlations exhibit chapter gaps (e.g., *Mushoku Tensei* missing Ch. 79–108; officially licensed series like *One Piece* missing Ch. 1–1162) and copyright/App Store compliance risks. | `docs/DATA_SOURCES_AND_API_STRATEGY.md` |
| `38fcee0` | **Feature-Flagged & Hid Manga on iOS (`StoryStore.isMangaEnabled = false`):** Pivoted the iOS app to focus 100% on open-source books, classic fables, folklore, and community manuscripts. Hid all manga filter pills, sections, genres, and stories across `LibraryView`, `ExploreView`, `GenreDetailView`, `AuthorDetailView`, `ShelfView`, and `WelcomeView`. Replaced manga author in `FEATURED_CATALOG_AUTHORS` with `"Lewis Carroll"` and `"Aesop"`. | `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift`, `LibraryView.swift`, `ExploreView.swift`, `GenreDetailView.swift`, `AuthorDetailView.swift`, `ShelfView.swift`, `WelcomeView.swift`, `backend/services/story_service.py` |
| `90b076e` | **Complete UI Screenshot & Walkthrough Video Archive:** Captured 29 PNG screenshots covering every screen, endpoint, filter pill, reader theme, and modal sheet—plus a continuous walkthrough screen recording (`fable_ios_full_walkthrough.mp4`)—indexed in `docs/simulator_captures/README.md`. | `docs/simulator_captures/*`, `frontend/FableApp/App/ContentView.swift` |
| `c5d9631` | **Security Vulnerabilities & Architecture Remediation Plan (Plan 06):** Audited the full stack for non-manga security flaws and poor architectural planning, producing `docs/plans/06_SECURITY_VULNERABILITIES_AND_ARCHITECTURE_REMEDIATION.md`. | `docs/plans/06_SECURITY_VULNERABILITIES_AND_ARCHITECTURE_REMEDIATION.md`, `docs/plans/README.md` |

---

## 3. Important Architectural Invariants (Do Not Break)

1. **Manga Must Remain Hidden on iOS (`StoryStore.isMangaEnabled == false`):**
   - `StoryStore.isMangaEnabled` in `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift` (around line 193) is intentionally `false`.
   - **Why backend manga routes still exist:** Backend MangaDex routes remain as provider API functionality, while `StoryStore.visibleCatalogStories` filters `.manga` out of the iOS client until source continuity and rights are verified. No local scanlation catalog is seeded.
2. **Live Provider Reading:**
   - Provider catalog responses contain metadata and official cover URLs. Gutenberg chapters are fetched from the provider's plain-text source by `/api/v1/public/gutenberg/{id}/chapters` when the user opens a book; no Gutenberg chapter bodies are downloaded for every catalog item.
3. **Python 3.9 Runtime Compatibility:**
   - The macOS system/lab Python environment may run Python 3.9+. Always include `from __future__ import annotations` at the top of Python modules if using `X | Y` union type syntax or `list[...]` / `dict[...]` built-in generics.

---

## 4. Deep-Dive Technical Context for Executing Plan 06 (Hardening — Historical Audit Baseline)

Below is the original file-and-line audit baseline gathered prior to executing **Plan 06** (now completed on `feat/security-and-architecture-remediation`; preserved below for historical context).

### Phase 1: Critical Security & Auth Hardening (P0)

#### 1. `SEC-01` — Unthrottled Password Reset Confirmation & Unbounded `auth_rate_limits`
- **Where:**
  - `backend/api/v1/endpoints/auth.py` lines `66–68`:
    ```python
    @router.post("/password-reset/confirm", status_code=204)
    def confirm_password_reset(payload: PasswordResetConfirmRequest):
        auth_service.confirm_password_reset(payload)
        return Response(status_code=204)
    ```
  - Compare with `/register` (lines `22–32`), `/login` (lines `35–45`), and `/password-reset/request` (lines `48–63`), which all call `enforce_auth_rate_limit(...)`.
  - In `backend/services/auth_service.py` lines `315–360`, `confirm_password_reset()` hashes the incoming token, opens a `BEGIN IMMEDIATE` transaction, and if valid runs `_hash_password(payload.new_password)` (`600,000` PBKDF2-HMAC-SHA256 iterations).
  - In `backend/services/auth_rate_limit.py` lines `58–94` (`_consume_bucket`), the `auth_rate_limits` SQLite table only deletes expired rows (`WHERE updated_at_epoch < ?`), with **no maximum row cap**.
- **How to Fix:**
  - Inject `request: Request` into `confirm_password_reset` in `backend/api/v1/endpoints/auth.py`.
  - Add `"password_reset_confirm"` to `AUTH_RATE_LIMIT_RULES` in `backend/services/auth_rate_limit.py` and call `enforce_auth_rate_limit("password_reset_confirm", client_host=extract_client_ip(request), identifier=payload.reset_token[:16])`.
  - In `backend/services/auth_rate_limit.py`, enforce a `max_buckets = 10_000` cap using the same oldest-bucket eviction pattern as `SharedTokenBucketRateLimiter` (`backend/core/rate_limit.py` lines `140–152`).

#### 2. `SEC-02` — Reverse-Proxy IP Collapse in Auth Rate Limiting
- **Where:**
  - `backend/api/v1/endpoints/auth.py` lines `26`, `39`, `52` use `request.client.host if request.client else None`.
  - Meanwhile, `backend/core/rate_limit.py` lines `201–247` already implements trusted-proxy CIDR validation (`_is_trusted_proxy` and `_extract_client_ip`) that safely parses `X-Forwarded-For` / `X-Real-IP` only when the immediate peer is in `FABLE_TRUSTED_PROXY_CIDRS`.
  - Because `auth.py` ignores `_extract_client_ip`, behind Caddy/Nginx/Docker every user shares the reverse proxy's internal IP (`127.0.0.1` or `172.x.x.x`), so 5 registrations in 15 minutes locks out all new registrations globally.
- **How to Fix:**
  - Make `extract_client_ip(request: Request) -> str` a public helper in `backend/core/rate_limit.py` (reading settings from `get_settings()`) and call it in `backend/api/v1/endpoints/auth.py`.

#### 3. `SEC-03` — Author Impersonation & Non-Unique User `@handle`s
- **Where:**
  - `backend/core/database.py` lines `155–166`: `users.handle` is `TEXT NOT NULL` without `UNIQUE`.
  - `backend/services/auth_service.py` lines `146–150` (`register_user`) and lines `252–269` (`update_current_user`) never check if `handle` or `name` is already in use or reserved.
  - `backend/api/v1/endpoints/stories.py` lines `58–61` copies `user.name` directly into `CreateStoryRequest.author`.
  - `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift` lines `814–833` (`matchesAuthor(_:author:)`) matches stories to featured authors purely by lowercase name substring/equality. Any user can set `name = "Aesop"` or `"Jane Austen"` via `PATCH /api/v1/auth/me` and inject arbitrary stories into official catalog author pages.
- **How to Fix:**
  - Deduplicate any colliding handles during `init_db()` migration and add `CREATE UNIQUE INDEX IF NOT EXISTS idx_users_handle_lower ON users(LOWER(handle))` in `backend/core/database.py`.
  - In `backend/services/auth_service.py`:
    - Auto-disambiguate default handles on `register_user()` if the email prefix is already taken (e.g., `@reader_a1b2`).
    - Check handle uniqueness in `update_current_user()` and raise `HTTPException(status_code=409, detail="Handle is already taken.")` on collision.
    - Reject reserved classic catalog author names (`FEATURED_CATALOG_AUTHORS` + seeded classic authors) in both `register_user` and `update_current_user`.
  - In `StoryStore.matchesAuthor(_:author:)` (`frontend/FableApp/Features/Library/ViewModels/StoryStore.swift` lines `814–833`), ensure official catalog author pages only match catalog works (`story.ownerUserId == nil`).

#### 4. `SEC-04` — Simulator Automation Hooks in Production Binary
- **Where:**
  - `frontend/FableApp/App/ContentView.swift` lines `56–65` and `187–311` (`runUITourIfRequested`, `AUTO_UI_TOUR`, `AUTO_GUEST_LOGIN`, `AUTO_SELECT_FILTER`).
  - `frontend/FableApp/Features/Library/Views/LibraryView.swift` lines `513–530` (`autoOpenMangaIfRequested`, `AUTO_OPEN_MANGA`).
- **How to Fix:**
  - Gate the body of `runUITourIfRequested()` and `autoOpenMangaIfRequested()` inside `#if DEBUG ... #endif`.

---

### Phase 2: Backend Performance & Database Scalability (P1)

#### 5. `PERF-01` — Synchronous SQLite `BEGIN IMMEDIATE` Disk Write on Every `GET` Request
- **Where:**
  - `backend/core/rate_limit.py` lines `114–174` (`SharedTokenBucketRateLimiter.is_allowed`) and lines `249–268` (`RateLimitMiddleware.dispatch`).
  - Every HTTP request—even read-only `GET /api/v1/stories`—opens a SQLite connection and executes `BEGIN IMMEDIATE` + `DELETE` + `SELECT` + `INSERT/UPDATE` + `COMMIT`.
- **How to Fix:**
  - Use the existing in-memory `SlidingWindowRateLimiter` (`backend/core/rate_limit.py` lines `46–86`) for safe read-only HTTP methods (`GET`, `HEAD`, `OPTIONS`), while keeping `SharedTokenBucketRateLimiter` for mutating methods (`POST`, `PUT`, `PATCH`, `DELETE`).
  - Ensure existing rate-limit unit tests in `backend/tests/test_api_v1.py` still pass (check how `test_api_v1.py` tests `RateLimitMiddleware` and `SharedTokenBucketRateLimiter`).

#### 6. `PERF-02` — `1 + N` SQL Query Problem on Story Listings
- **Where:**
  - `backend/services/story_service.py` lines `89–102` (`row_to_story_dto`):
    ```python
    row_count = conn.execute(
        "SELECT COUNT(DISTINCT owner_user_id || ':' || story_id) FROM account_shelf_items WHERE story_id = ?",
        (row["id"],),
    ).fetchone()[0]
    ```
  - Called inside a loop in `get_stories()` (lines `110–169`) for up to 100 stories per request.
- **How to Fix:**
  - Include `COALESCE(rc.read_count, 0) AS computed_read_count` via a `LEFT JOIN` subquery in `get_stories()` and `get_story_by_id()`, and have `row_to_story_dto()` read `row["computed_read_count"]` when present before falling back to a single query.
  - Add indexes `idx_stories_owner_created` and `idx_shelf_story_owner` in `backend/core/database.py`.

#### 7. `PERF-03` — Uncached Sequential OpenLibrary HTTP Calls in `GET /api/v1/authors/top`
- **Where:**
  - `backend/services/story_service.py` lines `408–498` (`get_top_authors`).
- **How to Fix:**
  - Add an in-memory TTL cache (`_TOP_AUTHORS_CACHE: tuple[float, list[AuthorDTO]] | None = None`, TTL `3600s`) and invalidate it when `create_story`, `update_story`, or `delete_story` mutates the `stories` table.
  - Run OpenLibrary HTTP fetches in parallel using `asyncio.gather`.

---

### Phase 3: Complete Domain Lifecycle & App Store Compliance (P1)

#### 8. `DOM-01` — In-App Account Deletion (`DELETE /api/v1/auth/me`)
- **Where:**
  - `backend/api/v1/endpoints/auth.py` and `backend/services/auth_service.py` lack account deletion.
  - Required by **Apple App Store Review Guideline 5.1.1(v)**.
- **How to Fix:**
  - Add `@router.delete("/me", status_code=204)` in `backend/api/v1/endpoints/auth.py`.
  - Implement `delete_current_user(access_token: str)` in `backend/services/auth_service.py` that resolves the authenticated user and atomically deletes their rows from `user_sessions`, `password_reset_tokens`, `account_shelf_items`, `reading_sessions`, `stories` (`WHERE owner_user_id = ?`), and `users` (`WHERE id = ?`).
  - Add `deleteAccount(accessToken:)` to `StoryAPIService.swift`, `deleteCurrentAccount()` to `StoryStore.swift`, and a destructive `"Delete Account"` button with confirmation alert in `ProfileView.swift`.

#### 9. `DOM-02` — Story Edit/Delete Endpoints & Author Display Name Sync
- **Where:**
  - `backend/api/v1/endpoints/stories.py` only has `GET` and `POST`.
  - `backend/services/auth_service.py` lines `252–269` updates `users.name` without updating `stories.author`.
- **How to Fix:**
  - Add `UpdateStoryRequest` in `backend/models/schemas.py` and `PATCH /api/v1/stories/{story_id}` + `DELETE /api/v1/stories/{story_id}` in `backend/api/v1/endpoints/stories.py` and `backend/services/story_service.py` enforcing `owner_user_id == user.id` (`403 Forbidden` if another user tries to modify/delete, `404` if not found).
  - In `auth_service.update_current_user()`, execute `UPDATE stories SET author = ?, updated_at_utc = ? WHERE owner_user_id = ?` in the same transaction when `name` changes.

---

### Phase 4: iOS Client Resilience & State Simplification (P2)

#### 10. `IOS-01` — Replace `fatalError` in `PersistenceService.init()`
- **Where:**
  - `frontend/FableApp/Features/Library/Services/PersistenceService.swift` lines `15–33`.
- **How to Fix:**
  - If `ModelContainer(for: schema, configurations: [modelConfiguration])` throws, attempt to remove the default SwiftData store URL and retry once; if it still throws, initialize with `ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)` instead of crashing with `fatalError`.

#### 11. `IOS-02` — Consolidate Shelf State Persistence
- **Where:**
  - `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift` lines `430–520`.
- **How to Fix:**
  - Keep SwiftData (`StoryEntity`) + `/api/v1/shelf` as the source of truth, migrating any legacy `UserDefaults` (`fable_shelf_state_<owner>`) state once.

---

## 5. Known Gotchas & Compiler Notes from This Session

1. **Swift Closure Type Inference in `StoryStore.swift`:**
   - Around line 880 in `StoryStore.swift` (`availableGenres`), keep `let candidates: [(name: String, matcher: (String) -> Bool)] = [...]` as a single typed array literal and filter inside the `for (name, matcher) in candidates` loop (`if !Self.isMangaEnabled && name == "Manga" { continue }`). Splitting it into `candidates.append(contentsOf: [...])` causes Swift compiler error `Cannot infer type of closure parameter '$0' without a type annotation`.
2. **`ReaderTheme` Enum Cases:**
   - The dark themes in `ReaderTheme` (`frontend/FableApp/Core/Models/Models.swift`) are `.parchment`, `.sepia`, `.midnight`, and `.oled` (there is **no** `.night` case).
3. **Verification Commands:**
   - **Backend Pytest Suite:**
     ```bash
     PYTHONPATH=.:backend .venv/bin/pytest backend -v
     ```
     *(Latest run on `feat/security-and-architecture-remediation`: `117 passed, 6 skipped` locally without a PostgreSQL instance; `test_postgres_database.py` runs in CI `postgres-verification`.)*
   - **iOS Release Config Validation:**
     ```bash
     CONFIGURATION=Release FABLE_API_BASE_URL=https://api.example.com/api/v1 scripts/validate_ios_release_config.sh
     ```
   - **iOS Xcode Test Suite:**
     ```bash
     xcodebuild -project frontend/FableApp.xcodeproj -scheme FableApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=- test
     ```
     *(Latest run on `feat/security-and-architecture-remediation`: `28 passed, 0 failed`. Ad-hoc signing flags provide simulated Keychain entitlements for `KeychainSecurityTests`; adjust `name=iPhone 17 Pro` to match an installed Simulator via `xcrun simctl list devices available`.)*
   - **iOS Release Simulator Build:**
     ```bash
     xcodebuild -project frontend/FableApp.xcodeproj -scheme FableApp -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath build/ReleaseDerivedData FABLE_API_BASE_URL=https://api.example.com/api/v1 CODE_SIGNING_ALLOWED=NO build
     ```
