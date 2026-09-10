import SwiftUI

public struct ReaderView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    
    let story: Story
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 5
    
    public init(story: Story) {
        self.story = story
        _currentPage = State(initialValue: max(1, story.currentPage))
        _totalPages = State(initialValue: max(1, story.totalPages))
    }
    
    private var currentStoryBookmarked: Bool {
        store.stories.first(where: { $0.id == story.id })?.isBookmarked ?? story.isBookmarked
    }
    
    private var readingProgressPercent: Int {
        min(100, max(0, Int((Double(currentPage) / Double(max(1, totalPages))) * 100)))
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Background according to selected theme
            store.readerTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar (FIGMA.md Frame 2: 1:159)
                HStack(spacing: 12) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(store.readerTheme.textColor)
                            .padding(8)
                            .background(store.readerTheme.textColor.opacity(0.06))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Chapter / Folio Tag
                    VStack(spacing: 2) {
                        Text("CHAPTER I • MANUSCRIPT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.0)
                            .foregroundColor(FableTheme.brandPrimary)
                        
                        Text(story.title)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(store.readerTheme.textColor.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Bookmark Toggle
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                store.toggleBookmark(for: story)
                            }
                        }) {
                            Image(systemName: currentStoryBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(currentStoryBookmarked ? FableTheme.brandPrimary : store.readerTheme.textColor)
                                .padding(8)
                                .background(store.readerTheme.textColor.opacity(0.06))
                                .clipShape(Circle())
                        }
                        
                        // Typography Options
                        Button(action: {
                            store.isShowingDisplayOptions = true
                        }) {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(store.readerTheme.textColor)
                                .padding(8)
                                .background(store.readerTheme.textColor.opacity(0.06))
                                .clipShape(Circle())
                        }
                        
                        // Native Share Link
                        ShareLink(
                            item: "\(story.title) by \(story.author)\n\n\(story.synopsis)\n\nRead on Fable."
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(store.readerTheme.textColor)
                                .padding(8)
                                .background(store.readerTheme.textColor.opacity(0.06))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Reading progress track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.12))
                            .frame(height: 2.5)
                        
                        Rectangle()
                            .fill(FableTheme.brandPrimary)
                            .frame(width: geo.size.width * CGFloat(readingProgressPercent) / 100.0, height: 2.5)
                            .animation(.easeInOut(duration: 0.2), value: readingProgressPercent)
                    }
                }
                .frame(height: 2.5)
                
                // Scrollable Editorial Manuscript Body
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 20) {
                        // Open Book Filigree Ornament
                        HStack(spacing: 16) {
                            Rectangle()
                                .fill(FableTheme.divider)
                                .frame(height: 1)
                            
                            Image(systemName: "book.pages")
                                .font(.system(size: 13))
                                .foregroundColor(FableTheme.brandPrimary)
                            
                            Rectangle()
                                .fill(FableTheme.divider)
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 60)
                        .padding(.top, 16)
                        
                        // Story Title
                        Text(story.title)
                            .font(store.readerFont.font(size: 30 * (store.readerFontSize / 100.0)))
                            .fontWeight(.bold)
                            .foregroundColor(store.readerTheme.textColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        // Author & Read Time Metadata Pill
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(FableTheme.brandPrimary.opacity(0.15))
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Text(String(story.author.prefix(1)))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(FableTheme.brandPrimary)
                                    )
                                Text(story.author)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(store.readerTheme.textColor.opacity(0.85))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.08))
                            .clipShape(Capsule())
                            
                            Text("•")
                                .foregroundColor(FableTheme.textMuted)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text("\(story.readingTimeMinutes) min read")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.gray.opacity(0.08))
                            .clipShape(Capsule())
                            .foregroundColor(store.readerTheme.textColor.opacity(0.85))
                        }
                        
                        // Editorial Engraving Vignette (FIGMA.md Frame 2: 1:159)
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                FableImageView(name: story.heroImageName ?? story.coverImageName ?? "hero_castle", placeholderIcon: "photo")
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
                                
                                Text("FOLIO 82")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.brandPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .padding(12)
                            }
                            
                            Text("“\(story.synopsis.isEmpty ? story.excerpt : story.synopsis)”")
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .italic()
                                .foregroundColor(store.readerTheme.textColor.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        
                        // Typographical Manuscript Body
                        VStack(alignment: .leading, spacing: 18 + store.readerLineSpacing.points) {
                            ForEach(story.paragraphs, id: \.self) { para in
                                Text(para)
                                    .font(store.readerFont.font(size: 17 * (store.readerFontSize / 100.0)))
                                    .lineSpacing(store.readerLineSpacing.points)
                                    .foregroundColor(store.readerTheme.textColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 130) // spacing for floating HUD
                    }
                }
            }
            
            // Floating Reading HUD Pill (FIGMA.md Frame 2 HUD)
            HStack(spacing: 12) {
                // Page Back Button
                Button(action: {
                    if currentPage > 1 {
                        currentPage -= 1
                        store.updateProgress(for: story.id, page: currentPage, totalPages: totalPages)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(currentPage > 1 ? FableTheme.brandPrimary : Color.gray.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Circle())
                }
                .disabled(currentPage <= 1)
                
                // Page Indicator
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(FableTheme.textPrimary)
                
                // Page Forward Button
                Button(action: {
                    if currentPage < totalPages {
                        currentPage += 1
                        store.updateProgress(for: story.id, page: currentPage, totalPages: totalPages)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(currentPage < totalPages ? FableTheme.brandPrimary : Color.gray.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Circle())
                }
                .disabled(currentPage >= totalPages)
                
                Text("•")
                    .foregroundColor(Color.gray.opacity(0.4))
                
                // Progress percentage
                Text("\(readingProgressPercent)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(FableTheme.brandPrimary)
                
                Spacer()
                
                // Display options toggle button
                Button(action: {
                    store.isShowingDisplayOptions = true
                }) {
                    Text("TT")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundColor(FableTheme.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(FableTheme.surface)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $store.isShowingDisplayOptions) {
            DisplayOptionsSheet()
                .environmentObject(store)
        }
    }
}
