# Fable iOS: Midterm Project Specification & Requirements

**Course Project:** Native iOS Application Development  
**Application Name:** Fable (Curated Micro-Narrative & Editorial E-Reader)  
**Primary Tech Stack:** Swift 5.9+, SwiftUI, Xcode 15/16, iOS 17+  
**Primary Tech Stack:** Swift 5.9+, SwiftUI, Xcode 15/16, iOS 17+ (iPhone 15/16 / Pro / Pro Max)  
**Architecture Pattern:** Model–View–Controller (MVC)  
**Evaluation Milestone:** Midterm Submission (Minimum 50% Functional & Interface Implementation)
**Evaluation Milestone:** Midterm Submission (Minimum 50% Functional & Interface Implementation)  
**Figma Prototype Fidelity:** 100% Complete Visual & Navigational Prototype  

---

## 1. Official Project Instructions & Guidelines

### 1.1 Core Objective
Create an iOS application using **Swift, SwiftUI, and Xcode**. For the midterm submission, your application must demonstrate **at least 50% of its planned interface and functionality**.

### 1.2 Application Requirements
Your application must:
1. **Appropriate SwiftUI Layouts & UI Components:** Use native stacks (`VStack`, `HStack`, `ZStack`), `ScrollView`, `NavigationStack`, `LazyVStack`, sheets, buttons, and custom controls.
2. **At Least Four Distinct Screens:** Contain a minimum of 4 distinct functional screens.
3. **Working Navigation:** Provide seamless, error-free navigation between screens (tab bar navigation, navigation stacks, modal sheets, and hierarchical push/pop).
4. **Reusable Component Modularity:** Define each screen or reusable interface component as a separate SwiftUI `View` structure.
5. **File Organization:** Organize the project into separate Swift files according to each file’s specific purpose or functionality.
6. **MVC Architecture:** Strictly apply the **Model–View–Controller (MVC)** architectural pattern.
7. **Consistent Standards:** Follow consistent naming, formatting, and code-organization practices.
8. **Zero Compilation Errors:** Compile and run cleanly without build errors or crashes in Xcode on macOS.

---

## 2. Midterm Project Scope & Deliverables

| Requirement | Required Level | Fable iOS Implementation Status |
|---|---|---|
| **Figma Prototype** | 100% of planned screens, navigation, and functionality | **100% Complete** (Live Figma canvas + exported `Fable-prototype.pdf`) |
| **SwiftUI Application** | At least 50% implemented and working | **~85% Complete** (5 Core Screens + 5 Sheets/Detail views + full interactive CRUD) |
| **Figma Consistency** | 1:1 fidelity with submitted Figma prototype | **100% Aligned** (Exact color tokens, typography, radii, and image assets) |

---

## 3. Screen Inventory & Architecture Mapping

Fable provides **5 distinct primary screens** plus **5 modal sheets and detail views**, exceeding the minimum 4-screen requirement:

### Primary Screens
1. **`LibraryView` / `StoryLibraryView` (Discovery & Feed):**
   - Header with dynamic date and user avatar profile link.
   - Horizontal scrolling category filter chips (*All*, *Folklore*, *Mythology*, *Gothic*, *Speculative*, *Classic*).
   - "Tale of the Day" hero featured card with cover art, badge, excerpt, and bookmark action.
   - "Continue Reading" and "Recent Submissions" vertical feed.
2. **`ExploreView` (Search & Genre Navigation):**
   - Live search bar filtering by story title, author, and synopsis.
   - 2-column visual genre category cards (*Folklore*, *Mythology*, *Gothic*, *Classic Mystery*).
   - Curated collections ("Staff Favorites", "5-Minute Reads").
3. **`ReaderView` / `StoryReaderView` (Manuscript Reader):**
   - Immersive reading surface with warm parchment canvas.
   - Chapter header filigree, title, author metadata, and reading time indicator.
   - Longform editorial serif manuscript rendering.
   - Bottom reading toolbar: progress percentage indicator, interactive bookmark toggle, font & theme customization sheet trigger.
