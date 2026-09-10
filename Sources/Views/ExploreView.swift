import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var store: StoryStore
    
    @State private var searchText: String = ""
    @State private var selectedFilter: String = "All"
    @State private var navigateToGenre: GenreCategory?
    
    let filters = ["All", "Under 5 mins", "Community Favorites", "Quick Reads"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                FableTheme.warmCream.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        // Top Brand Header
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .padding(7)
                                    .background(FableTheme.terracotta)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                
                                Text("Fable")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                            }
                            
                            Spacer()
                            
                            Text("Explore")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(FableTheme.deepCharcoal)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        // Title Area
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DISCOVERY")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(FableTheme.terracotta)
                            
                            Text("Explore")
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.deepCharcoal)
                        }
                        .padding(.horizontal, 20)
                        
                        // Search Bar
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(FableTheme.subtleSlate)
                            
                            TextField("Search stories, authors, or genres", text: $searchText)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                        .padding(.horizontal, 20)
                        
                        // Filter Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(filters, id: \.self) { filter in
                                    Button(action: {
                                        selectedFilter = filter
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(filter)
                                            if selectedFilter == filter && filter != "All" {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                        }
                                        .fableTag(isSelected: selectedFilter == filter)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Popular Genres Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Popular Genres")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                
                                Spacer()
                                
                                Text("24 categories")
                                    .font(.system(size: 13))
                                    .foregroundColor(FableTheme.subtleSlate)
                            }
                            .padding(.horizontal, 20)
                            
                            // 2x2 Grid
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                                ForEach(store.genres) { genre in
                                    Button(action: {
                                        navigateToGenre = genre
                                    }) {
                                        ZStack(alignment: .bottomLeading) {
                                            if let img = UIImage(named: genre.imageName) {
                                                Image(uiImage: img)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(height: 150)
                                                    .clipped()
                                            } else {
                                                Rectangle()
                                                    .fill(FableTheme.terracotta.opacity(0.8))
                                                    .frame(height: 150)
                                            }
                                            
                                            // Soft gradient overlay for text readability
                                            LinearGradient(
                                                colors: [Color.clear, Color.black.opacity(0.75)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(genre.name)
                                                    .font(.system(size: 18, weight: .bold, design: .serif))
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
                        
                        // Trending Writers Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 6) {
                                Text("Trending Writers")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 14))
                                    .foregroundColor(FableTheme.terracotta)
                                
                                Spacer()
                                
                                Button("View All >") {
                                    // View all writers
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(FableTheme.terracotta)
                            }
                            .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 18) {
                                    ForEach(store.writers) { writer in
                                        VStack(spacing: 8) {
                                            if let avatar = UIImage(named: writer.avatarImageName) {
                                                Image(uiImage: avatar)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 68, height: 68)
                                                    .clipShape(Circle())
                                                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                                            } else {
                                                Circle()
                                                    .fill(FableTheme.softPeach)
                                                    .frame(width: 68, height: 68)
                                            }
                                            
                                            VStack(spacing: 2) {
                                                Text(writer.name)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(FableTheme.deepCharcoal)
                                                    .lineLimit(1)
                                                
                                                Text("\(writer.storyCount) Stories")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(FableTheme.subtleSlate)
                                                
                                                HStack(spacing: 2) {
                                                    Image(systemName: "star.fill")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.yellow)
                                                    Text(String(format: "%.1f", writer.rating))
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(FableTheme.deepCharcoal)
                                                }
                                            }
                                        }
                                        .frame(width: 95)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 90) // spacing for custom tab bar
                    }
                }
            }
            .navigationDestination(item: $navigateToGenre) { _ in
                GenreDetailView()
                    .environmentObject(store)
            }
        }
    }
}
