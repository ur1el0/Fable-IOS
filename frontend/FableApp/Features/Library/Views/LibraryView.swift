import SwiftUI

public struct LibraryView: View {
    @EnvironmentObject var store: StoryStore
    @ObservedObject private var auth = AuthManager.shared
    
    @State private var selectedFilter: String = "All"
    @State private var selectedStoryToRead: Story?
    @State private var isShowingProfileSheet: Bool = false
    
    let filterCategories = ["All", "Manga", "Folklore", "Mythology", "Gothic", "Speculative", "Classic"]
    
    var filteredRecentStories: [Story] {
        let recents = store.stories.filter { $0.isRecentSubmission }
        if selectedFilter == "All" {
            return recents
        } else if selectedFilter == "Manga" {
            return recents.filter { $0.contentFormat == .manga || $0.genre == .manga }
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
                        // Header Date, Title & Profile Avatar
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("DISCOVER")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(1.4)
                                        .foregroundColor(FableTheme.brandPrimary)
                                    
                                    // Live Cloud Connectivity Pill
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(store.isBackendReachable ? Color.green : Color.orange)
                                            .frame(width: 6, height: 6)
                                        Text(store.isBackendReachable ? "Live Cloud" : "Offline Cache")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(store.isBackendReachable ? Color.green : Color.orange)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((store.isBackendReachable ? Color.green : Color.orange).opacity(0.12))
                                    .clipShape(Capsule())
                                }
                                
                                Text("Library")
                                    .font(.system(size: 32, weight: .black, design: .default))
                                    .foregroundColor(FableTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                isShowingProfileSheet = true
                            }) {
                                FableImageView(name: auth.currentSession?.avatarName ?? "avatar_roosc", placeholderIcon: "person.crop.circle")
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
                        
                        // Featured Hero Card
                        if let featuredStory = store.stories.first(where: { $0.isTaleOfTheDay }) ?? store.stories.first {
                            Button(action: {
                                selectedStoryToRead = featuredStory
                            }) {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Media Cover with Dynamic Format Badge
                                    ZStack(alignment: .top) {
                                        FableImageView(name: featuredStory.effectiveCoverImage, placeholderIcon: "square.stack")
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 220)
                                            .clipped()
                                        
                                        HStack {
                                            Text(featuredStory.contentFormat == .manga ? "FEATURED MANGA" : "FEATURED TITLE")
                                                .font(.system(size: 10, weight: .heavy))
                                                .tracking(1.0)
                                                .foregroundColor(FableTheme.brandPrimary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.white.opacity(0.95))
                                                .clipShape(Capsule())
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                    store.toggleBookmark(for: featuredStory)
                                                }
                                            }) {
                                                Image(systemName: featuredStory.isBookmarked ? "bookmark.fill" : "bookmark")
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
                                        HStack(spacing: 6) {
                                            Text(featuredStory.author)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(FableTheme.brandPrimary)
                                            Text("•")
                                                .foregroundColor(FableTheme.textMuted)
                                            Text(featuredStory.contentFormat == .manga ? "\(featuredStory.readingTimeMinutes)m read" : "\(featuredStory.readingTimeMinutes) min read")
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                        
                                        Text(featuredStory.title)
                                            .font(.system(size: 22, weight: .bold, design: .default))
                                            .foregroundColor(FableTheme.textPrimary)
                                        
                                        Text(featuredStory.excerpt)
                                            .font(.system(size: 14, weight: .regular, design: .default))
                                            .foregroundColor(FableTheme.textSecondary)
                                            .lineSpacing(3)
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(FableTheme.cardBackground)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Continue Reading Section
                        if let inProgressStory = store.stories.first(where: { $0.progressPercent > 0 && !$0.isCompleted }) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Continue Reading")
                                        .font(.system(size: 18, weight: .bold, design: .default))
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
                                        FableImageView(name: inProgressStory.effectiveCoverImage ?? inProgressStory.heroImageName, placeholderIcon: "square.stack")
                                            .frame(width: 64, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack(spacing: 6) {
                                                Text(inProgressStory.contentFormat == .manga ? "MANGA" : "NOVEL")
                                                    .font(.system(size: 9, weight: .heavy))
                                                    .foregroundColor(FableTheme.brandPrimary)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(FableTheme.surface)
                                                    .clipShape(Capsule())
                                                
                                                Text(inProgressStory.author)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(FableTheme.textMuted)
                                            }
                                            
                                            Text(inProgressStory.title)
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(FableTheme.textPrimary)
                                                .lineLimit(1)
                                            
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
                        
                        // Latest Releases Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Latest Releases")
                                    .font(.system(size: 18, weight: .bold, design: .default))
                                    .foregroundColor(FableTheme.textPrimary)
                                    
                                Spacer()
                                
                                Text("\(filteredRecentStories.count) titles")
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
                                            FableImageView(name: story.effectiveCoverImage, placeholderIcon: "square.stack")
                                                .frame(width: 72, height: 96)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            
                                            VStack(alignment: .leading, spacing: 5) {
                                                HStack {
                                                    // Dynamic Format Pill
                                                    Text(story.contentFormat == .manga ? "MANGA" : (story.sourceProvider == .standardEbooks ? "STANDARD EBOOKS" : story.genre.rawValue.uppercased()))
                                                        .font(.system(size: 9, weight: .heavy))
                                                        .tracking(0.5)
                                                        .foregroundColor(FableTheme.brandPrimary)
                                                        .padding(.horizontal, 7)
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
                                                    .font(.system(size: 16, weight: .bold, design: .default))
                                                    .foregroundColor(FableTheme.textPrimary)
                                                    .lineLimit(1)
                                                
                                                Text(story.author)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(FableTheme.textMuted)
                                                
                                                Text(story.excerpt)
                                                    .font(.system(size: 12, weight: .regular))
                                                    .foregroundColor(FableTheme.textSecondary)
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
                    await store.syncWithCloudBackend()
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

#Preview {
    LibraryView()
        .environmentObject(StoryStore())
}
