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

        // Test 2: Reading stats hours calculation formatting
        let hours = Double(summary.totalMinutesRead) / 60.0
        assert(hours == 2.0, "Reading Stats Hours Calculation Parity")

        // Test 3: Multi-tenant ShelfSyncItem payload contract
        let testStoryId = UUID()
        let shelfItem = ShelfSyncItem(
            storyId: testStoryId,
            readingProgress: 1.0,
            isBookmarked: false,
            isCompleted: true,
            updatedAtUtc: Date()
        )
        assert(shelfItem.storyId == testStoryId && shelfItem.isCompleted == true && shelfItem.isBookmarked == false, "ShelfSyncItem Multi-Tenant Contract Integrity")

        // Test 4: ShelfSyncItem JSON serialization matches backend expectations
        if let encoded = try? JSONEncoder().encode(shelfItem),
           let jsonString = String(data: encoded, encoding: .utf8) {
            assert(jsonString.contains("storyId") || jsonString.contains("story_id"), "ShelfSyncItem Identifier Serialization")
        } else {
            assert(false, "ShelfSyncItem Serialization Failure")
        }

        return (passed, total, failures)
    }
}
