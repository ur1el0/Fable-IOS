import SwiftUI

public struct GenreDetailView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    
    public var genre: GenreCategory
    
    @State private var selectedSubcategory: String = "All"
    @State private var isFollowing: Bool = false
    @State private var selectedStoryToRead: Story?
    
    let subcategories = ["All", "Popular", "Editor's Pick", "Quick Reads"]
    
    public init(genre: GenreCategory) {
        self.genre = genre
    }
    
    var genreStories: [Story] {
        let matching = store.stories.filter { story in
            store.storyMatchesCategory(story, category: genre.name)
        }
        let list = matching
        switch selectedSubcategory {
        case "Popular":
            return list.sorted { left, right in
                let leftCount = (Int(left.readsCount) ?? 0) + (Int(left.savesCount) ?? 0) + (left.providerDownloadCount ?? 0)
                let rightCount = (Int(right.readsCount) ?? 0) + (Int(right.savesCount) ?? 0) + (right.providerDownloadCount ?? 0)
                return leftCount > rightCount
            }
        case "Editor's Pick":
            return list.filter(\.isCuratorSpotlight)
        case "Quick Reads":
            return list.filter { $0.readingTimeMinutes > 0 && $0.readingTimeMinutes <= 4 }
        default:
            return list
        }
    }
    
    private func toggleGenreFollow() {
        withAnimation {
            isFollowing.toggle()
        }
        var followed = Set(UserDefaults.standard.stringArray(forKey: "fable_followed_genres") ?? [])
        if isFollowing {
            followed.insert(genre.name)
        } else {
            followed.remove(genre.name)
        }
        UserDefaults.standard.set(followed.sorted(), forKey: "fable_followed_genres")
    }

    public var body: some View {
        ZStack {
            FableTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Nav Bar
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .fableFont(size: 18, weight: .semibold)
                            .foregroundColor(FableTheme.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Back")
                    
                    Spacer()
                    
                    Text(genre.name)
                        .fableFont(size: 17, weight: .bold)
                        .foregroundColor(FableTheme.textPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 10) {
                        Button(action: toggleGenreFollow) {
                            Image(systemName: isFollowing ? "bookmark.fill" : "bookmark")
                                .fableFont(size: 15)
                                .foregroundColor(isFollowing ? FableTheme.brandPrimary : FableTheme.textPrimary)
                                .frame(width: 40, height: 40)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(isFollowing ? "Unfollow genre" : "Follow genre")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Curated Collection Header Card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .fableFont(size: 11)
                                Text("CURATED COLLECTION")
                                    .fableFont(size: 11, weight: .bold)
                                    .tracking(1.0)
                            }
                            .foregroundColor(FableTheme.brandPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(FableTheme.surface)
                            .clipShape(Capsule())
                            
                            Text(genre.name)
                                .fableFont(size: 28, weight: .black)
                                .foregroundColor(FableTheme.textPrimary)
                            
                            let displayTitleCount = store.displayStoryCount(for: genre)
                            if let readersCount = Int(genre.readersCount), readersCount > 0 {
                                Text("\(StoryStore.pluralizedCount(displayTitleCount, singular: "Title"))  •  \(StoryStore.pluralizedCount(readersCount, singular: "Reader"))")
                                    .fableFont(size: 12, weight: .medium)
                                    .foregroundColor(FableTheme.textMuted)
                            } else {
                                Text(StoryStore.pluralizedCount(displayTitleCount, singular: "Title"))
                                    .fableFont(size: 12, weight: .medium)
                                    .foregroundColor(FableTheme.textMuted)
                            }
                            
                            if !genre.description.isEmpty {
                                Text(genre.description)
                                    .fableFont(size: 14, weight: .regular)
                                    .foregroundColor(FableTheme.textPrimary.opacity(0.85))
                                    .lineSpacing(4)
                            }
                            
                            Button(action: toggleGenreFollow) {
                                HStack(spacing: 6) {
                                    Image(systemName: isFollowing ? "checkmark" : "plus")
                                        .fableFont(size: 12, weight: .bold)
                                    Text(isFollowing ? "Following Genre" : "Follow Genre")
                                        .fableFont(size: 13, weight: .semibold)
                                }
                                .foregroundColor(isFollowing ? FableTheme.brandPrimary : .white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(isFollowing ? FableTheme.surface : FableTheme.brandPrimary)
                                .clipShape(Capsule())
                            }
                            .padding(.top, 4)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FableTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                        .padding(.horizontal, 20)
                        
                        // Subcategory Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(subcategories, id: \.self) { sub in
                                    Button(action: {
                                        withAnimation {
                                            selectedSubcategory = sub
                                        }
                                    }) {
                                        Text(sub)
                                            .fableFont(size: 13, weight: selectedSubcategory == sub ? .semibold : .medium)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedSubcategory == sub ? FableTheme.brandPrimary : FableTheme.surfaceVariant)
                                            .foregroundColor(selectedSubcategory == sub ? .white : FableTheme.textPrimary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Stories Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Featured in \(genre.name)")
                                .fableFont(size: 18, weight: .bold)
                                .foregroundColor(FableTheme.textPrimary)
                                .padding(.horizontal, 20)
                            
                            if genreStories.isEmpty {
                                Text("No cached titles match this genre yet.")
                                    .fableFont(size: 14)
                                    .foregroundColor(FableTheme.textMuted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                            }

                            VStack(spacing: 12) {
                                ForEach(genreStories) { story in
                                    HStack(alignment: .top, spacing: 10) {
                                        Button {
                                            selectedStoryToRead = story
                                        } label: {
                                            HStack(alignment: .top, spacing: 14) {
                                                FableImageView(name: story.effectiveCoverImage, title: story.title, placeholderIcon: "book")
                                                    .frame(width: 72, height: 90)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                                VStack(alignment: .leading, spacing: 5) {
                                                    HStack(spacing: 4) {
                                                        Text(story.contentFormat.displayName.uppercased())
                                                            .fableFont(size: 8, weight: .bold)
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 2)
                                                            .background(story.contentFormat == .manga ? FableTheme.brandPrimary.opacity(0.12) : FableTheme.surfaceVariant)
                                                            .foregroundColor(story.contentFormat == .manga ? FableTheme.brandPrimary : FableTheme.textSecondary)
                                                            .clipShape(Capsule())

                                                        Text(story.badgeText ?? story.genre.rawValue.uppercased())
                                                            .fableFont(size: 9, weight: .bold)
                                                            .tracking(0.6)
                                                            .foregroundColor(FableTheme.brandPrimary)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(FableTheme.surface)
                                                            .clipShape(Capsule())
                                                    }

                                                    Text(story.title)
                                                        .fableFont(size: 16, weight: .bold)
                                                        .foregroundColor(FableTheme.textPrimary)
                                                        .lineLimit(1)

                                                    Text(story.excerpt)
                                                        .fableFont(size: 12, weight: .regular)
                                                        .foregroundColor(FableTheme.textPrimary.opacity(0.75))
                                                        .lineLimit(2)
                                                        .lineSpacing(2)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            store.toggleBookmark(for: story)
                                        } label: {
                                            Image(systemName: story.isBookmarked ? "bookmark.fill" : "bookmark")
                                                .fableFont(size: 12)
                                                .foregroundColor(story.isBookmarked ? FableTheme.brandPrimary : FableTheme.textMuted)
                                                .padding(6)
                                        }
                                        .accessibilityLabel(story.isBookmarked ? "Remove bookmark" : "Bookmark story")
                                    }
                                    .padding(14)
                                    .background(FableTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            let followed = UserDefaults.standard.stringArray(forKey: "fable_followed_genres") ?? []
            isFollowing = followed.contains(genre.name)
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
    }
}
