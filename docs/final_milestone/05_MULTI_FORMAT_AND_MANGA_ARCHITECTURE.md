# Fable Capstone: Multi-Format Content & Manga Architecture
**Document:** `05_MULTI_FORMAT_AND_MANGA_ARCHITECTURE.md`  
**Author:** Senior Technical Instructor & Enterprise Solutions Architect  
**Audience:** Developer / Capstone Student  
**Target Branch:** `feature/final-milestone`  
**Last Updated:** 2026-09-23

---

## 1. Executive Summary & Design Pivot

The **Fable** project originally launched with a focused proof-of-concept centered around public domain folklore and classical literature. As digital reading platforms have evolved, modern readers demand a unified reading client capable of effortlessly displaying both rich typographic prose (novels, essays, folklore) and visual graphic narratives (manga, comics, webtoons).

This document details the architecture, ingestion pipelines, schema designs, and presentation layer adaptations that transformed Fable into a high-performance multi-format reading platform.

---

## 2. Architecture Decision Record (ADR 005)

### Status
**Accepted & Implemented**

### Context
Readers and content creators require support for diverse media types:
1. **Classical & Contemporary Prose:** Text-based novels with customizable typography, margins, reading speeds, and synthesized audio narration.
2. **Serialized Visual Manga:** Graphic sequential art consisting of high-resolution panel image manifests requiring dynamic zooming, zero-margin vertical webtoon scrolling, and horizontal panel flipping.
3. **Multi-Source Aggregation:** Aggregating public domain classics (Project Gutenberg, Standard Ebooks), serialized graphic novels (MangaDex), and original community creations (Fable Originals).

### Decision Drivers
- **Contract-First Extensibility:** The schema must support new content formats (e.g. Light Novels, Graphic Audiobooks) without breaking legacy clients.
- **Zero-Friction Ingestion:** Safe decoding fallbacks (`decodeIfPresent`) must guarantee that older database records decode cleanly without format keys.
- **Modern Brand Identity:** Discard dated antique/parchment styling in favor of contemporary, crisp, format-neutral aesthetics (system sans-serif typography, cinema black manga reader, clean pill selectors).

---

## 3. Domain Model & Ingestion Schema

```
                     +-----------------------+
                     |         Story         |
                     +-----------------------+
                     | id: UUID              |
                     | title: String         |
                     | author: String        |
                     | contentFormat: Enum   | ----> [ PROSE | MANGA ]
                     | sourceProvider: Enum  | ----> [ GUTENBERG | STANDARD_EBOOKS |
                     | coverImageUrl: String |         MANGADEX | FABLE_ORIGINAL ]
                     | chapters: [Chapter]   |
                     +-----------+-----------+
                                 |
                                 | 1..*
                                 v
                     +-----------------------+
                     |        Chapter        |
                     +-----------------------+
                     | id: UUID              |
                     | chapterNumber: Int    |
                     | title: String         |
                     | content: String (Prose|
                     | pageUrls: [String]    | ----> Sequential Panel URLs
                     +-----------------------+
```

### 3.1 ContentFormat & SourceProvider Enums

```swift
public enum ContentFormat: String, Codable, CaseIterable, Identifiable {
    case prose = "PROSE"
    case manga = "MANGA"

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .prose: return "Novel"
        case .manga: return "Manga"
        }
    }
}

public enum SourceProvider: String, Codable, CaseIterable, Identifiable {
    case gutenberg = "GUTENBERG"
    case standardEbooks = "STANDARD_EBOOKS"
    case mangadex = "MANGADEX"
    case fableOriginal = "FABLE_ORIGINAL"

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .gutenberg: return "Project Gutenberg"
        case .standardEbooks: return "Standard Ebooks"
        case .mangadex: return "MangaDex"
        case .fableOriginal: return "Fable Original"
        }
    }
}
```

### 3.2 Chapter Panel Manifest

For prose novels, the `content` string contains the text manuscript, and `pageUrls` defaults to an empty list `[]`. For manga, `content` is empty or holds translator notes, while `pageUrls` holds the sequential high-resolution panel image URLs:

```swift
public struct Chapter: Identifiable, Hashable, Codable {
    public let id: UUID
    public let storyId: UUID
    public let chapterNumber: Int
    public var title: String
    public var content: String
    public var wordCount: Int
    public let createdAtUtc: Date
    public var pageUrls: [String]
}
```

---

## 4. Manga Reader Engine (`MangaReaderView`)

### 4.1 Dual Reading Modes
Manga readers differ in reading ergonomics based on art style and publication origin:
1. **Webtoon Mode (`.webtoon`):** Continuous vertical scrolling with zero gap between panels, optimized for vertical digital comics and mobile viewports.
2. **Paging Mode (`.paged`):** Full-bleed horizontal swipe pagination (`TabView` with `.page` style), replicating traditional tankōbon book page turns.

```swift
public enum MangaReadingMode: String, CaseIterable, Identifiable {
    case webtoon = "Webtoon"
    case paged = "Paging"

    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .webtoon: return "arrow.up.and.down"
        case .paged: return "arrow.left.and.right"
        }
    }
}
```

### 4.2 Dynamic Panel Resolution Hierarchy
To prevent blank screens or broken image states, `MangaReaderView` implements a 3-tier fallback hierarchy:
```swift
private var activePageUrls: [String] {
    // 1. Explicit panels defined on active chapter
    if let chapter = currentChapter, !chapter.pageUrls.isEmpty {
        return chapter.pageUrls
    }
    // 2. Fallback to story's first chapter panels
    if let firstChap = story.chapters?.first, !firstChap.pageUrls.isEmpty {
        return firstChap.pageUrls
    }
    // 3. High-resolution cover art fallback
    return [story.coverImageUrl, story.effectiveCoverImage].compactMap { $0 }
}
```

### 4.3 Cinema Black Aesthetics
While prose novels leverage warm sepia and crisp white themes, graphic manga panels pop significantly when framed by pure OLED black (`Color.black.ignoresSafeArea()`). This reduces eye strain and emphasizes contrast and ink linework.

---

## 5. Visual Identity & Modern Typography Pivot

To ensure the application feels fresh, accessible, and equally tailored to modern graphic novels and classic novels, the visual styling was systematically transitioned:
- **Typography:** Replaced antique serif defaults with Apple's modern system sans-serif (`SF Pro`) across splash screens, onboarding cards, creator headers, and genre pills.
- **Copy:** Replaced archaic nomenclature ("folklore", "ancient wanderers", "tales") with format-neutral terminology ("stories", "manga", "readers", "creators").
- **Dynamic Filtering:** Added format selector chips (`All`, `Novels`, `Manga`) allowing readers to instantly filter the library catalog.

---

## 6. Verification & Automated Test Coverage

1. **Backend Integration Suite (`backend/test_main.py`):**
   - `test_multi_format_content_and_provider_serialization`: Verifies API serialization of `contentFormat` and `sourceProvider`.
   - `test_manga_chapter_page_urls_contract`: Verifies chapter JSON payloads containing `pageUrls`.
   - `test_create_manga_story_via_api`: End-to-end POST endpoint test creating a manga title with panels.
   - Result: **21/21 passing**.
2. **iOS Swift Test Harness (`LibraryTests.swift` & `ReaderTests.swift`):**
   - Decodes legacy payloads without `contentFormat` (defaults to `.prose` and `.fableOriginal`).
   - Decodes multi-format payloads with `MANGA` and `MANGADEX`.
   - Tests chapter `pageUrls` array extraction and empty fallback.
   - Validates store catalog content format and source provider diversity.
   - Tests `MangaReadingMode` icons and active page resolution hierarchy.
