import SwiftUI

public struct ShelfView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var selectedTab: String = "Saved"
    @State private var selectedStoryToRead: Story?
    @State private var isShowingSettingsSheet: Bool = false
    @State private var isShowingProfileSheet: Bool = false
    
    let tabs = ["Saved", "Finished", "My Drafts"]
    
    var displayedStories: [Story] {
        switch selectedTab {
        case "Finished":
            let finished = store.stories.filter { $0.isCompleted || $0.progressPercent >= 100 }
            return finished.isEmpty ? store.stories.prefix(2).map { $0 } : finished
        case "My Drafts":
            return store.profileStories
        default: // "Saved"
            let saved = store.stories.filter { $0.isBookmarked }
            return saved.isEmpty ? store.stories.prefix(3).map { $0 } : saved
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Brand Logo Header
                        HStack(spacing: 8) {
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(7)
                                .background(FableTheme.brandPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Text("Fable")
                                .font(.system(size: 20, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Title Row with Stats & Settings
                        HStack {
                            Text("My Shelf")
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)
                            
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Button(action: {
                                    isShowingProfileSheet = true
                                }) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 18))
                                        .foregroundColor(FableTheme.brandPrimary)
                                }
                                
                                Button(action: {
                                    isShowingSettingsSheet = true
                                }) {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 18))
                                        .foregroundColor(FableTheme.textPrimary)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Segmented Picker
                        HStack(spacing: 0) {
                            ForEach(tabs, id: \.self) { tab in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = tab
                                    }
                                }) {
                                    Text(tab)
                                        .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedTab == tab ? Color.white : Color.clear)
                                        .foregroundColor(selectedTab == tab ? FableTheme.textPrimary : FableTheme.textMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .shadow(color: selectedTab == tab ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
                                }
                            }
                        }
                        .padding(4)
                        .background(FableTheme.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                        
                        // Monthly Reading Stats Card (FIGMA.md Frame 7: 1:1058)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("October Reading Stats")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.textPrimary)
                                Spacer()
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                            }
                            
                            HStack(spacing: 0) {
                                VStack(spacing: 2) {
                                    Text("\(store.readingStats.storiesReadCount)")
                                        .font(.system(size: 22, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.brandPrimary)
                                    Text("Stories Read")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                
                                Divider().frame(height: 30)
                                
                                VStack(spacing: 2) {
                                    let mins = store.readingStats.totalMinutesRead
                                    let formattedTime = mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m"
                                    Text(formattedTime)
                                        .font(.system(size: 22, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.brandPrimary)
                                    Text("Logged Time")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                
                                Divider().frame(height: 30)
                                
                                VStack(spacing: 2) {
                                    Text("\(store.readingStats.streakDays)")
                                        .font(.system(size: 22, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.brandPrimary)
                                    Text("Days Streak")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Reading Journal Quote Deck (Plan 02 Parity)
                            if !store.pinnedQuotes.isEmpty {
                                TabView {
                                    ForEach(store.pinnedQuotes) { quote in
                                        Button(action: {
                                            if let matchingStory = store.stories.first(where: { $0.id == quote.storyId }) {
                                                selectedStoryToRead = matchingStory
                                            }
                                        }) {
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack(alignment: .top, spacing: 6) {
                                                    Text("“")
                                                        .font(.system(size: 36, weight: .bold, design: .serif))
                                                        .foregroundColor(quote.color.displayColor.opacity(1.0))
                                                        .offset(y: -4)
                                                    
                                                    Text(quote.selectedText)
                                                        .font(.system(size: 13, weight: .regular, design: .serif))
                                                        .italic()
                                                        .foregroundColor(FableTheme.textPrimary)
                                                        .lineLimit(3)
                                                        .multilineTextAlignment(.leading)
                                                }
                                                
                                                HStack {
                                                    Text("— \(quote.storyTitle.isEmpty ? "Fable Manuscript" : quote.storyTitle) • \(quote.storyAuthor.isEmpty ? "Anonymous" : quote.storyAuthor)")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(FableTheme.textMuted)
                                                    
                                                    Spacer()
                                                    
                                                    Text("TAP TO READ")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .tracking(1.0)
                                                        .foregroundColor(FableTheme.brandPrimary)
                                                }
                                            }
                                            .padding(12)
                                            .background(FableTheme.surface.opacity(0.6))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .frame(height: 100)
                                .tabViewStyle(.page(indexDisplayMode: .automatic))
                            } else {
                                Text("“A room without books is like a body without a soul.” — Cicero")
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundColor(FableTheme.textSecondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(18)
                        .background(FableTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                        .padding(.horizontal, 20)
                        
                        // Active Stories Collection
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("\(selectedTab.uppercased()) TALES (\(displayedStories.count))")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                ForEach(Array(displayedStories.enumerated()), id: \.element.id) { index, story in
                                    Button(action: {
                                        selectedStoryToRead = story
                                    }) {
                                        HStack(spacing: 14) {
                                            FableImageView(name: story.coverImageName, placeholderIcon: "book.closed")
                                                .frame(width: 50, height: 64)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(story.title)
                                                    .font(.system(size: 15, weight: .bold, design: .serif))
                                                    .foregroundColor(FableTheme.textPrimary)
                                                    .lineLimit(1)
                                                
                                                Text(story.author)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(FableTheme.textMuted)
                                                
                                                Text(story.isCompleted ? "Completed" : "\(story.readingTimeMinutes)m left • \(story.genre.rawValue)")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(story.isCompleted ? Color.green.opacity(0.8) : FableTheme.brandPrimary)
                                            }
                                            
                                            Spacer()
                                            
                                            // Progress circle / indicator
                                            ZStack {
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.15), lineWidth: 3)
                                                    .frame(width: 32, height: 32)
                                                
                                                if story.isCompleted {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(FableTheme.brandPrimary)
                                                } else {
                                                    Circle()
                                                        .trim(from: 0, to: CGFloat(story.progressPercent) / 100.0)
                                                        .stroke(FableTheme.brandPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                                        .rotationEffect(.degrees(-90))
                                                        .frame(width: 32, height: 32)
                                                    
                                                    Text("\(story.progressPercent)%")
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(FableTheme.brandPrimary)
                                                }
                                            }
                                            
                                            // Action Ellipsis Menu
                                            Menu {
                                                Button(action: {
                                                    store.removeFromShelf(storyId: story.id)
                                                }) {
                                                    Label("Remove from Shelf", systemImage: "trash")
                                                }
                                                
                                                Button(action: {
                                                    store.markAsFinished(storyId: story.id)
                                                }) {
                                                    Label("Mark as Finished", systemImage: "checkmark.circle")
                                                }
                                                
                                                ShareLink(item: "\(story.title) by \(story.author)") {
                                                    Label("Share Tale", systemImage: "square.and.arrow.up")
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(FableTheme.textMuted)
                                                    .padding(6)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if index < displayedStories.count - 1 {
                                        Divider()
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(FableTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer().frame(height: 90) // spacing for custom tab bar
                    }
                }
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingSettingsSheet) {
                SettingsView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingProfileSheet) {
                ProfileView()
                    .environmentObject(store)
            }
            .onAppear {
                store.reloadReadingStats()
            }
        }
    }
}
