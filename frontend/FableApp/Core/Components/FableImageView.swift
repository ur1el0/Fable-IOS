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
            if let name = name, let uiImage = UIImage(named: name) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                proceduralFallback
            }
        }
    }

    @ViewBuilder
    private var proceduralFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.16, blue: 0.14),
                    Color(red: 0.12, green: 0.10, blue: 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Rectangle()
                .strokeBorder(Color(red: 0.85, green: 0.72, blue: 0.52).opacity(0.25), lineWidth: 1)
                .padding(4)
            
            VStack(spacing: 6) {
                Image(systemName: placeholderIcon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.52).opacity(0.85))
                
                if let name = name, !name.isEmpty {
                    Text(cleanTitle(from: name))
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(Color(red: 0.95, green: 0.92, blue: 0.88))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(8)
        }
    }

    private func cleanTitle(from rawName: String) -> String {
        rawName
            .replacingOccurrences(of: "cover_", with: "")
            .replacingOccurrences(of: "thumb_", with: "")
            .replacingOccurrences(of: "hero_", with: "")
            .replacingOccurrences(of: "genre_", with: "")
            .replacingOccurrences(of: "author_", with: "")
            .replacingOccurrences(of: "avatar_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
