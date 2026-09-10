# Figma Design Specification & Asset Reference: Fable iOS Client

**Figma File URL:** `https://www.figma.com/design/k90h1If7gNsEl56fQ1HxPq/Fable-App`  
**File Key:** `k90h1If7gNsEl56fQ1HxPq`  
**Last Synced:** September 3, 2026  
**Target Viewport:** Apple iPhone 14 / 15 / 16 (390 × 844 pt, Standard 3x Retina)

---

## 1. Executive Summary & Design Philosophy

**Fable** is an editorial-first storytelling and micro-narrative reading application focusing on folklore, speculative fiction, and serialized creative writing. The visual design establishes a warm, literary atmosphere reminiscent of high-end independent publishing houses and modern editorial journals (e.g., *The New Yorker*, *Substack*, *Kinfolk*).

### Key Aesthetic Hallmarks
- **Warm Parchment Canvas:** Soft off-white and blush background tones (`#FCF8FB`) replace sterile cold whites, reducing eye strain during prolonged reading sessions.
- **Editorial Typography Pairing:** Expressive serif headings (*Playfair Display* / *Source Serif 4*) paired with clean, accessible sans-serif interface elements (*Inter*).
- **Terracotta Brand Accent:** A signature rust-orange accent (`#9F3C16`) anchors calls-to-action, badges, active tab indicators, and progress tracks.

---

## 2. Global Design Tokens

### 2.1 Color Palette

| Token Name | Hex Code | Swift / RGB Representation | Usage & Role |
|---|---|---|---|
| `brandPrimary` | `#9F3C16` | `Color(red: 0.624, green: 0.235, blue: 0.086)` | Primary brand accent, active tabs, buttons, progress fills, tags |
| `brandSecondary` | `#57423B` | `Color(red: 0.341, green: 0.259, blue: 0.231)` | Deep chestnut, subheadings, author names, secondary icons |
| `brandAccent` | `#DEC0B7` | `Color(red: 0.871, green: 0.753, blue: 0.718)` | Soft muted blush, border highlights, chip accents |
| `background` | `#FCF8FB` | `Color(red: 0.988, green: 0.973, blue: 0.984)` | Global canvas background (warm cream/parchment) |
| `surface` | `#ECE0DB` | `Color(red: 0.925, green: 0.878, blue: 0.859)` | Container surface, badge backgrounds, quote card fills |
| `surfaceVariant` | `#F0EDEF` | `Color(red: 0.941, green: 0.929, blue: 0.937)` | Unselected filter chips, search bar backgrounds, tab containers |
| `textPrimary` | `#1B1B1D` | `Color(red: 0.106, green: 0.106, blue: 0.114)` | Near-black high-contrast title and body text |
| `textSecondary` | `#57423B` | `Color(red: 0.341, green: 0.259, blue: 0.231)` | Warm brown text for synopses and section headers |
| `textMuted` | `#8C736B` | `Color(red: 0.549, green: 0.451, blue: 0.420)` | Timestamps, read times, placeholders, inactive icons |
| `cardBackground` | `#FFFFFF` | `Color.white` | Pure white elevated cards for high content legibility |
| `divider` | `#E0D7D2` | `Color(red: 0.880, green: 0.840, blue: 0.820)` | Subtle hairline card borders and horizontal separators |

### 2.2 Typography Hierarchy

| Style Role | Font Family | Size | Weight | Line Height | Application Site |
|---|---|---|---|---|---|
| **Display Title** | Playfair Display | 30pt | Bold (700) | 36px | Main Screen Headlines ("Library", "Discover") |
| **Editorial Headline** | Playfair Display | 22pt | SemiBold (600) | 28px | Story Reader Header & Tale Titles |
| **Section Heading** | Inter | 17pt | SemiBold (600) | 24px | Section Titles ("Continue Reading", "Reading Stats") |
| **Card Title** | Playfair Display | 20pt | SemiBold (600) | 24px | Intermediate Card Story Titles |
| **Reader Body** | Source Serif 4 | 17pt | Regular (400) | 28px (1.65 line height) | Longform Story Manuscript Body |
| **UI Body** | Inter | 14pt / 13pt | Regular (400) | 20px | Subtitles, Author Lines, General UI Labels |
| **Button / Chip Label**| Inter | 12pt | Medium / SemiBold | 16px | Category Chips, Action Buttons, Navigation Links |
| **Eyebrow / Badge** | Inter | 11pt | SemiBold (600) | 13px | Uppercase Tags ("TALE OF THE DAY", "MYTH & LORE") |

### 2.3 Visual Metrics & Radii

