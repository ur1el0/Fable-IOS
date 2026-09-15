# FABLE: Visual Design & Figma Prototype Specification

**Application Name:** Fable (Curated Micro-Narrative & Editorial E-Reader)  
**Target Viewport:** Apple iPhone 14 / 15 / 16 (390 × 844 pt, Standard 3x Retina)  
**Figma File URL:** `https://www.figma.com/design/k90h1If7gNsEl56fQ1HxPq/Fable-App`  
**Prototype Document:** `Fable-prototype.pdf` (Included in Repository)  
**Fidelity Level:** 100% Visual and Navigational Parity with Midterm Submission

---

## 1. Design Philosophy & Aesthetic Hallmarks

Fable is designed with an **editorial-first aesthetic**, taking inspiration from distinguished independent publishers, literary gazettes, and modern longform platforms (such as *The New Yorker*, *The Paris Review*, and *Substack*). Unlike generic reading applications that rely on clinical monochrome palettes, Fable embraces a warm, tactually rich visual tone that invites contemplative, unhurried reading.

### Core Visual Pillars:
1. **Warm Parchment Canvas (`#FCF8FB`):** Soft, warm-cream paper tones prevent eye fatigue during extended reading sessions while establishing a sophisticated, classical feel.
2. **Signature Terracotta Accent (`#9F3C16`):** An earthy burnt orange anchors interactive components, active tab indicators, progress rings, and call-to-action buttons.
3. **Harmonious Typographic Pairing:** Expressive, literary serif headlines (*Playfair Display* and *Source Serif 4*) paired with clean, accessible sans-serif interface elements (*Inter* / *SF Pro*).
4. **Physicality & Tactility:** Generous whitespace, refined hairline dividers (`#E0D7D2`), subtle depth shadows, and capsule chips evoke physical paper stationery and vintage folios.

---

## 2. Global Design Tokens

### 2.1 Color Palette

| Token Name | Hex Code | Swift / RGB Equivalent | Architectural Role |
|---|---|---|---|
| `brandPrimary` | `#9F3C16` | `Color(red: 0.624, green: 0.235, blue: 0.086)` | Primary accent, CTA buttons, active tabs, progress fills |
| `brandSecondary` | `#57423B` | `Color(red: 0.341, green: 0.259, blue: 0.231)` | Deep chestnut, subheadings, author names |
| `brandAccent` | `#DEC0B7` | `Color(red: 0.871, green: 0.753, blue: 0.718)` | Soft muted blush, border highlights, chip highlights |
| `background` | `#FCF8FB` | `Color(red: 0.988, green: 0.973, blue: 0.984)` | Global canvas background (warm parchment) |
| `surface` | `#ECE0DB` | `Color(red: 0.925, green: 0.878, blue: 0.859)` | Container surfaces, quote card background, badge fills |
| `surfaceVariant` | `#F0EDEF` | `Color(red: 0.941, green: 0.929, blue: 0.937)` | Inactive filter chips, search bar container background |
| `textPrimary` | `#1B1B1D` | `Color(red: 0.106, green: 0.106, blue: 0.114)` | High-contrast title and body text (near-black) |
| `textSecondary` | `#57423B` | `Color(red: 0.341, green: 0.259, blue: 0.231)` | Warm brown text for synopses, authors, and subtitles |
| `textMuted` | `#8C736B` | `Color(red: 0.549, green: 0.451, blue: 0.420)` | Timestamps, reading times, placeholders, inactive icons |
| `cardBackground` | `#FFFFFF` | `Color.white` | Pure white elevated cards for high content legibility |
| `divider` | `#E0D7D2` | `Color(red: 0.880, green: 0.840, blue: 0.820)` | Hairline card borders and horizontal separators |

### 2.2 Typography Hierarchy

