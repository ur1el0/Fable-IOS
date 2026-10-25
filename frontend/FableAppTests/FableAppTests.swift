import XCTest
@testable import FableApp

final class FableAppTests: XCTestCase {
    @MainActor
    func testAppHealthContracts() {
        let result = AppHealthTests.runAllTests()
        XCTAssertTrue(result.failures.isEmpty, "App health test failures: \(result.failures)")
        XCTAssertEqual(result.passed, result.total, "All health contracts must pass")
    }

    @MainActor
    func testLibraryContracts() {
        let result = LibraryTests.runAllTests()
        XCTAssertTrue(result.failures.isEmpty, "Library test failures: \(result.failures)")
        XCTAssertEqual(result.passed, result.total, "All library assertions must pass")
    }

    @MainActor
    func testReaderEngineInvariants() {
        let result = ReaderTests.runAllTests()
        XCTAssertTrue(result.failures.isEmpty, "Reader engine test failures: \(result.failures)")
        XCTAssertEqual(result.passed, result.total, "All reader assertions must pass")
    }

    @MainActor
    func testWriterInvariants() {
        let result = WriteTests.runAllTests()
        XCTAssertTrue(result.failures.isEmpty, "Writer test failures: \(result.failures)")
        XCTAssertEqual(result.passed, result.total, "All writer assertions must pass")
    }

    @MainActor
    func testShelfAnalytics() {
        let result = ShelfTests.runAllTests()
        XCTAssertTrue(result.failures.isEmpty, "Shelf test failures: \(result.failures)")
        XCTAssertEqual(result.passed, result.total, "All shelf assertions must pass")
    }

    @MainActor
    func testAuthenticationBoundary() async {
        let result = await AuthTests.runAllTests()
        XCTAssertTrue(result.failures.isEmpty, "Authentication test failures: \(result.failures)")
        XCTAssertEqual(result.passed, result.total, "All authentication assertions must pass")
    }
}
