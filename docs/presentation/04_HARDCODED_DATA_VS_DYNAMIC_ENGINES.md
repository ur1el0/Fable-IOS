# Fable iOS: Hardcoded Assets vs. Dynamic Algorithmic Engines

**Document Version:** 1.0.0  
**Target Milestone:** Midterm Presentation & Technical Defense  
**Author:** Roosc Zaño (`@zanoroosc`)  

---

## 1. Executive Summary: The Dual-Track Data Strategy

A common flaw in student capstone defenses is presenting either a trivial hardcoded UI mockup with no underlying logic, or an over-engineered backend that fails to run during lab evaluation due to networking or credential issues.

Fable addresses this with a **Dual-Track Data Strategy**:
1. **Curated In-Memory Seeds (Hardcoded for Resilience):** Provides guaranteed, rich literary data so evaluators can test every screen immediately without network configuration.
2. **Dynamic Hardware & Algorithmic Engines (Live Computation):** Core features—such as pagination, speech narration, reading velocity, and graphics—are computed dynamically in real time on the device.

---

## 2. Inventory of Hardcoded / Seeded Components

| File Path | Component | Why It Was Seeded / Hardcoded |
|---|---|---|
| [`frontend/FableApp/ViewModels/StoryStore.swift`](file:///Users/maclab/Documents/roosc/Fable-IOS/frontend/FableApp/ViewModels/StoryStore.swift) | `sampleStories` array (10 titles) | Seed catalog ensuring the iOS Simulator has immediate, authentic literature on first launch. |
| [`backend/core/seed_catalog.py`](file:///Users/maclab/Documents/roosc/Fable-IOS/backend/core/seed_catalog.py) | `SEED_CATALOG` list | Database seed populating SQLite on initial server startup with multi-chapter classics (*Dracula*, *Sleepy Hollow*, *Metamorphosis*). |
| [`backend/services/story_service.py`](file:///Users/maclab/Documents/roosc/Fable-IOS/backend/services/story_service.py) | `GENRE_METADATA` dictionary | Curated descriptions and reader metrics for genre category headers (Folklore, Gothic, Mythology). |

### Why Real Literary Text Instead of "Lorem Ipsum"?
We deliberately avoided generic "Lorem Ipsum" placeholder text. By seeding authentic literature with actual chapter divisions, the pacing engine, word counters, and audio synthesizer execute on real sentence structures, producing realistic reading metrics during the presentation.

---

## 3. Inventory of Dynamic Algorithmic Engines

The following components are **100% dynamic, reactive, and computed in real time**:

### 3.1 Dynamic Physical Book Pacing & Pagination Engine (`PacingEngine.swift`)
- **How It Works:** Rather than displaying an endless, unformatted vertical web-scroll, Fable algorithmically measures manuscript text and chunks it into discrete, numbered book pages.
- **The Algorithm:**
  1. Inspects raw manuscript text for natural paragraph breaks (`\n\n`) and sentence boundaries (`. `, `! `, `? `).
  2. Measures target page capacity (~180 to 220 words per page on mobile viewports).
  3. Dynamically recalculates total pages whenever the reader modifies font sizes or line spacing in `DisplayOptionsSheet`.
- **Live Reading Velocity (WPM):**
  $$\text{WPM} = \frac{\text{Words Read on Current Page}}{\text{Seconds Spent on Page}} \times 60$$
  Tracks active reading pace and adapts estimated time remaining per chapter.

### 3.2 Native Oral Folklore Speech Synthesizer (`AudioNarratorController.swift`)
- **How It Works:** Uses Apple's native `AVSpeechSynthesizer` to convert manuscript text into natural spoken narration.
- **Real-Time Word Highlighting:**
  - Implements `AVSpeechSynthesizerDelegate` to receive exact character-range callbacks as words are uttered by the iOS text-to-speech engine.
  - Dynamically highlights the corresponding paragraph in `ReaderView`, creating an accessible, synchronized audio-visual reading experience.
- **Zero Cloud Costs:** Operates completely on-device with zero API latency or third-party cloud audio subscription fees.

### 3.3 Zero-Asset Procedural Visual Engine (`FableImageView.swift`)
- **The Problem:** Depending on external bitmap images (`.png`, `.jpg`) frequently leads to broken white boxes or missing asset warnings when testing across different simulator environments or lab computers.
- **The Solution:** Fable implements a procedural vector graphics engine directly in SwiftUI:
  - **Dynamic Book Covers:** Generates book covers using deterministic linear gradients, ornamental borders, and typography stamped with the story's genre and title.
  - **Author Monograms:** Generates circular author avatars featuring initials and contrasting color palettes derived deterministically from the author's name hash.

### 3.4 Live Reading Analytics & Session Logging (`PersistenceService.swift`)
- **How It Works:** Every reading session logs an atomic transaction in SwiftData/SQLite:
  - Records session start time, duration, and words consumed.
  - Dynamically computes reading streak days (calculating consecutive calendar days with active reading sessions).
  - Updates the reader's profile badge ("Apprentice Scholar", "Folklore Sage") based on cumulative reading milestones.

### 3.5 Real-Time Search & Multi-Criteria Filtering
- **How It Works:** In `StoryStore.filteredStories`:
  - Dynamically evaluates search tokens against title, synopsis, and author strings using localized case-insensitive string containment.
  - Intersects search matches with active genre selections (`.folklore`, `.gothic`, `.mythology`), updating the UI immediately via SwiftUI's reactive render cycle.

---

## 4. Defense Talking Point: "Is This Just a Hardcoded Prototype?"

> *"No. The data is seeded so the app runs without external network friction, but the engines that process that data—the physical pagination algorithm, the AVFoundation oral speech synthesizer, the WPM velocity tracker, the procedural visual engine, and the SwiftData persistence layer—are 100% live, dynamic, and computed on-device in real time."*
