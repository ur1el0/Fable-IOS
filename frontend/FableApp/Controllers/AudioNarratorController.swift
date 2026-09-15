import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
public final class AudioNarratorController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = AudioNarratorController()
    
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var currentSpokenRange: NSRange?
    @Published public var playbackRateMultiplier: Float = 1.0 // 0.75x to 1.5x
    @Published public private(set) var activeStoryId: UUID?
    
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
        if activeStoryId == story.id && isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
            isPaused = false
            return
        }
        
        if isPlaying {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        self.activeStory = story
        self.activeStoryId = story.id
        let utteranceText = story.content.isEmpty ? story.synopsis : story.content
        let utterance = AVSpeechUtterance(string: utteranceText)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        let clampedMultiplier = max(0.5, min(2.0, playbackRateMultiplier))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * clampedMultiplier
        utterance.pitchMultiplier = 0.95 // Deep, warm storytelling tone
        
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
        updateNowPlayingMetadata(story: story)
    }
    
    public func togglePlayback(for story: Story? = nil) {
        if let story = story, activeStoryId != story.id {
            speak(story: story)
            return
        }
        
        if synthesizer.isSpeaking && !synthesizer.isPaused {
            synthesizer.pauseSpeaking(at: .immediate)
            isPlaying = false
            isPaused = true
        } else if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
            isPaused = false
        } else if let story = story ?? activeStory {
            speak(story: story)
        }
    }
    
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentSpokenRange = nil
        activeStoryId = nil
        activeStory = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    public func setRateMultiplier(_ rate: Float) {
        self.playbackRateMultiplier = max(0.75, min(1.75, rate))
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
    
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isPlaying = false
            self.isPaused = false
            self.currentSpokenRange = nil
            self.activeStoryId = nil
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }
    
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isPlaying = false
            self.isPaused = false
            self.currentSpokenRange = nil
            self.activeStoryId = nil
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
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
