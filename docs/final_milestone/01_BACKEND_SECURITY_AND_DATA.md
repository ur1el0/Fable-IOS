# Domain 01: Backend Security, Data Isolation & Authentication Contract

**Domain:** Core Data Architecture, Multi-Tenancy & Security  
**Status:** Completed & Verified  
**Feature Branch:** `feature/live-data-and-button-wiring`

---

## 1. Problem Statement & Root Cause Analysis

### 1.1 Multi-Tenant Cross-Contamination
In the initial prototype, the SQLite database table `shelf_items` defined `story_id TEXT PRIMARY KEY`. 
- **The Defect:** When multiple client devices or users synchronized their shelves with the backend, they shared and overwrote a single row per story. If User A marked *Dracula* as completed at progress 1.0, and User B opened *Dracula* at progress 0.1, User B's sync either overwrote User A's record or was rejected as a stale timestamp against an entirely different person's progress.
- **The Initial Fix:** Shelf records were first partitioned by device, but a caller-controlled device identifier did not prove account ownership.
- **The Current Contract:** Authenticated shelf records are stored in `account_shelf_items` with key `(owner_user_id, device_id, story_id)`. Both reads and writes resolve the account from the bearer token. Legacy device-only rows are not exposed by these endpoints.

### 1.2 Offset-Naive vs Offset-Aware Datetime Crashes
- **The Defect:** When SQLite stores ISO-8601 strings (e.g. `2026-09-20T15:30:00Z` or `2026-09-20T15:30:00`), Python's `datetime.fromisoformat()` can yield either an offset-naive datetime or an offset-aware datetime depending on the trailing `Z` or timezone offset. When comparing `client_time > server_time`, Python raises:
  ```python
  TypeError: can't compare offset-naive and offset-aware datetimes
  ```
- **The Architectural Fix:** Implement a strict datetime normalizer `to_utc(dt: datetime) -> datetime` in `shelf_sync.py` that guarantees all timestamps are converted to UTC and given explicit `timezone.utc` awareness before comparison.

### 1.3 Contract Parity & Swift JSON Decoding
- **The Defect:** Swift models use idiomatic `camelCase` (`storyId`, `readingProgress`, `isBookmarked`), while standard Python backend models use `snake_case` (`story_id`, `reading_progress`). Without explicit serialization aliases, the Swift `JSONDecoder` required custom decoding strategies or failed to parse payload keys.
- **The Architectural Fix:** Configured Pydantic v2 `Field(..., alias="storyId", serialization_alias="storyId")` across all client-facing DTOs in `backend/schemas/schemas.py`, enabling zero-cost deserialization in Swift while preserving Pythonic snake_case internally.

### 1.4 Secure User Authentication & Session Handling
- **The Requirement:** Hash account passwords with salted PBKDF2-HMAC-SHA256 and support bearer authentication across backend process restarts with explicit session expiry and revocation.
- **The Architectural Fix:** Implemented salted PBKDF2-HMAC-SHA256 password hashes with constant-time comparison. Random bearer tokens are represented in SQLite by SHA-256 digests, expire after 30 days, and are revoked by `/api/v1/auth/logout`. Authenticated reading-session events and `/api/v1/auth/me/stats` provide account-scoped statistics.

---

## 2. API Contract & Endpoint Specifications

### 2.1 Shelf Synchronization: `POST /api/v1/shelf/sync`
- **Authorization:** Required. Shelf rows are keyed by account, device, and story.
- **Request Payload (`ShelfSyncPayload`):**
  ```json
  {
    "deviceId": "9e2118cb-eb72-46b1-8235-5d522dfcd8a0",
    "items": [
      {
        "storyId": "b1b16e00-...",
        "readingProgress": 0.45,
        "isBookmarked": true,
        "isCompleted": false,
        "updatedAtUtc": "2026-09-20T15:30:00Z"
      }
    ]
  }
  ```
