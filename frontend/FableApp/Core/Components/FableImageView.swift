import SwiftUI

@MainActor
public struct FableImageView: View {
    public let name: String?
    public let title: String?
    public var placeholderIcon: String = "book.closed"
    public var contentMode: ContentMode = .fill

    public init(
        name: String?,
        title: String? = nil,
        placeholderIcon: String = "book.closed",
        contentMode: ContentMode = .fill
    ) {
        self.name = name
        self.title = title
        self.placeholderIcon = placeholderIcon
        self.contentMode = contentMode
    }

    public var body: some View {
        GeometryReader { geo in
            if let name,
               let url = URL(string: name),
               url.scheme?.lowercased() == "https",
               url.host != nil {
                FableRemoteImageView(url: url, contentMode: contentMode) {
                    proceduralPlaceholder
                }
                .frame(width: max(1, geo.size.width), height: max(1, geo.size.height))
                .clipped()
            } else {
                proceduralPlaceholder
                    .frame(width: max(1, geo.size.width), height: max(1, geo.size.height))
                    .clipped()
            }
        }
        .clipped()
        .contentShape(Rectangle())
    }

    private var semanticKey: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let name, !name.contains("://") {
            return name
        }
        return ""
    }

    private var proceduralPlaceholder: some View {
        GeometryReader { geo in
            if placeholderIcon.contains("person") {
                avatarPlaceholder(size: min(geo.size.width, geo.size.height))
            } else if placeholderIcon.contains("books") {
                genrePlaceholder(size: geo.size)
            } else {
                bookCoverPlaceholder(size: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func avatarPlaceholder(size: CGFloat) -> some View {
        let (initials, colors) = avatarMetadata(for: semanticKey)
        return ZStack {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
            if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: max(10, size * 0.36), weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, y: 1)
            } else {
                Image(systemName: placeholderIcon)
                    .font(.system(size: max(14, size * 0.36), weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(width: max(1, size), height: max(1, size))
    }

    private struct GenrePalette {
        let colors: [Color]
        let symbol: String
    }

    private func genrePalette(for key: String) -> GenrePalette {
        let s = key.lowercased()
        if s.contains("gothic") || s.contains("horror") {
            return GenrePalette(colors: [Color(red: 0.28, green: 0.08, blue: 0.14), Color(red: 0.12, green: 0.04, blue: 0.08)], symbol: "flame.fill")
        } else if s.contains("romance") || s.contains("courtship") {
            return GenrePalette(colors: [Color(red: 0.35, green: 0.15, blue: 0.28), Color(red: 0.18, green: 0.06, blue: 0.16)], symbol: "heart.fill")
        } else if s.contains("classic") {
            return GenrePalette(colors: [Color(red: 0.15, green: 0.24, blue: 0.38), Color(red: 0.08, green: 0.12, blue: 0.22)], symbol: "building.columns.fill")
        } else if s.contains("adventure") {
            return GenrePalette(colors: [Color(red: 0.12, green: 0.28, blue: 0.24), Color(red: 0.06, green: 0.15, blue: 0.12)], symbol: "compass.drawing")
        } else if s.contains("folklore") || s.contains("myth") {
            return GenrePalette(colors: [Color(red: 0.28, green: 0.24, blue: 0.12), Color(red: 0.14, green: 0.12, blue: 0.06)], symbol: "leaf.fill")
        }
        return GenrePalette(colors: [Color(red: 0.14, green: 0.16, blue: 0.30), Color(red: 0.24, green: 0.16, blue: 0.40)], symbol: "books.vertical.fill")
    }

    private func genrePlaceholder(size: CGSize) -> some View {
        let palette = genrePalette(for: semanticKey)
        return ZStack {
            LinearGradient(
                colors: palette.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: palette.symbol)
                .font(.system(size: max(18, min(size.width, size.height) * 0.24), weight: .medium))
                .foregroundColor(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private struct BookPalette {
        let colors: [Color]
        let foilColor: Color
        let symbol: String
        let tagText: String
    }

    private func bookCoverPlaceholder(size: CGSize) -> some View {
        let palette = bookPalette(for: semanticKey)
        return ZStack {
            LinearGradient(
                colors: palette.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: max(3, size.width * 0.05))
                .strokeBorder(palette.foilColor.opacity(0.35), lineWidth: max(1, size.width * 0.015))
                .padding(max(3, size.width * 0.05))

            VStack(spacing: max(2, size.height * 0.04)) {
                Spacer(minLength: 2)
                Image(systemName: palette.symbol)
                    .font(.system(size: max(14, min(size.width, size.height) * 0.26), weight: .regular))
                    .foregroundColor(palette.foilColor.opacity(0.9))
                Text(palette.tagText.uppercased())
                    .font(.system(size: max(7, min(size.width, size.height) * 0.09), weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(palette.foilColor.opacity(0.85))
                    .lineLimit(1)
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func avatarMetadata(for key: String) -> (String, [Color]) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean.contains("austen") {
            return ("JA", [Color(red: 0.35, green: 0.22, blue: 0.42), Color(red: 0.18, green: 0.10, blue: 0.24)])
        } else if clean.contains("stoker") {
            return ("BS", [Color(red: 0.42, green: 0.12, blue: 0.15), Color(red: 0.20, green: 0.05, blue: 0.08)])
        } else if clean.contains("shelley") {
            return ("MS", [Color(red: 0.18, green: 0.32, blue: 0.28), Color(red: 0.08, green: 0.16, blue: 0.14)])
        } else if clean.contains("poe") {
            return ("EP", [Color(red: 0.24, green: 0.15, blue: 0.28), Color(red: 0.12, green: 0.06, blue: 0.14)])
        } else if clean.contains("kafka") {
            return ("FK", [Color(red: 0.32, green: 0.24, blue: 0.16), Color(red: 0.16, green: 0.10, blue: 0.06)])
        } else if clean.contains("clear") {
            return ("JC", [Color(red: 0.15, green: 0.28, blue: 0.45), Color(red: 0.08, green: 0.14, blue: 0.25)])
        } else if clean.contains("greene") {
            return ("RG", [Color(red: 0.28, green: 0.32, blue: 0.18), Color(red: 0.14, green: 0.16, blue: 0.08)])
        } else if clean.contains("rowling") {
            return ("JK", [Color(red: 0.45, green: 0.25, blue: 0.15), Color(red: 0.22, green: 0.12, blue: 0.06)])
        } else if clean.contains("kiyosaki") {
            return ("RK", [Color(red: 0.20, green: 0.28, blue: 0.36), Color(red: 0.10, green: 0.14, blue: 0.20)])
        } else if clean.contains("housel") {
            return ("MH", [Color(red: 0.34, green: 0.26, blue: 0.18), Color(red: 0.18, green: 0.12, blue: 0.08)])
        } else if clean.contains("manson") {
            return ("MM", [Color(red: 0.38, green: 0.22, blue: 0.16), Color(red: 0.18, green: 0.10, blue: 0.06)])
        }
        let fallbackInitials = clean.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
        return (fallbackInitials.isEmpty ? "" : fallbackInitials, [FableTheme.brandPrimary, FableTheme.brandSecondary])
    }

    private func bookPalette(for key: String) -> BookPalette {
        let gold = Color(red: 0.94, green: 0.85, blue: 0.65)
        let silver = Color(red: 0.90, green: 0.92, blue: 0.95)
        let bronze = Color(red: 0.88, green: 0.68, blue: 0.48)
        let s = key.lowercased()

        if s.contains("dracula") || s.contains("gothic") {
            return BookPalette(colors: [Color(red: 0.35, green: 0.08, blue: 0.12), Color(red: 0.15, green: 0.04, blue: 0.06)], foilColor: gold, symbol: "building.columns.fill", tagText: "Gothic")
        } else if s.contains("sleepy") || s.contains("folklore") {
            return BookPalette(colors: [Color(red: 0.18, green: 0.28, blue: 0.20), Color(red: 0.08, green: 0.16, blue: 0.10)], foilColor: gold, symbol: "leaf.fill", tagText: "Folklore")
        } else if s.contains("frankenstein") || s.contains("shelley") {
            return BookPalette(colors: [Color(red: 0.12, green: 0.28, blue: 0.22), Color(red: 0.06, green: 0.15, blue: 0.11)], foilColor: bronze, symbol: "bolt.fill", tagText: "Classic")
        } else if s.contains("pride") || s.contains("austen") {
            return BookPalette(colors: [Color(red: 0.32, green: 0.20, blue: 0.36), Color(red: 0.16, green: 0.08, blue: 0.20)], foilColor: gold, symbol: "heart.fill", tagText: "Romance")
        } else if s.contains("moby") || s.contains("adventure") {
            return BookPalette(colors: [Color(red: 0.12, green: 0.22, blue: 0.38), Color(red: 0.06, green: 0.12, blue: 0.22)], foilColor: silver, symbol: "water.waves", tagText: "Adventure")
        } else if s.contains("manga") || s.contains("chainsaw") {
            return BookPalette(colors: [Color(red: 0.23, green: 0.35, blue: 0.96), Color(red: 0.45, green: 0.15, blue: 0.70)], foilColor: .white, symbol: "flame.circle.fill", tagText: "Manga")
        }
        return BookPalette(colors: [FableTheme.brandPrimary, FableTheme.brandSecondary], foilColor: silver, symbol: "book.fill", tagText: "Fable")
    }
}

@MainActor
public struct FableRemoteImageView<Placeholder: View>: View {
    public let url: URL
    public let contentMode: ContentMode

    private let placeholder: Placeholder
    @State private var cachedImage: UIImage?
    @State private var cachedImageURL: URL?

    public init(
        url: URL,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    public var body: some View {
        Group {
            if let cachedImage, cachedImageURL == url {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
            } else {
                placeholder
            }
        }
        .task(id: url) {
            guard !Task.isCancelled else {
                return
            }

            cachedImage = nil
            cachedImageURL = nil

            if let cachedImage = DiskImageCache.shared.image(for: url) {
                self.cachedImage = cachedImage
                cachedImageURL = url
                return
            }

            await DiskImageCache.shared.prefetch(urls: [url])
            guard !Task.isCancelled else {
                return
            }

            if let cached = DiskImageCache.shared.image(for: url) {
                withAnimation(.easeIn(duration: 0.2)) {
                    self.cachedImage = cached
                    cachedImageURL = url
                }
            }
        }
        .clipped()
    }
}
