import SwiftUI

private struct FableScaledFontModifier: ViewModifier {
    @ScaledMetric private var scaledSize: CGFloat
    private let scale: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(
        size: CGFloat,
        scale: CGFloat,
        weight: Font.Weight,
        design: Font.Design,
        relativeTo textStyle: Font.TextStyle
    ) {
        self.scale = scale
        self.weight = weight
        self.design = design
        self._scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    func body(content: Content) -> some View {
        content.font(.system(size: scaledSize * scale, weight: weight, design: design))
    }
}

public extension View {
    func fableFont(
        size: CGFloat,
        scale: CGFloat = 1,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(FableScaledFontModifier(
            size: size,
            scale: scale,
            weight: weight,
            design: design,
            relativeTo: textStyle
        ))
    }
}

public enum AppAppearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    public static let storageKey = "fable_pref_app_appearance"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public enum FableTheme {
    private static func adaptive(
        light: (CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat)
    ) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1.0)
        })
        #else
        return Color(red: light.0, green: light.1, blue: light.2)
        #endif
    }

    // MARK: - Modern Format-Agnostic Design Tokens (Adaptive Light + Dark)
    // Electric Indigo accent for vibrant, media-neutral focus
    public static let brandPrimary = adaptive(
        light: (0.23, 0.35, 0.96),   // #3B59F6 Modern Electric Indigo
        dark: (0.36, 0.46, 1.00)     // #5C75FF High-contrast Indigo for dark surfaces
    )
    public static let brandSecondary = Color(red: 0.12, green: 0.16, blue: 0.24) // #1E293B Slate Navy (cover gradients)
    public static let brandAccent = adaptive(
        light: (0.49, 0.55, 0.98),   // #7D8CFA Soft Indigo Tint
        dark: (0.56, 0.62, 1.00)     // #8F9EFF
    )
    public static let background = adaptive(
        light: (0.968, 0.972, 0.980), // #F7F8FA Clean neutral canvas
        dark: (0.043, 0.059, 0.090)   // #0B0F17 Deep editorial slate canvas
    )
    public static let surface = adaptive(
        light: (0.933, 0.941, 0.957), // #EEF0F4 Neutral container surface
        dark: (0.078, 0.106, 0.149)   // #141B26 Elevated dark container
    )
    public static let surfaceVariant = adaptive(
        light: (0.910, 0.922, 0.941), // #E8EBF0 Clean interactive pill background
        dark: (0.110, 0.145, 0.204)   // #1C2534 Dark pill & control surface
    )
    public static let textPrimary = adaptive(
        light: (0.07, 0.09, 0.13),    // #111721 Sharp high-contrast text
        dark: (0.945, 0.961, 0.976)   // #F1F5F9 Crisp light editorial text
    )
    public static let textSecondary = adaptive(
        light: (0.30, 0.35, 0.43),    // #4D596E Clean slate secondary
        dark: (0.714, 0.761, 0.831)   // #B6C2D4 Readable cool slate
    )
    public static let textMuted = adaptive(
        light: (0.353, 0.392, 0.455), // #5A6474 Muted text with WCAG AA contrast on light surfaces
        dark: (0.580, 0.639, 0.722)   // #94A3B8 Muted text with WCAG AA contrast on dark surfaces
    )
    public static let cardBackground = adaptive(
        light: (1.0, 1.0, 1.0),       // #FFFFFF Clean surface
        dark: (0.067, 0.094, 0.141)   // #111824 Elevated dark card
    )
    public static let divider = adaptive(
        light: (0.89, 0.91, 0.93),    // #E3E8ED Fine hairline divider
        dark: (0.141, 0.188, 0.267)   // #243044 Subtle dark hairline divider
    )

    // MARK: - Prototype Aliases & Visual Palette
    public static let terracotta = brandPrimary
    public static let terracottaDark = adaptive(
        light: (0.15, 0.25, 0.85),
        dark: (0.28, 0.38, 0.95)
    )
    public static let warmCream = background
    public static let softPeach = surface
    public static let deepCharcoal = textPrimary
    public static let subtleSlate = textMuted
    public static let lightBorder = divider
    public static let tagBackground = surfaceVariant
    
    // Background themes for Reader
    public static let sepiaBackground = Color(red: 0.96, green: 0.95, blue: 0.93)
    public static let sepiaText = Color(red: 0.15, green: 0.15, blue: 0.18)
    
    public static let paperBackground = Color(red: 0.98, green: 0.96, blue: 0.92)
    public static let paperText = Color(red: 0.18, green: 0.15, blue: 0.13)
    
    public static let charcoalBackground = Color(red: 0.12, green: 0.13, blue: 0.15)
    public static let charcoalText = Color(red: 0.92, green: 0.93, blue: 0.95)
    
    public static let midnightBackground = Color(red: 0.08, green: 0.11, blue: 0.14)
    public static let midnightText = Color(red: 0.90, green: 0.93, blue: 0.95)
    
    public static let oledBackground = Color.black
    public static let oledText = Color(red: 0.92, green: 0.92, blue: 0.92)
}

public struct FableTagStyle: ViewModifier {
    public var isSelected: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .fableFont(size: 13, weight: isSelected ? .semibold : .medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? FableTheme.terracotta : FableTheme.tagBackground)
            .foregroundColor(isSelected ? .white : FableTheme.deepCharcoal)
            .clipShape(Capsule())
    }
}

public struct FableCardStyle: ViewModifier {
    var backgroundColor: Color = FableTheme.cardBackground
    var cornerRadius: CGFloat = 16
    var borderColor: Color = FableTheme.lightBorder.opacity(0.8)

    public func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

#if canImport(UIKit)
import UIKit

public enum FableHaptics {
    public static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    public static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}
#endif

public extension View {
    func fableTag(isSelected: Bool = false) -> some View {
        self.modifier(FableTagStyle(isSelected: isSelected))
    }

    func fableCard(
        backgroundColor: Color = FableTheme.cardBackground,
        cornerRadius: CGFloat = 16,
        borderColor: Color = FableTheme.lightBorder.opacity(0.8)
    ) -> some View {
        self.modifier(FableCardStyle(backgroundColor: backgroundColor, cornerRadius: cornerRadius, borderColor: borderColor))
    }
}

