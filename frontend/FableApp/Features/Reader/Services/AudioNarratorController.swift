import Foundation
import AVFoundation
import AVFAudio
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
    @Published public private(set) var activeChapterNumber: Int?
    @Published public var selectedVoiceIdentifier: String?
    
    private let synthesizer = AVSpeechSynthesizer()
    private var activeStory: Story?
    private var activeChapter: Chapter?
    private let voiceStorageKey = "fable_narrator_voice_id"
    
    public override init() {
        super.init()
        synthesizer.delegate = self
        self.selectedVoiceIdentifier = UserDefaults.standard.string(forKey: voiceStorageKey)
        configureAudioSession()
    }
    
    public var availableVoices: [AVSpeechSynthesisVoice] {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let english = all.filter { $0.language.hasPrefix("en") }
        return english.isEmpty ? all : english
    }
    
    public func setVoice(identifier: String) {
        self.selectedVoiceIdentifier = identifier
        UserDefaults.standard.set(identifier, forKey: voiceStorageKey)
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
    
    public func speak(story: Story, chapter: Chapter? = nil) {
        let sameStory = (activeStoryId == story.id)
        let sameChapter = (activeChapterNumber == chapter?.chapterNumber)
        
        if sameStory && sameChapter && isPaused {
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
        self.activeChapter = chapter
        self.activeChapterNumber = chapter?.chapterNumber
        
        let utteranceText: String
        if let chap = chapter, !chap.content.isEmpty {
            utteranceText = chap.content
        } else if !story.content.isEmpty {
            utteranceText = story.content
        } else {
            utteranceText = story.synopsis
        }
        
        let utterance = AVSpeechUtterance(string: utteranceText)
        if let voiceId = selectedVoiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        let clampedMultiplier = max(0.5, min(2.0, playbackRateMultiplier))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * clampedMultiplier
        utterance.pitchMultiplier = 0.95 // Deep, warm storytelling tone
        
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
        updateNowPlayingMetadata(story: story, chapter: chapter)
    }
    
    public func togglePlayback(for story: Story? = nil, chapter: Chapter? = nil) {
        if let story = story {
            let isDifferentStory = (activeStoryId != story.id)
            let isDifferentChapter = (activeChapterNumber != chapter?.chapterNumber)
            if isDifferentStory || isDifferentChapter {
                speak(story: story, chapter: chapter)
                return
            }
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
            speak(story: story, chapter: chapter ?? activeChapter)
        }
    }
    
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentSpokenRange = nil
        activeStoryId = nil
        activeChapterNumber = nil
        activeStory = nil
        activeChapter = nil
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
            self.activeChapterNumber = nil
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
            self.activeChapterNumber = nil
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }
    
    private func updateNowPlayingMetadata(story: Story, chapter: Chapter? = nil) {
        var info = [String: Any]()
        if let chap = chapter {
            info[MPMediaItemPropertyTitle] = "\(story.title) • Ch. \(chap.chapterNumber)"
            info[MPMediaItemPropertyAlbumTitle] = chap.title
        } else {
            info[MPMediaItemPropertyTitle] = story.title
            info[MPMediaItemPropertyAlbumTitle] = story.genre.rawValue
        }
        info[MPMediaItemPropertyArtist] = story.author
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