| Style Role | Font Family | Size | Weight | Line Height | Usage Location |
|---|---|---|---|---|---|
| **Large Display Title** | Playfair Display / Serif | 34pt | Bold (700) | 40px | Screen Titles ("Library", "Explore", "Shelf") |
| **Story Headline** | Playfair Display / Serif | 28pt | Bold (700) | 34px | Reader Screen Story Title |
| **Editorial Headline** | Playfair Display / Serif | 22pt | SemiBold (600) | 28px | Story Card Titles (Hero & Feed) |
| **Section Heading** | Inter / SF Pro | 17pt | SemiBold (600) | 24px | Section Titles ("Continue Reading", "Reading Stats") |
| **Card Title** | Playfair Display / Serif | 18pt / 16pt | SemiBold (600) | 22px | Grid story card titles |
| **Reader Manuscript** | Source Serif 4 / Serif | 17pt | Regular (400) | 28px (1.65) | Longform story body text |
| **UI Body** | Inter / SF Pro | 14pt | Regular (400) | 20px | Synopses, descriptions, form text |
| **Button / Chip Label** | Inter / SF Pro | 13pt | Medium (500) | 16px | Filter chips, action buttons, tab titles |
| **Metadata / Timestamp**| Inter / SF Pro | 12pt | Medium (500) | 16px | Author lines, read time estimates |
| **Eyebrow Tag** | Inter / SF Pro | 11pt | Bold (700) | 13px | Uppercase tags ("TALE OF THE DAY", "MYTH & LORE") |

### 2.3 Visual Metrics & Radii

- **Hero Card Corner Radius:** `20pt`
- **Standard Story Card Radius:** `16pt`
- **Stat & Quote Container Radius:** `14pt`
- **Standard Button & Input Radius:** `12pt`
- **Pill / Filter Chip Radius:** `9999pt` (Capsule)
- **Shadow Tokens:**
  - Card Shadow: `Color.black.opacity(0.04), radius: 8, x: 0, y: 2`
  - Terracotta Button Shadow: `brandPrimary.opacity(0.25), radius: 12, x: 0, y: 4`
  - Floating Sheet Shadow: `Color.black.opacity(0.08), radius: 16, x: 0, y: -4`

---

## 3. Screen-by-Screen Figma Frame Alignment (First Five Fixed Screens)

### 3.1 Frame 1: `Library Feed` (Figma ID `1:2`) ↔ `LibraryView.swift`
- **Layout:** Vertical scrolling layout bounded by standard iOS safe areas.
- **Top App Bar:** Date eyebrow (`"TUESDAY, OCT 14"` in muted Inter 11pt) and `"Library"` title in Playfair Display 30pt Bold.
- **Category Filter Chips:** Horizontally scrolling capsule chips (*All* [Active: `#9F3C16` terracotta], *Folklore*, *Mythology*, *Sci-Fi*, *Fables*).
- **Tale of the Day Hero:** 16:9 featured card showcasing *"Dracula"* by *Bram Stoker*:
  - Procedural blank parchment cover with terracotta monogram initial `"D"`.
  - Top-left capsule pill: `"TALE OF THE DAY"` (white background, terracotta text).
  - Top-right circular bookmark button with ribbon icon.
  - Subtitle: `"Bram Stoker •"`
  - Story Headline: `"Dracula"` (Playfair Display 22pt Bold).
  - Narrative Excerpt: *"“The castle is on the very edge of a terrible precipice. A stone falling from the window would fall a thousand feet without touching anything.”"*
- **Continue Reading Section:**
  - Section Header: `"Continue Reading"` with `"See All"` action link.
  - Story Card: *"The Legend of Sleepy Hollow"* by *Washington Irving*.
  - Procedural blank cover thumbnail (3:4 aspect ratio with monogram `"S"`).
  - Linear Progress Bar: Terracotta progress line displaying `"60% complete • Page 14 of 24"` with play icon `▷`.
- **Recent Submissions Section (Counter: "3 new stories"):**
  - Card 1: Author tag `"Franz Kafka"`, Title *"The Metamorphosis"*, excerpt: *"“One morning, when Gregor Samsa woke from troubled dreams, he found himself transformed in his bed into a monstrous vermin.”"*
  - Card 2: Author tag `"Edgar Allan Poe"`, Title *"The Tell-Tale Heart"*, excerpt: *"“True! — nervous — very, very dreadfully nervous I had been and am; but why will you say that I am mad?”"*
  - Card 3: Author tag `"Jose Rizal"`, Title *"The Legend of Maria Makiling"*, excerpt: *"“She was a fantastic creature, half nymph, half sylph, born under the moonbeams in the mystery of ancient...”"*
