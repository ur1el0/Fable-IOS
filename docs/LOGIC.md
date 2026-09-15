# FABLE: Application Logic, State Machine & CRUD Specifications

**Application:** Fable (Curated Micro-Narrative & Editorial E-Reader)  
**Target Platform:** Native iOS (SwiftUI, Xcode 15/16)  
**Core Logic Pattern:** Centralized Observable State & MVC Controller  
**Scope:** Complete End-to-End Business Logic & State Transitions

---

## 1. State Machine & Controller Lifecycle

Fable uses a single, centralized reactive state store (`StoryStore`, accessible via `@EnvironmentObject` or `@StateObject`) that coordinates all UI updates, mutations, and user interactions.

```
                  ┌────────────────────────────────────────┐
                  │          App Launch (FableApp)         │
                  └───────────────────┬────────────────────┘
                                      │ Initializes
                                      ▼
                  ┌────────────────────────────────────────┐
                  │        StoryStore Initialization       │
                  │  - Loads 10+ In-Memory Seed Stories   │
                  │  - Sets Active Filter: "All"           │
                  │  - Loads Default Reader Settings       │
                  └───────────────────┬────────────────────┘
                                      │
                 ┌────────────────────┴────────────────────┐
                 ▼                                         ▼
   ┌───────────────────────────┐             ┌───────────────────────────┐
   │     Browse / Read State   │             │    Authoring Draft State  │
   │  - stories: [Story]       │             │  - draftTitle: String     │
   │  - selectedCategory: "All"│             │  - draftGenre: String     │
   │  - activeReaderStory: Nil │             │  - draftManuscript: String│
   └─────────────┬─────────────┘             └─────────────┬─────────────┘
                 │                                         │
        Selects  │                                         │ Presses
        Story    ▼                                         ▼ "Publish"
   ┌───────────────────────────┐             ┌───────────────────────────┐
   │   Active Reading Session  │             │   Validation & Creation   │
   │  - activeReaderStory: St  │             │  - Validates non-empty    │
   │  - progress: 0.0 -> 1.0   │             │  - Computes read time     │
   │  - presentation: Modal    │             │  - Inserts into [Story]   │
   └───────────────────────────┘             └───────────────────────────┘
```

---

## 2. Comprehensive CRUD Operations Specification

Fable is fundamentally architected as a complete **CRUD (Create, Read, Update, Delete)** e-reader application.

### 2.1 CREATE: Story Authoring & Publishing Flow
- **Initiator:** `WriteView.swift`
- **Controller Method:** `StoryStore.publishStory(title:genre:chapter:synopsis:manuscript:)`

#### Execution Logic:
1. **Payload Extraction:** Captures text bindings from input fields:
   - `draftTitle: String`
   - `draftGenre: String`
   - `draftChapter: String`
   - `draftSynopsis: String`
   - `draftManuscript: String`
2. **Validation Rules:**
   - Title must not be empty or whitespace-only (`!draftTitle.trimmingCharacters(in: .whitespaces).isEmpty`).
   - Manuscript content must contain at least 20 words (`wordCount >= 20`).
   - If validation fails, the UI disables the "Publish" CTA and presents an inline prompt.
3. **Derived Metadata Computation:**
   - **Word Count:**
     ```swift
     let words = draftManuscript.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
     let wordCount = words.count
     ```
   - **Reading Time Estimation (Standard 200 Words-Per-Minute):**
     ```swift
     let estimatedMinutes = max(1, Int(ceil(Double(wordCount) / 200.0)))
     ```
4. **Model Instantiation & Insertion:**
   - Creates a new `Story` instance with `UUID()`, `createdAtUtc: Date()`, `isRecentSubmission: true`, `isBookmarked: false`, `isCompleted: false`, and `readingProgress: 0.0`.
   - Prepend to the beginning of the `store.stories` array (`stories.insert(newStory, at: 0)`).
5. **State Feedback:**
   - Sets `isStoryPublished = true` (triggers `StoryPublishedSheet`).
   - Clears draft input fields.
   - Redirects active tab to `FableTab.library`.

---

### 2.2 READ: Discovery, Search & Manuscript Consumption
- **Initiators:** `LibraryView.swift`, `ExploreView.swift`, `ReaderView.swift`

#### Execution Logic:
1. **Category Filtered Query:**
   ```swift
   var filteredRecentStories: [Story] {
       let recents = store.stories.filter { $0.isRecentSubmission }
       if selectedFilter == "All" {
           return recents
       } else {
           return recents.filter {
               $0.genre.rawValue.localizedCaseInsensitiveContains(selectedFilter) ||
               $0.title.localizedCaseInsensitiveContains(selectedFilter)
           }
       }
   }
   ```
