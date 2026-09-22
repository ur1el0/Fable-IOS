# Fable Capstone: Live Dynamic Metadata & Pure User-State Isolation
**Document:** `03_LIVE_METADATA_AND_USER_STATE_PURGING.md`  
**Author:** Senior Technical Instructor & Enterprise Solutions Architect  
**Audience:** Developer / Capstone Student  
**Target Branch:** `feature/final-milestone`  
**Last Updated:** 2026-09-22

---

## 1. Executive Summary & Problem Diagnosis

When registering and logging into a newly created account on Fable, the application previously exhibited unintended visual artifacts and pre-populated personal state:
1. **Ghost Shelf Items:** Newly minted accounts saw 3 saved stories and 2 finished stories on their Shelf tab instead of an authentic empty state.
2. **Artificial Reading Analytics:** New accounts displayed 12 stories completed, 48 minutes logged, and a 3-day reading streak.
3. **Ghost "Continue Reading" Card:** The Library feed displayed *The Legend of Sleepy Hollow* as an active reading session even when the user had never opened it.
4. **Static Visual Assets & Placeholders:** Top genres and trending authors relied on local asset catalog name strings (`author_kuang`, `genre_folklore`) and procedural initials, while *The Legend of Maria Makiling* had no live cover image URL.

This document serves as the complete engineering specification, architectural blueprint, and drop-in code guide to resolve these issues and finalize the milestone on your laptop.

---

## 2. Root Cause Traceability Matrix

| Area | File Path | Line Range | Defect Mechanism | Corrective Architecture |
| :--- | :--- | :--- | :--- | :--- |
| **Shelf Fallbacks** | `frontend/FableApp/Features/Shelf/Views/ShelfView.swift` | L13–L24 | `displayedStories` returned `store.stories.prefix(3)` if `saved.isEmpty` and `prefix(2)` if `finished.isEmpty`. | Remove slice fallbacks. Return strictly user-saved/finished items. Render brand-styled empty states. |
| **Profile Fallbacks** | `frontend/FableApp/Features/Shelf/Views/ProfileView.swift` | L215–L218 | Saved tab used `saved.isEmpty ? store.stories.prefix(3) : saved`. | Display empty state when `saved.isEmpty` or `profileStories.isEmpty`. |
| **Analytics Clamping** | `frontend/FableApp/Features/Library/Services/PersistenceService.swift` | L353–L365 | `fetchReadingStats()` clamped values with `max(12, 12 + completed)` and `max(48, 48 + mins)`. | Enforce pure zero-baseline: `storiesReadCount = completedCount`, `totalMinutes = mins`, `streakDays = uniqueDays`. |
| **Seed Bookmark State** | `frontend/FableApp/Features/Library/Models/Story.swift` | L550–L640 | `defaultSeedStories` set `isSaved: true` and fake progress (`35%`, `60%`, `80%`). | Default all catalog seeds to `isSaved: false`, `progressPercent: 0`, `currentPage: 1`. |
| **Continue Reading** | `frontend/FableApp/Features/Library/Views/LibraryView.swift` | L176 | Fallback `?? store.stories.first(where: { $0.title.contains("Sleepy Hollow") })`. | Display card *only* if an actual reading session is in progress (`$0.progressPercent > 0 && !$0.isCompleted`). |
| **Backend Images** | `backend/services/story_service.py` | L242–L338 | `get_top_authors()` and `get_genres()` set image URLs to `None`. | Pass authentic Wikimedia/Open Library portrait URLs and curated editorial genre banners. |
| **Missing Cover URL** | `backend/core/seed_catalog.py` | L144 | *The Legend of Maria Makiling* had `cover_image_url: None`. | Add official Project Gutenberg catalog cover URL (`pg38269.cover.medium.jpg`). |
| **Sign-Out Disconnect** | `frontend/FableApp/Features/Shelf/Views/SettingsView.swift` | L276 | Called `auth.signOut()` directly without triggering `AuthViewModel.shared.logout()`. | Route sign-out through `AuthViewModel.shared.logout()` to reset reactive root state to `.signedOut`. |

---

## 3. Detailed Step-by-Step Implementation Guide

### Step 1: Backend Live Image URLs & Dynamic Aggregation

