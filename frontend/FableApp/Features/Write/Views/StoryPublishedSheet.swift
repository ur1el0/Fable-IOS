import SwiftUI

struct StoryPublishedSheet: View {
    @Environment(\.dismiss) private var dismiss

    let story: Story
    var onReturnToLibrary: () -> Void
    var onViewStory: () -> Void

    private var shareableStoryDetails: String {
        "\(story.title) by \(story.author)\n\n\(story.synopsis)"
    }

    private var wordCount: Int {
        story.content.split { $0.isWhitespace || $0.isNewline }.count
    }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 16)

            Spacer()

            ZStack {
                Circle()
                    .fill(FableTheme.brandPrimary.opacity(0.12))
                    .frame(width: 90, height: 90)

                Circle()
                    .fill(FableTheme.brandPrimary.opacity(0.20))
                    .frame(width: 68, height: 68)

                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(FableTheme.brandPrimary)

                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundColor(FableTheme.brandPrimary)
                    .offset(x: 46, y: -34)

                Image(systemName: "sparkle")
                    .font(.system(size: 10))
                    .foregroundColor(FableTheme.brandPrimary.opacity(0.7))
                    .offset(x: -42, y: 30)
            }
            .padding(.top, 10)

            VStack(spacing: 12) {
                Text("Story Published")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(FableTheme.textPrimary)

                Text("\(story.title) is now available in the Community Library.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(FableTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(FableTheme.brandPrimary)
                        .frame(width: 6, height: 6)
                    Text("Public")
                        .font(.system(size: 12, weight: .medium))
                }

                Text("•")
                    .foregroundColor(FableTheme.textMuted.opacity(0.4))

                Text(story.genre.rawValue)
                    .font(.system(size: 12, weight: .medium))

                Text("•")
                    .foregroundColor(FableTheme.textMuted.opacity(0.4))

                Text("\(wordCount) words")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(FableTheme.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(FableTheme.surfaceVariant)
            .clipShape(Capsule())

            Spacer()

            VStack(spacing: 14) {
                Button {
                    dismiss()
                    onViewStory()
                } label: {
                    HStack {
                        Text("View Story Now")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FableTheme.brandPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    dismiss()
                    onReturnToLibrary()
                } label: {
                    Text("Return to Library")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FableTheme.textPrimary)
                        .padding(.vertical, 8)
                }

                ShareLink(item: shareableStoryDetails) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                        Text("Share story details")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(FableTheme.brandPrimary)
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .presentationDetents([.fraction(0.65)])
        .presentationDragIndicator(.hidden)
        .background(Color.white)
    }
}
