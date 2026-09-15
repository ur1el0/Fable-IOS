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
        ZStack {
            Color.white
            Rectangle()
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        }
    }
}