#### 1.1 Update `backend/core/seed_catalog.py`
Locate *"The Legend of Maria Makiling"* (around line 135) and supply its official Project Gutenberg cover URL:
```python
    {
        "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        "title": "The Legend of Maria Makiling",
        "author": "Jose Rizal",
        "genre": "Folklore",
        "chapter": "Chapter I",
        "synopsis": "The celestial guardian of Mount Makiling blesses the villagers with harvest and protection until betrayal silences her valley.",
        "content": "She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient woods... Her voice was like the murmur of crystal water over white pebbles, and her step was as light as the dewdrop falling upon a leaf at dawn.",
        "read_time_minutes": 5,
        "cover_image_name": "cover_maria",
        "hero_image_name": "cover_maria",
        "cover_image_url": "https://www.gutenberg.org/cache/epub/38269/pg38269.cover.medium.jpg",
        "is_tale_of_the_day": 0,
        "is_recent_submission": 1,
        "is_curator_spotlight": 0,
        "badge_text": None,
        ...
```

#### 1.2 Update `backend/services/story_service.py`
Enrich `GENRE_METADATA` with curated high-resolution editorial photography, and provide live public-domain portrait URLs for top authors in `get_top_authors()`:

```python
GENRE_METADATA = {
    "Folklore": {
        "description": "Traditional tales passed down through generations, reimagined by contemporary scribes—from fireside Slavic forest myths to maritime legends whispered across coastal tides.",
        "image_name": "genre_folklore",
        "image_url": "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=800&auto=format&fit=crop",
        "default_readers": "18.4k"
    },
    "Mythology": {
        "description": "Epic sagas of deities, ancient heroes, and cosmic origins spanning classical traditions to obscure forgotten pantheons.",
        "image_name": "genre_mythology",
        "image_url": "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?q=80&w=800&auto=format&fit=crop",
        "default_readers": "12.1k"
    },
    "Gothic": {
        "description": "Atmospheric hauntings, crumbling estates, and romantic dread exploring the psychological depths of human melancholy.",
        "image_name": "genre_gothic",
        "image_url": "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?q=80&w=800&auto=format&fit=crop",
        "default_readers": "9.8k"
    },
    "Classic Fiction": {
        "description": "Enduring literary cornerstones, psychological inquiries, and philosophical journeys across the centuries.",
        "image_name": "genre_folklore",
        "image_url": "https://images.unsplash.com/photo-1457369804613-52c61a468e7d?q=80&w=800&auto=format&fit=crop",
        "default_readers": "16.5k"
    },
    "Classic Mystery": {
        "description": "Whodunits, deductive puzzles, and atmospheric investigations through gaslit cobblestones and locked rooms.",
        "image_name": "genre_mystery",
        "image_url": "https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?q=80&w=800&auto=format&fit=crop",
        "default_readers": "14.2k"
    }
}

AUTHOR_PORTRAIT_URLS = {
    "Bram Stoker": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Bram_Stoker_1906.jpg/440px-Bram_Stoker_1906.jpg",
    "Washington Irving": "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Washington_Irving_by_John_Wesley_Jarvis%2C_1809.jpg/440px-Washington_Irving_by_John_Wesley_Jarvis%2C_1809.jpg",
    "Edgar Allan Poe": "https://upload.wikimedia.org/wikipedia/commons/thumb/7/75/Edgar_Allan_Poe_2_edit.jpg/440px-Edgar_Allan_Poe_2_edit.jpg",
    "Franz Kafka": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/Franz_Kafka%2C_1923.jpg/440px-Franz_Kafka%2C_1923.jpg",
    "Mary Shelley": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/RothwellMaryShelley.jpg/440px-RothwellMaryShelley.jpg",
    "Oscar Wilde": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/Oscar_Wilde_by_Napoleon_Sarony_-_1882.jpg/440px-Oscar_Wilde_by_Napoleon_Sarony_-_1882.jpg",
    "Homer": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1c/Homer_British_Museum.jpg/440px-Homer_British_Museum.jpg",
    "Brothers Grimm": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Grimm.jpg/440px-Grimm.jpg",
    "Jose Rizal": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b0/Jose_rizal_01.jpg/440px-Jose_rizal_01.jpg",
    "Lewis Carroll": "https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/LewisCarrollSelfPhoto.jpg/440px-LewisCarrollSelfPhoto.jpg"
}
```

In `get_genres()`, pass `image_url=meta.get("image_url")`:
```python
        genres.append(GenreDTO(
            id=genre_id,
            name=name,
            story_count=count,
            readers_count=meta["default_readers"],
            description=meta["description"],
            image_name=meta["image_name"],
            image_url=meta.get("image_url")
        ))
```

