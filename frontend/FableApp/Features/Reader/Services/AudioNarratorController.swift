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
    private static var registeredRemoteTargets: [(MPRemoteCommand, Any)] = []
    public private(set) var isRemoteCommandCenterConfigured: Bool = false

    public static func clampPlaybackRate(_ rate: Float) -> Float {
        max(0.75, min(1.75, rate))
    }

    public static func makeNowPlayingInfo(
        for story: Story,
        chapter: Chapter? = nil,
        isPlaying: Bool,
        playbackRate: Float
    ) -> [String: Any] {
        var info = [String: Any]()
        if let chap = chapter {
            info[MPMediaItemPropertyTitle] = "\(story.title) • Ch. \(chap.chapterNumber)"
            info[MPMediaItemPropertyAlbumTitle] = chap.title
        } else {
            info[MPMediaItemPropertyTitle] = story.title
            info[MPMediaItemPropertyAlbumTitle] = story.genre.rawValue
        }
        info[MPMediaItemPropertyArtist] = story.author
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(clampPlaybackRate(playbackRate)) : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        return info
    }
    
    public override init() {
        super.init()
        synthesizer.delegate = self
        self.selectedVoiceIdentifier = UserDefaults.standard.string(forKey: voiceStorageKey)
        configureAudioSession()
        configureRemoteCommandCenter()
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
    
    public func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }

    public func configureRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        for (command, token) in Self.registeredRemoteTargets {
            command.removeTarget(token)
        }
        Self.registeredRemoteTargets.removeAll()

        center.playCommand.isEnabled = true
        let playTarget = center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isPaused {
                    self.synthesizer.continueSpeaking()
                    self.isPlaying = true
                    self.isPaused = false
                    self.syncNowPlayingState()
                } else if !self.isPlaying, let story = self.activeStory {
                    self.speak(story: story, chapter: self.activeChapter)
                }
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        let pauseTarget = center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                self.synthesizer.pauseSpeaking(at: .immediate)
                self.isPlaying = false
                self.isPaused = true
                self.syncNowPlayingState()
            }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        let toggleTarget = center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.togglePlayback()
            }
            return .success
        }

        center.stopCommand.isEnabled = true
        let stopTarget = center.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stop()
            }
            return .success
        }

        Self.registeredRemoteTargets = [
            (center.playCommand, playTarget),
            (center.pauseCommand, pauseTarget),
            (center.togglePlayPauseCommand, toggleTarget),
            (center.stopCommand, stopTarget)
        ]
        isRemoteCommandCenterConfigured = true
    }
    
    public func speak(story: Story, chapter: Chapter? = nil) {
        let sameStory = (activeStoryId == story.id)
        let sameChapter = (activeChapterNumber == chapter?.chapterNumber)
        
        if sameStory && sameChapter && isPaused {
            configureAudioSession()
            synthesizer.continueSpeaking()
            isPlaying = true
            isPaused = false
            syncNowPlayingState()
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
        
        configureAudioSession()
        let utterance = AVSpeechUtterance(string: utteranceText)
        if let voiceId = selectedVoiceIdentifier, let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        }
        
        let clampedMultiplier = Self.clampPlaybackRate(playbackRateMultiplier)
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
            syncNowPlayingState()
        } else if synthesizer.isPaused {
            configureAudioSession()
            synthesizer.continueSpeaking()
            isPlaying = true
            isPaused = false
            syncNowPlayingState()
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
        MPNowPlayingInfoCenter.default().playbackState = .stopped
    }
    
    public func setRateMultiplier(_ rate: Float) {
        self.playbackRateMultiplier = Self.clampPlaybackRate(rate)
        syncNowPlayingState()
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
            MPNowPlayingInfoCenter.default().playbackState = .stopped
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
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
    }

    public func updateNowPlayingMetadata(story: Story, chapter: Chapter? = nil) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = Self.makeNowPlayingInfo(
            for: story,
            chapter: chapter,
            isPlaying: isPlaying,
            playbackRate: playbackRateMultiplier
        )
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : (isPaused ? .paused : .stopped)
    }

    private func syncNowPlayingState() {
        if let story = activeStory {
            updateNowPlayingMetadata(story: story, chapter: activeChapter)
        }
    }
}