- **Hero Card Corner Radius:** `20px`
- **Story Card Corner Radius:** `16px`
- **Stat / Journal Container Radius:** `14px`
- **Standard Button & Input Radius:** `12px`
- **Pill / Filter Chip Radius:** `9999px` (Capsule)
- **Shadow Tokens:**
  - Card Shadow: `0px 2px 8px rgba(0, 0, 0, 0.04)`
  - CTA Button Shadow: `0px 4px 12px rgba(159, 60, 22, 0.25)`

---

## 3. Live Canvas Frame Breakdown

The Figma workspace consists of **7 primary artboards/frames** detailing the complete end-to-end user experience of the Fable iOS app.

### 3.1 Frame 1: `Library Feed` (Home / Discovery)
- **Frame ID:** `1:2`
- **Viewport Dimensions:** `390.0 × 1247.38 pt`
- **SwiftUI Mapping:** `Sources/Views/Screens/StoryLibraryView.swift` & `StoryShelfView.swift`
- **Key Sub-Components:**
  1. **Header Section:**
     - Date Eyebrow: `"TUESDAY, OCT 14"` (Inter 11pt, SemiBold)
     - Screen Title: `"Library"` (Playfair Display 30pt, Bold)
     - User Profile Avatar (32×32 pt circle)
  2. **Category Filter Chips (Horizontal Scroll):**
     - Pill Chips: `"All"` (Active: `#9F3C16`), `"Folklore"`, `"Mythology"`, `"Sci-Fi"`, `"Fables"`, `"Gothic"`.
  3. **Tale of the Day (Hero Featured Card):**
     - 16:9 Cover Image Frame
     - Eyebrow Tag: `"TALE OF THE DAY"`
     - Story Title: `"The Clockmaker of Prague"` (Playfair Display 22pt)
     - Excerpt: *"“In the shadows of the Old Town square, Master Han...”"* (Source Serif 4 18pt)
     - Author & Read Time: `"M. Vance • 4 min read"`
     - Action: Bookmark Button overlay
  4. **Continue Reading Section:**
     - Section Title: `"Continue Reading"` | Action: `"See All"`
     - Card 1: `"The Whispering Pines"` by *Elena Rostova* (Tag: `MYTH & LORE`)
     - Card 2: `"The Starlit Loom"` by *Julian Thorne*

---

### 3.2 Frame 2: `Story Reader` (Manuscript Screen)
- **Frame ID:** `1:159`
- **Viewport Dimensions:** `390.0 × 1962.94 pt`
- **SwiftUI Mapping:** `Sources/Views/Screens/StoryReaderView.swift`
- **Key Sub-Components:**
  1. **Top Filigree & Chapter Header:**
     - Chapter Tag: `"CHAPTER IV • THE CELESTIAL ASTROLABE"` (Inter 11pt SemiBold)
  2. **Story Headline & Metadata:**
     - Main Title: `"The Clockmaker of Prague"` (Playfair Display 28pt Bold)
     - Author Metadata Pill: `"M. Vance • Sep 2026 • 4 min read"`
  3. **Editorial Engraving Vignette:**
     - Illustration Container: *"Orloj Horologe, Old Town Square"*
     - Folio Badge: `"FOLIO 82"`
  4. **Typographical Manuscript Body:**
     - Styled paragraphs in *Source Serif 4* (17pt, line height 1.65)
     - Warm parchment background canvas (`#FCF8FB`)
     - Pull-quote highlights & paragraph filigree section dividers

---

### 3.3 Frame 3: `Reader Customization Sheet` (Appearance Modal)
- **Frame ID:** `1:302`
- **Viewport Dimensions:** `390.0 × 884.5 pt`
- **SwiftUI Mapping:** Sheet presented over `StoryReaderView.swift`
- **Key Sub-Components:**
  1. **Title Header:** `"Reading Experience & Appearance"`
  2. **Font Selector Segment:**
     - Choices: *Source Serif 4* (Default), *Playfair Display*, *Inter*, *Georgia*
  3. **Font Size Adjustment Controls:**
     - `A-` / `A+` Stepper (14pt to 24pt scaling)
  4. **Theme Mode Color Swatches:**
     - Parchment (`#FCF8FB`), Sepia (`#F4ECD8`), Night (`#1C1B1A`), Snow (`#FFFFFF`)

---

### 3.4 Frame 4: `Story Composer` (Editor Studio)
- **Frame ID:** `1:454`
- **Viewport Dimensions:** `390.0 × 1713.63 pt`
- **SwiftUI Mapping:** `Sources/Views/Screens/StoryComposerView.swift`
- **Key Sub-Components:**
  1. **Navigation Bar:**
     - Title: `"Draft Story"` | Action Button: `"Publish"` (Terracotta filled button `#9F3C16`)
  2. **Story Setup Fields:**
     - Title Input Placeholder: *"Title your tale..."* (Playfair Display 24pt)
     - Cover Image Drop Zone / Picker
     - Genre selector chips (*Folklore*, *Dark Fantasy*, *Micro-fiction*)
  3. **Rich Manuscript Editor:**
     - Formatting Toolbar (Bold, Italic, Blockquote, Section Break)
     - Body Text Field (*"Write your narrative here..."*)