In `get_top_authors()`, pass `avatar_image_url=AUTHOR_PORTRAIT_URLS.get(author_name)`:
```python
    writers = []
    for r in rows:
        author_name = r["author"]
        writer_id = UUID(int=abs(hash(f"author_{author_name}")) % (2**128))
        avatar_slug = f"author_{author_name.lower().replace(' ', '_').replace('.', '')[:15]}"
        rating = round(r["avg_rating"] if r["avg_rating"] else 4.9, 1)
        writers.append(WriterDTO(
            id=writer_id,
            name=author_name,
            avatar_image_name=avatar_slug,
            avatar_image_url=AUTHOR_PORTRAIT_URLS.get(author_name),
            story_count=r["story_count"],
            rating=rating
        ))
    return writers
```

---

### Step 2: Zero-Baseline Domain Models & Persistence

#### 2.1 Update `frontend/FableApp/Features/Library/Models/Story.swift`
In `Story.defaultSeedStories`:
- Set `isSaved: false` for all 6 catalog stories.
- Set `progressPercent: 0`, `currentPage: 1`, and `isFinished: false`.
- Catalog stories are discovery records, not pre-saved user shelf records.

In `GenreCategory.defaultCategories`:
- Add `imageUrl` pointing to the curated high-res links.

In `Writer.defaultWriters`:
- Add `avatarImageUrl` pointing to official author portraits.

#### 2.2 Update `frontend/FableApp/Features/Library/Services/PersistenceService.swift`
Replace lines 353–365 in `fetchReadingStats()`:
```swift
            // Pure calculated stats based on authentic user activity
            let finalStories = completedCount
            let finalMinutes = additionalMinutes
            let finalStreak = uniqueDaySet.count
            
            return ReadingStatsSummary(
                storiesReadCount: finalStories,
                totalMinutesRead: finalMinutes,
                streakDays: finalStreak
            )
        } catch {
            return ReadingStatsSummary(storiesReadCount: 0, totalMinutesRead: 0, streakDays: 0)
        }
```

#### 2.3 Update `frontend/FableApp/Features/Library/ViewModels/StoryStore.swift`
In `StoryStore.swift`:
1. Ensure `profileStories` initializes to empty `[]`. Do NOT insert "The Clockmaker of Prague" on startup for newly registered users.
2. In `syncWithCloudBackend()`:
   - When merging remote stories, preserve the user's explicit local bookmark state:
     ```swift
     stories[idx].coverImageUrl = remote.coverImageUrl
     stories[idx].totalChapters = remote.totalChapters
     ```
3. Scope `persistentDeviceId` per authenticated user handle so multi-user logins on the same device do not bleed shelf state:
   ```swift
   public var persistentDeviceId: String {
       let userHandle = AuthManager.shared.currentSession?.handle ?? "guest"
       let storageKey = "fable_persistent_device_id_\(userHandle)"
       if let stored = UserDefaults.standard.string(forKey: storageKey) {
           return stored
       }
       let fresh = UUID().uuidString
       UserDefaults.standard.set(fresh, forKey: storageKey)
       return fresh
   }
   ```
4. Add a `clearUserStateOnSignOut()` method:
   ```swift
   public func clearUserStateOnSignOut() {
       self.profileStories = []
       for i in 0..<stories.count {
           stories[i].isBookmarked = false
           stories[i].isCompleted = false
           stories[i].progressPercent = 0
           stories[i].currentPage = 1
       }
       reloadReadingStats()
       reloadPinnedQuotes()
   }
   ```

---

### Step 3: Frontend Empty State Architecture

#### 3.1 Update `frontend/FableApp/Features/Shelf/Views/ShelfView.swift`
1. Clean `displayedStories`:
   ```swift
   var displayedStories: [Story] {
       switch selectedTab {
       case "Finished":
           return store.stories.filter { $0.isCompleted || $0.progressPercent >= 100 }
       case "My Drafts":
           return store.profileStories
       default: // "Saved"
           return store.stories.filter { $0.isBookmarked }
       }
   }
   ```
