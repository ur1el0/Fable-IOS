import SwiftUI

struct GenreDetailView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedSubcategory: String = "All"
    @State private var isFollowing: Bool = false
    @State private var selectedStoryToRead: Story?
    
    let subcategories = ["All", "Forest Spirits", "Urban Legends", "Slavic"]
    
    var body: some View {
        ZStack {
            FableTheme.warmCream.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Nav Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(FableTheme.deepCharcoal)
                    }
                    
                    Spacer()
                    
                    Text("Genre Detail")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(FableTheme.deepCharcoal)
                    
                    Spacer()
                    
                    HStack(spacing: 16) {
                        Button(action: {}) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16))
                                .foregroundColor(FableTheme.deepCharcoal)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 16))
                                .foregroundColor(FableTheme.deepCharcoal)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Archive Edition Header Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 6) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 11))
                                Text("ARCHIVE EDITION")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                            }
                            .foregroundColor(FableTheme.terracotta)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(FableTheme.softPeach)
                            .clipShape(Capsule())
                            
                            Text("Folklore & Legends")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(FableTheme.deepCharcoal)
                            
                            Text("340 Tales  •  18.4k Readers  •  Curated Weekly")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(FableTheme.subtleSlate)
                            
                            Text("Traditional tales passed down through generations, reimagined by contemporary scribes—from fireside Slavic forest myths to maritime legends whispered across coastal tides.")
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .foregroundColor(FableTheme.deepCharcoal.opacity(0.85))
                                .lineSpacing(4)
                            
                            Button(action: {
                                withAnimation {
                                    isFollowing.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: isFollowing ? "checkmark" : "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text(isFollowing ? "Following" : "Follow Genre")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(isFollowing ? FableTheme.terracotta : .white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(isFollowing ? FableTheme.softPeach : FableTheme.terracotta)
                                .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                        
                        // Subcategory Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(subcategories, id: \.self) { sub in
                                    Button(action: {
                                        selectedSubcategory = sub
                                    }) {
                                        Text(sub)
                                            .fableTag(isSelected: selectedSubcategory == sub)
                                    }
                                }
                            }
                        }
                        
                        // Curator's Spotlight Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Curator's Spotlight")
                                    .font(.system(size: 17, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                
                                Spacer()
                                
                                Text("STORY OF THE WEEK")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(0.8)
                                    .foregroundColor(FableTheme.subtleSlate)
                            }
                            
                            // Spotlight Card
                            VStack(alignment: .center, spacing: 14) {
                                ZStack(alignment: .bottom) {
                                    if let cover = UIImage(named: "cover_sleepy_featured") {
                                        Image(uiImage: cover)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                                    }
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.yellow)
                                        Text("4.95")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Capsule())
                                    .padding(.bottom, 8)
                                }
                                
                                Text("The Legend of Sleepy Hollow")
                                    .font(.system(size: 20, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                    .multilineTextAlignment(.center)
                                
                                Text("BY WASHINGTON IRVING")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.terracotta)
                                
                                Text("“A drowsy, dreamy influence seems to hang over the land, and to pervade the very atmosphere.”")
                                    .font(.system(size: 14, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundColor(FableTheme.subtleSlate)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                
                                HStack(spacing: 14) {
                                    Button(action: {
                                        if let story = store.stories.first(where: { $0.title.contains("Sleepy Hollow") }) {
                                            selectedStoryToRead = story
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Text("Read Now")
                                                .font(.system(size: 14, weight: .semibold))
                                            Image(systemName: "book.pages")
                                                .font(.system(size: 13))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(FableTheme.terracotta)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    
                                    Button(action: {}) {
                                        Image(systemName: "bookmark")
                                            .font(.system(size: 16))
                                            .foregroundColor(FableTheme.deepCharcoal)
                                            .frame(width: 44, height: 44)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                        }
                        
                        // Recent Dispatches
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Recent Dispatches")
                                    .font(.system(size: 17, weight: .bold, design: .serif))
                                    .foregroundColor(FableTheme.deepCharcoal)
                                
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    Text("Sort by")
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(FableTheme.terracotta)
                            }
                            
                            // Story Cards List
                            let dispatchStories = store.stories.filter { $0.badgeText != nil }
                            ForEach(dispatchStories) { story in
                                Button(action: {
                                    selectedStoryToRead = story
                                }) {
                                    HStack(alignment: .top, spacing: 14) {
                                        if let cover = story.coverImageName, let img = UIImage(named: cover) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 70, height: 95)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                if let badge = story.badgeText {
                                                    Text(badge)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .tracking(0.8)
                                                        .foregroundColor(FableTheme.terracotta)
                                                }
                                                
                                                Spacer()
                                                
                                                HStack(spacing: 3) {
                                                    Image(systemName: "clock")
                                                        .font(.system(size: 9))
                                                    Text("\(story.readingTimeMinutes) min")
                                                        .font(.system(size: 10))
                                                }
                                                .foregroundColor(FableTheme.subtleSlate)
                                            }
                                            
                                            Text(story.title)
                                                .font(.system(size: 16, weight: .bold, design: .serif))
                                                .foregroundColor(FableTheme.deepCharcoal)
                                                .lineLimit(1)
                                            
                                            Text(story.author)
                                                .font(.system(size: 12))
                                                .foregroundColor(FableTheme.subtleSlate)
                                            
                                            HStack(spacing: 12) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "star.fill")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.yellow)
                                                    Text(String(format: "%.1f", story.rating))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(FableTheme.deepCharcoal)
                                                }
                                                
                                                HStack(spacing: 3) {
                                                    Image(systemName: "bookmark")
                                                        .font(.system(size: 9))
                                                    Text(story.savesCount)
                                                        .font(.system(size: 11))
                                                }
                                                .foregroundColor(FableTheme.subtleSlate)
                                            }
                                            .padding(.top, 2)
                                            
                                            Text(story.excerpt)
                                                .font(.system(size: 12, weight: .regular, design: .serif))
                                                .foregroundColor(FableTheme.deepCharcoal.opacity(0.75))
                                                .lineLimit(2)
                                                .padding(.top, 2)
                                        }
                                    }
                                    .padding(14)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(item: $selectedStoryToRead) { story in
            ReaderView(story: story)
                .environmentObject(store)
        }
    }
}