- **Bottom Persistent Navigation:** 4-tab bar (`Library` active, `Explore`, `Write`, `Shelf`).

### 3.2 Frame 2: `Story Reader` (Figma ID `1:159`) ↔ `ReaderView.swift`
- **Layout:** Immersive full-screen reading canvas.
- **Navigation:** Back chevron (`<`) at top-left dismissing back to Library.
- **Header:** Centered title *"Dracula"* in Playfair Display 28pt Bold.
- **Metadata Capsule:** Centered pill displaying `🌓 M. Vance • Sep 2026 • ⏱ 4 min read`.
- **Hero Chapter Vignette:** 16:9 procedural blank parchment container with hairline border and soft corner radius (asset-decoupled placeholder).
- **Manuscript Text:** Elegant justified serif paragraphs (*Source Serif 4*, 17pt, 1.65 line height) on warm parchment canvas (`#FCF8FB`).
- **Floating Bottom Reader Toolbar Capsule:**
  - Left segment: Book symbol + `"Page 2 of 5"`.
  - Separator: Muted bullet `•`.
  - Center segment: Mini terracotta progress track indicating `"40%"`.
  - Right segment: Circular `"TT"` button opening the Display Options Sheet.

### 3.3 Frame 3: `Reader Customization Sheet` (Figma ID `1:302`) ↔ `DisplayOptionsSheet.swift`
- **Layout:** Half-height modal sheet presented over dimmed reader content.
- **Top Control Bar:** Left `"Reset"` action in terracotta, centered `"Display Options"` title, right `"✕"` dismiss button.
- **Typography Section:** Header `"TYPOGRAPHY"` | `"Source Serif 4"`. 3-segment control: `Serif` (active white card with shadow), `Sans`, `Mono`.
- **Text Size Section:** Header `"TEXT SIZE"` | `"100%"`. Continuous slider bounded by small `A` and large `A` with terracotta fill.
- **Reading Background Section:** Header `"READING BACKGROUND"`. 4 circular color swatches:
  - `White` (`#FFFFFF`)
  - `Sepia` (`#F4ECE0`, active with terracotta `✓` checkmark inside)
  - `Charcoal` (`#2B2B2B`)
  - `OLED` (`#000000`)
- **Line Spacing Section:** Header `"LINE SPACING"`. 3 options:
  - `Compact` (tight lines)
  - `Normal` (standard lines; active state: peach `#FBEAE3` fill, terracotta `#9F3C16` border and text)
  - `Spacious` (relaxed lines)

### 3.4 Frame 4: `Story Composer` (Figma ID `1:454`) ↔ `WriteView.swift`
- **Layout:** Scrollable authoring studio with live word and time calculations.
- **Top Navigation Bar:**
  - Left: `"Clear"` in terracotta / red.
  - Center: `✍️ DRAFT MODE` capsule pill.
  - Right: Circular terracotta publish button with upward arrow `↑`.
- **Identity Section (`IDENTITY • Manuscript`):**
  - Card container:
    - Row 1: `"Title"` label | `"The Metamorphosis"` in Playfair Display bold.
    - Divider line.
    - Row 2: `"Genre"` label | Pill badge `📖 Classic Fiction` | `"Chapter I"` | Chevron `>`.
- **Synopsis Section (`SYNOPSIS • Micro-prologue`):**
  - Card container:
    - Text: *"“Gregor Samsa wakes one morning to discover he has transformed into a monstrous insect, forcing his family to confront their dependency and disgust.”"*
    - Footer: `⏱ Card preview previewable on Shelf` (left) | Character count `"142 / 200"` (right).
- **Manuscript Section (`MANUSCRIPT`):**
  - Longform body editor containing Gregor Samsa's transformation text.
  - Pagination dots `• •` and resize grip.
