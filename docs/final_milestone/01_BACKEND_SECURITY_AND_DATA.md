# Domain 01: Backend Security, Data Isolation & Authentication Contract

**Domain:** Core Data Architecture, Multi-Tenancy & Security  
**Status:** In Progress  
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
- **Parameters:** `device_id: UUID` (query parameter).
- **Response:** List of `ShelfSyncItemDTO` belonging exclusively to that `device_id`.

### 2.3 User Authentication: `/api/v1/auth`
- **`POST /api/v1/auth/register`**: Registers a new user with PBKDF2-SHA256 salted password hashing.
- **`POST /api/v1/auth/login`**: Authenticates credentials and issues a secure Bearer token.
- **`GET /api/v1/auth/me`**: Returns current authenticated user profile (`UserDTO`).

---

## 3. Changes Applied & File Manifest

| File Path | Action | Description |
| :--- | :--- | :--- |
| `backend/core/database.py` | MODIFIED | Added compound PK `(device_id, story_id)` to `shelf_items`, created `users` table with `idx_users_email`. |
| `backend/schemas/schemas.py` | MODIFIED | Added camelCase serialization aliases to shelf DTOs; defined `UserDTO`, `LoginRequest`, `RegisterRequest`, `AuthResponse`. |
| `backend/services/shelf_sync.py` | VERIFIED | Enforces `device_id` partitioning across SELECT/INSERT/UPDATE; normalizes ISO timestamps with `to_utc()`; implemented `get_shelf()`. |
| `backend/api/v1/endpoints/shelf.py` | VERIFIED | Added `GET /shelf` endpoint with query validation against `deviceId`. |
| `backend/test_main.py` | VERIFIED | Validated Last-Write-Wins and multi-device shelf isolation (13/13 tests passing). |
| `backend/services/auth_service.py` | PENDING | Security service providing PBKDF2 password hashing, verification, and token management. |
| `backend/api/v1/endpoints/auth.py` | PENDING | Authentication router exposing register, login, and me endpoints. |

---

## 4. Verification & Test Evidence

- **Test Suite Run:** `PYTHONPATH=backend .venv/bin/pytest backend/test_main.py`
- **Result:** `13 passed, 2 warnings in 3.54s`
- **Verified Scenarios:**
  - `test_last_write_wins_resolution`: Stale client sync rejected, fresh client sync accepted using camelCase aliases.
  - `test_multi_tenant_device_shelf_isolation`: Device A (progress `0.75`) and Device B (progress `0.20`) update identical `story_id` without collision; querying `GET /api/v1/shelf?deviceId=...` returns isolated states.

