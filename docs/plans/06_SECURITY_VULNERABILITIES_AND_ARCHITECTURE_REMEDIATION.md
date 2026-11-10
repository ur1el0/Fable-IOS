# Feature Plan 06: Security Vulnerabilities & Architectural Remediation Plan

**Document Version:** 1.0.0  
**Architectural Scope:** Authentication Hardening, SQLite Concurrency & Query Optimization, Content/Account Lifecycle Completion, iOS State Resilience  
**Backend Stack:** Python 3.9+ / FastAPI / Pydantic v2 / SQLite (WAL)  
**Client Stack:** Swift 5.9+ / SwiftUI / SwiftData  

---

## 1. Executive Summary & Audit Scope

Following the strategic decision to focus **Fable iOS** exclusively on open-source books, classic fables, and community manuscripts (`StoryStore.isMangaEnabled = false`), a full-stack security and architectural audit was conducted across the FastAPI backend (`backend/`) and the native iOS client (`frontend/FableApp/`).

This document records all **non-manga security vulnerabilities**, **database/backend scalability bottlenecks**, **incomplete domain lifecycle planning**, and **iOS client architectural flaws**, paired with a 4-phase engineering remediation plan.

---

## 2. Vulnerability & Architectural Deficit Matrix

| ID | Category | Severity | Component / File | Finding Summary |
|---|---|---|---|---|
| **SEC-01** | Auth Rate Limiting & DoS | **P0 (High)** | `backend/api/v1/endpoints/auth.py`<br>`backend/services/auth_rate_limit.py` | `POST /api/v1/auth/password-reset/confirm` lacks `enforce_auth_rate_limit()`. Each call acquires a `BEGIN IMMEDIATE` SQLite write lock and runs 600,000 PBKDF2-HMAC-SHA256 iterations on match. Additionally, `auth_rate_limits` has no maximum row cap. |
| **SEC-02** | Reverse-Proxy IP Collapse | **P0 (High)** | `backend/api/v1/endpoints/auth.py`<br>`backend/core/rate_limit.py` | `/auth/register`, `/auth/login`, and `/auth/password-reset/request` pass `request.client.host` directly instead of the trusted-proxy-aware IP extractor. Behind Nginx/Caddy/Docker, all users share the proxy IP, so 5 registrations in 15 minutes locks out all new registrations globally. |
| **SEC-03** | Author Impersonation & Handle Collisions | **P0 (High)** | `backend/core/database.py`<br>`backend/services/auth_service.py`<br>`StoryStore.swift` | `users.handle` lacks a `UNIQUE` constraint. Worse, `POST /api/v1/stories` copies `user.name` into `stories.author` and `StoryStore.matchesAuthor` matches by plain string name—allowing any user to rename themselves `"Aesop"` or `"Jane Austen"` and inject stories into official catalog author pages. |
| **SEC-04** | Release Binary Test Hooks | **P0 (Medium)** | `ContentView.swift`<br>`LibraryView.swift` | Simulator automation hooks (`AUTO_UI_TOUR`, `AUTO_GUEST_LOGIN`, `AUTO_SELECT_FILTER`, `AUTO_OPEN_MANGA`) are compiled unconditionally into production builds instead of being gated behind `#if DEBUG`. |
| **PERF-01** | Per-GET SQLite Disk Write Serialization | **P1 (High)** | `backend/core/rate_limit.py` | `SharedTokenBucketRateLimiter.is_allowed` opens a SQLite connection and executes `BEGIN IMMEDIATE` + `UPDATE request_rate_limit_buckets` + `COMMIT` on **every single read-only HTTP `GET` request**, serializing all concurrent readers behind a global disk write lock. |
| **PERF-02** | `1 + N` SQL Queries on Story Listing | **P1 (High)** | `backend/services/story_service.py`<br>`backend/core/database.py` | `get_stories()` calls `row_to_story_dto()` in a loop, executing a separate `SELECT COUNT(DISTINCT ...)` query against `account_shelf_items` for every returned story row (up to 101 queries per catalog request). |
| **PERF-03** | Uncached Sequential Upstream Calls | **P1 (Medium)** | `backend/services/story_service.py` | `GET /api/v1/authors/top` (`get_top_authors()`) has no TTL cache and executes up to 7 sequential HTTP calls to `openlibrary.org` (`7 × 5s = 35s` worst-case blocking latency) on every iOS sync. |
| **DOM-01** | Missing In-App Account Deletion | **P1 (Compliance)** | `backend/api/v1/endpoints/auth.py`<br>`ProfileView.swift` | Users can register accounts in-app, but there is no `DELETE /api/v1/auth/me` endpoint or UI control. **Apple App Store Review Guideline 5.1.1(v)** mandates in-app account deletion for any app supporting account creation. |
| **DOM-02** | Write-Only Story Lifecycle & Name Drift | **P1 (Medium)** | `backend/api/v1/endpoints/stories.py`<br>`backend/services/auth_service.py` | `stories.py` only implements `POST /api/v1/stories` (no `PATCH` or `DELETE` for story owners, and no multi-chapter append endpoint). Updating a user's display name via `PATCH /api/v1/auth/me` also leaves stale `stories.author` values on previously published works. |
| **IOS-01** | Fatal Crash on SwiftData Schema Change | **P2 (Medium)** | `PersistenceService.swift` | `PersistenceService.init()` calls `fatalError("Failed to initialize SwiftData ModelContainer")` if local SQLite schema migration fails, permanently crashing the app on launch after schema updates. |
| **IOS-02** | Triple-Duplicated Shelf Persistence | **P2 (Low)** | `StoryStore.swift`<br>`PersistenceService.swift` | Reading progress and bookmarks are duplicated across three stores (`SwiftData` `StoryEntity`, `UserDefaults` `fable_shelf_state_<owner>`, and `/api/v1/shelf`), requiring brittle 3-way reconciliation logic on boot. |