- **Reconciliation Logic:** Last-Write-Wins (LWW) resolution is isolated by `(owner_user_id, device_id, story_id)`. Both shelf reads and writes require a valid bearer token; a device identifier alone cannot access another account's data.

### 2.2 Shelf Retrieval: `GET /api/v1/shelf`
- **Parameters:** `deviceId: UUID` query parameter and `Authorization: Bearer <token>`.
- **Response:** List of `ShelfSyncItemDTO` belonging exclusively to the authenticated account and device.

### 2.3 Reading Activity: `/api/v1/auth/me/reading-sessions` and `/api/v1/auth/me/stats`
- **Authorization:** Required. Session ingestion is idempotent by event ID; the response reports completed stories, minutes read, and consecutive UTC reading days.

### 2.4 User Authentication: `/api/v1/auth`
- **`POST /api/v1/auth/register`**: Registers a new user with PBKDF2-SHA256 salted password hashing. Returns HTTP 201 Created and `AuthResponse` (`accessToken`, `user`).
- **`POST /api/v1/auth/login`**: Authenticates credentials and issues a secure Bearer token. Returns `AuthResponse`.
- **`GET /api/v1/auth/me`**: Returns current authenticated user profile (`UserDTO`) based on `Authorization: Bearer <token>`.
- **`POST /api/v1/auth/logout`**: Revokes the active bearer session.
- Bearer token bytes are never stored in the database; SHA-256 digests are stored with a 30-day expiry.

---

## 3. Changes Applied & File Manifest

| File Path | Action | Description |
| :--- | :--- | :--- |
| `backend/core/database.py` | VERIFIED | Creates account-scoped shelf records, users, expiring session digests, and reading-session events. |
| `backend/schemas/schemas.py` | VERIFIED | Added camelCase serialization aliases to shelf DTOs; defined `UserDTO`, `LoginRequest`, `RegisterRequest`, `AuthResponse`. |
| `backend/schemas/__init__.py` | VERIFIED | Exported auth DTOs for modular package access. |
| `backend/services/shelf_sync.py` | VERIFIED | Enforces user and device partitioning across SELECT/INSERT/UPDATE; normalizes ISO timestamps with `to_utc()`. |
| `backend/api/v1/endpoints/shelf.py` | VERIFIED | Added `GET /shelf` endpoint with query validation against `deviceId`. |
| `backend/services/auth_service.py` | VERIFIED | Security service providing PBKDF2 password hashing, verification, token sessions, and database cleanup. |
| `backend/services/__init__.py` | VERIFIED | Exported `auth_service` and `get_shelf`. |
| `backend/api/v1/endpoints/auth.py` | VERIFIED | Authentication router exposes register, login, profile update, logout, owned stories, reading events, and statistics. |
| `backend/api/v1/api.py` | VERIFIED | Mounted `auth.router` into API v1. |
| `backend/test_main.py` | VERIFIED | 36 tests cover provider contracts, account ownership, shelf isolation, persistent sessions, statistics, and authorization. |

---

## 4. Verification & Test Evidence

- **Container Build:** `docker build -t fable-backend:test -f backend/Dockerfile .`
- **Test Command:** `docker run --rm --entrypoint pytest fable-backend:test test_main.py -v`
- **Result:** `36 passed, 1 warning` (Starlette TestClient deprecation notice).
- **Coverage includes:** Empty fresh catalog, DTO aliases and privacy, live provider metadata, chapter retrieval, owner-only publishing, account-isolated shelf sync, idempotent reading sessions, stats isolation, persisted bearer sessions, logout revocation, and database-path override, and exact-ID legacy catalog cleanup.
- The iOS simulator build and on-device diagnostics were not run in this Fedora workspace because Swift, Xcode, and `xcrun` are unavailable.

- Startup cleanup deletes chapters and story rows for the twelve exact UUIDs from the retired demo catalog; user-authored stories with similar titles are preserved.
