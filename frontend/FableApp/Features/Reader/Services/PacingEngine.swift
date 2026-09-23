import Foundation
import SwiftUI
import Combine

@MainActor
public final class PacingEngine: ObservableObject {
    public static let shared = PacingEngine()
    
    @Published public private(set) var pacingVelocityWPM: Double = 200.0
    private var lastPageTurnTimestamp: Date?
    private let alpha: Double = 0.25 // EMA smoothing factor
    
    public init() {}
    
    public func startSession() {
        lastPageTurnTimestamp = Date()
    }
    
    public func recordPageTurn(wordsOnPage: Int) {
        guard let previousTime = lastPageTurnTimestamp else {
            lastPageTurnTimestamp = Date()
            return
        }
        
        let now = Date()
        let elapsedSeconds = now.timeIntervalSince(previousTime)
        lastPageTurnTimestamp = now
        
        // Discard fast skims (< 3.0s) and cap long idle reads (> 180.0s)
        guard elapsedSeconds >= 3.0 else { return }
        let clampedSeconds = min(180.0, elapsedSeconds)
        
        let instantaneousWPM = Double(wordsOnPage) / (clampedSeconds / 60.0)
        
        // Guard against absurd spikes
        guard instantaneousWPM >= 50.0 && instantaneousWPM <= 600.0 else { return }
        
        // Apply Exponential Moving Average (EMA)
        self.pacingVelocityWPM = (alpha * instantaneousWPM) + ((1.0 - alpha) * pacingVelocityWPM)
    }
    
    public var currentWPM: Double {
        pacingVelocityWPM
    }
    
    public func recordReadingPace(wordsRead: Int, elapsedSeconds: Double) {
        guard elapsedSeconds > 0 else { return }
        let instantaneousWPM = Double(wordsRead) / (elapsedSeconds / 60.0)
        let clampedWPM = min(600.0, max(100.0, instantaneousWPM))
        self.pacingVelocityWPM = (alpha * clampedWPM) + ((1.0 - alpha) * pacingVelocityWPM)
    }
    
    public func estimatedMinutesRemaining(remainingWords: Int) -> Int {
        guard remainingWords > 0 else { return 1 }
        let minutes = Double(remainingWords) / max(80.0, pacingVelocityWPM)
        return max(1, Int(ceil(minutes)))
    }
    
    /// Zoom-invariant, Unicode-compliant word counter.
    /// Accurately counts words across irregular whitespaces, tabs, newlines, and punctuation.
    public static func countWords(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }
    
    /// Chunks a continuous manuscript into structured pages based on paragraphs,
    /// dynamic viewport font scaling, and target word thresholds.
    public static func chunkIntoPages(
        text: String,
        fontSizePercentage: Double = 100.0,
        baseWordsPerPage: Int = 180
    ) -> [String] {
        let scale = max(0.5, fontSizePercentage / 100.0)
        let effectiveTargetWords = max(50, Int(round(Double(baseWordsPerPage) / scale)))
        
        let paragraphs = text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard !paragraphs.isEmpty else {
            return [text.isEmpty ? "No manuscript content available." : text]
        }
        
        var pages: [String] = []
        var currentPageParagraphs: [String] = []
        var currentWordCount = 0
        
        for paragraph in paragraphs {
            let wordsInPara = countWords(in: paragraph)
            
            if currentWordCount + wordsInPara > effectiveTargetWords && !currentPageParagraphs.isEmpty {
                pages.append(currentPageParagraphs.joined(separator: "\n\n"))
                currentPageParagraphs = [paragraph]
                currentWordCount = wordsInPara
            } else {
                currentPageParagraphs.append(paragraph)
                currentWordCount += wordsInPara
            }
        }
        
        if !currentPageParagraphs.isEmpty {
            pages.append(currentPageParagraphs.joined(separator: "\n\n"))
        }
        
        return pages.isEmpty ? [text] : pages
    }
}