2. **Compound Live Search Query (`ExploreView`):**
   - Matches search terms case-insensitively across:
     - `story.title`
     - `story.author`
     - `story.genre.rawValue`
     - `story.synopsis`
3. **Reader Session Instantiation (`ReaderView`):**
   - User taps a story card (`StoryCardView` or hero).
   - Sets `activeReaderStory = selectedStory`.
   - Reader renders with current user appearance preferences (font family, font size, theme background).

---

### 2.3 UPDATE: Bookmarks, Reading Progress & Appearance Preferences
- **Initiators:** `ReaderView.swift`, `ShelfView.swift`, `DisplayOptionsSheet.swift`

#### 1. Bookmark Toggle:
```swift
func toggleBookmark(for story: Story) {
    if let index = stories.firstIndex(where: { $0.id == story.id }) {
        stories[index].isBookmarked.toggle()
        if hapticFeedback {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
```

#### 2. Reading Progress Tracking:
- As the user scrolls through `ReaderView`, the scroll offset relative to the total content height is mapped to a normalized floating point value (`0.0` to `1.0`):
  ```swift
  let progress = min(1.0, max(0.0, currentOffset / totalScrollableHeight))
  story.readingProgress = progress
  ```
- **Completion Threshold:** When `progress >= 0.95`, the story automatically sets `isCompleted = true`.
- **Shelf Progress Ring:** The progress value dynamically drives the SwiftUI stroke trim:
  ```swift
  Circle()
      .trim(from: 0, to: CGFloat(story.readingProgress))
      .stroke(FableTheme.brandPrimary, lineWidth: 3.5)
  ```

#### 3. Reading Journal Statistics Update:
- When a story reaches `isCompleted == true`:
  - `userStats.storiesRead += 1`
  - `userStats.minutesLogged += story.readTimeMinutes`
  - Updates daily streak counter if active today.

#### 4. Appearance Configuration:
- Updates live in `DisplayOptionsSheet`:
  - `readerFont`: Changes between `.serif` (Source Serif 4), `.sans` (SF Pro), `.mono` (SF Mono).
  - `readerFontSize`: Adjusts scaling multiplier (80% to 150%).
  - `readerTheme`: Resolves background canvas and text colors across *White*, *Sepia*, *Charcoal*, and *OLED*.
  - `readerLineSpacing`: Toggles between `.compact` (4pt), `.normal` (8pt), and `.spacious` (14pt).

---

### 2.4 DELETE: Collection Pruning & Draft Discard
- **Initiator:** `ShelfView.swift`
- **Controller Method:** `StoryStore.removeStory(id:)` or `StoryStore.removeBookmark(for:)`

#### Execution Logic:
1. **Un-bookmarking:**
   - Setting `isBookmarked = false` automatically animates the item out of the "Bookmarked" shelf collection tab.
2. **Story Removal:**
   ```swift
   func deleteStory(id: UUID) {
       withAnimation(.spring()) {
           stories.removeAll(where: { $0.id == id })
       }
   }
   ```
3. **Draft Reset:**
   - "Clear Draft" button in `WriteView` resets all authoring fields to empty defaults.

---

## 3. Typographical Rendering & Customization Engine

The reading surface dynamically adapts based on the active `ReaderTheme` and `ReaderFont`:

```swift
public struct ReaderContentModifier: ViewModifier {
    let font: ReaderFont
    let fontSizePercentage: Double
    let theme: ReaderTheme
    let lineSpacing: ReaderLineSpacing
    
    public func body(content: Content) -> some View {
        let baseSize: CGFloat = 17.0
        let scaledSize: CGFloat = baseSize * CGFloat(fontSizePercentage / 100.0)
        
        content
            .font(font.font(size: scaledSize))
            .lineSpacing(lineSpacing.points)
            .foregroundColor(theme.textColor)
    }
}
```

---

## 4. Invariant Guarantees & Defensive Logic

1. **Non-Empty Feed Invariant:** The store guarantees that `stories` is never empty on cold boot by seeding 10+ classical and folk stories if the collection is unpopulated.
2. **Bounded Reading Progress:** Reading progress is clamped within `[0.0, 1.0]` to prevent overflow rendering in circular progress rings.
3. **Safe Memory Footprint:** Full manuscript strings are loaded in memory; for micro-narratives (<5,000 words), memory usage remains minimal (<15 MB heap consumption in Xcode Instruments).
4. **Haptic Decoupling:** Haptic feedback generators are safely guarded and only invoked if `hapticFeedback == true` to respect device settings.

