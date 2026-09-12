# Feature Plan 03: Authentic Pagination & Adaptive WPM Velocity Tracker

**Document Version:** 1.0.0  
**Architectural Scope:** Viewport Text Segmentation, Horizontal Paging, Exponential Moving Average Pacing  
**Target Framework:** SwiftUI + CoreText Layout Metrics (iOS 17.0+)  
**Design Reference:** Figma Frame 2 (`ReaderView` Filigree & Bottom Progress Bar)  

---

## 1. Executive Problem Statement & Reading Pacing

### 1.1 The Limitations of Continuous Scroll
While vertical scrolling is conventional in web feeds, longform reading on a mobile device introduces ocular disorientation:
- Readers lose their spatial anchor when scrolling.
- Static reading time badges (e.g., *"4 min read"*) remain fixed regardless of whether a user reads at 120 words-per-minute (deliberate study) or 350 words-per-minute (fast skim).

### 1.2 The Architectural Solution
1. **Authentic Horizontal Pagination Mode:** Allows readers to toggle between continuous vertical scroll and discrete horizontal page-turning with clean slide animations.
2. **Dynamic Viewport Text Fragmentation:** Deconstructs manuscript strings into distinct page blocks calculated from the active viewport bounds, font point size, and line height.
3. **Adaptive WPM Velocity Tracker:** Measures actual elapsed reading time per page and smooths the reader's pace using an Exponential Moving Average (EMA) to display an accurate, dynamic `"~X mins left in chapter"`.

---

## 2. Adaptive Reading Velocity Mathematical Model

### 2.1 Velocity Calculation per Page Turn
When the user turns from Page $k$ to Page $k+1$, the system records the elapsed dwell time $\Delta t_k$ (in seconds) and the word count $W_k$ on Page $k$:

$$\text{InstantaneousWPM}_k = \frac{W_k}{\max(1.0, \Delta t_k) / 60.0}$$

### 2.2 Outlier Filtering & Invariants
- If $\Delta t_k < 3.0\text{ s}$ (rapid skimming / flicking), the data point is discarded to avoid artificially inflating reading speed.
- If $\Delta t_k > 180.0\text{ s}$ (device left idle), the data point is capped at 180 seconds.

### 2.3 Exponential Moving Average (EMA) Smoothing
To prevent wild fluctuations between short and dense pages, velocity is smoothed with a smoothing factor $\alpha = 0.25$:

$$\text{PacingVelocity}_k = \alpha \cdot \text{InstantaneousWPM}_k + (1 - \alpha) \cdot \text{PacingVelocity}_{k-1}$$

### 2.4 Dynamic Chapter Remaining Time
$$\text{EstimatedMinutesRemaining} = \max\left(1, \left\lceil \frac{\sum_{i = k+1}^{N} W_i}{\text{PacingVelocity}_k} \right\rceil\right)$$

---

## 3. Viewport Pagination Algorithm

```
┌────────────────────────────────────────────────────────┐
│                   PAGE SLICING ENGINE                  │
│                                                        │
│  [ Full Manuscript String: 1,840 Words ]               │
│                        │                               │
│  Calculates TextKit 2  ▼ Bounds per Screen             │
│  ┌───────────────────┬───────────────────┬──────────┐  │
│  │ Page 1 (210 w)    │ Page 2 (195 w)    │ Page 3.. │  │
│  │ Chapter IV Intro  │ Astrolabe desc.   │ ...      │  │
│  └───────────────────┴───────────────────┴──────────┘  │
│                                                        │
│  Bottom Bar: "Page 2 of 9  •  ~3 mins left in chapter" │
└────────────────────────────────────────────────────────┘
```

### 3.1 SwiftUI Implementation Structure
```swift
public struct PaginatedReaderView: View {
    @ObservedObject var store: StoryStore
    let story: Story
    @State private var currentPageIndex: Int = 0
    @State private var pages: [String] = []
    
    public var body: some View {
        TabView(selection: $currentPageIndex) {
            ForEach(0..<pages.count, id: \.self) { index in
                VStack(alignment: .leading, spacing: 16) {
                    Text(pages[index])
                        .modifier(ReaderContentModifier(
                            font: store.readerFont,
                            fontSizePercentage: store.readerFontSize,
                            theme: store.readerTheme,
                            lineSpacing: store.readerLineSpacing
                        ))
                    Spacer()
                }
                .padding(.horizontal, 24)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(store.readerTheme.backgroundColor)
    }
}
```

---

## 4. Verification & Testing Plan

### 4.1 Unit Tests
- **`test_ema_smoothing_rejects_sub_3_second_flips()`**: Assert that instant page flips do not mutate `PacingVelocity`.
- **`test_pagination_text_integrity()`**: Assert that concatenating all sliced pages reconstructs the exact original manuscript string with zero dropped characters.
- **`test_minutes_remaining_decreases_monotonically()`**: Advance through pages at constant pace and verify estimated remaining time decreases toward 1 minute.

### 4.2 Manual Verification Runbook
1. Open a story in `ReaderView`.
2. Toggle reading mode from Vertical Scroll to **Paginated Book Mode**.
3. Swipe through 3 pages, dwelling ~30 seconds per page.
4. **Pass Criteria:** The bottom bar displays accurate `"Page 3 of X"` and dynamic time remaining updates smoothly.
