import SwiftUI

enum FableTheme {
    // Colors extracted from Fable Prototype
    static let terracotta = Color(red: 0.784, green: 0.388, blue: 0.216) // #C86337
    static let terracottaDark = Color(red: 0.69, green: 0.32, blue: 0.16)
    static let warmCream = Color(red: 0.984, green: 0.980, blue: 0.965) // #FAF9F6
    static let cardBackground = Color.white
    static let softPeach = Color(red: 0.965, green: 0.933, blue: 0.906) // #F6EFE7
    static let deepCharcoal = Color(red: 0.11, green: 0.11, blue: 0.11) // #1C1C1C
    static let subtleSlate = Color(red: 0.52, green: 0.50, blue: 0.48) // #85807A
    static let lightBorder = Color(red: 0.92, green: 0.90, blue: 0.88)
    static let tagBackground = Color(red: 0.94, green: 0.93, blue: 0.91)
    
    // Background themes for Reader
    static let sepiaBackground = Color(red: 0.957, green: 0.925, blue: 0.847) // #F4ECE0
    static let sepiaText = Color(red: 0.28, green: 0.22, blue: 0.18)
    
    static let charcoalBackground = Color(red: 0.17, green: 0.17, blue: 0.17) // #2B2B2B
    static let charcoalText = Color(red: 0.88, green: 0.88, blue: 0.88)
    
    static let oledBackground = Color.black
    static let oledText = Color(red: 0.85, green: 0.85, blue: 0.85)
}

struct FableTagStyle: ViewModifier {
    var isSelected: Bool = false
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? FableTheme.terracotta : FableTheme.tagBackground)
            .foregroundColor(isSelected ? .white : FableTheme.deepCharcoal)
            .clipShape(Capsule())
    }
}

extension View {
    func fableTag(isSelected: Bool = false) -> some View {
        self.modifier(FableTagStyle(isSelected: isSelected))
    }
}
