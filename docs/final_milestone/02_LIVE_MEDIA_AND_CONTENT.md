# Domain 02: Live Media, Content Pipelines & Device Affinity

**Domain:** Remote Media Architecture, CDN Ingestion & Client Identity  
**Status:** Completed & Verified  
**Feature Branch:** `feature/final-milestone`

---

## 1. Problem Statement & Root Cause Analysis

### 1.1 Live Remote Media Bypassed in SwiftUI Views
- **The Defect:** While the backend delivered `imageUrl` on genres, `avatarImageUrl` on writers, and `coverImageUrl` on Gutenberg/editorial stories, several SwiftUI views bypassed these remote fields:
  1. `GenreCategory` and `Writer` models in Swift only defined `imageName: String` and `avatarImageName: String`, causing the Swift `JSONDecoder` to silently drop remote URLs.
  2. `ExploreView` passed `genre.imageName` and `writer.avatarImageName` directly to `FableImageView`, ignoring live media.
  3. `ProfileView` and `ReaderView` directly referenced `story.coverImageName` instead of `story.effectiveCoverImage`. If a story had a live Gutenberg cover URL, these views rendered a generic procedural fallback instead of the live cover.
  4. `LibraryView` and `ProfileView` hardcoded `"avatar_roosc"` in their header profile buttons rather than reading the active authenticated session avatar.
- **The Architectural Fix:** 
  - Added `imageUrl: String?` and `effectiveImage: String { imageUrl ?? imageName }` to `GenreCategory`.
  - Added `avatarImageUrl: String?` and `effectiveAvatar: String { avatarImageUrl ?? avatarImageName }` to `Writer`.
  - Standardized all views (`ExploreView`, `GenreDetailView`, `LibraryView`, `ProfileView`, `ReaderView`, `ShelfView`) to consume `effectiveCoverImage`, `effectiveAvatar`, and `effectiveImage`.
  - Bound profile button avatars dynamically to `auth.currentSession?.avatarName ?? "avatar_roosc"`.

### 1.2 Volatile Device Identity in Shelf Synchronization
- **The Defect:** In `StoryStore.swift`, `syncWithCloudBackend()` passed a fresh `UUID()` on every sync request.
  ```swift
  // Defective:
  let reconciled = try await apiService.syncShelf(deviceId: UUID(), items: shelfItems)
  ```
  Generating a new random UUID destroyed device identity, meaning the server treated every app launch as a distinct device.
- **The Architectural Fix:** Implemented a persistent, vendor-stable device identifier property on `StoryStore`:
  ```swift
  public var persistentDeviceId: UUID {
      let key = "fable_device_id"
      if let saved = UserDefaults.standard.string(forKey: key), let uuid = UUID(uuidString: saved) {
          return uuid
      }
      let newId = UUID()
      UserDefaults.standard.set(newId.uuidString, forKey: key)
      return newId
  }
  ```
  Now, shelf synchronization preserves continuous device affinity across restarts.

### 1.3 Flexible Dual-Format CodingKeys in Swift API Service
- **The Defect:** `StoryAPIService` used strict snake_case coding keys (`reconciled_items`, `server_time_utc`), which broke when communicating with the updated Pydantic v2 contract that outputs camelCase aliases (`reconciledItems`, `serverTimeUtc`).
- **The Architectural Fix:** Implemented resilient dual-key decoding in `ShelfSyncItem`, `ShelfSyncPayload`, and `ShelfSyncResponse` that attempts camelCase first with graceful fallback to snake_case.

---

## 2. Three-Tier Image Presentation Architecture

```
[ Remote URL (CDN / Gutendex) ] 
              │
              ▼ (Network Failure / Null URL)
[ Local Asset Catalog (UIImage) ]
              │
              ▼ (Asset Not Found)
[ Procedural Editorial Graphics (FableImageView) ]
```

1. **Tier 1 (Remote Image):** Loaded asynchronously via `AsyncImage` with progressive loading spinner.
2. **Tier 2 (Asset Catalog):** Loaded synchronously via `UIImage(named:)` if packaged locally.
3. **Tier 3 (Procedural Vector):** Algorithmic leather binding, gold-leaf monogram, and foil filigree borders rendered via SwiftUI native path shapes and gradients based on title/author hash.

---

## 3. Changes Applied & File Manifest

| File Path | Action | Description |
| :--- | :--- | :--- |
| `frontend/FableApp/Models/Models.swift` | VERIFIED | Added `imageUrl` to `GenreCategory` and `avatarImageUrl` to `Writer` with `effectiveImage` and `effectiveAvatar` properties. |
| `frontend/FableApp/Services/StoryAPIService.swift` | VERIFIED | Added dual-key camelCase/snake_case decoding to shelf DTOs; added `fetchShelf`, `register`, `login`, and `fetchCurrentUser` API methods. |
| `frontend/FableApp/ViewModels/StoryStore.swift` | VERIFIED | Added `persistentDeviceId` stored in `UserDefaults`; bound `syncWithCloudBackend()` to persistent device identity. |
| `frontend/FableApp/Views/ExploreView.swift` | VERIFIED | Bound genres to `effectiveImage` and writers to `effectiveAvatar`. |
| `frontend/FableApp/Views/ProfileView.swift` | VERIFIED | Bound profile avatar to active session; updated published and saved story lists to use `effectiveCoverImage`. |
| `frontend/FableApp/Views/LibraryView.swift` | VERIFIED | Bound header profile button to active session avatar. |
| `frontend/FableApp/Views/ReaderView.swift` | VERIFIED | Bound hero engraving vignette to `story.heroImageName ?? story.effectiveCoverImage`. |

---

## 4. Verification & Consistency Audit

- **Cover Image Usage Audit:** `grep -rn "coverImageName" frontend/FableApp/` confirmed zero direct raw usages in UI views — 100% of UI views now use `effectiveCoverImage`.
- **Backend Test Suite:** `PYTHONPATH=backend .venv/bin/pytest backend/test_main.py` passing 17/17 tests.