---

## 3. Phased Engineering Remediation Plan

### Phase 1: Critical Security & Authentication Hardening (P0)

#### 1.1 Throttle Password Reset Confirmation & Bound `auth_rate_limits` (`SEC-01`)
- **Target Files:** `backend/api/v1/endpoints/auth.py`, `backend/services/auth_rate_limit.py`
- **Implementation:**
  1. Register a `"password_reset_confirm"` rule (`5 attempts / 15 min` per IP and per token prefix) in `AUTH_RATE_LIMIT_RULES`.
  2. Call `enforce_auth_rate_limit("password_reset_confirm", client_host=client_ip, identifier=payload.reset_token[:16])` at the top of `confirm_password_reset()` before touching `auth_service`.
  3. Add a `MAX_AUTH_RATE_LIMIT_BUCKETS = 10_000` cap in `_consume_bucket()` (`backend/services/auth_rate_limit.py`) to evict oldest buckets when the table reaches capacity.

#### 1.2 Unify Trusted-Proxy Client IP Extraction (`SEC-02`)
- **Target Files:** `backend/core/rate_limit.py`, `backend/api/v1/endpoints/auth.py`
- **Implementation:**
  1. Expose a public `extract_client_ip(request: Request) -> str` helper in `backend/core/rate_limit.py` that honors `FABLE_TRUST_PROXY_HEADERS` and `FABLE_TRUSTED_PROXY_CIDRS`.
  2. Replace all raw `request.client.host` references in `backend/api/v1/endpoints/auth.py` with `extract_client_ip(request)`.

#### 1.3 Enforce Unique Handles & Prevent Catalog Author Impersonation (`SEC-03`)
- **Target Files:** `backend/core/database.py`, `backend/services/auth_service.py`, `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift`
- **Implementation:**
  1. Add a unique index `CREATE UNIQUE INDEX IF NOT EXISTS idx_users_handle_lower ON users(LOWER(handle))` in `backend/core/database.py` (normalizing any legacy duplicates during startup migration).
  2. In `auth_service.py`, validate handle uniqueness on `PATCH /api/v1/auth/me` (returning `409 Conflict` if taken) and auto-append a short suffix on initial registration when derived from an email local-part.
  3. Block reserved catalog author names/handles (`Aesop`, `Jane Austen`, `Mary Shelley`, `Herman Melville`, `Bram Stoker`, `Lewis Carroll`, `Brothers Grimm`, `Arthur Conan Doyle`, `H. G. Wells`, `Edgar Allan Poe`) from being claimed by community accounts.
  4. In `StoryStore.matchesAuthor(_:author:)`, restrict official catalog author pages to catalog works (`ownerUserId == nil`) so community manuscripts cannot be injected into classic author bibliographies.

#### 1.4 Gate Simulator Automation Hooks Behind `#if DEBUG` (`SEC-04`)
- **Target Files:** `frontend/FableApp/App/ContentView.swift`, `frontend/FableApp/Features/Library/Views/LibraryView.swift`
- **Implementation:**
  1. Wrap `runUITourIfRequested()`, `AUTO_UI_TOUR`, `AUTO_GUEST_LOGIN`, `AUTO_SELECT_FILTER`, and `AUTO_OPEN_MANGA` in `#if DEBUG ... #endif` blocks so release binaries contain zero automation backdoors.

---

### Phase 2: Backend Performance & Database Scalability (P1)

#### 2.1 Fast-Path In-Memory Rate Limiting for Read-Only Requests (`PERF-01`)
- **Target File:** `backend/core/rate_limit.py`
- **Implementation:**
  1. Route idempotent read methods (`GET`, `HEAD`, `OPTIONS`) through the thread-safe in-memory `SlidingWindowRateLimiter` instead of executing a synchronous `BEGIN IMMEDIATE` SQLite write on every read request.
  2. Retain `SharedTokenBucketRateLimiter` (SQLite-backed cross-worker bucket) for state-mutating methods (`POST`, `PUT`, `PATCH`, `DELETE`) and authentication routes.

