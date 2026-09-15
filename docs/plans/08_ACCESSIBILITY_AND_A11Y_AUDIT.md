# Feature Plan 08: Universal Accessibility (a11y) & VoiceOver Compliance

**Document Version:** 1.0.0  
**Architectural Scope:** Human Interface Guidelines (HIG), Inclusive Design, Assistive Technologies  
**Target Standards:** Apple Accessibility API, WCAG 2.1 AA (iOS 17.0+, Swift 5.9+)  
**Engineering Discipline:** Accessible Mobile Software Engineering  

---

## 1. Executive Summary & Compliance Invariants

### 1.1 The Accessibility Mandate
A literary e-reader must be usable by all readers, including visually impaired individuals who navigate via Apple’s **VoiceOver** screen reader or require Dynamic Type font scaling. Enterprise capstone rubrics evaluate accessibility compliance as a primary measure of software maturity.

### 1.2 Architectural Invariants
1. **Semantic Screen Reader Labels:** All icon-only interactive elements (e.g. quote export, narration controls, bookmark toggles) must provide explicit `.accessibilityLabel` and `.accessibilityHint` attributes.
2. **Dynamic Type Resiliency:** All UI containers and reading surfaces must adapt cleanly to iOS system-level text size adjustments without clipping or visual corruption.
3. **Contrast Ratios:** Foreground serif typography and accent colors against parchment backgrounds must satisfy a minimum contrast ratio of **4.5:1** for standard text and **3:1** for large headings.

---

## 2. Component Accessibility Mapping Matrix

| View Component | Target Control | Accessibility Label | Accessibility Hint | Accessibility Traits |
|---|---|---|---|---|
| [`ReaderView`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Views/ReaderView.swift) | Audio Narrator Play Button | `"Play Oral Audio Narration"` | `"Speaks the manuscript aloud with sentence highlighting"` | `.isButton` |
| [`ReaderView`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Views/ReaderView.swift) | Bookmark Toggle | `story.isBookmarked ? "Remove Bookmark" : "Add Bookmark"` | `"Saves this manuscript to your personal shelf"` | `.isButton` |
| [`ShelfView`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Views/ShelfView.swift) | Quote Export Button | `"Export Typographic Quote Card"` | `"Opens the quote card preview to share or save to photos"` | `.isButton` |
| [`DisplayOptionsSheet`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Views/DisplayOptionsSheet.swift) | Font Size Slider | `"Reader Font Size"` | `"Adjusts the reading typography size from 80% to 150%"` | `.isAdjustable` |
| [`FableDonutLoader`](file:///Users/maclab/Documents/roosc/Fable-iOS/frontend/FableApp/Views/FableDonutLoader.swift) | Donut Activity Spinner | `"Loading content"` | `""` | `.updatesFrequently` |

---

## 3. Implementation Code Patterns

### 3.1 Auditing Custom Icon Buttons

```swift
Button(action: {
    quoteToExport = quote
}) {
    HStack(spacing: 4) {
        Image(systemName: "square.and.arrow.up")
        Text("EXPORT")
    }
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Export quote by \(quote.storyAuthor)")
.accessibilityHint("Generates a typographic quote card to share or save")
.accessibilityAddTraits(.isButton)
```

### 3.2 Dynamic Type Scaled Font Modifiers

Ensure font sizes adapt to iOS system accessibility preferences using `@ScaledMetric`:

```swift
@ScaledMetric(relativeTo: .body) var baseFontSize: CGFloat = 17.0
```

---

## 4. Verification Protocol

1. **Accessibility Inspector:** Run Xcode's built-in Accessibility Inspector against the simulator. Run the automated audit tool to verify zero missing labels or low-contrast warnings.
2. **VoiceOver Simulation:** Enable VoiceOver on the simulator (`Cmd + F5`) and navigate through the 4 core tabs (Library, Explore, Write, Shelf) and ReaderView using swipe gestures.
