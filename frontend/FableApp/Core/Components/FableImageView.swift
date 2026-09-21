import SwiftUI

public struct FableImageView: View {
    public let name: String?
    public var placeholderIcon: String = "book.closed"
    public var contentMode: ContentMode = .fill

    public init(name: String?, placeholderIcon: String = "book.closed", contentMode: ContentMode = .fill) {
        self.name = name
        self.placeholderIcon = placeholderIcon
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            if let name = name, !name.isEmpty {
                if name.hasPrefix("http://") || name.hasPrefix("https://"), let url = URL(string: name) {
                    // Web URL: Remote image from Gutendex or external API
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: contentMode)
                        case .failure:
                            proceduralGraphicView
                        case .empty:
                            ZStack {
                                FableTheme.surface
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        @unknown default:
                            proceduralGraphicView
                        }
                    }
                } else if let localImage = UIImage(named: name) {
                    // Local asset catalog image if present
                    Image(uiImage: localImage)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    // Procedural editorial fallback
                    proceduralGraphicView
                }
            } else {
                proceduralGraphicView
            }
        }
    }

    @ViewBuilder
    private var proceduralGraphicView: some View {
        let key = (name ?? "").lowercased()
        
        if isAvatar {
            avatarView(key: key)
        } else if isGenre {
            genreCoverView(key: key)
        } else {
            bookCoverView(key: key)
        }
    }

    private var isAvatar: Bool {
        let key = (name ?? "").lowercased()
        return key.contains("avatar") || key.contains("author") || placeholderIcon.contains("person")
    }

    private var isGenre: Bool {
        let key = (name ?? "").lowercased()
        return key.contains("genre")
    }

    // MARK: - Procedural Author Avatars
    private func avatarView(key: String) -> some View {
        let (initials, bgGradient) = avatarMetadata(for: key)
        
        return ZStack {
            LinearGradient(
                colors: bgGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Circle()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
            
            Text(initials)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.2), radius: 1, y: 1)
        }
    }

    private func avatarMetadata(for key: String) -> (String, [Color]) {
        if key.contains("roosc") {
            return ("RZ", [FableTheme.brandPrimary, FableTheme.brandSecondary])
        } else if key.contains("kuang") {
            return ("RF", [Color(red: 0.55, green: 0.22, blue: 0.18), Color(red: 0.32, green: 0.12, blue: 0.10)])
        } else if key.contains("yarros") {
            return ("RY", [Color(red: 0.35, green: 0.30, blue: 0.45), Color(red: 0.20, green: 0.15, blue: 0.30)])
        } else if key.contains("klune") {
            return ("TK", [Color(red: 0.25, green: 0.38, blue: 0.35), Color(red: 0.15, green: 0.25, blue: 0.22)])
        } else {
            return ("F", [FableTheme.brandPrimary, FableTheme.brandSecondary])
        }
    }

    // MARK: - Procedural Genre Cards
    private func genreCoverView(key: String) -> some View {
        let (icon, gradientColors, subtitle) = genreMetadata(for: key)
        
        return ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            
            // Subtle parchment filigree border
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                .padding(6)
            
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.92))
                    .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
                
                Text(subtitle.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2.0)
                    .foregroundColor(Color.white.opacity(0.85))
            }
        }
    }

    private func genreMetadata(for key: String) -> (String, [Color], String) {
        if key.contains("folklore") {
            return ("tree.fill", [Color(red: 0.60, green: 0.30, blue: 0.15), Color(red: 0.35, green: 0.18, blue: 0.08)], "Folklore")
        } else if key.contains("mythology") {
            return ("sparkles", [Color(red: 0.25, green: 0.28, blue: 0.48), Color(red: 0.14, green: 0.16, blue: 0.30)], "Mythology")
        } else if key.contains("gothic") {
            return ("flame.fill", [Color(red: 0.30, green: 0.15, blue: 0.20), Color(red: 0.15, green: 0.08, blue: 0.10)], "Gothic")
        } else {
            return ("magnifyingglass", [Color(red: 0.22, green: 0.32, blue: 0.38), Color(red: 0.12, green: 0.18, blue: 0.24)], "Mystery")
        }
    }

    // MARK: - Procedural Physical Book Covers
    private func bookCoverView(key: String) -> some View {
        let palette = bookPalette(for: key)
        
        return GeometryReader { geo in
            ZStack {
                // Leather / Linen Background Gradient
                LinearGradient(colors: palette.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                
                // Spine crease highlight (physical book volume effect)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.black.opacity(0.35), Color.black.opacity(0.05), Color.white.opacity(0.12), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * 0.08))
                    
                    Spacer()
                }
                
                // Double Gold/Foil Hairline Border
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(palette.foilColor.opacity(0.55), lineWidth: 1)
                    .padding(max(4, geo.size.width * 0.05))
                
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(palette.foilColor.opacity(0.25), lineWidth: 0.5)
                    .padding(max(7, geo.size.width * 0.08))
                
                // Center Ornamental Medallion
                VStack(spacing: max(2, geo.size.height * 0.02)) {
                    // Top filigree emblem
                    Image(systemName: palette.symbol)
                        .font(.system(size: min(22, max(12, geo.size.width * 0.18)), weight: .medium))
                        .foregroundColor(palette.foilColor)
                        .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                    
                    // Center Title Monogram
                    Text(palette.monogram)
                        .font(.system(size: min(34, max(18, geo.size.width * 0.26)), weight: .bold, design: .serif))
                        .foregroundColor(palette.foilColor)
                        .shadow(color: Color.black.opacity(0.4), radius: 3, y: 2)
                    
                    // Foil Divider
                    Rectangle()
                        .fill(palette.foilColor.opacity(0.6))
                        .frame(width: max(16, geo.size.width * 0.25), height: 1)
                    
                    // Micro Folio Stamp
                    Text(palette.tagText.uppercased())
                        .font(.system(size: min(9, max(6, geo.size.width * 0.07)), weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(palette.foilColor.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
            }
        }
    }

    private struct BookPalette {
        let colors: [Color]
        let foilColor: Color
        let symbol: String
        let monogram: String
        let tagText: String
    }

    private func bookPalette(for key: String) -> BookPalette {
        let gold = Color(red: 0.94, green: 0.85, blue: 0.65)
        let silver = Color(red: 0.90, green: 0.92, blue: 0.95)
        let bronze = Color(red: 0.88, green: 0.68, blue: 0.48)

        if key.contains("dracula") || key.contains("castle") {
            return BookPalette(
                colors: [Color(red: 0.35, green: 0.08, blue: 0.12), Color(red: 0.15, green: 0.04, blue: 0.06)],
                foilColor: gold,
                symbol: "building.columns.fill",
                monogram: "D",
                tagText: "Gothic"
            )
        } else if key.contains("sleepy") {
            return BookPalette(
                colors: [Color(red: 0.18, green: 0.28, blue: 0.20), Color(red: 0.08, green: 0.16, blue: 0.10)],
                foilColor: gold,
                symbol: "leaf.fill",
                monogram: "S",
                tagText: "Folklore"
            )
        } else if key.contains("metamorphosis") {
            return BookPalette(
                colors: [Color(red: 0.38, green: 0.24, blue: 0.16), Color(red: 0.18, green: 0.10, blue: 0.06)],
                foilColor: bronze,
                symbol: "hourglass",
                monogram: "M",
                tagText: "Classic"
            )
        } else if key.contains("clockmaker") {
            return BookPalette(
                colors: [Color(red: 0.28, green: 0.24, blue: 0.18), Color(red: 0.12, green: 0.10, blue: 0.08)],
                foilColor: gold,
                symbol: "clock.fill",
                monogram: "C",
                tagText: "Horology"
            )
        } else if key.contains("balete") {
            return BookPalette(
                colors: [Color(red: 0.16, green: 0.26, blue: 0.22), Color(red: 0.08, green: 0.14, blue: 0.10)],
                foilColor: gold,
                symbol: "tree.circle.fill",
                monogram: "B",
                tagText: "Baler"
            )
        } else if key.contains("jeepney") {
            return BookPalette(
                colors: [Color(red: 0.20, green: 0.22, blue: 0.32), Color(red: 0.10, green: 0.11, blue: 0.18)],
                foilColor: silver,
                symbol: "moon.stars.fill",
                monogram: "J",
                tagText: "Midnight"
            )
        } else if key.contains("diwata") || key.contains("maria") {
            return BookPalette(
                colors: [Color(red: 0.15, green: 0.32, blue: 0.28), Color(red: 0.07, green: 0.18, blue: 0.15)],
                foilColor: gold,
                symbol: "drop.fill",
                monogram: "M",
                tagText: "Myth"
            )
        } else if key.contains("tell_tale") {
            return BookPalette(
                colors: [Color(red: 0.30, green: 0.12, blue: 0.18), Color(red: 0.14, green: 0.05, blue: 0.08)],
                foilColor: silver,
                symbol: "heart.fill",
                monogram: "P",
                tagText: "Poe"
            )
        } else {
            return BookPalette(
                colors: [FableTheme.brandPrimary, FableTheme.brandSecondary],
                foilColor: gold,
                symbol: "book.closed.fill",
                monogram: "F",
                tagText: "Fable"
            )
        }
    }
}
