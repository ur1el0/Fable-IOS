import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct QuoteCardView: View {
    public let quoteText: String
    public let storyTitle: String
    public let storyAuthor: String
    public let chapterNumber: Int?
    public let note: String?
    public let highlightColor: HighlightColor

    public init(
        quoteText: String,
        storyTitle: String,
        storyAuthor: String,
        chapterNumber: Int? = nil,
        note: String? = nil,
        highlightColor: HighlightColor = .terracotta
    ) {
        self.quoteText = quoteText
        self.storyTitle = storyTitle
        self.storyAuthor = storyAuthor
        self.chapterNumber = chapterNumber
        self.note = note
        self.highlightColor = highlightColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header: Fable Reads Branding & Chapter Tag
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "quote.opening")
                        .fableFont(size: 11, weight: .bold)
                        .foregroundColor(highlightColor.displayColor)
                    
                    Text("FABLE READS")
                        .fableFont(size: 10, weight: .heavy)
                        .tracking(1.4)
                        .foregroundColor(FableTheme.subtleSlate)
                }

                Spacer()

                if let chap = chapterNumber {
                    Text("CHAPTER \(chap)")
                        .fableFont(size: 10, weight: .bold)
                        .tracking(1.0)
                        .foregroundColor(FableTheme.subtleSlate)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.04))
                        .clipShape(Capsule())
                }
            }

            // Quote Excerpt
            VStack(alignment: .leading, spacing: 8) {
                Text("“\(quoteText.trimmingCharacters(in: .whitespacesAndNewlines))”")
                    .fableFont(size: 17, weight: .medium, design: .serif)
                    .italic()
                    .lineSpacing(5)
                    .foregroundColor(FableTheme.deepCharcoal)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)

            // Optional Marginalia Note
            if let note = note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil.line")
                            .fableFont(size: 9, weight: .bold)
                        Text("READER NOTE")
                            .fableFont(size: 9, weight: .bold)
                            .tracking(0.8)
                    }
                    .foregroundColor(highlightColor.displayColor)

                    Text(note)
                        .fableFont(size: 12, weight: .regular)
                        .foregroundColor(FableTheme.textSecondary)
                        .italic()
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(highlightColor.displayColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Divider()
                .background(FableTheme.divider)

            // Footer: Story Title, Author, and App Mark
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(storyTitle)
                        .fableFont(size: 14, weight: .bold, design: .serif)
                        .foregroundColor(FableTheme.deepCharcoal)
                        .lineLimit(2)

                    Text("— \(storyAuthor)")
                        .fableFont(size: 12, weight: .medium)
                        .foregroundColor(FableTheme.textMuted)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "book.pages")
                            .fableFont(size: 10, weight: .semibold)
                        Text("fable")
                            .fableFont(size: 12, weight: .bold)
                    }
                    .foregroundColor(FableTheme.brandPrimary)
                }
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(red: 0.99, green: 0.985, blue: 0.975))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(highlightColor.displayColor.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 5)
    }
}

#if canImport(UIKit)
@MainActor
public enum QuoteCardRenderer {
    public static func renderImage(
        quoteText: String,
        storyTitle: String,
        storyAuthor: String,
        chapterNumber: Int? = nil,
        note: String? = nil,
        highlightColor: HighlightColor = .terracotta
    ) -> UIImage? {
        let card = QuoteCardView(
            quoteText: quoteText,
            storyTitle: storyTitle,
            storyAuthor: storyAuthor,
            chapterNumber: chapterNumber,
            note: note,
            highlightColor: highlightColor
        )
        .frame(width: 360)

        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

public struct QuoteCardShareSheet: View {
    public let quoteText: String
    public let storyTitle: String
    public let storyAuthor: String
    public let chapterNumber: Int?
    public let note: String?
    public let highlightColor: HighlightColor

    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?
    @State private var hasSavedToPhotos: Bool = false
    @State private var showSaveAlert: Bool = false

    public init(
        quoteText: String,
        storyTitle: String,
        storyAuthor: String,
        chapterNumber: Int? = nil,
        note: String? = nil,
        highlightColor: HighlightColor = .terracotta
    ) {
        self.quoteText = quoteText
        self.storyTitle = storyTitle
        self.storyAuthor = storyAuthor
        self.chapterNumber = chapterNumber
        self.note = note
        self.highlightColor = highlightColor
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                QuoteCardView(
                    quoteText: quoteText,
                    storyTitle: storyTitle,
                    storyAuthor: storyAuthor,
                    chapterNumber: chapterNumber,
                    note: note,
                    highlightColor: highlightColor
                )
                .frame(maxWidth: 360)
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 12) {
                    if let image = renderedImage {
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("“\(storyTitle)” Quote", image: Image(uiImage: image))
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .fableFont(size: 15, weight: .semibold)
                                Text("Share Quote Card")
                                    .fableFont(size: 15, weight: .semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(FableTheme.brandPrimary)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        Button(action: {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                            FableHaptics.success()
                            hasSavedToPhotos = true
                            showSaveAlert = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: hasSavedToPhotos ? "checkmark" : "arrow.down.to.line")
                                    .fableFont(size: 14, weight: .semibold)
                                Text(hasSavedToPhotos ? "Saved to Photos" : "Save to Photos")
                                    .fableFont(size: 14, weight: .semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(FableTheme.deepCharcoal)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        ProgressView()
                            .padding(.vertical, 20)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(Color(red: 0.95, green: 0.94, blue: 0.93).ignoresSafeArea())
            .navigationTitle("Quote Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fableFont(size: 15, weight: .semibold)
                }
            }
            .task {
                renderedImage = QuoteCardRenderer.renderImage(
                    quoteText: quoteText,
                    storyTitle: storyTitle,
                    storyAuthor: storyAuthor,
                    chapterNumber: chapterNumber,
                    note: note,
                    highlightColor: highlightColor
                )
            }
            .alert("Saved to Photos", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your quote card has been saved to your Photos library.")
            }
        }
    }
}
#endif
