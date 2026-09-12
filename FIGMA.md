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
- **SwiftUI Mapping:** `Sources/Views/LibraryView.swift` & `StoryCardView.swift`
- **Asset Strategy:** Pure procedural placeholder geometry (`PlaceholderCoverView`) with warm parchment fill (`#ECE0DB`), 1pt hairline border, and terracotta serif monograms.
- **Key Sub-Components:**
  1. **Header Section:**
     - Date Eyebrow: `"TUESDAY, OCT 14"` (Inter 11pt, SemiBold, muted)
     - Screen Title: `"Library"` (Playfair Display 30pt, Bold)
  2. **Category Filter Chips (Horizontal Scroll):**
     - Pill Chips: `"All"` (Active: `#9F3C16` terracotta fill, white text), `"Folklore"`, `"Mythology"`, `"Sci-Fi"`, `"Fables"`
  3. **Tale of the Day (Hero Featured Card):**
     - 16:9 Cover Frame: Procedural parchment cover with serif monogram `"D"`
     - Eyebrow Tag: `"TALE OF THE DAY"` (White capsule pill with terracotta text)
     - Bookmark Action: Top-right circular white button with bookmark ribbon outline
     - Byline: `"Bram Stoker •"`
     - Story Title: `"Dracula"` (Playfair Display 22pt Bold)
     - Narrative Excerpt: *"“The castle is on the very edge of a terrible precipice. A stone falling from the window would fall a thousand feet without touching anything.”"* (Source Serif 4, 15pt)
  4. **Continue Reading Section:**
     - Section Header: `"Continue Reading"` | Action link: `"See All"`
     - Card: `"The Legend of Sleepy Hollow"` by *Washington Irving*
     - Thumbnail: 3:4 aspect ratio procedural placeholder with monogram `"S"`
     - Progress Indicator: Terracotta linear progress bar showing `"60% complete • Page 14 of 24"` with terracotta play icon `▷`
  5. **Recent Submissions Section:**
     - Section Header: `"Recent Submissions"` | Counter badge: `"3 new stories"`
     - Card 1: Author tag `"Franz Kafka"`, Title `"The Metamorphosis"`, Excerpt: *"“One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin.”"*
     - Card 2: Author tag `"Edgar Allan Poe"`, Title `"The Tell-Tale Heart"`, Excerpt: *"“True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad?”"*
     - Card 3: Author tag `"Jose Rizal"`, Title `"The Legend of Maria Makiling"`, Excerpt: *"“She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient...”"*
  6. **Bottom Persistent Navigation:** 4 tabs (`Library` active, `Explore`, `Write`, `Shelf`).

---

### 3.2 Frame 2: `Story Reader` (`Dracula` Manuscript Screen)
- **Frame ID:** `1:159`
- **Viewport Dimensions:** `390.0 × 1962.94 pt`
- **SwiftUI Mapping:** `Sources/Views/ReaderView.swift`
- **Asset Strategy:** Asset-decoupled blank placeholder for the hero chapter vignette (16:9 parchment container with subtle border).
- **Key Sub-Components:**
  1. **Navigation:** Top-left back chevron button (`<`) dismissing back to Library.
  2. **Headline & Metadata:**
     - Centered Title: `"Dracula"` (Playfair Display 28pt Bold)
     - Byline Metadata Pill: Capsule container displaying `🌓 M. Vance • Sep 2026 • ⏱ 4 min read`
  3. **Chapter Vignette Placeholder:** 16:9 rounded rectangle container with warm parchment fill and hairline border.
  4. **Typographical Manuscript Body:**
     - Opening Paragraph: *"Before the sun had set, we reached the Bistritz pass. The grey of the evening had begun to fall, and the shadows of the mountains seemed to close in around us with every mile. The horses began to strain against the harness as the road turned sharply upward into the deep pine forests of Transylvania."*
     - Dialogue Paragraph: *"“The castle is on the very edge of a terrible precipice,” the driver whispered, crossing himself as the wolves began their low, distant howling down in the valley below. “A stone falling from the window would fall a thousand feet without touching anything.”"*
  5. **Floating Bottom Reader Toolbar Pill:**
     - Left Segment: Book icon + `"Page 2 of 5"`
     - Separator: Muted bullet `•`
     - Center Segment: Mini terracotta progress track indicating `"40%"`
     - Right Segment: Circular `"TT"` button triggering the Display Options Sheet.

