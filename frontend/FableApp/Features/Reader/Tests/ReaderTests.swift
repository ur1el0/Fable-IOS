import Foundation

@MainActor
public struct ReaderTests {
    public static func runAllTests() -> (passed: Int, total: Int, failures: [String]) {
        var passed = 0
        var total = 0
        var failures: [String] = []

        func assert(_ condition: Bool, _ testName: String) {
            total += 1
            if condition {
                passed += 1
            } else {
                failures.append(testName)
            }
        }

        let engine = PacingEngine()

        // Test 1: Baseline pace calculation (200 WPM baseline -> 1,000 words = 5 mins)
        let estimatedMins = engine.estimatedMinutesRemaining(remainingWords: 1000)
        assert(estimatedMins == 5, "Baseline Remaining Minutes Calculation")

        // Test 2: Extreme high-speed velocity clamping (<= 600 WPM)
        engine.recordReadingPace(wordsRead: 1000, elapsedSeconds: 10)
        assert(engine.currentWPM <= 600, "Clamp Upper Velocity Limit (600 WPM)")

        // Test 3: Extreme low-speed velocity clamping (>= 100 WPM)
        engine.recordReadingPace(wordsRead: 5, elapsedSeconds: 300)
        assert(engine.currentWPM >= 100, "Clamp Lower Velocity Limit (100 WPM)")

        return (passed, total, failures)
    }
}
