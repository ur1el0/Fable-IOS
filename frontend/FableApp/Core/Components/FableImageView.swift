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
                    .fableFont(size: max(10, size * 0.36), weight: .bold)
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.2), radius: 1, y: 1)
            } else {
                Image(systemName: placeholderIcon)
                    .fableFont(size: max(14, size * 0.36), weight: .medium)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(width: max(1, size), height: max(1, size))
    }

    private func genrePlaceholder(size: CGSize) -> some View {
        return ZStack {
            LinearGradient(
                colors: [FableTheme.brandPrimary, FableTheme.brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "books.vertical.fill")
                .fableFont(size: max(18, min(size.width, size.height) * 0.24), weight: .medium)
                .foregroundColor(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bookCoverPlaceholder(size: CGSize) -> some View {
        return ZStack {
            LinearGradient(
                colors: [FableTheme.brandPrimary, FableTheme.brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: max(3, size.width * 0.05))
                .strokeBorder(Color.white.opacity(0.35), lineWidth: max(1, size.width * 0.015))
                .padding(max(3, size.width * 0.05))

            Image(systemName: "book.closed")
                .fableFont(size: max(14, min(size.width, size.height) * 0.26), weight: .regular)
                .foregroundColor(Color.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func avatarMetadata(for key: String) -> (String, [Color]) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let fallbackInitials = clean.split(separator: " ").compactMap { $0.first.map(String.init) }.prefix(2).joined().uppercased()
        return (fallbackInitials.isEmpty ? "" : fallbackInitials, [FableTheme.brandPrimary, FableTheme.brandSecondary])
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
