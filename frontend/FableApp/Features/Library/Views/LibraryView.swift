import SwiftUI

public struct LibraryView: View {
    @EnvironmentObject var store: StoryStore
    @ObservedObject private var auth = AuthManager.shared
    
    @State private var selectedFilter: String = "All"
    @State private var selectedStoryToRead: Story?
    @State private var isShowingProfileSheet: Bool = false
    
    var filterCategories: [String] { ["All"] + store.genres.map(\.name) }
    
    var filteredRecentStories: [Story] {
        if selectedFilter == "Manga" {
            let mangaStories = store.stories.filter { $0.contentFormat == .manga || $0.genre == .manga }
            var seen = Set<String>()
            var uniqueManga: [Story] = []
            for item in mangaStories {
                let key = item.providerId ?? item.id.uuidString
                if !seen.contains(key) {
                    seen.insert(key)
                    uniqueManga.append(item)
                }
            }
            return uniqueManga.sorted { first, second in
                let firstDirect = first.badgeText == "DIRECT PANELS" ? 1 : 0
                let secondDirect = second.badgeText == "DIRECT PANELS" ? 1 : 0
                if firstDirect != secondDirect {
                    return firstDirect > secondDirect
                }
                return false
            }
        }
        let validStories = store.stories.filter { !PersistenceService.legacyDemoStoryIds.contains($0.id) }
        if selectedFilter == "All" {
            return validStories
        } else {
            return validStories.filter { store.storyMatchesCategory($0, category: selectedFilter) }
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
                                FableImageView(name: auth.currentSession?.avatarName, placeholderIcon: "person.crop.circle")
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
                                        FableHaptics.selection()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
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
                                            .shadow(color: selectedFilter == cat ? FableTheme.brandPrimary.opacity(0.25) : Color.clear, radius: 4, y: 2)
                                            .contentShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                        .zIndex(2)
                        
                        if store.stories.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 32))
                                    .foregroundColor(FableTheme.textMuted)
                                Text("Your library is empty")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(FableTheme.textPrimary)
                                Text(store.isBackendReachable
                                     ? "No titles are available from the live catalog yet."
                                     : "Connect to the catalog to discover books. Previously saved books will remain available offline.")
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(FableTheme.textMuted)
                                Button("Retry catalog sync") {
                                    Task { await store.syncWithCloudBackend() }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(FableTheme.brandPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .background(FableTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                        }

                        // Featured Hero Card
                        if let featuredStory = (selectedFilter == "All" ? (filteredRecentStories.first(where: { $0.isTaleOfTheDay }) ?? filteredRecentStories.first) : filteredRecentStories.first) {
                            VStack(alignment: .leading, spacing: 0) {
                                ZStack(alignment: .top) {
                                    Button {
                                        selectedStoryToRead = featuredStory
                                    } label: {
                                        ZStack(alignment: .bottom) {
                                            FableImageView(name: featuredStory.effectiveCoverImage, placeholderIcon: "square.stack")
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 220)
                                                .clipped()

                                            // Elegant gradient scrim for contrast
                                            LinearGradient(
                                                colors: [Color.clear, Color.black.opacity(0.45)],
                                                startPoint: .center,
                                                endPoint: .bottom
                                            )
                                        }
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 220)
                                        .clipped()
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    HStack {
                                        if featuredStory.contentFormat == .manga {
                                            storyBadge(for: featuredStory)
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 8, weight: .bold))
                                                Text("FEATURED TITLE")
                                                    .font(.system(size: 10, weight: .heavy))
                                                    .tracking(1.0)
                                            }
                                            .foregroundColor(FableTheme.brandPrimary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.white.opacity(0.95))
                                            .clipShape(Capsule())
                                            .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
                                        }

                                        Spacer()

                                        Button {
                                            FableHaptics.light()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                store.toggleBookmark(for: featuredStory)
                                            }
                                        } label: {
                                            Image(systemName: featuredStory.isBookmarked ? "bookmark.fill" : "bookmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(featuredStory.isBookmarked ? FableTheme.brandPrimary : FableTheme.textPrimary)
                                                .padding(8)
                                                .background(Color.white.opacity(0.95))
                                                .clipShape(Circle())
                                                .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                                        }
                                        .accessibilityLabel(featuredStory.isBookmarked ? "Remove bookmark" : "Bookmark story")
                                    }
                                    .padding(14)
                                }

