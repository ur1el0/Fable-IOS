import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var selectedFilter: String = "All"
    @State private var selectedStoryToRead: Story?
    @State private var bookmarkedStories: Set<UUID> = []
    
    let filterCategories = ["All", "Folklore", "Mythology", "Sci-Fi", "Fables"]
    
    var filteredRecentStories: [Story] {
        let recents = store.stories.filter { $0.isRecentSubmission }
        if selectedFilter == "All" {
            return recents
        } else {
            return recents.filter { $0.genre.localizedCaseInsensitiveContains(selectedFilter) }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.warmCream.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Date & Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TUESDAY, OCT 14")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(FableTheme.subtleSlate)
                            
                            Text("Library")
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.deepCharcoal)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Filter Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filterCategories, id: \.self) { cat in
                                    Button(action: {
                                        withAnimation {
                                            selectedFilter = cat
                                        }
                                    }) {
                                        Text(cat)
                                            .fableTag(isSelected: selectedFilter == cat)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Tale of the Day Featured Card
                        if let taleOfTheDay = store.stories.first(where: { $0.isTaleOfTheDay }) {
                            Button(action: {
                                selectedStoryToRead = taleOfTheDay
                            }) {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Book Cover with Badge & Bookmark
                                    ZStack(alignment: .top) {
                                        if let cover = taleOfTheDay.coverImageName, let img = UIImage(named: cover) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 200)
                                                .clipped()
                                        } else {
                                            Rectangle()
                                                .fill(Color(red: 0.96, green: 0.82, blue: 0.38))
                                                .frame(height: 200)
                                        }
                                        
                                        HStack {
                                            Text("TALE OF THE DAY")
                                                .font(.system(size: 10, weight: .bold))
                                                .tracking(1.0)
                                                .foregroundColor(FableTheme.terracotta)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.white.opacity(0.95))
                                                .clipShape(Capsule())
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                if bookmarkedStories.contains(taleOfTheDay.id) {
                                                    bookmarkedStories.remove(taleOfTheDay.id)
                                                } else {
                                                    bookmarkedStories.insert(taleOfTheDay.id)
                                                }
                                            }) {
                                                Image(systemName: bookmarkedStories.contains(taleOfTheDay.id) ? "bookmark.fill" : "bookmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(FableTheme.deepCharcoal)
                                                    .padding(8)
                                                    .background(Color.white.opacity(0.9))
                                                    .clipShape(Circle())
                                            }
                                        }
                                        .padding(14)
                                    }
                                    
                                    // Description Area
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 4) {
                                            Text(taleOfTheDay.author)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(FableTheme.subtleSlate)
                                            Text("•")
                                                .foregroundColor(FableTheme.subtleSlate)
                                        }
                                        
                                        Text(taleOfTheDay.title)
                                            .font(.system(size: 24, weight: .bold, design: .serif))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                        
                                        Text(taleOfTheDay.excerpt)
                                            .font(.system(size: 14, weight: .regular, design: .serif))
                                            .foregroundColor(FableTheme.deepCharcoal.opacity(0.85))
                                            .lineSpacing(4)
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: Color.black.opacity(0.06), radius: 10, y: 3)
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Continue Reading Section
                        if let sleepy = store.stories.first(where: { $0.title.contains("Sleepy Hollow") }) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Continue Reading")
                                        .font(.system(size: 18, weight: .bold, design: .serif))
                                        .foregroundColor(FableTheme.deepCharcoal)
                                    
                                    Spacer()
                                    
                                    Button("See All") {
                                        // View all
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(FableTheme.terracotta)
                                }
                                .padding(.horizontal, 20)
                                
                                Button(action: {
                                    selectedStoryToRead = sleepy
                                }) {
                                    HStack(spacing: 14) {
                                        if let cover = sleepy.coverImageName, let img = UIImage(named: cover) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 64, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(sleepy.title)
                                                .font(.system(size: 16, weight: .bold, design: .serif))
                                                .foregroundColor(FableTheme.deepCharcoal)
                                                .lineLimit(1)
                                            
                                            Text(sleepy.author)
                                                .font(.system(size: 13))
                                                .foregroundColor(FableTheme.subtleSlate)
                                            
                                            // Progress Bar
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    Capsule()
                                                        .fill(Color.gray.opacity(0.15))
                                                        .frame(height: 4)
                                                    
                                                    Capsule()
                                                        .fill(FableTheme.terracotta)
                                                        .frame(width: geo.size.width * CGFloat(sleepy.progressPercent) / 100.0, height: 4)
                                                }
                                            }
                                            .frame(height: 4)
                                            .padding(.top, 2)
                                            
                                            Text("\(sleepy.progressPercent)% complete • Page \(sleepy.currentPage) of \(sleepy.totalPages)")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(FableTheme.subtleSlate)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(FableTheme.terracotta)
                                            .padding(8)
                                    }
                                    .padding(14)
                                    .background(Color.white)
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
                                    .foregroundColor(FableTheme.deepCharcoal)
                                
                                Spacer()
                                
                                Text("\(filteredRecentStories.count) new stories")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(FableTheme.subtleSlate)
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(filteredRecentStories) { story in
                                    Button(action: {
                                        selectedStoryToRead = story
                                    }) {
                                        HStack(alignment: .top, spacing: 14) {
                                            if let cover = story.coverImageName, let img = UIImage(named: cover) {
                                                Image(uiImage: img)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 72, height: 90)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(story.author)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .tracking(0.6)
                                                    .foregroundColor(FableTheme.terracotta)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(FableTheme.softPeach)
                                                    .clipShape(Capsule())
                                                
                                                Text(story.title)
                                                    .font(.system(size: 17, weight: .bold, design: .serif))
                                                    .foregroundColor(FableTheme.deepCharcoal)
                                                
                                                Text(story.excerpt)
                                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                                    .foregroundColor(FableTheme.deepCharcoal.opacity(0.75))
                                                    .lineLimit(3)
                                                    .lineSpacing(2)
                                            }
                                        }
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.white)
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
            }
            .fullScreenCover(item: $selectedStoryToRead) { story in
                ReaderView(story: story)
                    .environmentObject(store)
            }
        }
    }
}
