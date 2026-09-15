# Feature Plan 04: Oral Folklore Audio Synthesizer & Accessibility Narration

**Document Version:** 1.0.0  
**Architectural Scope:** Audio Session Management, Speech Synthesis, Lock-Screen Controls  
**Target Framework:** AVFoundation (`AVSpeechSynthesizer`) + MediaPlayer (`MPNowPlayingInfoCenter`)  
**Design Role:** Native Spoken Folklore & Vision Accessibility (a11y)  

---

## 1. Executive Problem Statement & Cultural Vision

### 1.1 The Oral Heritage of Folklore
Folklore, ghost stories, and mythological tales were originally spoken aloud around firesides long before being inscribed onto parchment. Furthermore, relying solely on visual reading excludes visually impaired users or readers in hands-busy contexts (commuting, evening relaxation).

### 1.2 The Asset-Decoupled Solution: Native Speech Synthesis
Instead of bundling hundreds of megabytes of brittle, pre-recorded MP3 audio files, Fable integrates Apple's native **`AVSpeechSynthesizer`**:
1. **Zero Asset Storage Overhead:** Synthesizes audio dynamically from manuscript text strings using iOS's neural voice models.
2. **Synchronized Text Highlight:** A subtle terracotta sentence wash tracks the active spoken sentence in real time.
3. **Background & Lock-Screen Audio:** Supports background playback with standard iOS Control Center and Lock Screen play/pause/scrub controls.
4. **Accessible Variable Playback Speed:** Allows speed adjustments from $0.75\times$ to $1.75\times$.

---

## 2. Audio State Machine & Controller Topology

```
                  ┌──────────────┐
                  │     Idle     │
                  └──────┬───────┘
                         │ Tap "Listen to Tale"
                         ▼
                  ┌──────────────┐
     ┌───────────►│   Playing    │◄───────────┐
     │ Resume     └──────┬───────┘            │ Play
     │                   │                    │
     │                   │ Pause              │
     │            ┌──────▼───────┐            │
     └────────────┤    Paused    ├────────────┘
                  └──────┬───────┘
                         │ Story Ends / Dismiss
                         ▼
                  ┌──────────────┐
                  │  Completed   │
                  └──────────────┘
```

---

## 3. Implementation Contract: `AudioNarratorController`

```swift
import Foundation
import AVFoundation
import MediaPlayer

@MainActor
public final class AudioNarratorController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentSpokenRange: NSRange?
    @Published public var playbackRateMultiplier: Float = 1.0 // 0.75x to 1.5x
    
    private let synthesizer = AVSpeechSynthesizer()
    private var activeStory: Story?
    
    public override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }
    
    public func speak(story: Story) {
        self.activeStory = story
        let utterance = AVSpeechUtterance(string: story.content)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * playbackRateMultiplier
        utterance.pitchMultiplier = 0.95 // Slightly deeper, warm storytelling tone
        
        synthesizer.speak(utterance)
        isPlaying = true
        updateNowPlayingMetadata(story: story)
    }
    
    public func togglePlayback() {
        if synthesizer.isPlaying {
            synthesizer.pauseSpeaking(at: .immediate)
            isPlaying = false
        } else if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
        }
    }
    
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        currentSpokenRange = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.currentSpokenRange = characterRange
        }
    }
    
    private func updateNowPlayingMetadata(story: Story) {
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = story.title
        info[MPMediaItemPropertyArtist] = story.author
        info[MPMediaItemPropertyAlbumTitle] = story.genre.rawValue
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
```

---

## 4. Verification & Testing Plan

### 4.1 Unit Tests
- **`test_audio_session_category_is_playback()`**: Verify audio session category is configured to `.playback` to prevent silent-switch muting.
- **`test_rate_multiplier_clamps_within_safe_bounds()`**: Verify speech rate multiplier is clamped between $0.5\times$ and $2.0\times$.
- **`test_stop_clears_now_playing_info()`**: Assert that stopping playback cleanly resets `MPNowPlayingInfoCenter`.

### 4.2 Manual Verification Runbook
1. Open any story in `ReaderView`.
2. Tap the floating **Listen** button in the reader navigation bar.
3. Verify spoken audio begins in a clear, natural storytelling voice.
4. Lock the iPhone simulator screen (`Cmd + L`).
5. **Pass Criteria:** Audio continues playing, and the lock-screen widget displays story title and author.
