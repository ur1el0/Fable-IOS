import Foundation

@MainActor
public struct LibraryTests {
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

        let store = StoryStore()

        // Test 1: Story store initialization
        assert(!store.stories.isEmpty, "Stories Catalog Loaded")

        // Test 2: Bookmark toggling
        if let first = store.stories.first {
            let initialState = first.isBookmarked
            store.toggleBookmark(for: first)
            let updatedState = store.stories.first(where: { $0.id == first.id })?.isBookmarked ?? false
            assert(updatedState != initialState, "Toggle Bookmark State")
            store.toggleBookmark(for: first) // revert
        }

        // Test 3: Reading progress mutation
        if let first = store.stories.first {
            store.updateProgress(for: first, progressPercent: 75, currentPage: 3, totalPages: 4)
            let updated = store.stories.first(where: { $0.id == first.id })
            assert(updated?.progressPercent == 75 && updated?.currentPage == 3, "Update Reading Progress")
        }

        return (passed, total, failures)
    }
}