                                Button {
                                    selectedStoryToRead = featuredStory
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 6) {
                                            Text(featuredStory.author)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(FableTheme.brandPrimary)
                                            Text("•")
                                                .foregroundColor(FableTheme.textMuted)
                                            HStack(spacing: 3) {
                                                Image(systemName: "clock")
                                                    .font(.system(size: 10))
                                                Text("\(featuredStory.readingTimeMinutes) min read")
                                                    .font(.system(size: 13, weight: .regular))
                                            }
                                            .foregroundColor(FableTheme.textMuted)
                                        }

                                        Text(featuredStory.title)
                                            .font(.system(size: 22, weight: .bold, design: .default))
                                            .foregroundColor(FableTheme.textPrimary)

                                        Text(featuredStory.excerpt)
                                            .font(.system(size: 14, weight: .regular, design: .default))
                                            .foregroundColor(FableTheme.textSecondary)
                                            .lineSpacing(3)
                                            .lineLimit(3)
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(FableTheme.cardBackground)
                                }
                                .buttonStyle(.plain)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(FableTheme.divider.opacity(0.8), lineWidth: 0.8)
                            )
                            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
                            .padding(.horizontal, 20)
                        }

                        // Continue Reading Section
                        if let inProgressStory = store.stories.first(where: { !PersistenceService.legacyDemoStoryIds.contains($0.id) && $0.progressPercent > 0 && !$0.isCompleted }) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Continue Reading")
                                        .font(.system(size: 18, weight: .bold, design: .default))
                                        .foregroundColor(FableTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Button("See All") {
                                        FableHaptics.light()
                                        store.selectedTab = .shelf
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(FableTheme.brandPrimary)
                                }
                                .padding(.horizontal, 20)
                                
                                Button(action: {
                                    FableHaptics.medium()
                                    selectedStoryToRead = inProgressStory
                                }) {
                                    HStack(spacing: 14) {
                                        FableImageView(name: inProgressStory.effectiveCoverImage ?? inProgressStory.effectiveHeroImage, placeholderIcon: "square.stack")
                                            .frame(width: 64, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(FableTheme.divider.opacity(0.8), lineWidth: 0.8)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack(spacing: 6) {
                                                HStack(spacing: 4) {
                                                    Image(systemName: inProgressStory.contentFormat == .manga ? "photo.on.rectangle.angled" : "book.closed.fill")
                                                        .font(.system(size: 8))
                                                    Text(inProgressStory.contentFormat == .manga ? "MANGA" : "NOVEL")
                                                        .font(.system(size: 9, weight: .heavy))
                                                }
                                                .foregroundColor(FableTheme.brandPrimary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2.5)
                                                .background(FableTheme.brandPrimary.opacity(0.08))
                                                .clipShape(Capsule())
                                                
                                                Text(inProgressStory.author)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(FableTheme.textMuted)
                                                    .lineLimit(1)
                                            }
                                            
                                            Text(inProgressStory.title)
                                                .font(.system(size: 15, weight: .bold, design: .default))
                                                .foregroundColor(FableTheme.textPrimary)
                                                .lineLimit(1)
                                            
                                            // Refined Progress Bar with subtle gradient
                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    Capsule()
                                                        .fill(Color.gray.opacity(0.12))
                                                        .frame(height: 5)
                                                    
                                                    Capsule()
                                                        .fill(
                                                            LinearGradient(
                                                                colors: [FableTheme.brandPrimary, FableTheme.brandAccent],
                                                                startPoint: .leading,
                                                                endPoint: .trailing
                                                            )
                                                        )
                                                        .frame(width: max(4, geo.size.width * CGFloat(inProgressStory.progressPercent) / 100.0), height: 5)
                                                }
                                            }
                                            .frame(height: 5)
                                            .padding(.top, 2)
                                            
                                            if let chapNum = inProgressStory.lastReadChapterNumber {
                                                Text("\(inProgressStory.progressPercent)% complete • Ch. \(chapNum) • Page \(inProgressStory.currentPage) of \(inProgressStory.totalPages)")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(FableTheme.textMuted)
                                            } else {
                                                Text("\(inProgressStory.progressPercent)% complete • Page \(inProgressStory.currentPage) of \(inProgressStory.totalPages)")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(FableTheme.textMuted)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(FableTheme.brandPrimary)
                                            .padding(11)
                                            .background(FableTheme.brandPrimary.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .padding(14)
                                    .background(FableTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(FableTheme.divider.opacity(0.8), lineWidth: 0.8)
                                    )
                                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
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
                                    HStack(alignment: .top, spacing: 10) {
                                        Button {
                                            selectedStoryToRead = story
                                        } label: {
                                            HStack(alignment: .top, spacing: 14) {
                                                FableImageView(name: story.effectiveCoverImage, placeholderIcon: "square.stack")
                                                    .frame(width: 72, height: 96)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .stroke(FableTheme.divider.opacity(0.6), lineWidth: 0.6)
                                                    )

                                                VStack(alignment: .leading, spacing: 5) {
                                                    storyBadge(for: story)

                                                    Text(story.title)
                                                        .font(.system(size: 16, weight: .bold, design: .default))
                                                        .foregroundColor(FableTheme.textPrimary)
                                                        .lineLimit(1)

                                                    Text(story.author)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(FableTheme.textMuted)
                                                        .lineLimit(1)

                                                    Text(story.excerpt)
                                                        .font(.system(size: 12, weight: .regular))
                                                        .foregroundColor(FableTheme.textSecondary)
                                                        .lineLimit(2)
                                                        .lineSpacing(2)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            FableHaptics.light()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                store.toggleBookmark(for: story)
                                            }
                                        } label: {
                                            Image(systemName: story.isBookmarked ? "bookmark.fill" : "bookmark")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(story.isBookmarked ? FableTheme.brandPrimary : FableTheme.textMuted)
                                                .padding(8)
                                                .background(story.isBookmarked ? FableTheme.brandPrimary.opacity(0.1) : Color.clear)
                                                .clipShape(Circle())
                                        }
                                        .accessibilityLabel(story.isBookmarked ? "Remove bookmark" : "Bookmark story")
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(FableTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(FableTheme.divider.opacity(0.8), lineWidth: 0.8)
                                    )
                                    .shadow(color: Color.black.opacity(0.035), radius: 8, y: 2)
                                    .padding(.horizontal, 20)
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
            .onAppear {
                if let filter = ProcessInfo.processInfo.environment["AUTO_SELECT_FILTER"], !filter.isEmpty {
                    selectedFilter = filter
                }
                Task {
                    await store.fetchMangaPublicStories()
                }
                if let targetTitle = ProcessInfo.processInfo.environment["AUTO_OPEN_MANGA"], !targetTitle.isEmpty {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        if let match = store.stories.first(where: { $0.title.localizedCaseInsensitiveContains(targetTitle) }) {
                            selectedStoryToRead = match
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func storyBadge(for story: Story) -> some View {
        if story.contentFormat == .manga {
            if story.badgeText == "DIRECT PANELS" {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 8))
                    Text("DIRECT PANELS")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(red: 0.12, green: 0.58, blue: 0.32))
                .clipShape(Capsule())
            } else if story.badgeText == "OFFICIAL LINK" {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .bold))
                    Text("OFFICIAL LINK")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                }
                .foregroundColor(Color.orange)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 8))
                    Text("MANGA")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.5)
                }
                .foregroundColor(FableTheme.brandPrimary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(FableTheme.surface)
                .clipShape(Capsule())
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 8))
                Text(story.sourceProvider == .standardEbooks ? "STANDARD EBOOKS" : story.genre.rawValue.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.5)
            }
            .foregroundColor(FableTheme.brandPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(FableTheme.surface)
            .clipShape(Capsule())
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(StoryStore())
}