---

### 3.5 Frame 5: `Publish Success Sheet` (Celebration Modal)
- **Frame ID:** `1:638`
- **Viewport Dimensions:** `390.0 × 884.0 pt`
- **SwiftUI Mapping:** Sheet presented upon publishing in `StoryComposerView.swift`
- **Key Sub-Components:**
  1. **Illustration Seal:** Centered parchment quill badge icon
  2. **Headline:** `"Tale Published!"` (Playfair Display 24pt Bold)
  3. **Description:** `"Your story is now live in the Fable Library for readers to discover."`
  4. **Action Buttons:**
     - Primary Button: `"Share Tale"` (`#9F3C16` fill, 12pt corner radius)
     - Secondary Button: `"Return to Shelf"` (Subtle outline button)

---

### 3.6 Frame 6: `Explore & Search Tab` (Discovery & Search)
- **Frame ID:** `1:752`
- **Viewport Dimensions:** `390.0 × 1500.0 pt`
- **SwiftUI Mapping:** Search & Explore view tab in `MainTabView.swift`
- **Key Sub-Components:**
  1. **Search Input Bar:**
     - Search Field: *"Search titles, authors, folklore..."* (Background: `#F0EDEF`)
  2. **Trending Genres Grid (2-Column):**
     - Genre Cards: *Folklore*, *Speculative Fiction*, *Urban Legends*, *Gothic Horror*
  3. **Curated Reading Lists:**
     - *"Editor's Choice"*, *"Under 5-Minute Reads"*, *"New Voices"*

---

### 3.7 Frame 7: `Shelf & Reading Journal` (Personal Dashboard)
- **Frame ID:** `1:1058`
- **Viewport Dimensions:** `390.0 × 930.0 pt`
- **SwiftUI Mapping:** `Sources/Views/Screens/StoryShelfView.swift`
- **Key Sub-Components:**
  1. **Screen Header:**
     - App Brand Logo + `"Fable"` Title
     - Page Title: `"Shelf"` (Inter 17pt SemiBold) | Profile Link
  2. **Active Reading List:**
     - Row 1: `"The Whispering Pines"` by *Elena Rostova*
       - Progress Ring: `60%` SVG Ring
       - Badge: `"Reading • 2m left"`
     - Row 2: `"The Starlit Loom"` by *Julian Thorne*
       - Badge: `"Completed yesterday"` (100% Check Ring)
  3. **Monthly Reading Stats Card:**
     - Card Title: `"October Reading Stats"` (Inter 17pt SemiBold)
     - **3-Column Metric Grid:**
       - **12** *Stories Read*
       - **48m** *Logged Time*
       - **3** *Days Streak*
  4. **Motivational Micro-Quote:**
     - Quote Text: *“A room without books is like a body without a soul.” — Cicero* (Source Serif 4 15pt Italic)

---

## 4. Navigation & Tab Bar Mapping

The global app shell (`MainTabView.swift`) hosts 4 main navigation tabs matching the Figma bottom navigation bar (`Frame ID: 1:1204`):

| Tab Index | Tab Title | SF Symbol Icon | Connected Screen View |
|---|---|---|---|
| **0** | **Library** | `books.vertical.fill` | `StoryLibraryView.swift` (Frame `1:2`) |
| **1** | **Explore** | `magnifyingglass` | `ExploreView.swift` (Frame `1:752`) |
| **2** | **Write** | `square.and.pencil` | `StoryComposerView.swift` (Frame `1:454`) |
| **3** | **Shelf** | `bookmark.fill` | `StoryShelfView.swift` (Frame `1:1058`) |

---

## 5. Asset Export & SF Symbols Reference

- **SF Symbols Usage:**
  - `books.vertical` / `books.vertical.fill` (Library)
  - `magnifyingglass` (Explore)
  - `square.and.pencil` (Write / Compose)
  - `bookmark` / `bookmark.fill` (Shelf / Save)
  - `textformat.size` (Reader Appearance Sheet Trigger)
  - `clock` (Reading Time Indicator)
  - `flame.fill` (Reading Streak Metric)
- **Colors & Asset Tokens:** Handled strictly via [`FableTheme.swift`](file:///home/dokja/vsc-fedora/all/Projects/swift-projects/Fable-IOS/Sources/Views/Theme/FableTheme.swift).
