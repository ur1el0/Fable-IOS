# Fable iOS: Curated Editorial E-Reader & Micro-Fiction Platform

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS 17.0+](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple.svg)](https://developer.apple.com/xcode/swiftui/)
[![Architecture](https://img.shields.io/badge/Architecture-MVC-green.svg)](https://developer.apple.com)
[![Figma Prototype](https://img.shields.io/badge/Figma-100%25%20Prototype-pink.svg)](https://www.figma.com/design/k90h1If7gNsEl56fQ1HxPq/Fable-App)

**Fable** is a native iOS creative writing and serial micro-narrative reading application engineered for high typographical elegance and distraction-free reading. Designed around folklore, mythology, speculative fiction, and serialized creative shorts, Fable couples an editorial bookish visual identity with a responsive, offline-first client architecture.

---

## ⚡ 60-Second Mac Lab Quickstart

Follow these exact steps to clone, build, and run Fable with **100% consistent results** on any Mac in the computer lab:

### 1. Clone the Repository
Open **Terminal** on the Mac and run:
```bash
git clone https://github.com/ur1el0/Fable-IOS.git
cd Fable-IOS
```

### 2. Open in Xcode
You can open the project directly via Terminal or through the Xcode GUI:
```bash
open Package.swift
```
*(Or launch Xcode ➔ **File** ➔ **Open...** ➔ Select the `Fable-IOS` folder).*

### 3. Select Target & Simulator
1. At the top toolbar of Xcode, click the active scheme dropdown (it should read **FableApp**).
2. Set the run destination to **iPhone 16 Pro** or **iPhone 15 Pro** (any simulator running **iOS 17.0+**).
   > **Note:** If Xcode defaults to *"My Mac"*, click the destination selector and choose an **iOS Simulator**.

### 4. Build & Run
- Press `Cmd + R` (or click the **Play** button in the top left).
- **Result:** Xcode compiles with **0 errors**, launches the iOS Simulator, and boots into the warm parchment Library feed with 10+ pre-seeded stories!

---

## 📱 App Architecture & Screens (MVC)

Fable strictly implements the **Model–View–Controller (MVC)** architectural pattern:

```
[ Model: Models.swift ]  ◄──►  [ Controller: StoryStore.swift ]  ◄──►  [ View: Sources/Views/ ]
  - Story, Genre, Author         - Observable centralized state          - LibraryView (Feed)
  - Enums (Theme, Font)          - In-memory mock repository             - ExploreView (Search)
  - Pure value types             - CRUD business logic mutations         - ReaderView (Reader)
                                                                         - WriteView (Composer)
                                                                         - ShelfView (Journal)
```

### Core Screens & Features:
1. **`LibraryView` (Discovery & Feed):** Daily editorial headline ("Library"), category filter pills (*All*, *Folklore*, *Mythology*, *Gothic*), and the featured 16:9 "Tale of the Day" hero card.
2. **`ExploreView` (Search & Browse):** Dynamic search bar filtering titles/authors/synopses in real-time, 2-column visual genre category banners, and curated reading lists.
3. **`ReaderView` (Manuscript Reader):** Longform serif reading canvas on warm parchment (`#FCF8FB`), chapter filigree headers, live progress tracking, bookmark toggle, and quick display customizer.
4. **`WriteView` (Story Composer - CRUD Create):** Authoring studio with dynamic word counter, automatic 200-WPM reading time estimator, input validation, and publish celebration sheet.
5. **`ShelfView` (Personal Library & Journal - CRUD Read/Update/Delete):** Segmented collection (*Bookmarked* vs. *Completed*), SVG circular progress rings (e.g. 60%, 100%), and the October Reading Stats dashboard.
6. **`DisplayOptionsSheet` (Reader Customizer):** Live font selector (*Source Serif 4*, *SF Pro*, *SF Mono*), size stepper (80% to 150%), line spacing, and theme swatches (*White*, *Sepia*, *Charcoal*, *OLED*).

---

## 🎨 Design System & Figma Token Parity

All visual assets and tokens match the live Figma design specification with 100% fidelity:
- **Primary Brand Accent:** Terracotta `#9F3C16` (`FableTheme.brandPrimary`)
- **Canvas Background:** Soft warm parchment `#FCF8FB` (`FableTheme.background`)
- **Surface Fill:** Warm beige `#ECE0DB` (`FableTheme.surface`)
- **Typography:** *Playfair Display* / Serif (Display titles), *Source Serif 4* (Manuscript body), *Inter* / *SF Pro* (UI elements).
- **Corner Radii:** Hero cards (20pt), Story cards (16pt), Buttons (12pt), Filter chips (Capsule).

---

## 🛠️ Lab Troubleshooting & Consistency Guarantees

If you encounter common Mac lab environment quirks:

| Problem in Lab | Root Cause | Immediate Fix |
|---|---|---|
| **Xcode says "My Mac" destination only** | Xcode auto-selected macOS destination | Click the target dropdown at the top center of Xcode ➔ Choose `iOS Simulators` ➔ `iPhone 16 Pro`. |
| **Old cached build fails** | Stale build artifacts from a previous user | Go to **Product** ➔ **Clean Build Folder** (`Shift + Cmd + K`), then rebuild (`Cmd + B`). |
| **Simulators not booted** | First time launch on that Mac | Allow Xcode 30–60 seconds to boot the simulator runtime on cold lab machines. |
| **Offline Lab Network** | Campus Wi-Fi blocked / offline machine | **No problem!** Fable has **zero external network dependencies** for midterm grading; all seed data is 100% self-contained in `StoryStore.swift`. |

---

## 📂 Project Structure

```
Fable-IOS/
├── README.md                     # Repository entrypoint & quickstart (this file)
├── MAC_LAB_RUNBOOK.md            # Detailed Mac lab setup & verification runbook
├── PROJECT_INSTRUCTIONS.md       # Official midterm rubric & submission requirements
├── ARCHITECTURE.md               # Technical architecture & MVC layer documentation
├── DESIGN.md                     # Visual tokens, typography hierarchy & asset inventory
├── LOGIC.md                      # State machine, CRUD flows & algorithm mechanics
├── IMPROVEMENTS.md               # Midterm evaluation audit & final FastAPI roadmap
├── Fable-prototype.pdf           # 100% complete Figma prototype reference document
├── Package.swift                 # Swift Package Manager manifest (iOS 17+)
└── Sources/
    ├── FableApp.swift            # Application entry point (@main)
    ├── ContentView.swift         # Root Tab navigation host & custom tab bar
    ├── Models.swift              # Pure domain models (Story, Genre, Author, Enums)
    ├── StoryStore.swift          # Central MVC controller & in-memory database
    ├── Theme.swift               # Design tokens, palette & view modifiers
    ├── Views/                    # All 14 modular SwiftUI views & sheets
    └── Resources/
        └── Assets.xcassets/      # 3x Retina covers, thumbnails, avatars & banners
```

---

## 🔗 Links & Submission References

- **Live Figma Prototype:** [Fable Figma Prototype](https://www.figma.com/design/k90h1If7gNsEl56fQ1HxPq/Fable-App) *(Set to "Anyone with the link can view")*
- **Local Prototype PDF:** [`Fable-prototype.pdf`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/Fable-prototype.pdf)
- **Source Code Repository:** [https://github.com/ur1el0/Fable-IOS](https://github.com/ur1el0/Fable-IOS)