- **Bottom Stats Capsule (Floating above Tab Bar):**
  - `"142 / 500 words"` (list icon with active terracotta underline).
  - `•` bullet.
  - `⏱ ~1 min fable`.
  - `•` bullet.
  - `☁️ Saved 2m ago`.

### 3.5 Frame 5: `Publish Success Sheet` (Figma ID `1:638`) ↔ `StoryPublishedSheet.swift`
- **Layout:** Centered celebration modal card over dimmed backdrop.
- **Celebration Badge:** Circular peach badge (`#FBEAE3`) with subtle terracotta sparkles, enclosing an inner circle with terracotta checkmark `✓`.
- **Typography:**
  - Headline: `"Story Published!"` (Playfair Display 24pt Bold).
  - Subtitle: `"Your fable is now live in the Community Library for fellow wanderers to read and reflect upon."` (14pt regular, centered).
- **Metadata Pill:** Capsule container with `• Public  • Folklore  • 142 words`.
- **Action Hierarchy:**
  - Primary CTA: `"View Story Now →"` (Full-width terracotta `#9F3C16` button, 14pt corner radius).
  - Secondary Action: `"Return to Library"` (Centered text button).
  - Tertiary Action: `↑ Share story link` (Terracotta link with upload/share symbol).

### 3.6 Frame 6: `Explore & Search Tab` (Figma ID `1:752`) ↔ `ExploreView.swift`
- **Layout:** Discovery hub with search bar, 2x2 genre categories, and author spotlights.
- **Top Brand Bar:** `📖 Fable` logo on left, category label `"Explore"` on right.
- **Search Header:** Persistent search field (`#F0EDEF` container) with magnifying glass icon and placeholder `"Search stories, authors, or genres"`.
- **Discovery Filter Chips:** Capsule pills: `"All"` (active terracotta `#9F3C16`), `"Under 5 mins ✓"`, `"Community Favorites"`.
- **Popular Genres (2x2 Grid):**
  - Section Header: `"Popular Genres"` | `"24 categories"`.
  - Cards: *Folklore* (`340 stories`), *Mythology* (`218 stories`), *Gothic* (`185 stories`), *Classic Mystery* (`185 stories`).
  - Rendered with procedural warm parchment surfaces and serif typography titles.
- **Trending Writers Carousel:**
  - Section Header: `"Trending Writers 📈"` | `"View All>"`.
  - Horizontal scrolling avatar cards with author names, story counts, and ratings (*R.F. Kuang*, *Rebecca Yarros*, *T.J. Klune*, *Silvia Moreno-Garcia*).

### 3.7 Frame 7: `My Shelf` (Figma ID `1:1058`) ↔ `ShelfView.swift`
- **Layout:** Personal reading dashboard and library archive.
- **Top Bar:** Brand logo `📖 Fable`, large headline `"My Shelf"`, top-right analytics icon `📈`, and settings gear icon `⚙️` (presents `SettingsView`).
- **3-Segment Collection Control:** `"Saved"` (active white card with shadow), `"Finished"`, `"My Drafts"`.
- **Active Stories List (`ACTIVE STORIES (4)` | `Filter 🎛️`):**
  - Item 1: `Reading • 2m left` | *"The Legend of Sleepy Hollow"* by *Washington Irving* | Circular progress ring: `60%` | Menu `•••`
  - Item 2: `Reading • 5m left` | *"Dracula"* by *Bram Stoker* | Circular progress ring: `35%` | Menu `•••`
  - Item 3: `Reading • 2m left` | *"Metamorphosis"* by *Franz Kafka* | Circular progress ring: `80%` | Menu `•••`
  - Item 4: `Reading • 1m left` | *"The Tell-Tale Heart"* by *Edgar Allan Poe* | Circular progress ring: `15%` | Menu `•••`
- **Progress Ring Architecture:** Rendered using vector circle stroke trim (`Circle().trim(from: 0, to: progress)`) in `brandPrimary` terracotta with centered percentage label.

