import SwiftUI

public struct ExploreView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "All"
    @State private var selectedGenreForDetail: GenreCategory?
    @State private var selectedStoryToRead: Story?
    @State private var selectedWriter: Writer?
    
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
            return store.stories.filter { $0.readingTimeMinutes <= 5 }
        case "Community Favorites":
            return store.stories.filter { $0.rating >= 4.9 }
        case "Quick Reads":
            return store.stories.filter { $0.readingTimeMinutes <= 3 }
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
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(FableTheme.brandPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text("Fable")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(FableTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Text("Explore")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(FableTheme.textPrimary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Title Area
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DISCOVERY")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(FableTheme.brandPrimary)
                            
                            Text("Explore")
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(FableTheme.textPrimary)
                        }
                        .padding(.horizontal, 20)
                        
                        // Search Bar (Live Filter)
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(FableTheme.textMuted)
                            
                            TextField("Search stories, manga, or authors...", text: $searchText)
                                .font(.system(size: 15))
                                .foregroundColor(FableTheme.textPrimary)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(FableTheme.textMuted)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(FableTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                        .padding(.horizontal, 20)
                        
                        // If searching, show search results
                        if !searchText.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Search Results (\(searchResults.count))")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(FableTheme.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                
                                if searchResults.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: 30))
                                            .foregroundColor(FableTheme.textMuted)
                                        Text("No titles found matching \"\(searchText)\"")
                                            .font(.system(size: 14))
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 30)
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(searchResults) { story in
                                            Button(action: {
                                                selectedStoryToRead = story
                                            }) {
                                                HStack(spacing: 14) {
                                                    FableImageView(name: story.effectiveCoverImage, placeholderIcon: "book.closed")
                                                        .frame(width: 50, height: 64)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(story.title)
                                                            .font(.system(size: 15, weight: .bold))
                                                            .foregroundColor(FableTheme.textPrimary)
                                                        HStack(spacing: 6) {
                                                            Text(story.contentFormat.displayName.uppercased())
                                                                .font(.system(size: 9, weight: .bold))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(story.contentFormat == .manga ? FableTheme.brandPrimary.opacity(0.12) : FableTheme.surfaceVariant)
                                                                .foregroundColor(story.contentFormat == .manga ? FableTheme.brandPrimary : FableTheme.textSecondary)
                                                                .clipShape(Capsule())
                                                            Text("\(story.author) • \(story.genre.rawValue)")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(FableTheme.textMuted)
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
                                        withAnimation {
                                            selectedFilter = filter
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(filter)
                                            if selectedFilter == filter && filter != "All" {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                        }
                                        .font(.system(size: 13, weight: selectedFilter == filter ? .semibold : .medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedFilter == filter ? FableTheme.brandPrimary : FableTheme.surfaceVariant)
                                        .foregroundColor(selectedFilter == filter ? .white : FableTheme.textPrimary)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Curated Stories Horizontal Scroll (when a filter is selected)
                        if selectedFilter != "All" {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(selectedFilter) (\(curatedStories.count))")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(FableTheme.textPrimary)
                                    .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 14) {
                                        ForEach(curatedStories) { story in
                                            Button(action: {
                                                selectedStoryToRead = story
                                            }) {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    FableImageView(name: story.effectiveCoverImage, placeholderIcon: "book")
                                                        .frame(width: 120, height: 150)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                    
                                                    Text(story.title)
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(FableTheme.textPrimary)
                                                        .lineLimit(1)
                                                    
                                                    Text(story.author)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(FableTheme.textMuted)
                                                        .lineLimit(1)
                                                }
                                                .frame(width: 120)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Popular Genres Section (FIGMA.md Frame 6: 1:752)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Popular Genres")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(FableTheme.textPrimary)
                                
                                Spacer()
                                
                                Text("\(store.genres.count) categories")
                                    .font(.system(size: 13))
                                    .foregroundColor(FableTheme.textMuted)
                            }
                            .padding(.horizontal, 20)
                            
                            // 2x2 Grid
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                                ForEach(store.genres) { genre in
                                    Button(action: {
                                        selectedGenreForDetail = genre
                                    }) {
                                        ZStack(alignment: .bottomLeading) {
                                            FableImageView(name: genre.effectiveImage, placeholderIcon: "books.vertical.fill")
                                                .frame(height: 150)
                                                .clipped()
                                            
                                            // Soft gradient overlay for text readability
                                            LinearGradient(
                                                colors: [Color.clear, Color.black.opacity(0.75)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(genre.name)
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(.white)
                                                
                                                Text("\(genre.storyCount) stories")
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(Color.white.opacity(0.85))
                                            }
                                            .padding(14)
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Trending Creators Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 6) {
                                Text("Trending Creators")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(FableTheme.textPrimary)
                                
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 14))
                                    .foregroundColor(FableTheme.brandPrimary)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(store.writers) { writer in
                                        Button(action: {
                                            selectedWriter = writer
                                        }) {
                                            VStack(spacing: 8) {
                                                FableImageView(name: writer.effectiveAvatar, placeholderIcon: "person.circle.fill")
                                                    .frame(width: 68, height: 68)
                                                    .clipShape(Circle())
                                                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                                                
                                                VStack(spacing: 2) {
                                                    Text(writer.name)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(FableTheme.textPrimary)
                                                        .lineLimit(1)
                                                    
                                                    Text("\(writer.storyCount) Stories")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(FableTheme.textMuted)
                                                    
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "star.fill")
                                                            .font(.system(size: 9))
                                                            .foregroundColor(.orange)
                                                        Text(String(format: "%.1f", writer.rating))
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundColor(FableTheme.textPrimary)
                                                    }
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
                        .padding(.top, 8)
                        .padding(.bottom, 90) // spacing for custom tab bar
                    }
                }
                .refreshable {
                    await store.syncWithCloudBackend()
                    await store.fetchGutenbergPublicStories(topic: "fiction", search: nil)
                }
            }
            .navigationDestination(item: $selectedGenreForDetail) { genre in
                GenreDetailView(genre: genre)
                    .environmentObject(store)
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
            .sheet(item: $selectedWriter) { writer in
                VStack(spacing: 20) {
                    FableImageView(name: writer.effectiveAvatar, placeholderIcon: "person.circle.fill")
                        .frame(width: 84, height: 84)
                        .clipShape(Circle())
                        .padding(.top, 24)
                    
                    Text(writer.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(FableTheme.textPrimary)
                    
                    Text("Featured Creator • \(writer.storyCount) published titles")
                        .font(.system(size: 14))
                        .foregroundColor(FableTheme.textMuted)
                    
                    Button("Read Top Title") {
                        selectedWriter = nil
                        if let first = store.stories.first {
                            selectedStoryToRead = first
                        }
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(FableTheme.brandPrimary)
                    .clipShape(Capsule())
                    
                    Spacer()
                }
                .presentationDetents([.fraction(0.4)])
            }
        }
    }
}

#Preview {
    ExploreView()
        .environmentObject(StoryStore())
}
