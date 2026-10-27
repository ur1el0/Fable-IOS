import SwiftUI

public struct ShelfView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var selectedTab: String = "Saved"
    @State private var selectedStoryToRead: Story?
    @State private var isShowingSettingsSheet: Bool = false
    @State private var isShowingProfileSheet: Bool = false
    
    let tabs = ["Saved", "Finished", "My Drafts"]
    
    var displayedStories: [Story] {
        let activePool = store.stories.filter { !PersistenceService.legacyDemoStoryIds.contains($0.id) }
        switch selectedTab {
        case "Finished":
            return activePool.filter { $0.isCompleted || $0.progressPercent >= 100 }
        case "My Drafts":
            return store.profileStories
        default: // "Saved"
            return activePool.filter { $0.isBookmarked || ($0.progressPercent > 0 && !$0.isCompleted) }
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
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .padding(7)
                                .background(FableTheme.brandPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Text("Fable")
                                .font(.system(size: 20, weight: .bold, design: .default))
                                .foregroundColor(FableTheme.textPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Title Row with Profile & Settings
                        HStack {
                            Text("My Shelf")
                                .font(.system(size: 32, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Button(action: {
                                    FableHaptics.light()
                                    isShowingProfileSheet = true
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(FableTheme.brandPrimary.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: "person.crop.circle")
                                            .font(.system(size: 19))
                                            .foregroundColor(FableTheme.brandPrimary)
                                    }
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                }
                                .accessibilityLabel("Author profile and reading analytics")
                                
                                Button(action: {
                                    FableHaptics.light()
                                    isShowingSettingsSheet = true
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(FableTheme.surface)
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: "gearshape")
                                            .font(.system(size: 17))
                                            .foregroundColor(FableTheme.textPrimary)
                                    }
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                                }
                                .accessibilityLabel("Settings")
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Segmented Filter Bar
                        HStack(spacing: 0) {
                            ForEach(tabs, id: \.self) { tab in
                                Button(action: {
                                    FableHaptics.selection()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        selectedTab = tab
                                    }
                                }) {
                                    Text(tab)
                                        .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedTab == tab ? Color.white : Color.clear)
                                        .foregroundColor(selectedTab == tab ? FableTheme.textPrimary : FableTheme.textMuted)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(selectedTab == tab ? Color.black.opacity(0.04) : Color.clear, lineWidth: 1)
                                        )
                                        .shadow(color: selectedTab == tab ? Color.black.opacity(0.06) : Color.clear, radius: 4, y: 1)
                                }
                            }
                        }
                        .padding(4)
                        .background(FableTheme.surfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 20)
                        
                        // Apple Fitness-Inspired Reading Stats Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(FableTheme.brandPrimary)
                                    Text("Reading Journal & Stats")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(FableTheme.textPrimary)
                                }
                                Spacer()
                                
                                Text("THIS MONTH")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(0.8)
                                    .foregroundColor(FableTheme.textMuted)
                            }
                            
                            // 3 Circular Metric Hubs
                            HStack(spacing: 0) {
                                // Stories Completed
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.green)
                                    }
                                    
                                    Text("\(store.readingStats.storiesReadCount)")
                                        .font(.system(size: 22, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundColor(FableTheme.textPrimary)
                                    
                                    Text("Completed")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                
                                Divider().frame(height: 48)
                                
                                // Total Logged Time
                                VStack(spacing: 6) {
                                    let mins = store.readingStats.totalMinutesRead
                                    let formattedTime = mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m"
                                    
                                    ZStack {
                                        Circle()
                                            .fill(FableTheme.brandPrimary.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(FableTheme.brandPrimary)
                                    }
                                    
                                    Text(formattedTime)
                                        .font(.system(size: 22, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundColor(FableTheme.textPrimary)
                                    
                                    Text("Logged Time")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                                
                                Divider().frame(height: 48)
                                
                                // Days Streak
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.12))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text("\(store.readingStats.streakDays)")
                                        .font(.system(size: 22, weight: .bold))
                                        .monospacedDigit()
                                        .foregroundColor(FableTheme.textPrimary)
                                    
                                    Text("Day Streak")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(FableTheme.textMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Tactical Editorial Quote Deck
                            if !store.pinnedQuotes.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "quote.opening")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FableTheme.brandPrimary)
                                        Text("PINNED PASSAGES")
                                            .font(.system(size: 10, weight: .bold))
                                            .tracking(1.0)
                                            .foregroundColor(FableTheme.textMuted)
                                        Spacer()
                                    }
                                    
                                    TabView {
                                        ForEach(store.pinnedQuotes) { quote in
                                            Button(action: {
                                                if let matchingStory = store.stories.first(where: { $0.id == quote.storyId }) {
                                                    selectedStoryToRead = matchingStory
                                                }
                                            }) {
                                                VStack(alignment: .leading, spacing: 8) {
                                                    HStack(alignment: .top, spacing: 6) {
                                                        Text("“")
                                                            .font(.system(size: 34, weight: .bold, design: .serif))
                                                            .foregroundColor(quote.color.displayColor)
                                                            .offset(y: -6)
                                                        
                                                        Text(quote.selectedText)
                                                            .font(.system(size: 13, weight: .medium, design: .serif))
                                                            .foregroundColor(FableTheme.textPrimary)
                                                            .lineSpacing(3)
                                                            .lineLimit(3)
                                                            .multilineTextAlignment(.leading)
                                                    }
                                                    
                                                    HStack {
                                                        let attribution = [quote.storyTitle, quote.storyAuthor]
                                                            .filter { !$0.isEmpty }
                                                            .joined(separator: " • ")
                                                        if !attribution.isEmpty {
                                                            Text("— \(attribution)")
                                                                .font(.system(size: 11, weight: .medium))
                                                                .foregroundColor(FableTheme.textMuted)
                                                                .lineLimit(1)
                                                        }
                                                        
                                                        Spacer()
                                                        
                                                        HStack(spacing: 3) {
                                                            Text("OPEN")
                                                                .font(.system(size: 9, weight: .bold))
                                                                .tracking(0.8)
                                                            Image(systemName: "chevron.right")
                                                                .font(.system(size: 8, weight: .bold))
                                                        }
                                                        .foregroundColor(FableTheme.brandPrimary)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(FableTheme.brandPrimary.opacity(0.1))
                                                        .clipShape(Capsule())
                                                    }
                                                }
                                                .padding(14)
                                                .background(FableTheme.surface.opacity(0.7))
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(quote.color.displayColor.opacity(0.3), lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(height: 116)
                                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                                }
                                .padding(.top, 4)
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "text.quote")
                                        .font(.system(size: 16))
                                        .foregroundColor(FableTheme.brandPrimary)
                                    Text("Highlight and pin memorable passages while reading to view them here.")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(FableTheme.textSecondary)
                                }
                                .padding(12)
                                .background(FableTheme.surface.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.top, 2)
                            }
                        }
                        .padding(18)
                        .background(FableTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
                        .shadow(color: FableTheme.brandPrimary.opacity(0.06), radius: 12, y: 4)
                        .padding(.horizontal, 20)
                        
                        // Active Stories Collection
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("\(selectedTab.uppercased()) TITLES (\(displayedStories.count))")
                                    .font(.system(size: 11, weight: .bold))
                                    .monospacedDigit()
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.textMuted)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 0) {
                                if displayedStories.isEmpty {
                                    VStack(spacing: 14) {
                                        Image(systemName: selectedTab == "Finished" ? "checkmark.circle" : (selectedTab == "My Drafts" ? "square.and.pencil" : "books.vertical"))
                                            .font(.system(size: 38))
                                            .foregroundColor(FableTheme.textMuted.opacity(0.5))
                                        
                                        Text(selectedTab == "My Drafts" ? "No drafts yet" : (selectedTab == "Finished" ? "No finished stories yet" : "Your shelf is empty"))
                                            .font(.system(size: 16, weight: .bold, design: .serif))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        Text(selectedTab == "My Drafts" ? "Head to the Write tab to begin drafting your first tale." : "Explore the library to discover novels, short fiction, and manga.")
                                            .font(.system(size: 13))
                                            .foregroundColor(FableTheme.textMuted)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 32)
                                        
                                        if selectedTab != "My Drafts" {
                                            Button(action: {
                                                store.selectedTab = .library
                                            }) {
                                                Text("Browse Library")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 18)
                                                    .padding(.vertical, 9)
                                                    .background(FableTheme.brandPrimary)
                                                    .clipShape(Capsule())
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    ForEach(Array(displayedStories.enumerated()), id: \.element.id) { index, story in
                                        Button(action: {
                                            selectedStoryToRead = story
                                        }) {
                                            HStack(spacing: 14) {
                                                // Book Cover with Realistic Depth
                                                FableImageView(name: story.effectiveCoverImage, placeholderIcon: "square.stack")
                                                    .frame(width: 52, height: 72)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                                    )
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    // Genre / Format Pill
                                                    HStack(spacing: 6) {
                                                        Text(story.contentFormat == .manga ? "MANGA" : (story.sourceProvider == .standardEbooks ? "STANDARD EBOOKS" : story.genre.rawValue.uppercased()))
                                                            .font(.system(size: 8, weight: .heavy))
                                                            .foregroundColor(FableTheme.brandPrimary)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(FableTheme.surface)
                                                            .clipShape(Capsule())
                                                    }
                                                    
                                                    // Serif Title
                                                    Text(story.title)
                                                        .font(.system(size: 15, weight: .bold, design: .serif))
                                                        .foregroundColor(FableTheme.textPrimary)
                                                        .lineLimit(1)
                                                    
                                                    Text(story.author)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(FableTheme.textMuted)
                                                    
                                                    // Reading Progress Indicator
                                                    if story.isCompleted {
                                                        HStack(spacing: 4) {
                                                            Image(systemName: "checkmark.circle.fill")
                                                                .font(.system(size: 11))
                                                            Text("Completed")
                                                                .font(.system(size: 11, weight: .medium))
                                                        }
                                                        .foregroundColor(Color.green.opacity(0.9))
                                                    } else if let chapNum = story.lastReadChapterNumber, story.progressPercent > 0 {
                                                        Text("Ch. \(chapNum) • Page \(story.currentPage) of \(story.totalPages)")
                                                            .font(.system(size: 11, weight: .medium))
                                                            .monospacedDigit()
                                                            .foregroundColor(FableTheme.brandPrimary)
                                                    } else if story.progressPercent > 0 {
                                                        Text("Page \(story.currentPage) of \(story.totalPages) • \(story.readingTimeMinutes)m left")
                                                            .font(.system(size: 11, weight: .medium))
                                                            .monospacedDigit()
                                                            .foregroundColor(FableTheme.brandPrimary)
                                                    } else {
                                                        Text("\(story.readingTimeMinutes)m read")
                                                            .font(.system(size: 11, weight: .medium))
                                                            .monospacedDigit()
                                                            .foregroundColor(FableTheme.brandPrimary)
                                                    }
                                                }
                                                
                                                Spacer()
                                                
                                                // Dual-Gradient Progress Ring
                                                ZStack {
                                                    Circle()
                                                        .stroke(Color.gray.opacity(0.12), lineWidth: 3.5)
                                                        .frame(width: 34, height: 34)
                                                    
                                                    if story.isCompleted {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 13, weight: .bold))
                                                            .foregroundColor(.green)
                                                    } else {
                                                        Circle()
                                                            .trim(from: 0, to: CGFloat(max(0, min(100, story.progressPercent))) / 100.0)
                                                            .stroke(
                                                                LinearGradient(
                                                                    colors: [FableTheme.brandPrimary, FableTheme.brandPrimary.opacity(0.7)],
                                                                    startPoint: .topLeading,
                                                                    endPoint: .bottomTrailing
                                                                ),
                                                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                                                            )
                                                            .rotationEffect(.degrees(-90))
                                                            .frame(width: 34, height: 34)
                                                        
                                                        Text("\(story.progressPercent)%")
                                                            .font(.system(size: 9, weight: .bold))
                                                            .monospacedDigit()
                                                            .foregroundColor(FableTheme.brandPrimary)
                                                    }
                                                }
                                                
                                                // Story Action Menu
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
                                                        .frame(width: 44, height: 44)
                                                        .contentShape(Rectangle())
                                                }
                                                .accessibilityLabel("Story options for \(story.title)")
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
                            }
                            .background(FableTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
                            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer().frame(height: 100) // Spacing for floating glass navigation bar
                    }
                }
                .refreshable {
                    await store.syncWithCloudBackend()
                }
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                let currentStory = store.stories.first(where: { $0.id == story.id }) ?? story
                if currentStory.contentFormat == .manga || currentStory.sourceProvider == .mangadex {
                    MangaReaderView(story: currentStory)
                        .environmentObject(store)
                } else {
                    ReaderView(story: currentStory)
                        .environmentObject(store)
                }
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

#Preview {
    ShelfView()
        .environmentObject(StoryStore())
}