### 3.8 Frame 8: `Author / User Profile` ↔ `ProfileView.swift`
- **Layout:** Personal author profile and published folio archive.
- **Navigation:** Top-left back chevron button (`<`).
- **Identity Header:**
  - Centered circular avatar photo with edit badge (`✏️`).
  - Name: `"Roosc Zaño"` with verified terracotta badge (`✓`).
  - Handle: `"@zanoroosc"`.
  - Bio: *"“Writer of quiet lore, archivist of dusk folklore, and collector of vintage horology tales. Author of 14 published stories.”"*
- **Actions:** Primary `"✏️ Edit Profile"` (terracotta) | Secondary `"⬆️ Share Profile"`.
- **3-Column Metrics:** `14` *Stories* | `4.9k` *Reads* | `890` *Followers*.
- **Segmented Control:** `"Published"` (active) | `"Reading Lists"`.
- **Published Story Cards:**
  - *"The Clockmaker of Prague"* (★ 4.9, 👁 1.2k reads)
  - *"The Whispering Pines"* (★ 4.8, 👁 840 reads)
  - *"The Starlit Loom"* (★ 5.0, 👁 620 reads)

### 3.9 Frame 9: `Genre Detail View` ↔ `GenreDetailView.swift`
- **Layout:** Thematic curated archive hub.
- **Navigation:** Back chevron (`<`), title `"Genre Detail"`, top pills: `📖 ARCHIVE EDITION`, filter, bookmark.
- **Curated Genre Hero Card (Warm Parchment):**
  - Headline: `"Folklore & Legends"` (Playfair Display 26pt Bold).
  - Metadata: `340 Tales • 19.4k Readers • Curated Weekly`.
  - Description: *"“Traditional tales passed down through generations, reimagined by contemporary scribes—from fireside Slavic forest myths to maritime legends whispered across coastal tides.”"*
  - CTA Button: `+ Follow Genre` (`#9F3C16` terracotta).
- **Sub-Category Filter Chips:** Capsule pills: `"All"` (active terracotta), `"Forest Spirits"`, `"Urban Legends"`, `"Slavic Myths"`.
- **Curator's Spotlight (`STORY OF THE WEEK`):**
  - Card: *"The Legend of Sleepy Hollow"* by *Washington Irving* (★ 4.9) with excerpt, `"Read Now 📖"` CTA, and bookmark button.
- **Recent Dispatches Section (`Sort by ⌄`):**
  - 4 stories: *"Rip Van Winkle"*, *"The Monkey's Paw"*, *"The Fisherman and His Wife"*, *"The Sandman"*.

### 3.10 Frame 10: `Settings Modal View` ↔ `SettingsView.swift`
- **Layout:** Modal half/full sheet presenting app and reader preferences.
- **Header:** Top grabber handle, Left `"Cancel"`, Center `"Settings"` (bold), Right `"Done"` (terracotta).
- **Account Row:** Avatar of `Roosc Zaño`, email `roosc-zano@fable.app`, chevron `>`.
- **Reading Preferences Group:**
  - Row 1: `Default Reader Font` | `"New York >"`
  - Row 2: `Default Theme` | `"⚪ Light >"`
  - Row 3: `Haptic Feedback` | Toggle switch: `ON` (terracotta active)
- **Shelf & Library Group:**
  - Row 1: `Downloaded Stories` | `"12 Tales (42 MB)"` | Action button `"Clear Cache"`
  - Row 2: `Auto-Archive Stories` (*"Move completed tales out of shelf view"*) | Toggle switch: `OFF`
- **Account Action:** Full-width rounded card with centered `"Sign Out"` in red text.

---

## 4. Asset-Decoupled Blank Placeholder Architecture

To eliminate brittle runtime dependencies on external binary bitmap assets (`.png`, `.jpg`) and guarantee 100% operational consistency across every Mac lab workstation, Fable implements an **asset-decoupled procedural visual architecture**.