#### 2.2 Single-Query `LEFT JOIN` Aggregation for Story Read Counts (`PERF-02`)
- **Target Files:** `backend/services/story_service.py`, `backend/core/database.py`
- **Implementation:**
  1. Replace the per-row `SELECT COUNT(DISTINCT ...)` inside `row_to_story_dto()` with a single `LEFT JOIN` subquery in `get_stories()` and `get_story_by_id()`:
     ```sql
     SELECT s.*, COALESCE(rc.read_count, 0) AS computed_read_count
     FROM stories s
     LEFT JOIN (
         SELECT story_id, COUNT(DISTINCT owner_user_id) AS read_count
         FROM account_shelf_items
         GROUP BY story_id
     ) rc ON rc.story_id = s.id
     ```
  2. Add composite indexes in `backend/core/database.py`:
     - `CREATE INDEX IF NOT EXISTS idx_stories_owner_created ON stories(owner_user_id, created_at_utc DESC)`
     - `CREATE INDEX IF NOT EXISTS idx_shelf_story_owner ON account_shelf_items(story_id, owner_user_id)`

#### 2.3 Concurrent & TTL-Cached Top Authors Directory (`PERF-03`)
- **Target File:** `backend/services/story_service.py`
- **Implementation:**
  1. Refactor `get_top_authors()` to fetch OpenLibrary metadata concurrently via `asyncio.gather(..., return_exceptions=True)` instead of sequential `for` loop awaits.
  2. Cache the assembled `[AuthorDTO]` list in memory with a `3600s` (1-hour) TTL, invalidated automatically when a new story is published.

---

### Phase 3: Domain Lifecycle & App Store Compliance (P1)

#### 3.1 In-App Account Deletion (`DOM-01`)
- **Target Files:** `backend/api/v1/endpoints/auth.py`, `backend/services/auth_service.py`, `frontend/FableApp/Features/Profile/Views/ProfileView.swift`, `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift`
- **Implementation:**
  1. Add `DELETE /api/v1/auth/me` in `auth.py` and `delete_current_user()` in `auth_service.py` executing an atomic transaction that removes:
     - `user_sessions` (`WHERE user_id = ?`)
     - `password_reset_tokens` (`WHERE user_id = ?`)
     - `account_shelf_items` (`WHERE owner_user_id = ?`)
     - `reading_sessions` (`WHERE owner_user_id = ?`)
     - `stories` (`WHERE owner_user_id = ?`)
     - `users` (`WHERE id = ?`)
  2. Add a destructive confirmation alert (`"Delete Account Permanently"`) in `ProfileView.swift` that calls `DELETE /api/v1/auth/me` and clears local keychain/SwiftData state.

#### 3.2 Full Story Author CRUD & Author Name Sync (`DOM-02`)
- **Target Files:** `backend/api/v1/endpoints/stories.py`, `backend/services/story_service.py`, `backend/services/auth_service.py`, `backend/models/schemas.py`
- **Implementation:**
  1. Add `PATCH /api/v1/stories/{story_id}` and `DELETE /api/v1/stories/{story_id}` gated by `owner_user_id == current_user.id` (`403 Forbidden` if another user attempts mutation).
  2. In `auth_service.update_current_user()`, update `stories SET author = ? WHERE owner_user_id = ?` inside the same SQLite transaction whenever a user changes their display name.

---

### Phase 4: iOS Client Resilience & State Simplification (P2)

#### 4.1 Non-Fatal SwiftData Recovery (`IOS-01`)
- **Target File:** `frontend/FableApp/Features/Library/Services/PersistenceService.swift`
- **Implementation:**
  1. Replace `fatalError("Failed to initialize SwiftData ModelContainer: \(error)")` with a 3-step recovery cascade:
     - Attempt standard on-disk `ModelContainer`.
     - If migration/corruption throws, delete the local default store files and retry on-disk creation once.
     - If disk creation still fails, fall back to `ModelConfiguration(isStoredInMemoryOnly: true)` so the app always launches.

#### 4.2 Single Local Source of Truth for Shelf State (`IOS-02`)
- **Target Files:** `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift`, `frontend/FableApp/Features/Library/Services/PersistenceService.swift`
- **Implementation:**
  1. Consolidate local reading progress and bookmark persistence into SwiftData (`StoryEntity` scoped by `ownerUserId`) synced with `/api/v1/shelf`, migrating any existing `UserDefaults` (`fable_shelf_state_<owner>`) entries once and retiring the redundant `UserDefaults` mirror.

---

## 4. Verification & Acceptance Gate

1. **Automated Backend Suite (`pytest`):**
   - Rate-limit tests for `/api/v1/auth/password-reset/confirm` and trusted-proxy `X-Forwarded-For` extraction.
   - Handle uniqueness (`409 Conflict`), reserved author name rejection, and display-name propagation to `stories.author`.
   - Story `PATCH` / `DELETE` ownership authorization (`200`/`204` for owner, `403` for non-owner) and `DELETE /api/v1/auth/me` cascade verification.
2. **Automated iOS Suite (`xcodebuild test`):**
   - Verify `PersistenceService` fallback recovery, catalog vs. community author isolation, and full `AppHealthTests` pass rate.
