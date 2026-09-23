# Fable Capstone: UI Interactions, Voice Selection & Audio Accessibility Architecture
**Document:** `04_UI_INTERACTIONS_AND_AUDIO_ACCESSIBILITY.md`  
**Author:** Senior Technical Instructor & Enterprise Solutions Architect  
**Audience:** Developer / Capstone Student  
**Target Branch:** `feature/final-milestone`  
**Last Updated:** 2026-09-23

---

## 1. Executive Summary & Design Rationale

In modern reading applications, accessibility is not merely an auxiliary toggle—it is a core pillar of system architecture. Readers engage with narratives in diverse environments: on daily commutes, in low-light environments, or with visual impairments that necessitate auditory playback.

To provide an enterprise-grade accessible reading experience, **Fable** implements:
1. **Auditory Story Delivery (`AVSpeechSynthesizer`):** A synchronized state machine supporting seamless play, pause, resume, and rate modulation across multi-chapter manuscripts.
2. **Dynamic Voice & Locale Selection:** Runtime discovery of installed system voices via `AVSpeechSynthesisVoice.speechVoices()`, sorting by language, accent (`en-US`, `en-GB`, `en-AU`, `en-IE`), and rendering fidelity (`.enhanced`, `.premium`).
3. **Interactive Control Ergonomics:** Elimination of dead buttons or static placeholders across all application surfaces, ensuring full touch-target compliance (>= 44x44 pt) and accessible VoiceOver semantic labeling.

---

## 2. Audio Engine Architecture (`AudioNarratorController`)

```
                      +-------------------+
                      |   User / View     |
                      | (ReaderView/HUD)  |
                      +---------+---------+
                                |
             togglePlayPause()  |  selectVoice(identifier)
                                v
                +-------------------------------+
                |   AudioNarratorController     |
                |   (@MainActor, Observable)    |
                +---------------+---------------+
                                |
       +------------------------+------------------------+
       |                        |                        |
       v                        v                        v
+--------------+       +------------------+     +------------------+
| AVSpeech-    |       | AVSpeech-        |     | AVAudioSession   |
| Synthesizer  |       | SynthesisVoice   |     | .setCategory(    |
| State Machine|       | Registry         |     |   .playback)     |
+--------------+       +------------------+     +------------------+
```

### 2.1 Narration State Machine

The audio controller models playback as a discrete state machine:
- **`idle`:** No utterance active; speech engine is unallocated.
- **`speaking`:** `AVSpeechUtterance` active and feeding the audio bus.
- **`paused`:** Playback halted mid-paragraph with preserved utterance offset via `synthesizer.pauseSpeaking(at: .immediate)`.
- **`completed`:** Utterance has traversed all manuscript text; triggers transition to next chapter if auto-advance is enabled.

### 2.2 Utterance Configuration & Audio Session Discipline

```swift
// Background Audio Session Configuration
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
try session.setActive(true)

// Utterance Tuning
let utterance = AVSpeechUtterance(string: chapterText)
utterance.voice = selectedVoice ?? AVSpeechSynthesisVoice(language: "en-US")
utterance.rate = AVSpeechUtteranceDefaultSpeechRate // 0.50 baseline
utterance.pitchMultiplier = 1.0
utterance.preUtteranceDelay = 0.1
utterance.postUtteranceDelay = 0.1
```

---

## 3. Dynamic Voice Selection (`VoiceSelectionSheet`)

Rather than hardcoding a single synthetic voice, `VoiceSelectionSheet` queries the operating system for all high-quality synthetic voices available on the user's device:

1. **Filtering & Deduplication:** Filters voices by language code (defaulting to English dialects `en-*`, while supporting multi-lingual expansion).
2. **Quality Tier Badging:** Distinguishes between standard system voices, enhanced downloaded voices (`.enhanced`), and Apple neural synthesis voices (`.premium`).
3. **Auditory Preview:** Provides an immediate sample audition (`"The dusk fell upon the ancient stones of the library."`) directly within the sheet before committing the selection.
4. **Preference Persistence:** Stores the selected voice identifier in `UserDefaults` (`fable_pref_narrator_voice_id`), instantly restoring the user's preferred narrator on subsequent launches.

---

## 4. UI Interactions & Full Button Pass

Every interactive element in the interface has been audited to guarantee responsiveness:

| View | Control | Interaction Behavior | Accessibility Label |
| :--- | :--- | :--- | :--- |
| `ExploreView` | Search Button | Toggles full-width animated search bar | `"Search stories and manga"` |
| `ExploreView` | Format Filter Pills | Toggles filtering between All, Novel, and Manga | `"Filter by format: Novel"` |
| `ReaderView` | Audio HUD Play/Pause | Toggles `AudioNarratorController` state machine | `"Play narration" / "Pause narration"` |
| `ReaderView` | Voice Selector Button | Displays `VoiceSelectionSheet` modal | `"Select narrator voice"` |
| `ReaderView` | Display Options | Displays `DisplayOptionsSheet` (Font, Theme, Spacing) | `"Reader display options"` |
| `MangaReaderView` | Reading Mode Toggle | Switches between Webtoon (vertical) and Paging (horizontal) | `"Switch reading mode"` |
| `WriteView` | Publish Button | Validates manuscript, calculates word count, and persists | `"Publish story to community"` |
| `StoryPublishedSheet` | Return to Library | Dismisses sheet and navigates to Library feed | `"Return to library"` |
| `StoryPublishedSheet` | Share Story Link | Generates standard iOS share sheet (`UIActivityViewController`) | `"Share story link"` |
| `ProfileView` | Settings Trigger | Navigates to `SettingsView` for account/data management | `"Account and app settings"` |

---

## 5. Verification & Testing Standards

- **Unit Verification (`ReaderTests.swift`):**
  - Validates `ReaderFont.allCases` and `ReaderTheme.allCases` exhaustiveness.
  - Tests `MangaReadingMode` enum icon invariants (`arrow.up.and.down`, `arrow.left.and.right`).
  - Verifies reading pace clamping (100–600 WPM) and word tokenization accuracy.
- **Hardware & Simulator Verification:**
  - Audition playback on iOS Simulator (macOS host audio bus routing).
  - Verify seamless background audio continuation when switching tabs.
