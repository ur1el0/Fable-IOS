import Foundation

public struct WriteTests {
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

        // Test 1: Word count tokenizer
        let sampleManuscript = "The quick brown fox jumps over the lazy dog."
        let wordCount = sampleManuscript.split { $0.isWhitespace || $0.isNewline }.count
        assert(wordCount == 9, "Manuscript Word Tokenizer")

        // Test 2: Read time estimation (approx 150 words per minute)
        let estimatedMinutes = max(1, wordCount / 150)
        assert(estimatedMinutes == 1, "Estimated Read Time Calculation")

        return (passed, total, failures)
    }
}