4. **`WriteView` / `StoryComposerView` (Manuscript Authoring - CRUD Create):**
   - Manuscript composer: Title field, Genre picker, Chapter identifier, Synopsis editor, and full Body manuscript editor.
   - Dynamic live word counter and reading time estimator.
   - "Publish" action button that validates inputs, adds the story to the controller's active collection, and presents the celebration modal.
5. **`ShelfView` / `StoryShelfView` (Personal Collection & Journal - CRUD Read/Update/Delete):**
   - Segmented control toggling between "Bookmarked" and "Completed" stories.
   - Progress rings showing reading percentage per book.
   - Monthly Reading Stats grid (Stories Read, Minutes Logged, Day Streak).
   - Literary quote card (Cicero).

### Modal Sheets & Detail Views
6. **`DisplayOptionsSheet`:** Reader customization bottom sheet allowing readers to change font family (*Source Serif 4*, *SF Pro*, *SF Mono*), font size scaling (80% to 150%), line spacing (*Compact*, *Normal*, *Spacious*), and theme background (*White*, *Sepia*, *Charcoal*, *OLED*).
7. **`StoryPublishedSheet`:** Congratulatory modal presented upon publishing a manuscript.
8. **`GenreDetailView`:** Filtered list of stories belonging to a selected genre with reader count and background banner.
9. **`ProfileView`:** User reading profile, streak statistics, and reading goal tracker.
10. **`SettingsView`:** App preferences, haptic feedback toggle, and reading defaults.

---

## 4. Final Submission Document Requirements (PDF Deliverable)

The midterm submission requires a single, well-organized PDF file containing:

### Section 1: Application Overview
- Brief description of Fable.
- Target audience (readers of micro-fiction, serialized creative writing, folklore, and mythology enthusiasts).
- Core features and value proposition.

### Section 2: Figma Prototype
- Working link to the completed Figma prototype:  
  `https://www.figma.com/design/k90h1If7gNsEl56fQ1HxPq/Fable-App`
  `https://www.figma.com/design/k90h1If7gNsEl56fQ1HxPq/Fable-App` *(Must be set to "Anyone with the link can view")*.
- Accompanying prototype document: `Fable-prototype.pdf`.

### Section 3: Application Screenshots
- High-resolution simulator screenshots of the actual running SwiftUI app demonstrating:
  1. Library Feed screen with category filtering.
  2. Explore and Search screen.
  3. Reader view with parchment background and custom serif typography.
  4. Reader Display Options customization sheet.
  5. Story Composer authoring and validation.
  6. Publish Success celebration modal.
  7. Shelf collection with reading progress rings and reading stats.

### Section 4: Source-Code Link
- Public GitHub repository link:  
  `https://github.com/ur1el0/Fable-IOS`

### Section 5: Midterm Learning Reflection
- Detailed answers addressing:
  1. *What you learned while developing the application.*
  2. *The challenges you encountered.*
  3. *How you addressed those challenges.*
  4. *The SwiftUI concepts or development skills you improved.*
  5. *What you plan to complete or improve for the final project.*

---

## 5. Lab Mac Reproducibility Guarantees

To ensure that pulling or cloning this repository on any shared lab Mac produces **identical, error-free results**:

1. **Self-Contained Swift Package (`Package.swift`):**
   - Configured with `.iOS(.v17)` and `resources: [.process("Resources")]`.
   - Opening `Package.swift` in Xcode automatically links the target, sets up the executable scheme (`FableApp`), and packages the asset catalog (`Assets.xcassets`).
2. **Zero External Network Dependencies:**
   - The app does not rely on external CocoaPods, remote Swift Package dependencies, or remote database endpoints.
   - All seed data (10+ stories, covers, author profiles) is statically populated in memory inside `StoryStore.swift`.
3. **Resilient Asset Loading (`FableImageView`):**
   - If an asset image is missing or cannot be resolved on an older simulator cache, `FableImageView` renders a graceful SF Symbol fallback on parchment background, preventing UI crashes.
4. **Standard 4-Step Lab Routine:**
   ```bash
   git clone https://github.com/ur1el0/Fable-IOS.git
   cd Fable-IOS
   open frontend/Package.swift
   # In Xcode: Select iPhone 16 Pro / iPhone 15 Pro simulator -> Press Cmd + R
   ```