---

### 3.3 Frame 3: `Display Options Sheet` (Appearance Modal)
- **Frame ID:** `1:302`
- **Viewport Dimensions:** `390.0 × 884.5 pt`
- **SwiftUI Mapping:** `Sources/Views/DisplayOptionsSheet.swift` (Presented over Reader)
- **Key Sub-Components:**
  1. **Top Control Bar:**
     - Left: `"Reset"` action (terracotta text)
     - Center: `"Display Options"` title (17pt bold)
     - Right: `"✕"` close icon button (circular muted surface)
  2. **Typography Section:**
     - Header: `"TYPOGRAPHY"` (Left, 11pt bold) | `"Source Serif 4"` (Right, terracotta)
     - 3-Segment Control: `Serif` (Active: white card fill with subtle shadow), `Sans`, `Mono`
  3. **Text Size Section:**
     - Header: `"TEXT SIZE"` (Left, 11pt bold) | `"100%"` (Right, muted text)
     - Continuous Stepper Slider: Small `A` label on left, terracotta active track with white thumb, Large `A` on right
  4. **Reading Background Section:**
     - Header: `"READING BACKGROUND"` (11pt bold)
     - 4 Circular Color Swatches with labels:
       - `White` (`#FFFFFF`)
       - `Sepia` (`#F4ECE0`, active state with terracotta `✓` checkmark inside)
       - `Charcoal` (`#2B2B2B`)
       - `OLED` (`#000000`)
  5. **Line Spacing Section:**
     - Header: `"LINE SPACING"` (11pt bold)
     - 3 Segmented Cards:
       - `Compact` (tight line icon)
       - `Normal` (standard line icon with vertical arrows; active state: peach `#FBEAE3` fill, terracotta `#9F3C16` 1.5pt border and text)
       - `Spacious` (relaxed line icon)

---

### 3.4 Frame 4: `Story Composer` (Write Tab / Studio)
- **Frame ID:** `1:454`
- **Viewport Dimensions:** `390.0 × 1713.63 pt`
- **SwiftUI Mapping:** `Sources/Views/WriteView.swift`
- **Key Sub-Components:**
  1. **Top Navigation Bar:**
     - Left Action: `"Clear"` (terracotta / red text to discard uncommitted draft)
     - Center Pill: `✍️ DRAFT MODE` (peach capsule pill with terracotta text)
     - Right Action: Circular terracotta button with upward arrow `↑` (Publish CTA)
  2. **Identity Section:**
     - Header: `"IDENTITY"` (11pt bold) | Indicator: `"• Manuscript"` (terracotta)
     - Grouped Container Card (1pt hairline border, rounded corners):
       - Title Row: `"Title"` label | Input value `"The Metamorphosis"` (Playfair Display bold)
       - Divider Line
       - Genre Row: `"Genre"` label | Pill badge `📖 Classic Fiction` (peach surface) | `"Chapter I"` | Disclosure chevron `>`
  3. **Synopsis Section:**
     - Header: `"SYNOPSIS"` (11pt bold) | Subtitle: `"Micro-prologue"`
     - Grouped Container Card:
       - Text Input: *"“Gregor Samsa wakes one morning to discover he has transformed into a monstrous insect, forcing his family to confront their dependency and disgust.”"*
       - Card Footer: `⏱ Card preview previewable on Shelf` (left) | Character Counter: `"142 / 200"` (right)
  4. **Manuscript Section:**
     - Header: `"MANUSCRIPT"` (11pt bold) | Icon on right
     - Longform Body Editor: Gregor Samsa's morning transformation narrative
     - Pagination & Resize Controls: Bottom indicator dots `• •` and text frame expander
  5. **Bottom Stats Pill (Floating above Tab Bar):**
     - Left: `"142 / 500 words"` (list icon with active terracotta underline)
     - Center: `⏱ ~1 min fable`
     - Right: `☁️ Saved 2m ago` (cloud auto-save indicator)

