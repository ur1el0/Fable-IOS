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
        if let name = name, !name.isEmpty, let img = UIImage(named: name) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if let name = name, !name.isEmpty {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            ZStack {
                FableTheme.surface
                Image(systemName: placeholderIcon)
                    .font(.system(size: 24))
                    .foregroundColor(FableTheme.terracotta)
            }
        }
    }
}
