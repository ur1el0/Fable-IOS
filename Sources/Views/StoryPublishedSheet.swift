import SwiftUI

struct StoryPublishedSheet: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    
    var onReturnToLibrary: () -> Void
    var onViewStory: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Drag indicator
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 16)
            
            Spacer()
            
            // Success Icon with Sparkles
            ZStack {
                Circle()
                    .fill(FableTheme.softPeach)
                    .frame(width: 90, height: 90)
                
                Circle()
                    .fill(Color(red: 0.98, green: 0.88, blue: 0.82))
                    .frame(width: 68, height: 68)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(FableTheme.terracotta)
                
                // Sparkle ornaments
                Image(systemName: "sparkle")
                    .font(.system(size: 14))
                    .foregroundColor(FableTheme.terracotta)
                    .offset(x: 46, y: -34)
                
                Image(systemName: "sparkle")
                    .font(.system(size: 10))
                    .foregroundColor(FableTheme.terracotta.opacity(0.7))
                    .offset(x: -42, y: 30)
            }
            .padding(.top, 10)
            
            // Title & Subtitle
            VStack(spacing: 12) {
                Text("Story Published!")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundColor(FableTheme.deepCharcoal)
                
                Text("Your fable is now live in the Community Library for fellow wanderers to read and reflect upon.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(FableTheme.subtleSlate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
            }
            
            // Metadata Pill
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(FableTheme.terracotta)
                        .frame(width: 6, height: 6)
                    Text("Public")
                        .font(.system(size: 12, weight: .medium))
                }
                
                Text("•")
                    .foregroundColor(FableTheme.subtleSlate.opacity(0.4))
                
                Text(store.draftGenre)
                    .font(.system(size: 12, weight: .medium))
                
                Text("•")
                    .foregroundColor(FableTheme.subtleSlate.opacity(0.4))
                
                Text("\(store.draftWordCount) words")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(FableTheme.deepCharcoal)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.08))
            .clipShape(Capsule())
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 14) {
                Button(action: {
                    dismiss()
                    onViewStory()
                }) {
                    HStack {
                        Text("View Story Now")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(FableTheme.terracotta)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                Button(action: {
                    dismiss()
                    onReturnToLibrary()
                }) {
                    Text("Return to Library")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(FableTheme.deepCharcoal)
                        .padding(.vertical, 8)
                }
                
                Button(action: {
                    // Share action
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                        Text("Share story link")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(FableTheme.terracotta)
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
