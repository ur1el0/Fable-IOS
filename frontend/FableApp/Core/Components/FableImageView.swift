import SwiftUI

@MainActor
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
            if let name,
               let url = URL(string: name),
               url.scheme?.lowercased() == "https",
               url.host != nil {
                FableRemoteImageView(url: url, contentMode: contentMode) {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
        .clipped()
    }

    private var placeholderView: some View {
        ZStack {
            FableTheme.surface
            Image(systemName: placeholderIcon)
                .font(.system(size: 28, weight: .regular))
                .foregroundColor(FableTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

@MainActor
public struct FableRemoteImageView<Placeholder: View>: View {
    public let url: URL
    public let contentMode: ContentMode

    private let placeholder: Placeholder
    @State private var cachedImage: UIImage?

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
            if let cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
            } else {
                asyncImageFallback
            }
        }
        .task(id: url) {
            cachedImage = nil

            if let cachedImage = DiskImageCache.shared.image(for: url) {
                self.cachedImage = cachedImage
                return
            }

            await DiskImageCache.shared.prefetch(urls: [url])
            guard !Task.isCancelled else {
                return
            }

            cachedImage = DiskImageCache.shared.image(for: url)
        }
        .clipped()
    }

    private var loadingView: some View {
        ZStack {
            FableTheme.surface
            ProgressView()
                .scaleEffect(0.8)
        }
        .clipped()
    }

    @ViewBuilder
    private var asyncImageFallback: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .clipped()
                    .task(id: url) {
                        await DiskImageCache.shared.prefetch(urls: [url])
                        guard !Task.isCancelled else {
                            return
                        }
                        if let cachedImage = DiskImageCache.shared.image(for: url) {
                            self.cachedImage = cachedImage
                        }
                    }
            case .empty:
                loadingView
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .clipped()
    }
}
