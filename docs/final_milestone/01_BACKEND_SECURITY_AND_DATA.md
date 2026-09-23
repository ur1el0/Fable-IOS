# Domain 01: Backend Security, Data Isolation & Authentication Contract

**Domain:** Core Data Architecture, Multi-Tenancy & Security  
**Status:** Completed & Verified  
**Feature Branch:** `feature/final-milestone`

---

## 1. Problem Statement & Root Cause Analysis

### 1.1 Multi-Tenant Cross-Contamination
In the initial prototype, the SQLite database table `shelf_items` defined `story_id TEXT PRIMARY KEY`. 
- **The Defect:** When multiple client devices or users synchronized their shelves with the backend, they shared and overwrote a single row per story. If User A marked *Dracula* as completed at progress 1.0, and User B opened *Dracula* at progress 0.1, User B's sync either overwrote User A's record or was rejected as a stale timestamp against an entirely different person's progress.
- **The Architectural Fix:** We altered the database primary key to a compound key: `PRIMARY KEY (device_id, story_id)`. Every shelf item record is strictly namespaced by the requesting device. Additionally, an index `idx_shelf_items_device` was added on `device_id` to guarantee $O(\log N)$ retrieval times when fetching a full shelf.

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
- **The Requirement:** Provide NIST-compliant PBKDF2 password hashing (SHA-256, 100,000 iterations, 16-byte cryptographically secure salt) and stateless bearer token issuance for reader account creation, profile persistence, and multi-device identity.
- **The Architectural Fix:** Implemented `backend/services/auth_service.py` with `hash_password`, constant-time `verify_password` using `hmac.compare_digest`, `register_user`, `login_user`, and `get_current_user`. Exposed via `/api/v1/auth` endpoints with proper `try...finally: conn.close()` resource cleanup.

---

## 2. API Contract & Endpoint Specifications

### 2.1 Shelf Synchronization: `POST /api/v1/shelf/sync`
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
- **Reconciliation Logic:** Last-Write-Wins (LWW) resolution isolated by `(device_id, story_id)`. If the client timestamp is newer than the stored record for that device, the record updates. If older, the server returns the authoritative server state.

### 2.2 Shelf Retrieval: `GET /api/v1/shelf`
- **Parameters:** `device_id: UUID` (query parameter `deviceId`).
- **Response:** List of `ShelfSyncItemDTO` belonging exclusively to that `device_id`.

### 2.3 User Authentication: `/api/v1/auth`
- **`POST /api/v1/auth/register`**: Registers a new user with PBKDF2-SHA256 salted password hashing. Returns HTTP 201 Created and `AuthResponse` (`accessToken`, `user`).
- **`POST /api/v1/auth/login`**: Authenticates credentials and issues a secure Bearer token. Returns `AuthResponse`.
- **`GET /api/v1/auth/me`**: Returns current authenticated user profile (`UserDTO`) based on `Authorization: Bearer <token>`.

---

## 3. Changes Applied & File Manifest

| File Path | Action | Description |
| :--- | :--- | :--- |
| `backend/core/database.py` | VERIFIED | Added compound PK `(device_id, story_id)` to `shelf_items`, created `users` table with `idx_users_email`. |
| `backend/schemas/schemas.py` | VERIFIED | Added camelCase serialization aliases to shelf DTOs; defined `UserDTO`, `LoginRequest`, `RegisterRequest`, `AuthResponse`. |
| `backend/schemas/__init__.py` | VERIFIED | Exported auth DTOs for modular package access. |
| `backend/services/shelf_sync.py` | VERIFIED | Enforces `device_id` partitioning across SELECT/INSERT/UPDATE; normalizes ISO timestamps with `to_utc()`; implemented `get_shelf()`. |
| `backend/api/v1/endpoints/shelf.py` | VERIFIED | Added `GET /shelf` endpoint with query validation against `deviceId`. |
| `backend/services/auth_service.py` | VERIFIED | Security service providing PBKDF2 password hashing, verification, token sessions, and database cleanup. |
| `backend/services/__init__.py` | VERIFIED | Exported `auth_service` and `get_shelf`. |
| `backend/api/v1/endpoints/auth.py` | VERIFIED | Authentication router exposing register, login, and me endpoints. |
| `backend/api/v1/api.py` | VERIFIED | Mounted `auth.router` into API v1. |
| `backend/test_main.py` | VERIFIED | Comprehensive test suite covering LWW, multi-tenant isolation, auth flow, duplicate registration conflicts, invalid passwords, and unauthorized access (17/17 tests passing). |

---

## 4. Verification & Test Evidence

- **Test Suite Command:** `PYTHONPATH=backend .venv/bin/pytest backend/test_main.py`
- **Result:** `17 passed, 2 warnings in 4.33s`
- **Verified Test Cases:**
  1. `test_health_check`
  2. `test_get_stories_includes_full_editorial_catalog`
  3. `test_story_dto_camelcase_serialization_contract`
  4. `test_get_story_chapters`
  5. `test_extract_chapters_from_text`
  6. `test_get_genres_endpoint`
  7. `test_get_top_authors_endpoint`
  8. `test_get_update_feed_endpoint`
  9. `test_create_story`
  10. `test_last_write_wins_resolution`
  11. `test_multi_tenant_device_shelf_isolation`
  12. `test_package_modularity_imports`
  13. `test_get_gutenberg_public_stories`
  14. `test_register_and_login_auth_flow`
  15. `test_register_duplicate_email_conflict`
  16. `test_login_invalid_password`
  17. `test_auth_me_unauthorized`

