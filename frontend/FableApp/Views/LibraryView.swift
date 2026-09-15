import SwiftUI

public struct LibraryView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var selectedFilter: String = "All"
    @State private var selectedStoryToRead: Story?
    @State private var isShowingProfileSheet: Bool = false
    @State private var isRefreshing: Bool = false
    
    let filterCategories = ["All", "Folklore", "Mythology", "Gothic", "Speculative", "Classic"]
    
    var filteredRecentStories: [Story] {
        let recents = store.stories.filter { $0.isRecentSubmission }
        if selectedFilter == "All" {
            return recents
        } else {
            return recents.filter {
                $0.genre.rawValue.localizedCaseInsensitiveContains(selectedFilter) ||
                $0.title.localizedCaseInsensitiveContains(selectedFilter)
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        if isRefreshing {
                            InlineDonutRefreshView(message: "Syncing Library Manuscripts...")
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        }
                        // Header Date, Title & Profile Avatar
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TUESDAY, OCT 14")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.2)
                                    .foregroundColor(FableTheme.textMuted)
                                
                                Text("Library")
                                    .font(.system(size: 34, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                isShowingProfileSheet = true
                            }) {
                                FableImageView(name: "avatar_roosc", placeholderIcon: "person.crop.circle")
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(FableTheme.divider, lineWidth: 1.5))
                                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Category Filter Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filterCategories, id: \.self) { cat in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedFilter = cat
                                        }
                                    }) {
                                        Text(cat)
                                            .font(.system(size: 13, weight: selectedFilter == cat ? .semibold : .medium))
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedFilter == cat ? FableTheme.brandPrimary : FableTheme.surfaceVariant)
                                            .foregroundColor(selectedFilter == cat ? .white : FableTheme.textPrimary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Tale of the Day Featured Hero Card (Figma Frame 1:2)
                        if let taleOfTheDay = store.stories.first(where: { $0.isTaleOfTheDay }) {
                            Button(action: {
                                selectedStoryToRead = taleOfTheDay
                            }) {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Book Cover with Badge & Bookmark
                                    ZStack(alignment: .top) {
                                        FableImageView(name: taleOfTheDay.coverImageName ?? "cover_dracula", placeholderIcon: "book.closed")
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 210)
                                            .clipped()
                                        
                                        HStack {
                                            Text("TALE OF THE DAY")
                                                .font(.system(size: 10, weight: .bold))
                                                .tracking(1.0)
                                                .foregroundColor(FableTheme.brandPrimary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.white.opacity(0.95))
                                                .clipShape(Capsule())
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                    store.toggleBookmark(for: taleOfTheDay)
                                                }
                                            }) {
                                                Image(systemName: taleOfTheDay.isBookmarked ? "bookmark.fill" : "bookmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(taleOfTheDay.isBookmarked ? FableTheme.brandPrimary : FableTheme.textPrimary)
                                                    .padding(8)
                                                    .background(Color.white.opacity(0.95))
                                                    .clipShape(Circle())
                                                    .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                                            }
                                        }
                                        .padding(14)
                                    }
                                    
                                    // Description Area
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 4) {
                                            Text(taleOfTheDay.author)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(FableTheme.textSecondary)
                                            Text("•")
                                                .foregroundColor(FableTheme.textMuted)
                                            Text("\(taleOfTheDay.readingTimeMinutes) min read")
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                        
                                        Text(taleOfTheDay.title)
                                            .font(.system(size: 24, weight: .bold, design: .serif))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        Text(taleOfTheDay.excerpt)
                                            .font(.system(size: 14, weight: .regular, design: .serif))
                                            .foregroundColor(FableTheme.textPrimary.opacity(0.85))
                                            .lineSpacing(4)
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(FableTheme.cardBackground)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 3)
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Continue Reading Section
                        if let inProgressStory = store.stories.first(where: { $0.progressPercent > 0 && !$0.isCompleted }) ?? store.stories.first(where: { $0.title.contains("Sleepy Hollow") }) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Continue Reading")
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Button("See All") {
                                        store.selectedTab = .shelf
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(FableTheme.brandPrimary)
                                }
                                .padding(.horizontal, 20)
                                
                                Button(action: {
                                    selectedStoryToRead = inProgressStory
                                }) {
                                    HStack(spacing: 14) {
                                        FableImageView(name: inProgressStory.coverImageName ?? inProgressStory.heroImageName, placeholderIcon: "book.pages")
                                            .frame(width: 64, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(inProgressStory.title)
                                                .font(.system(size: 16, weight: .bold, design: .serif))
                                                .foregroundColor(FableTheme.textPrimary)
                                                .lineLimit(1)
                                            
                                            Text(inProgressStory.author)
                                                .font(.system(size: 13))
                                                .foregroundColor(FableTheme.textMuted)
                                            
                                            // Progress Bar
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    Capsule()
                                                        .fill(Color.gray.opacity(0.15))
                                                        .frame(height: 4)
                                                    
                                                    Capsule()
                                                        .fill(FableTheme.brandPrimary)
                                                        .frame(width: geo.size.width * CGFloat(inProgressStory.progressPercent) / 100.0, height: 4)
                                                }
                                            }
                                            .frame(height: 4)
                                            .padding(.top, 2)
                                            
                                            Text("\(inProgressStory.progressPercent)% complete • Page \(inProgressStory.currentPage) of \(inProgressStory.totalPages)")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(FableTheme.brandPrimary)
                                            .padding(10)
                                            .background(FableTheme.surface)
                                            .clipShape(Circle())
                                    }
                                    .padding(14)
                                    .background(FableTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                                    .padding(.horizontal, 20)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.top, 6)
                        }
                        
                        // Recent Submissions Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Submissions")
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.textPrimary)
                                
                                Spacer()
                                
                                Text("\(filteredRecentStories.count) new stories")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(FableTheme.textMuted)
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(filteredRecentStories) { story in
                                    Button(action: {
                                        selectedStoryToRead = story
                                    }) {
                                        HStack(alignment: .top, spacing: 14) {
                                            FableImageView(name: story.coverImageName, placeholderIcon: "book.closed")
                                                .frame(width: 72, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            
                                            VStack(alignment: .leading, spacing: 5) {
                                                HStack {
                                                    Text(story.author)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .tracking(0.6)
                                                        .foregroundColor(FableTheme.brandPrimary)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3)
                                                        .background(FableTheme.surface)
                                                        .clipShape(Capsule())
                                                    
                                                    Spacer()
                                                    
                                                    Button(action: {
                                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                            store.toggleBookmark(for: story)
                                                        }
                                                    }) {
                                                        Image(systemName: story.isBookmarked ? "bookmark.fill" : "bookmark")
                                                            .font(.system(size: 13))
                                                            .foregroundColor(story.isBookmarked ? FableTheme.brandPrimary : FableTheme.textMuted)
                                                    }
                                                }
                                                
                                                Text(story.title)
                                                    .font(.system(size: 17, weight: .bold, design: .serif))
                                                    .foregroundColor(FableTheme.textPrimary)
                                                
                                                Text(story.excerpt)
                                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                                    .foregroundColor(FableTheme.textPrimary.opacity(0.75))
                                                    .lineLimit(2)
                                                    .lineSpacing(2)
                                            }
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(FableTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                        .padding(.horizontal, 20)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 90) // spacing for custom tab bar
                    }
                }
                .refreshable {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRefreshing = true
                    }
                    try? await Task.sleep(nanoseconds: 550_000_000)
                    store.refreshAll()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRefreshing = false
                    }
                }
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingProfileSheet) {
                ProfileView()
                    .environmentObject(store)
            }
        }
    }
}
