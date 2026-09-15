# Feature Plan 02: Marginalia, Text Highlights & Reading Journal Quotes

**Document Version:** 1.0.0  
**Architectural Scope:** Text Range Anchoring, Passage Annotation, Shelf Journal Integration  
**Target Framework:** SwiftUI + TextKit 2 (iOS 17.0+)  
**Design Reference:** Figma Frame 7 (`ShelfView` Cicero Quote Card)  

---

## 1. Executive Problem Statement & Literary Vision

### 1.1 Beyond Passive Consumption
Reading folklore and literary fiction is inherently contemplative. Readers frequently encounter evocative sentences, mythic aphorisms, or narrative clues that they wish to preserve. In the current prototype, the quote card on the Shelf (*"A room without books is like a body without a soul. — Cicero"*) is statically hardcoded.

### 1.2 The Architectural Solution
We introduce an **Interactive Marginalia & Passage Annotation Engine** that empowers readers to:
1. Long-press and drag-select passages within `ReaderView`.
2. Apply editorial highlights using muted literary color tones.
3. Attach private margin notes (marginalia).
4. Pin memorable excerpts directly into the **Shelf Reading Journal Deck** as customized typographic quote cards.

---

## 2. Text Range Anchoring & Coordinate Math

### 2.1 The Challenge of Dynamic Typography
Because readers can scale font sizes from 80% to 150% and switch font families (*Source Serif 4* vs. *SF Pro*), annotations **must not rely on pixel coordinates or line numbers**. Instead, annotations are anchored to deterministic **UTF-16 Character Offsets** paired with **Surrounding Context Checksums**:

$$\text{Anchor} = (\text{StartOffset}, \text{EndOffset}, \text{ContextPrefixHash}, \text{ContextSuffixHash})$$

```
"The old horologe [began to chime the thirteenth hour] as shadows lengthened."
                      ▲                             ▲
                 Start: 18                      End: 55
```

If manuscript text undergoes minor formatting edits, the 16-byte surrounding context hash detects position drift and automatically re-anchors the highlight to the correct sentence.

---

## 3. Data Schema & Color Token Specifications

```swift
public enum HighlightColor: String, Codable, CaseIterable {
    case terracotta  // Primary editorial insights (#9F3C16, 25% alpha)
    case amber       // Mythic folklore motifs (#D99A4E, 30% alpha)
    case sage        // Historical / philosophical notes (#7B8C7E, 30% alpha)
    
    public var displayColor: Color {
        switch self {
        case .terracotta: return Color(red: 0.624, green: 0.235, blue: 0.086).opacity(0.25)
        case .amber:      return Color(red: 0.851, green: 0.604, blue: 0.306).opacity(0.30)
        case .sage:       return Color(red: 0.482, green: 0.549, blue: 0.494).opacity(0.30)
        }
    }
}

public struct Annotation: Identifiable, Codable, Equatable {
    public let id: UUID
    public let storyId: UUID
    public let utf16StartOffset: Int
    public let utf16EndOffset: Int
    public let selectedText: String
    public var note: String?
    public var color: HighlightColor
    public var isPinnedToJournal: Bool
    public let createdAt: Date
}
```

---

## 4. UI Interaction & Shelf Journal Quote Deck

```
┌────────────────────────────────────────────────────────┐
│             READER VIEW SELECTION OVERLAY              │
│                                                        │
│  "He listened to the mechanical ticking..."            │
│  ┌──────────────────────────────────────────────────┐  │
│  │ [Terracotta]  [Amber]  [Sage]  |  [Pin to Quote] │  │
│  └──────────────────────────────────────────────────┘  │
│  [================= SELECTED TEXT =================]   │
└────────────────────────────────────────────────────────┘
```

### 4.1 Shelf View Quote Deck Integration (Figma Frame 7 Parity)
When `isPinnedToJournal == true`, the excerpt is promoted to the dynamic **Quote Deck** in `ShelfView`:
- **Parchment Card Background:** `FableTheme.surface` (`#ECE0DB`).
- **Styling:** Large opening curly quote mark ($48\text{pt}$ terracotta serif `“`), italicized excerpt text in *Source Serif 4*, and attribution subtitle (`"Title • Author"`).
- **Interactive Action:** Tapping the quote opens the source story directly scrolled to that exact paragraph.

---

## 5. Verification & Testing Plan

### 5.1 Unit Tests
- **`test_annotation_range_validity()`**: Validate that `utf16EndOffset > utf16StartOffset` and is bounded by manuscript length.
- **`test_pin_to_journal_filters_properly()`**: Ensure `store.pinnedQuotes` queries only annotations where `isPinnedToJournal == true`.
- **`test_overlapping_highlights_resolution()`**: Verify that contiguous or nested highlights render without crashing TextKit layout managers.

### 5.2 Manual Verification Runbook
1. Open *"The Clockmaker of Prague"* in `ReaderView`.
2. Select the sentence *"Time is not a stream, but a clockwork wheel."*
3. Tap **Terracotta** highlight and toggle **Pin to Journal**.
4. Dismiss reader and open the **Shelf** tab.
5. **Pass Criteria:** The quote card renders with the selected passage and attribution.
