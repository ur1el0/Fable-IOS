import SwiftUI
import UIKit

// MARK: - Quote Card Color Palettes

public enum QuoteCardPalette: String, CaseIterable, Identifiable {
    case parchment = "Parchment"
    case noir = "Midnight"
    case terracotta = "Terracotta"

    public var id: String { rawValue }

    public var backgroundColor: Color {
        switch self {
        case .parchment:
            return FableTheme.sepiaBackground
        case .noir:
            return FableTheme.charcoalBackground
        case .terracotta:
            return FableTheme.brandPrimary
        }
    }

    public var textPrimaryColor: Color {
        switch self {
        case .parchment:
            return FableTheme.sepiaText
        case .noir:
            return FableTheme.charcoalText
        case .terracotta:
            return Color.white
        }
    }

    public var textSecondaryColor: Color {
        switch self {
        case .parchment:
            return FableTheme.brandSecondary
        case .noir:
            return Color(white: 0.72)
        case .terracotta:
            return Color.white.opacity(0.85)
        }
    }

    public var accentColor: Color {
        switch self {
        case .parchment:
            return FableTheme.brandPrimary
        case .noir:
            return FableTheme.brandAccent
        case .terracotta:
            return Color(red: 0.98, green: 0.85, blue: 0.75)
        }
    }

    public var borderColor: Color {
        switch self {
        case .parchment:
            return FableTheme.divider.opacity(0.7)
        case .noir:
            return Color.white.opacity(0.12)
        case .terracotta:
            return Color.white.opacity(0.20)
        }
    }
}

// MARK: - Standalone Render Target: QuoteCardView

public struct QuoteCardView: View {
    public let quote: Annotation
    public let palette: QuoteCardPalette

    public init(quote: Annotation, palette: QuoteCardPalette = .parchment) {
        self.quote = quote
        self.palette = palette
    }

    public var body: some View {
        ZStack {
            palette.backgroundColor

            VStack(alignment: .leading, spacing: 0) {
                // Header brandmark
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(palette.accentColor)

                    Text("F A B L E")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .tracking(3.0)
                        .foregroundColor(palette.accentColor)

                    Spacer()

                    Text("FOLKLORE ARCHIVE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(palette.textSecondaryColor)
                }
                .padding(.bottom, 24)

                // Large Serif Quotation Mark
                Text("“")
                    .font(.system(size: 54, weight: .bold, design: .serif))
                    .foregroundColor(palette.accentColor.opacity(0.8))
                    .frame(height: 32, alignment: .leading)
                    .offset(x: -4)

                // Quote Content
                Text(quote.selectedText)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(6)
                    .foregroundColor(palette.textPrimaryColor)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)

                // Optional Annotation Note
                if let note = quote.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MARGIN NOTE")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(palette.accentColor)

                        Text(note)
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundColor(palette.textSecondaryColor)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.borderColor.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 14)
                }

                Spacer(minLength: 20)

                // Vignette Divider
                HStack {
                    Rectangle()
                        .fill(palette.borderColor)
                        .frame(height: 1)
                    Text("❦")
                        .font(.system(size: 14))
                        .foregroundColor(palette.accentColor)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .fill(palette.borderColor)
                        .frame(height: 1)
                }
                .padding(.vertical, 16)

                // Attribution Footer
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.storyTitle.isEmpty ? "Fable Manuscript" : quote.storyTitle)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(palette.textPrimaryColor)

                    HStack {
                        Text(quote.storyAuthor.isEmpty ? "Unknown Author" : quote.storyAuthor)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(palette.textSecondaryColor)

                        Spacer()

                        Text("ARCHIVED IN JOURNAL")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(palette.accentColor)
                    }
                }
            }
            .padding(28)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.borderColor, lineWidth: 1)
        )
    }
}

// MARK: - Native iOS UIActivityViewController Wrapper

public struct ShareActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export Sheet Controller

public struct QuoteExportSheet: View {
    public let quote: Annotation
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPalette: QuoteCardPalette = .parchment
    @State private var renderedCardImage: UIImage? = nil
    @State private var isShowingShareSheet: Bool = false
    @State private var savedAlertMessage: String? = nil

    public init(quote: Annotation) {
        self.quote = quote
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Card Preview Canvas
                        QuoteCardView(quote: quote, palette: selectedPalette)
                            .frame(maxWidth: 340)
                            .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
                            .padding(.top, 10)

                        // Success notification banner
                        if let msg = savedAlertMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(msg)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                        }

                        // Palette Selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CARD PALETTE")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.0)
                                .foregroundColor(FableTheme.textMuted)
                                .padding(.horizontal, 24)

                            HStack(spacing: 12) {
                                ForEach(QuoteCardPalette.allCases) { palette in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPalette = palette
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(palette.backgroundColor)
                                                .frame(width: 18, height: 18)
                                                .overlay(
                                                    Circle()
                                                        .stroke(FableTheme.divider, lineWidth: 1)
                                                )

                                            Text(palette.rawValue)
                                                .font(.system(size: 13, weight: selectedPalette == palette ? .semibold : .regular))
                                                .foregroundColor(FableTheme.textPrimary)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedPalette == palette
                                                ? FableTheme.brandPrimary.opacity(0.10)
                                                : FableTheme.cardBackground
                                        )
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    selectedPalette == palette
                                                        ? FableTheme.brandPrimary
                                                        : FableTheme.divider,
                                                    lineWidth: selectedPalette == palette ? 1.5 : 1
                                                )
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(.top, 6)

                        // Action Buttons
                        VStack(spacing: 12) {
                            // Native Share Sheet
                            Button(action: {
                                if let image = renderCard() {
                                    self.renderedCardImage = image
                                    self.isShowingShareSheet = true
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Share Typographic Card")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(FableTheme.brandPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: FableTheme.brandPrimary.opacity(0.25), radius: 8, y: 3)
                            }

                            // Save Directly to Photo Library
                            Button(action: {
                                saveToPhotos()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.to.line")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Save to Camera Roll")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(FableTheme.brandSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(FableTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(FableTheme.lightBorder, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Export Quote Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(FableTheme.brandPrimary)
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                if let image = renderedCardImage {
                    ShareActivityView(activityItems: [image])
                }
            }
        }
    }

    // MARK: - Offscreen ImageRenderer Pipeline (iOS 16+)

    @MainActor
    private func renderCard() -> UIImage? {
        let exportTarget = QuoteCardView(quote: quote, palette: selectedPalette)
            .frame(width: 360, height: 480)

        let renderer = ImageRenderer(content: exportTarget)
        renderer.scale = 3.0 // 3x Retina DPI export
        return renderer.uiImage
    }

    private func saveToPhotos() {
        guard let image = renderCard() else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation {
            savedAlertMessage = "Saved to Photo Library!"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                savedAlertMessage = nil
            }
        }
    }
}
