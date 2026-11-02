import SwiftUI

public struct ExploreView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "All"
    @State private var selectedGenreForDetail: GenreCategory?
    @State private var selectedStoryToRead: Story?
    @State private var selectedWriter: Writer?
    @FocusState private var isSearchFocused: Bool
    
    let filters = ["All", "Under 5 mins", "Community Favorites", "Quick Reads"]
    
    var searchResults: [Story] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.stories.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.author.localizedCaseInsensitiveContains(query) ||
            $0.genre.rawValue.localizedCaseInsensitiveContains(query) ||
            $0.synopsis.localizedCaseInsensitiveContains(query)
        }
    }
    
    var curatedStories: [Story] {
        switch selectedFilter {
        case "Under 5 mins":
            return store.stories.filter { $0.readingTimeMinutes > 0 && $0.readingTimeMinutes <= 5 }
        case "Community Favorites":
            return store.stories.filter { (Int($0.savesCount) ?? 0) > 0 }
        case "Quick Reads":
            return store.stories.filter { $0.readingTimeMinutes > 0 && $0.readingTimeMinutes <= 3 }
        default:
            return store.stories
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        // Top Brand Header
                        HStack {
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
                            
                            Spacer()
                            
                            Text("Discovery")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(FableTheme.textMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Editorial Title Area
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURATED CATALOG")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(FableTheme.brandPrimary)
                            
                            Text("Explore")
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.textPrimary)
                        }
                        .padding(.horizontal, 20)

                        ProviderCatalogStatusView()
                        
                        // Search Bar with Active Focus Indicator
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(isSearchFocused ? FableTheme.brandPrimary : FableTheme.textMuted)
                            
                            TextField("Search stories, manga, or authors...", text: $searchText)
                                .font(.system(size: 15))
                                .foregroundColor(FableTheme.textPrimary)
                                .focused($isSearchFocused)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    FableHaptics.light()
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(FableTheme.textMuted)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel("Clear search")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(FableTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSearchFocused ? FableTheme.brandPrimary : FableTheme.divider.opacity(0.8), lineWidth: isSearchFocused ? 1.5 : 0.8)
                        )
                        .shadow(color: isSearchFocused ? FableTheme.brandPrimary.opacity(0.12) : Color.black.opacity(0.03), radius: isSearchFocused ? 10 : 8, y: 2)
                        .padding(.horizontal, 20)
                        
                        // Search Results Section (Shown When Searching)
                        if !searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Search Results (\(searchResults.count))")
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                if searchResults.isEmpty {
                                    VStack(spacing: 10) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 32))
                                            .foregroundColor(FableTheme.textMuted.opacity(0.5))
                                        Text("No titles found matching \"\(searchText)\"")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 32)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(searchResults) { story in
                                            Button(action: {
                                                selectedStoryToRead = story
                                            }) {
                                                HStack(spacing: 14) {
                                                    FableImageView(name: story.effectiveCoverImage, title: story.title, placeholderIcon: "book.closed")
                                                        .frame(width: 52, height: 68)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                        .shadow(color: Color.black.opacity(0.1), radius: 3, y: 1)
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(story.title)
                                                            .font(.system(size: 15, weight: .bold, design: .serif))
                                                            .foregroundColor(FableTheme.textPrimary)
                                                            .lineLimit(1)
                                                        
                                                        HStack(spacing: 6) {
                                                            Text(story.contentFormat.displayName.uppercased())
                                                                .font(.system(size: 8, weight: .heavy))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(story.contentFormat == .manga ? FableTheme.brandPrimary.opacity(0.12) : FableTheme.surface)
                                                                .foregroundColor(story.contentFormat == .manga ? FableTheme.brandPrimary : FableTheme.textSecondary)
                                                                .clipShape(Capsule())
                                                            
                                                            Text("\(story.author) • \(story.genre.rawValue)")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(FableTheme.textMuted)
                                                                .lineLimit(1)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(FableTheme.textMuted)
                                                }
                                                .padding(12)
                                                .background(FableTheme.cardBackground)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
                                                .padding(.horizontal, 20)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Curated Filter Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filters, id: \.self) { filter in
                                    Button(action: {
                                        FableHaptics.selection()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            selectedFilter = filter
                                        }
                                    }) {
                                        HStack(spacing: 5) {
                                            Text(filter)
                                            if selectedFilter == filter && filter != "All" {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                        }
                                        .font(.system(size: 13, weight: selectedFilter == filter ? .semibold : .medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(
                                            selectedFilter == filter
                                                ? AnyView(LinearGradient(colors: [FableTheme.brandPrimary, FableTheme.brandPrimary.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                : AnyView(FableTheme.surfaceVariant)
                                        )
                                        .foregroundColor(selectedFilter == filter ? .white : FableTheme.textPrimary)
                                        .clipShape(Capsule())
                                        .shadow(color: selectedFilter == filter ? FableTheme.brandPrimary.opacity(0.25) : Color.clear, radius: 6, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Curated Stories Horizontal Scroll (when filter active)
                        if selectedFilter != "All" {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("\(selectedFilter) (\(curatedStories.count))")
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(curatedStories) { story in
                                            Button(action: {
                                                selectedStoryToRead = story
                                            }) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    FableImageView(name: story.effectiveCoverImage, title: story.title, placeholderIcon: "book")
                                                        .frame(width: 124, height: 160)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                        .shadow(color: Color.black.opacity(0.12), radius: 5, y: 2)
                                                    
                                                    Text(story.title)
                                                        .font(.system(size: 13, weight: .bold, design: .serif))
                                                        .foregroundColor(FableTheme.textPrimary)
                                                        .lineLimit(1)
                                                    
                                                    Text(story.author)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(FableTheme.textMuted)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 124)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Popular Genres Section (2x2 Editorial Grid)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Popular Genres")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.textPrimary)
                                
                                Spacer()
                                
                                Text("\(store.genres.count) categories")
                                    .font(.system(size: 13))
                                    .monospacedDigit()
                                    .foregroundColor(FableTheme.textMuted)
                            }
                            .padding(.horizontal, 20)
                            
                            if store.genres.isEmpty {
                                Text("Live genres will appear here after the catalog syncs.")
                                    .font(.system(size: 14))
                                    .foregroundColor(FableTheme.textMuted)
                                    .padding(.horizontal, 20)
                            }

                            // 2x2 Grid with Gradient Scrims & Soft Shadows
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                                ForEach(store.genres) { genre in
                                    Button(action: {
                                        selectedGenreForDetail = genre
                                    }) {
                                        ZStack(alignment: .bottomLeading) {
                                            FableImageView(name: genre.effectiveImage, title: genre.name, placeholderIcon: "books.vertical.fill")
                                                .frame(height: 156)
                                                .clipped()
                                            
                                            // Rich linear gradient scrim for maximum text legibility
                                            LinearGradient(
                                                colors: [Color.clear, Color.black.opacity(0.35), Color.black.opacity(0.85)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(genre.name)
                                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                                    .foregroundColor(.white)
                                                    .shadow(color: Color.black.opacity(0.4), radius: 2, y: 1)
                                                
                                                Text("\(genre.storyCount) stories")
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(Color.white.opacity(0.9))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 2)
                                                    .background(Color.white.opacity(0.2))
                                                    .clipShape(Capsule())
                                            }
                                            .padding(14)
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
                                        .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Trending Creators Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 6) {
                                Text("Trending Creators")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.textPrimary)
                                
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 14))
                                    .foregroundColor(FableTheme.brandPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    if store.writers.isEmpty {
                                        Text("Live author profiles will appear here after sync.")
                                            .font(.system(size: 14))
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                    ForEach(store.writers) { writer in
                                        Button(action: {
                                            selectedWriter = writer
                                        }) {
                                            VStack(spacing: 8) {
                                                FableImageView(name: writer.effectiveAvatar, title: writer.name, placeholderIcon: "person.circle.fill")
                                                    .frame(width: 68, height: 68)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                                    .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)
                                                
                                                VStack(spacing: 2) {
                                                    Text(writer.name)
                                                        .font(.system(size: 13, weight: .bold, design: .serif))
                                                        .foregroundColor(FableTheme.textPrimary)
                                                        .lineLimit(1)
                                                    
                                                    Text("\(writer.storyCount) Stories")
                                                        .font(.system(size: 11, weight: .medium))
                                                        .foregroundColor(FableTheme.textMuted)
                                                }
                                            }
                                            .frame(width: 95)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 100) // Spacing for floating glass navigation pill
                    }
                }
                .refreshable {
                    await store.syncWithCloudBackend()
                }
            }
            .task(id: searchText) {
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return }
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await store.searchCatalog(query: query)
            }
            .navigationDestination(item: $selectedGenreForDetail) { genre in
                GenreDetailView(genre: genre)
                    .environmentObject(store)
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
            .sheet(item: $selectedWriter) { writer in
                AuthorDetailView(writer: writer)
                    .environmentObject(store)
            }
        }
    }
}

#Preview {
    ExploreView()
        .environmentObject(StoryStore())
}