### 4.1 Visual Parity with Prototype (Without Bitmap Images)
Instead of relying on fragile raster image files that can fail to resolve in school computer labs, all story covers, hero containers, and visual banners are rendered procedurally:
- **Parchment Surface Fill:** `FableTheme.surface` (`#ECE0DB`, warm beige parchment).
- **Hairline Border:** 1pt stroke in `FableTheme.divider` (`#E0D7D2`).
- **Dynamic Monogram:** The first initial of the story title rendered in *Playfair Display* / System Serif Bold (`#9F3C16` terracotta).
- **Genre Eyebrow Pill:** Uppercase category tag pinned to top-left.
- **Watermark Symbol:** Subtle SF Symbol (`book.closed` or `text.book.closed`) rendered at 40% opacity in `brandSecondary` (`#57423B`).

### 4.2 Structural Blueprint: `PlaceholderCoverView`
```swift
public struct PlaceholderCoverView: View {
    public let title: String
    public let genre: String
    public var aspectRatio: CGFloat = 16/9
    public var cornerRadius: CGFloat = 16
    
    public init(title: String, genre: String, aspectRatio: CGFloat = 16/9, cornerRadius: CGFloat = 16) {
        self.title = title
        self.genre = genre
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        ZStack {
            FableTheme.surface
            
            VStack {
                HStack {
                    Text(genre.uppercased())
                        .font(FableTypography.eyebrowTag)
                        .foregroundColor(FableTheme.terracotta)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(FableTheme.cardBackground.opacity(0.85))
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "book.closed")
                        .font(.system(size: 14))
                        .foregroundColor(FableTheme.textMuted.opacity(0.6))
                }
                .padding(12)
                
                Spacer()
                
                Text(String(title.prefix(1)).uppercased())
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundColor(FableTheme.terracotta.opacity(0.85))
                
                Spacer()
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(FableTheme.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
```
Sources/Resources/Assets.xcassets/

### 4.3 Engineering & Architectural Benefits
1. **Deterministic Execution:** Zero risk of `UIImage(named:) -> nil` crashes or broken image placeholder squares.
2. **Instant Clone & Compilation:** Reduces repository footprint by removing 50MB+ of binary image assets.
3. **High Editorial Tactility:** Evokes high-end typography-first book covers (reminiscent of Faber & Faber and Penguin Modern Classics).
4. **Offline & Lab Safe:** Zero asynchronous network downloads; 100% instant rendering on both Simulator and physical hardware.

---

## 5. Reference Asset Inventory (Archival / Figma Mapping)

If external artwork is reintroduced in a future production release, the original visual mapping from the Figma prototype correlates to the following identifier namespace:

```
Sources/Resources/Assets.xcassets/ (Optional Reference)
├── AccentColor.colorset
├── AppIcon.appiconset
├── hero_castle.imageset                # Hero card feature image
├── cover_dracula.imageset              # Classic horror book cover
├── cover_sleepy_featured.imageset      # Legend of Sleepy Hollow cover
├── thumb_clockmaker.imageset           # Clockmaker of Prague thumbnail
├── thumb_pines.imageset                # Whispering Pines thumbnail
├── thumb_loom.imageset                 # Starlit Loom thumbnail
├── thumb_fisherman.imageset            # Urashima Taro thumbnail
├── thumb_maria_makiling.imageset       # Maria Makiling folklore thumbnail
├── thumb_metamorphosis.imageset        # Franz Kafka Metamorphosis cover
├── thumb_tell_tale.imageset            # Tell-Tale Heart thumbnail
├── thumb_monkeys_paw.imageset          # Monkey's Paw thumbnail
├── thumb_sandman.imageset              # ETA Hoffmann Sandman thumbnail
├── thumb_rip_van_winkle.imageset       # Rip Van Winkle thumbnail
├── thumb_sleepy.imageset               # Sleepy Hollow thumbnail
├── genre_folklore.imageset             # Genre banner: Folklore
├── genre_mythology.imageset            # Genre banner: Mythology
├── genre_gothic.imageset               # Genre banner: Gothic
├── genre_mystery.imageset              # Genre banner: Mystery
├── avatar_roosc.imageset               # Current logged-in user profile avatar
├── author_kuang.imageset               # Featured author: R.F. Kuang
├── author_klune.imageset               # Featured author: TJ Klune
└── author_yarros.imageset              # Featured author: Rebecca Yarros
```

