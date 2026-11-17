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
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let lightSurfaces: [(String, Color)] = [
            ("background", FableTheme.background),
            ("surface", FableTheme.surface),
            ("surface variant", FableTheme.surfaceVariant),
            ("card background", FableTheme.cardBackground)
        ]

        for (name, surface) in lightSurfaces {
            let fg = UIColor(FableTheme.textMuted).resolvedColor(with: lightTraits)
            let bg = UIColor(surface).resolvedColor(with: lightTraits)
            guard let ratio = contrastRatio(fg, bg) else {
                XCTFail("Unable to resolve colors for \(name)")
                continue
            }

            XCTAssertGreaterThanOrEqual(ratio, 4.5, "Muted text must meet WCAG AA contrast on light \(name)")
        }
    }

    func testMutedTextMeetsWCAGAAContrastOnDarkSurfaces() {
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        let darkSurfaces: [(String, Color)] = [
            ("background", FableTheme.background),
            ("surface", FableTheme.surface),
            ("surface variant", FableTheme.surfaceVariant),
            ("card background", FableTheme.cardBackground)
        ]

        for (name, surface) in darkSurfaces {
            let fg = UIColor(FableTheme.textMuted).resolvedColor(with: darkTraits)
            let bg = UIColor(surface).resolvedColor(with: darkTraits)
            guard let ratio = contrastRatio(fg, bg) else {
                XCTFail("Unable to resolve dark colors for \(name)")
                continue
            }

            XCTAssertGreaterThanOrEqual(ratio, 4.5, "Muted text must meet WCAG AA contrast on dark \(name)")
        }
    }

    @MainActor
    func testAppAppearanceColorSchemeMappingAndPersistence() {
        XCTAssertNil(AppAppearance.system.colorScheme)
        XCTAssertEqual(AppAppearance.light.colorScheme, .light)
        XCTAssertEqual(AppAppearance.dark.colorScheme, .dark)

        let defaults = UserDefaults.standard
        let original = defaults.string(forKey: AppAppearance.storageKey)
        let originalReaderTheme = defaults.string(forKey: "fable_pref_reader_theme")
        defer {
            if let original {
                defaults.set(original, forKey: AppAppearance.storageKey)
            } else {
                defaults.removeObject(forKey: AppAppearance.storageKey)
            }
            if let originalReaderTheme {
                defaults.set(originalReaderTheme, forKey: "fable_pref_reader_theme")
            } else {
                defaults.removeObject(forKey: "fable_pref_reader_theme")
            }
            AppAppearance.system.applyToWindows()
        }

        let store = StoryStore()
        store.appAppearance = .dark
        XCTAssertEqual(defaults.string(forKey: AppAppearance.storageKey), AppAppearance.dark.rawValue)

        let reloaded = StoryStore()
        XCTAssertEqual(reloaded.appAppearance, .dark)

        reloaded.appAppearance = .system
        XCTAssertEqual(defaults.string(forKey: AppAppearance.storageKey), AppAppearance.system.rawValue)
    }

    @MainActor
    func testAppAppearanceUIUserInterfaceStyleAndWindowSync() {
        XCTAssertEqual(AppAppearance.system.userInterfaceStyle, .unspecified)
        XCTAssertEqual(AppAppearance.light.userInterfaceStyle, .light)
        XCTAssertEqual(AppAppearance.dark.userInterfaceStyle, .dark)

        defer { AppAppearance.system.applyToWindows() }

        let connectedWindows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)

        for appearance in AppAppearance.allCases {
            appearance.applyToWindows()
            for window in connectedWindows {
                XCTAssertEqual(window.overrideUserInterfaceStyle, appearance.userInterfaceStyle)
                if let root = window.rootViewController {
                    XCTAssertEqual(root.overrideUserInterfaceStyle, appearance.userInterfaceStyle)
                }
            }
        }
    }

    @MainActor
    func testAppAppearanceSyncsReaderThemeAndPreservesManualChoiceOnLoad() {
        let defaults = UserDefaults.standard
        let originalAppearance = defaults.string(forKey: AppAppearance.storageKey)
        let originalReaderTheme = defaults.string(forKey: "fable_pref_reader_theme")
        defer {
            if let originalAppearance {
                defaults.set(originalAppearance, forKey: AppAppearance.storageKey)
            } else {
                defaults.removeObject(forKey: AppAppearance.storageKey)
            }
            if let originalReaderTheme {
                defaults.set(originalReaderTheme, forKey: "fable_pref_reader_theme")
            } else {
                defaults.removeObject(forKey: "fable_pref_reader_theme")
            }
            AppAppearance.system.applyToWindows()
        }

        defaults.removeObject(forKey: AppAppearance.storageKey)
        defaults.removeObject(forKey: "fable_pref_reader_theme")

        let store = StoryStore()
        store.appAppearance = .dark
        XCTAssertTrue(store.readerTheme.isDark)
        XCTAssertEqual(store.readerTheme, .midnight)

        store.readerTheme = .oled
        XCTAssertEqual(store.readerTheme, .oled)

        store.appAppearance = .light
        XCTAssertFalse(store.readerTheme.isDark)
        XCTAssertEqual(store.readerTheme, .sepia)

        // Manual ReaderTheme override stays intact across reloads
        store.appAppearance = .dark
        store.readerTheme = .paper
        let reloaded = StoryStore()
        XCTAssertEqual(reloaded.appAppearance, .dark)
        XCTAssertEqual(reloaded.readerTheme, .paper)
    }

    @MainActor
    func testReaderFontDesignsSpacingAndScaleToggles() {
        let defaults = UserDefaults.standard
        let originalFont = defaults.string(forKey: "fable_pref_reader_font")
        let originalSize = defaults.object(forKey: "fable_pref_reader_font_size")
        let originalSpacing = defaults.string(forKey: "fable_pref_reader_line_spacing")
        defer {
            if let originalFont {
                defaults.set(originalFont, forKey: "fable_pref_reader_font")
            } else {
                defaults.removeObject(forKey: "fable_pref_reader_font")
            }
            if let originalSize {
                defaults.set(originalSize, forKey: "fable_pref_reader_font_size")
            } else {
                defaults.removeObject(forKey: "fable_pref_reader_font_size")
            }
            if let originalSpacing {
                defaults.set(originalSpacing, forKey: "fable_pref_reader_line_spacing")
            } else {
                defaults.removeObject(forKey: "fable_pref_reader_line_spacing")
            }
        }

        XCTAssertEqual(ReaderFont.serif.design, .serif)
        XCTAssertEqual(ReaderFont.sans.design, .default)
        XCTAssertEqual(ReaderFont.rounded.design, .rounded)
        XCTAssertEqual(ReaderFont.mono.design, .monospaced)

        XCTAssertLessThan(ReaderLineSpacing.compact.points, ReaderLineSpacing.normal.points)
        XCTAssertLessThan(ReaderLineSpacing.normal.points, ReaderLineSpacing.spacious.points)

        let store = StoryStore()
        store.readerFont = .mono
        store.readerFontSize = 135.0
        store.readerLineSpacing = .spacious

        let reloaded = StoryStore()
        XCTAssertEqual(reloaded.readerFont, .mono)
        XCTAssertEqual(reloaded.readerFontSize, 135.0)
        XCTAssertEqual(reloaded.readerLineSpacing, .spacious)

        let compactWidth = renderedReaderTextSize(scale: 0.8, dynamicTypeSize: .large).width
        let standardWidth = renderedReaderTextSize(scale: 1.0, dynamicTypeSize: .large).width
        let enlargedWidth = renderedReaderTextSize(scale: 1.5, dynamicTypeSize: .large).width
        XCTAssertLessThan(compactWidth, standardWidth)
        XCTAssertLessThan(standardWidth, enlargedWidth)

        let serifNarrowWidth = renderedSampleWidth(text: "iiiiiiiiii", design: .serif, respectReaderFont: false)
        let monoWideWidth = renderedSampleWidth(text: "iiiiiiiiii", design: .monospaced, respectReaderFont: false)
        XCTAssertGreaterThan(monoWideWidth, serifNarrowWidth)

        let readerFontAppliedWidth = renderedSampleWidth(text: "iiiiiiiiii", design: .serif, respectReaderFont: true)
        XCTAssertGreaterThan(readerFontAppliedWidth, serifNarrowWidth)
    }

    @MainActor
    private func renderedSampleWidth(text: String, design: Font.Design, respectReaderFont: Bool) -> CGFloat {
        let view = Text(text)
            .fableFont(size: 17, design: design, relativeTo: .body, respectReaderFont: respectReaderFont)
            .fixedSize()
            .environment(\.dynamicTypeSize, .large)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: 2000, height: 2000))
            .width
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
