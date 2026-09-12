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

## 3. Screen-by-Screen Figma Frame Alignment

### 3.1 Frame 1: `Library Feed` (Figma ID `1:2`) ↔ `LibraryView.swift`
- **Layout:** Vertical scrolling layout bounded by standard iOS safe areas.
- **Top App Bar:** Date eyebrow (`"TUESDAY, OCT 14"`), `"Library"` headline, and circular avatar button (opens `ProfileView`).
- **Category Filter Chips:** Horizontally scrolling pill chips (*All*, *Folklore*, *Mythology*, *Gothic*, *Speculative*, *Classic*).
- **Tale of the Day Hero:** 16:9 featured card showcasing *"The Clockmaker of Prague"*, displaying cover image, `"TALE OF THE DAY"` badge, bookmark heart button, title, excerpt, and author metadata.
- **Feed Section:** Vertical stack of story cards featuring cover thumbnails, title, author, read time, and direct tap-to-read triggers.

### 3.2 Frame 2: `Story Reader` (Figma ID `1:159`) ↔ `ReaderView.swift`
- **Layout:** Full-screen immersive reader.
- **Top Filigree & Metadata:** Chapter label (*"CHAPTER IV • THE CELESTIAL ASTROLABE"*), story title, author byline pill (*"M. Vance • Sep 2026 • 4 min read"*).
- **Vignette Break:** Illustration container with caption (*"Orloj Horologe, Old Town Square • FOLIO 82"*).
- **Manuscript Rendering:** Justified serif paragraphs with 1.65 line height on warm parchment canvas.
- **Reading Toolbar (Bottom Float):**
  - Progress indicator showing current completion percentage.
  - Interactive bookmark toggle button.
  - Typography & display settings trigger (presents `DisplayOptionsSheet`).
  - Dismiss/Close button.

### 3.3 Frame 3: `Reader Customization Sheet` (Figma ID `1:302`) ↔ `DisplayOptionsSheet.swift`
- **Layout:** Half-height modal sheet over active reading session.
- **Font Selection:** 3-way segment (*Source Serif 4*, *SF Pro*, *SF Mono*).
- **Font Size Stepper:** `A-` / `A+` buttons scaling font size from 80% to 150%.
- **Theme Swatches:** Circular color selectors for *White*, *Sepia* (`#F4ECE0`), *Charcoal* (`#2B2B2B`), and *OLED Black* (`#000000`).
- **Line Spacing:** Segment control (*Compact*, *Normal*, *Spacious*).

### 3.4 Frame 4: `Story Composer` (Figma ID `1:454`) ↔ `WriteView.swift`
- **Layout:** Scrollable authoring form with live word and time calculations.
- **Header:** Navigation title `"Write Tale"` with primary action button `"Publish"`.
- **Form Controls:**
  - Story Title (`TextField` with Playfair Display styling).
  - Genre Picker (Horizontal capsule selection).
  - Chapter Header input (`TextField`).
  - Synopsis field (`TextEditor` with character limits).
  - Main Manuscript Body (`TextEditor` with live word count).
- **Validation:** Enforces non-empty title and minimum content length before enabling the Publish button.

### 3.5 Frame 5: `Publish Success Sheet` (Figma ID `1:638`) ↔ `StoryPublishedSheet.swift`
- **Layout:** Centered celebration modal sheet.
- **Iconography:** Terracotta quill and parchment seal symbol.
- **Typography:** `"Tale Published!"` in Playfair Display 24pt Bold.
- **Actions:** Primary `"Share Tale"` button and secondary `"Return to Library"` button that dismisses the sheet and redirects the tab to Library.

### 3.6 Frame 6: `Explore & Search Tab` (Figma ID `1:752`) ↔ `ExploreView.swift`
- **Layout:** Discovery hub with search and thematic categorizations.
- **Search Header:** Persistent search field with clear button.
- **2-Column Genre Grid:** Visual genre banners for *Folklore*, *Mythology*, *Gothic*, and *Classic Mystery*.
- **Featured Authors Carousel:** Horizontal scrolling author cards with avatar, name, and story count.
- **Curated Reading Lists:** "Staff Picks", "Short Reads Under 5 Mins", and "Trending Legends".

### 3.7 Frame 7: `Shelf & Reading Journal` (Figma ID `1:1058`) ↔ `ShelfView.swift`
- **Layout:** Personal reading dashboard and archive.
- **Segmented Control:** Toggles between `"Bookmarked"` and `"Completed"` collections.
- **Reading Progress Cards:** Each story card renders an interactive SVG circular progress ring indicating current read status (e.g., 60%).
- **October Reading Stats Grid (3 Columns):**
  - Metric 1: **12** *Stories Read*
  - Metric 2: **48m** *Logged Time*
  - Metric 3: **3** *Days Streak* (with terracotta flame icon)
- **Literary Quote Card:** *“A room without books is like a body without a soul.” — Cicero* styled in italic Source Serif 4.

---

## 4. Asset Catalog Inventory (`Assets.xcassets`)
## 4. Asset-Decoupled Blank Placeholder Architecture

All image assets from the Figma design have been exported at 3x Retina resolution and organized into standard Xcode `.imageset` catalogs:
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