---

### 3.5 Frame 5: `Publish Success Sheet` (Celebration Modal)
- **Frame ID:** `1:638`
- **Viewport Dimensions:** `390.0 × 884.0 pt`
- **SwiftUI Mapping:** `Sources/Views/StoryPublishedSheet.swift`
- **Key Sub-Components:**
  1. **Celebration Badge:**
     - Circular pale peach badge (`#FBEAE3`) with subtle terracotta sparkle accents
     - Inner concentric circle with terracotta checkmark icon (`✓`)
  2. **Typography:**
     - Headline: `"Story Published!"` (Playfair Display 24pt Bold)
     - Subtitle: `"Your fable is now live in the Community Library for fellow wanderers to read and reflect upon."` (14pt regular, centered)
  3. **Metadata Pill:**
     - Capsule container with centered bullet items: `• Public  • Folklore  • 142 words`
  4. **Action Hierarchy:**
     - Primary Button: `"View Story Now →"` (Full-width terracotta `#9F3C16` button, 14pt corner radius)
     - Secondary Button: `"Return to Library"` (Centered text button)
     - Tertiary Link: `↑ Share story link` (Terracotta link with upload/share symbol)

---

#### 3.6 Frame 6: `Explore & Search Tab` (Discovery & Search)
- **Frame ID:** `1:752`
- **Viewport Dimensions:** `390.0 × 1500.0 pt`
- **SwiftUI Mapping:** `Sources/Views/ExploreView.swift`
- **Asset Strategy:** 2x2 genre cards and author avatars use procedural parchment surfaces with serif typography monograms (`PlaceholderCoverView`).
- **Key Sub-Components:**
  1. **Top Brand Header:** `📖 Fable` logo on left, screen category label `"Explore"` on right.
  2. **Search Header:**
     - Eyebrow: `"DISCOVERY"` (11pt bold uppercase)
     - Title: `"Explore"` (Playfair Display 30pt Bold)
     - Search Input: Persistent search bar with search icon `🔍` and placeholder `"Search stories, authors, or genres"` (`#F0EDEF` fill, 12pt radius).
  3. **Filter Pills:** Horizontally scrolling chips: `"All"` (active terracotta `#9F3C16`), `"Under 5 mins ✓"`, `"Community Favorites"`.
  4. **Popular Genres (2x2 Grid):**
     - Section Header: `"Popular Genres"` | `"24 categories"`
     - Card 1: `"Folklore"` (`340 stories`)
     - Card 2: `"Mythology"` (`218 stories`)
     - Card 3: `"Gothic"` (`185 stories`)
     - Card 4: `"Classic Mystery"` (`185 stories`)
  5. **Trending Writers Carousel:**
     - Section Header: `"Trending Writers 📈"` | Action: `"View All>"`
     - Horizontal Carousel with circular avatars, story counts, and ratings:
       - *R.F. Kuang* (`14 Stories`, ★ 4.9)
       - *Rebecca Yarros* (`9 Stories`, ★ 4.8)
       - *T.J. Klune* (`16 Stories`, ★ 4.9)
       - *Silvia Moreno-Garcia* (`14 Stories`, ★ 4.8)
  6. **Bottom Persistent Navigation:** 4 tabs (`Explore` active in terracotta).

---

