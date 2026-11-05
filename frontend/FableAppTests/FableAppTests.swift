import XCTest
import SwiftUI
import UIKit
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

    @MainActor
    func testPasswordRecoveryFlow() async {
        let result = await PasswordRecoveryTests.runAllTests()
        XCTAssertTrue(result.failures.isEmpty, "Password recovery test failures: \(result.failures)")
        XCTAssertEqual(result.passed, result.total, "All password recovery assertions must pass")
    }

    func testMutedTextMeetsWCAGAAContrastOnLightSurfaces() {
        let lightSurfaces: [(String, Color)] = [
            ("background", FableTheme.background),
            ("surface", FableTheme.surface),
            ("surface variant", FableTheme.surfaceVariant),
            ("card background", FableTheme.cardBackground)
        ]

        for (name, surface) in lightSurfaces {
            guard let ratio = contrastRatio(UIColor(FableTheme.textMuted), UIColor(surface)) else {
                XCTFail("Unable to resolve colors for \(name)")
                continue
            }

            XCTAssertGreaterThanOrEqual(ratio, 4.5, "Muted text must meet WCAG AA contrast on \(name)")
        }
    }

    @MainActor
    func testReaderTypographyCombinesDynamicTypeAndReaderScale() {
        let defaultSize = renderedReaderTextSize(scale: 1, dynamicTypeSize: .large)
        let readerEnlargedSize = renderedReaderTextSize(scale: 1.5, dynamicTypeSize: .large)
        let accessibilitySize = renderedReaderTextSize(scale: 1, dynamicTypeSize: .accessibility3)

        XCTAssertGreaterThan(readerEnlargedSize.width, defaultSize.width)
        XCTAssertGreaterThan(accessibilitySize.width, defaultSize.width)
    }

    @MainActor
    private func renderedReaderTextSize(scale: CGFloat, dynamicTypeSize: DynamicTypeSize) -> CGSize {
        let text = Text("Reader text follows accessibility settings")
            .fableFont(size: 17, scale: scale, design: .serif, relativeTo: .body)
            .fixedSize()
            .environment(\.dynamicTypeSize, dynamicTypeSize)
        return UIHostingController(rootView: text)
            .sizeThatFits(in: CGSize(width: 2000, height: 2000))
    }

    private func contrastRatio(_ first: UIColor, _ second: UIColor) -> Double? {
        guard let firstLuminance = relativeLuminance(first),
              let secondLuminance = relativeLuminance(second) else {
            return nil
        }

        let lighter = max(firstLuminance, secondLuminance)
        let darker = min(firstLuminance, secondLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> Double? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha), alpha >= 0.999 else {
            return nil
        }

        func linearize(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }
}
