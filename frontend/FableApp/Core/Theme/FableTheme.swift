import SwiftUI

public enum FableTheme {
    // MARK: - Modern Format-Agnostic Design Tokens
    // Electric Indigo accent for vibrant, media-neutral focus
    public static let brandPrimary = Color(red: 0.23, green: 0.35, blue: 0.96) // #3B59F6 Modern Electric Indigo
    public static let brandSecondary = Color(red: 0.12, green: 0.16, blue: 0.24) // #1E293B Slate Navy
    public static let brandAccent = Color(red: 0.49, green: 0.55, blue: 0.98) // #7D8CFA Soft Indigo Tint
    public static let background = Color(red: 0.968, green: 0.972, blue: 0.980) // #F7F8FA Clean neutral canvas
    public static let surface = Color(red: 0.933, green: 0.941, blue: 0.957) // #EEF0F4 Neutral container surface
    public static let surfaceVariant = Color(red: 0.910, green: 0.922, blue: 0.941) // #E8EBF0 Clean interactive pill background
    public static let textPrimary = Color(red: 0.07, green: 0.09, blue: 0.13) // #111721 Sharp high-contrast text
    public static let textSecondary = Color(red: 0.30, green: 0.35, blue: 0.43) // #4D596E Clean slate secondary
    public static let textMuted = Color(red: 0.58, green: 0.62, blue: 0.70) // #949EB2 Crisp metadata text
    public static let cardBackground = Color.white // #FFFFFF Clean surface
    public static let divider = Color(red: 0.89, green: 0.91, blue: 0.93) // #E3E8ED Fine hairline divider

    // MARK: - Prototype Aliases & Visual Palette
    public static let terracotta = brandPrimary
    public static let terracottaDark = Color(red: 0.15, green: 0.25, blue: 0.85)
    public static let warmCream = background
    public static let softPeach = surface
    public static let deepCharcoal = textPrimary
    public static let subtleSlate = textMuted
    public static let lightBorder = divider
    public static let tagBackground = surfaceVariant
    
    // Background themes for Reader
    public static let sepiaBackground = Color(red: 0.96, green: 0.95, blue: 0.93)
    public static let sepiaText = Color(red: 0.15, green: 0.15, blue: 0.18)
    
    public static let charcoalBackground = Color(red: 0.12, green: 0.13, blue: 0.15)
    public static let charcoalText = Color(red: 0.92, green: 0.93, blue: 0.95)
    
    public static let oledBackground = Color.black
    public static let oledText = Color(red: 0.92, green: 0.92, blue: 0.92)
}

public struct FableTagStyle: ViewModifier {
    public var isSelected: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
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
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

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