### 3.7 Frame 7: `My Shelf` (Reading Dashboard & Archive)
- **Frame ID:** `1:1058`
- **Viewport Dimensions:** `390.0 × 930.0 pt`
- **SwiftUI Mapping:** `Sources/Views/ShelfView.swift`
- **Key Sub-Components:**
  1. **Top Brand Header:** `📖 Fable` logo with title `"My Shelf"`, top-right analytics icon `📈`, and settings gear icon `⚙️` (triggers `SettingsView`).
  2. **Segmented Collection Control (3 Segments):**
     - Segment 1: `"Saved"` (active white pill with subtle shadow)
     - Segment 2: `"Finished"`
     - Segment 3: `"My Drafts"`
  3. **Active Reading List (`ACTIVE STORIES (4)` | `Filter 🎛️`):**
     - Row 1: `"Reading • 2m left"` | `"The Legend of Sleepy Hollow"` by *Washington Irving* | Circular progress ring: `60%` | Menu `•••`
     - Row 2: `"Reading • 5m left"` | `"Dracula"` by *Bram Stoker* | Circular progress ring: `35%` | Menu `•••`
     - Row 3: `"Reading • 2m left"` | `"Metamorphosis"` by *Franz Kafka* | Circular progress ring: `80%` | Menu `•••`
     - Row 4: `"Reading • 1m left"` | `"The Tell-Tale Heart"` by *Edgar Allan Poe* | Circular progress ring: `15%` | Menu `•••`
  4. **Progress Ring Architecture:** Rendered using vector circle stroke trim (`Circle().trim(from: 0, to: progress)`) in `brandPrimary` terracotta.
  5. **Bottom Persistent Navigation:** 4 tabs (`Shelf` active in terracotta).

---

### 3.8 Frame 8: `Author / User Profile` (Personal Identity & Catalog)
- **Viewport Dimensions:** `390.0 × 1200.0 pt`
- **SwiftUI Mapping:** `Sources/Views/ProfileView.swift`
- **Key Sub-Components:**
  1. **Navigation:** Top-left back chevron (`<`) returning to previous screen.
  2. **Profile Identity Card:**
     - Centered circular avatar with pencil edit badge (`✏️`).
     - Display Name: `"Roosc Zaño"` with terracotta verified starburst (`✓`).
     - Handle: `"@zanoroosc"` (muted brown text).
     - Bio: *"“Writer of quiet lore, archivist of dusk folklore, and collector of vintage horology tales. Author of 14 published stories.”"*
  3. **Action Buttons:**
     - Primary: `✏️ Edit Profile` (terracotta button `#9F3C16`, 12pt radius)
     - Secondary: `⬆️ Share Profile` (light surface button)
  4. **Engagement Metrics (3 Columns):**
     - `14` *Stories* | `4.9k` *Reads* | `890` *Followers*
  5. **Segmented Catalog Control:** `"Published"` (active) | `"Reading Lists"`
  6. **Published Story Cards:**
     - Card 1: `FOLKLORE • 4 min read` | `"The Clockmaker of Prague"` (★ 4.9, 👁 1.2k reads)
     - Card 2: `NATURE MYTH • 2 min read` | `"The Whispering Pines"` (★ 4.8, 👁 840 reads)
     - Card 3: `FABLE • Completed` | `"The Starlit Loom"` (★ 5.0, 👁 620 reads)

---

### 3.9 Frame 9: `Genre Detail View` (Thematic Archive Hub)
- **Viewport Dimensions:** `390.0 × 1800.0 pt`
- **SwiftUI Mapping:** `Sources/Views/GenreDetailView.swift`
- **Key Sub-Components:**
  1. **Navigation Bar:** Back chevron (`<`) on left, centered title `"Genre Detail"`, top pills: `📖 ARCHIVE EDITION`, filter icon, bookmark icon.
  2. **Curated Genre Hero Card (Warm Parchment Surface):**
     - Headline: `"Folklore & Legends"` (Playfair Display 26pt Bold)
     - Metadata: `340 Tales • 19.4k Readers • Curated Weekly`
     - Description: *"“Traditional tales passed down through generations, reimagined by contemporary scribes—from fireside Slavic forest myths to maritime legends whispered across coastal tides.”"*
     - Action Button: `+ Follow Genre` (Terracotta filled button `#9F3C16`)
  3. **Sub-Theme Filter Chips:** Horizontally scrolling pills: `"All"` (active terracotta), `"Forest Spirits"`, `"Urban Legends"`, `"Slavic Myths"`.
  4. **Curator's Spotlight (`STORY OF THE WEEK`):**
     - Card: `"The Legend of Sleepy Hollow"` by *Washington Irving* (★ 4.9)
     - Excerpt: *"“A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere.”"*
     - Action: `Read Now 📖` terracotta button + bookmark toggle.
  5. **Recent Dispatches Section (`Sort by ⌄`):**
     - Item 1: `AMERICAN TALE • ⏱ 4 min` | `"Rip Van Winkle"` by *Washington Irving* (★ 4.9, 1.2k saves)
     - Item 2: `GOTHIC FABLE • ⏱ 3 min` | `"The Monkey's Paw"` by *W.W. Jacobs* (★ 4.8, 890 saves)
     - Item 3: `GRIMM'S FAIRY TALE • ⏱ 4 min` | `"The Fisherman and His Wife"` by *Brothers Grimm* (★ 4.8, 670 saves)
     - Item 4: `DARK ROMANTICISM • ⏱ 2 min` | `"The Sandman"` by *E.T.A. Hoffmann* (★ 4.7, 410 saves)

