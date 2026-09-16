import SwiftUI

public enum FableTheme {
    // MARK: - Figma Global Design Tokens (FIGMA.md Section 2.1)
    public static let brandPrimary = Color(red: 0.624, green: 0.235, blue: 0.086) // #9F3C16 Primary brand accent, active tabs, buttons
    public static let brandSecondary = Color(red: 0.341, green: 0.259, blue: 0.231) // #57423B Deep chestnut, subheadings, author names
    public static let brandAccent = Color(red: 0.871, green: 0.753, blue: 0.718) // #DEC0B7 Soft muted blush, border highlights
    public static let background = Color(red: 0.988, green: 0.973, blue: 0.984) // #FCF8FB Global canvas background
    public static let surface = Color(red: 0.925, green: 0.878, blue: 0.859) // #ECE0DB Container surface, badge fills
    public static let surfaceVariant = Color(red: 0.941, green: 0.929, blue: 0.937) // #F0EDEF Filter chips, search bar background
    public static let textPrimary = Color(red: 0.106, green: 0.106, blue: 0.114) // #1B1B1D High contrast body and title text
    public static let textSecondary = Color(red: 0.341, green: 0.259, blue: 0.231) // #57423B Warm brown synopses text
    public static let textMuted = Color(red: 0.549, green: 0.451, blue: 0.420) // #8C736B Timestamps, read times, placeholders
    public static let cardBackground = Color.white // #FFFFFF Elevated cards
    public static let divider = Color(red: 0.880, green: 0.840, blue: 0.820) // #E0D7D2 Subtle hairline borders

    // MARK: - Prototype Aliases & Visual Palette
    public static let terracotta = brandPrimary
    public static let terracottaDark = Color(red: 0.50, green: 0.18, blue: 0.07)
    public static let warmCream = background
    public static let softPeach = surface
    public static let deepCharcoal = textPrimary
    public static let subtleSlate = textMuted
    public static let lightBorder = divider
    public static let tagBackground = surfaceVariant
    
    // Background themes for Reader
    public static let sepiaBackground = Color(red: 0.957, green: 0.925, blue: 0.847) // #F4ECE0
    public static let sepiaText = Color(red: 0.28, green: 0.22, blue: 0.18)
    
    public static let charcoalBackground = Color(red: 0.17, green: 0.17, blue: 0.17) // #2B2B2B
    public static let charcoalText = Color(red: 0.88, green: 0.88, blue: 0.88)
    
    public static let oledBackground = Color.black
    public static let oledText = Color(red: 0.85, green: 0.85, blue: 0.85)
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