2. Render an elegant empty state card when `displayedStories.isEmpty`:
   ```swift
   if displayedStories.isEmpty {
       VStack(spacing: 14) {
           Image(systemName: emptyStateIcon)
               .font(.system(size: 40))
               .foregroundColor(FableTheme.brandPrimary.opacity(0.8))
               .padding(.top, 28)
           
           Text(emptyStateTitle)
               .font(.system(size: 17, weight: .bold, design: .serif))
               .foregroundColor(FableTheme.textPrimary)
           
           Text(emptyStateSubtitle)
               .font(.system(size: 13))
               .foregroundColor(FableTheme.textMuted)
               .multilineTextAlignment(.center)
               .padding(.horizontal, 28)
               .padding(.bottom, 28)
       }
       .frame(maxWidth: .infinity)
       .background(FableTheme.cardBackground)
       .clipShape(RoundedRectangle(cornerRadius: 16))
       .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
       .padding(.horizontal, 20)
   } else {
       // Stories List (existing ForEach)
   }
   ```
   Helpers for copy:
   ```swift
   private var emptyStateIcon: String {
       switch selectedTab {
       case "Finished": return "checkmark.seal"
       case "My Drafts": return "square.and.pencil"
       default: return "bookmark"
       }
   }

   private var emptyStateTitle: String {
       switch selectedTab {
       case "Finished": return "No Finished Tales Yet"
       case "My Drafts": return "No Drafts in Studio"
       default: return "Your Shelf is Empty"
       }
   }

   private var emptyStateSubtitle: String {
       switch selectedTab {
       case "Finished": return "Tales you complete will be archived here alongside your reading achievements."
       case "My Drafts": return "Stories and manuscripts you draft in the Studio will appear here."
       default: return "Bookmark stories from the Library or Explore tabs to build your personal reading list."
       }
   }
   ```

#### 3.2 Update `frontend/FableApp/Features/Shelf/Views/ProfileView.swift`
- In the `Saved` tab: remove `store.stories.prefix(3)` fallback. If `saved.isEmpty`, display a clean empty message ("No saved tales yet").
- In the `Published` tab: if `store.profileStories.isEmpty`, display a clean empty message ("No stories published yet").
- In the `Reading Stats` tab: display `store.readingStats` directly (0 stories, 0.0 hrs, 0 days for new accounts).

#### 3.3 Update `frontend/FableApp/Features/Library/Views/LibraryView.swift`
In line 176, remove the `Sleepy Hollow` fallback:
```swift
if let inProgressStory = store.stories.first(where: { $0.progressPercent > 0 && !$0.isCompleted }) {
    // Continue reading card
}
```
If the user hasn't started reading any story yet, this card will not display.

#### 3.4 Update `frontend/FableApp/Features/Shelf/Views/SettingsView.swift`
In the sign-out confirmation button (line 274):
```swift
Button(auth.isGuestMode ? "Exit" : "Sign Out", role: .destructive) {
    dismiss()
    store.clearUserStateOnSignOut()
    AuthViewModel.shared.logout()
}
```
This guarantees that:
1. `AuthViewModel.shared.authState` becomes `.signedOut`.
2. `ContentView` switches back to `WelcomeView`.
3. `StoryStore` resets personal shelf state.

---

## 4. Verification & Testing Checklist

When you resume on your laptop, run these verifications in order:

### 1. Backend Verification
```bash
cd backend
source .venv/bin/activate
pytest test_main.py -v
```
*Expected Result:* 17/17 pytest tests pass with zero failures.

### 2. Frontend Build Verification
```bash
xcodebuild -project frontend/FableApp.xcodeproj \
  -scheme FableApp \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```
*Expected Result:* `** BUILD SUCCEEDED **` with zero errors.

### 3. End-to-End Manual Testing Scenario
1. Launch FastAPI backend (`uvicorn main:app --port 8000`).
2. Run FableApp in the iOS Simulator.
3. Sign out of any existing session via **Shelf -> Settings -> Sign Out**.
4. Tap **Create Account** on `WelcomeView`.
5. Enter a new name, email (`testuser@fable.io`), and password (`password123`).
6. **Verify Shelf Tab:**
   - Saved tab displays: *"Your Shelf is Empty"*.
   - Finished tab displays: *"No Finished Tales Yet"*.
   - My Drafts displays: *"No Drafts in Studio"*.
   - October Reading Stats card shows: `0 Stories Read`, `0m Logged Time`, `0 Days Streak`.
7. **Verify Library Tab:**
   - Tale of the Day displays *Dracula* with live Gutenberg cover.
   - "Continue Reading" card is **NOT** visible (since 0 stories have been read).
8. **Verify Explore Tab:**
   - Popular Genres display live photography banners.
   - Trending Writers display official author portraits and accurate live story counts.
9. **Verify Reading Workflow:**
   - Open *Dracula*, bookmark it, and read to page 3.
   - Return to **Shelf**: *Dracula* now appears under Saved with 60% progress.
   - Return to **Library**: *Dracula* now appears in "Continue Reading".
   - Mark as Finished: *Dracula* moves to Finished tab, and reading stats increment to `1 Story Read`.