---

### 3.10 Frame 10: `Settings Modal View` (App & Reading Preferences)
- **Viewport Dimensions:** `390.0 × 844.0 pt`
- **SwiftUI Mapping:** `Sources/Views/SettingsView.swift`
- **Key Sub-Components:**
  1. **Modal Header:** Grabber handle, Left `"Cancel"` button, Center `"Settings"` title, Right `"Done"` button (terracotta).
  2. **Account Row Card:** Avatar of `Roosc Zaño`, email `roosc-zano@fable.app`, chevron `>`.
  3. **Reading Preferences Group:**
     - Row 1: `Default Reader Font` (icon: `[A]`), value `"New York >"`
     - Row 2: `Default Theme` (icon: palette), value `"⚪ Light >"`
     - Row 3: `Haptic Feedback` (icon: vibration waves), toggle switch: `ON` (terracotta active state)
  4. **Shelf & Library Group:**
     - Row 1: `Downloaded Stories`, value `"12 Tales (42 MB)"`, action button `"Clear Cache"`
     - Row 2: `Auto-Archive Stories` (*"Move completed tales out of shelf view"*), toggle switch: `OFF`
  5. **Sign Out Action:** Full-width rounded card with centered `"Sign Out"` in red text (`#D32F2F`).

---

## 4. Complete 10-Screen Navigation & Routing Topology

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FableApp (Root App Shell)                       │
│                                                                        │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌────────────┐  │
│  │   [0] LibraryView     │  │    [1] ExploreView    │  │ [2] Write  │  │
│  │   (Tale of Day, Feed) │  │  (Search, 2x2 Genres) │  │(Composer)  │  │
│  └───────────┬───────────┘  └───────────┬───────────┘  └─────┬──────┘  │
│              │                          │                    │         │
│              ▼                          ▼                    ▼         │
│     ┌─────────────────┐       ┌─────────────────┐    ┌───────────────┐ │
│     │   ReaderView    │       │ GenreDetailView │    │PublishedSheet │ │
│     │(Dracula Chapter)│       │ (Archive Hub)   │    │ (Celebration) │ │
│     └────────┬────────┘       └─────────────────┘    └───────────────┘ │
│              │                                                         │
│              ▼                                                         │
│     ┌─────────────────┐       ┌─────────────────┐    ┌───────────────┐ │
│     │DisplayOptions   │       │ [3] ShelfView   │───►│ SettingsView  │ │
│     │ (Fonts, Themes) │       │(Saved/Drafts/44)│    │ (Preferences) │ │
│     └─────────────────┘       └────────┬────────┘    └───────────────┘ │
│                                        │                               │
│                                        ▼                               │
│                               ┌─────────────────┐                      │
│                               │   ProfileView   │                      │
│                               │ (Roosc Zaño)    │                      │
│                               └─────────────────┘                      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Asset Strategy: Pure Procedural Blank Placeholders

Per our critical system design requirements:
1. **Zero Bitmap Image Failures:** All story covers, genre banners, author avatars, and vignette containers render procedurally via `PlaceholderCoverView`.
2. **Deterministic Styling:** Built-in warm beige parchment fills (`#ECE0DB`), 1pt hairline borders (`#E0D7D2`), and bold terracotta serif monograms (`story.title.prefix(1)`).
3. **100% Visual Parity with Prototype:** Replaces external asset dependencies with crash-proof vector and typography layouts while maintaining the exact visual hierarchy of the 10 Figma screens.
