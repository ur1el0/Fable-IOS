import SwiftUI

struct ReaderView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    
    let story: Story
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background according to selected theme
            store.readerTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(store.readerTheme.textColor)
                            .frame(width: 44, height: 44, alignment: .leading)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                // Top thin reading progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(FableTheme.terracotta)
                            .frame(width: geo.size.width * CGFloat(story.progressPercent) / 100.0, height: 2)
                    }
                }
                .frame(height: 2)
                .padding(.bottom, 12)
                
                // Scrollable Reader Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: 20) {
                        // Open Book Ornament
                        HStack(spacing: 16) {
                            Rectangle()
                                .fill(FableTheme.lightBorder)
                                .frame(height: 1)
                            
                            Image(systemName: "book.pages")
                                .font(.system(size: 14))
                                .foregroundColor(FableTheme.terracotta)
                            
                            Rectangle()
                                .fill(FableTheme.lightBorder)
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 60)
                        .padding(.top, 8)
                        
                        // Story Title
                        Text(story.title)
                            .font(store.readerFont.font(size: 32 * (store.readerFontSize / 100.0)))
                            .fontWeight(.bold)
                            .foregroundColor(store.readerTheme.textColor)
                            .multilineTextAlignment(.center)
                        
                        // Author & Meta Info
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(FableTheme.terracotta.opacity(0.2))
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Text(String(story.author.prefix(1)))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(FableTheme.terracotta)
                                    )
                                Text(story.author)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(store.readerTheme.textColor.opacity(0.8))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.08))
                            .clipShape(Capsule())
                            
                            Text("•")
                                .foregroundColor(FableTheme.subtleSlate)
                            
                            Text("Sep 2026")
                                .font(.system(size: 12))
                                .foregroundColor(FableTheme.subtleSlate)
                            
                            Text("•")
                                .foregroundColor(FableTheme.subtleSlate)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text("\(story.readingTimeMinutes) min read")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.08))
                            .clipShape(Capsule())
                            .foregroundColor(store.readerTheme.textColor.opacity(0.8))
                        }
                        
                        // Hero Image (if present)
                        if let hero = story.heroImageName, let _ = UIImage(named: hero) {
                            Image(hero)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        
                        // Story Paragraphs
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
                        .padding(.top, 10)
                        .padding(.bottom, 120) // spacing for floating HUD
                    }
                }
            }
            
            // Floating Reading HUD Pill
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "book")
                        .font(.system(size: 12))
                        .foregroundColor(FableTheme.terracotta)
                    Text("Page \(story.currentPage) of \(story.totalPages)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FableTheme.deepCharcoal)
                }
                
                Text("•")
                    .foregroundColor(Color.gray.opacity(0.4))
                
                // Progress mini indicator
                HStack(spacing: 6) {
                    Capsule()
                        .fill(FableTheme.terracotta)
                        .frame(width: 24, height: 4)
                    
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 16, height: 4)
                    
                    Text("\(story.progressPercent)%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FableTheme.terracotta)
                }
                
                Spacer()
                
                // Font/Display options toggle button
                Button(action: {
                    store.isShowingDisplayOptions = true
                }) {
                    Text("TT")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundColor(FableTheme.deepCharcoal)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
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
