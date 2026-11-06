import XCTest
@testable import FableApp

final class MangaReaderAccessibilityTests: XCTestCase {
    func testReaderActionLabelsFollowReaderState() {
        XCTAssertEqual(
            MangaReaderAccessibilityActions.chromeControls(isVisible: true),
            "Hide reader controls"
        )
        XCTAssertEqual(
            MangaReaderAccessibilityActions.chromeControls(isVisible: false),
            "Show reader controls"
        )
        XCTAssertEqual(MangaReaderAccessibilityActions.previousPage, "Previous page")
        XCTAssertEqual(MangaReaderAccessibilityActions.nextPage, "Next page")
        XCTAssertEqual(MangaReaderAccessibilityActions.pageLabel(3), "Manga page 3")
    }
}
