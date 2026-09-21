import Foundation

public struct ShelfTests {
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

        // Test 1: Reading stats summary initialization
        let summary = PersistenceService.ReadingStatsSummary(storiesReadCount: 5, totalMinutesRead: 120, streakDays: 7)
        assert(summary.storiesReadCount == 5 && summary.totalMinutesRead == 120 && summary.streakDays == 7, "Reading Stats Summary Metrics")

        return (passed, total, failures)
    }
}
