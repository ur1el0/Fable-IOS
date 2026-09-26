import SwiftUI

public enum MangaReadingMode: String, CaseIterable, Identifiable {
    case webtoon = "Webtoon"
    case paged = "Paging"

    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .webtoon: return "arrow.up.and.down"
        case .paged: return "arrow.left.and.right"
        }
    }
}

public struct MangaReaderView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss

    let story: Story

    @State private var chapters: [Chapter] = []
    @State private var currentChapterIndex: Int = 0
    @State private var currentPageIndex: Int = 0
    @State private var readingMode: MangaReadingMode = .webtoon
    @State private var isChromeVisible: Bool = true
    @State private var isLoading: Bool = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var isShowingChapterSheet: Bool = false

    public init(story: Story) {
        self.story = story
    }

    private var currentChapter: Chapter? {
        if chapters.indices.contains(currentChapterIndex) {
            return chapters[currentChapterIndex]
        }
        return nil
    }

    private var activePageUrls: [String] {
        if let chapter = currentChapter, !chapter.pageUrls.isEmpty {
            return chapter.pageUrls
        }
        if let firstChap = story.chapters?.first, !firstChap.pageUrls.isEmpty {
            return firstChap.pageUrls
        }
        // Fallback to story covers
        return [story.coverImageUrl, story.effectiveCoverImage].compactMap { $0 }
    }

    public var body: some View {
        ZStack {
            // High-contrast cinema black background for maximum art pop
            Color.black.ignoresSafeArea()

            // Main Content Area
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(FableTheme.brandPrimary)
                    Text("Loading panels...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.gray)
                }
            } else if activePageUrls.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 44))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No pages available")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("This manga chapter has no published image panels yet.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                Group {
                    if readingMode == .webtoon {
                        // Vertical Webtoon Continuous Scroll
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(activePageUrls.enumerated()), id: \.offset) { index, urlString in
                                    MangaPageView(urlString: urlString, pageNumber: index + 1)
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isChromeVisible.toggle()
                                            }
                                        }
                                }
                            }
                            .padding(.bottom, 80)
                        }
                    } else {
                        // Horizontal Page Flip (Paging)
                        TabView(selection: $currentPageIndex) {
                            ForEach(Array(activePageUrls.enumerated()), id: \.offset) { index, urlString in
                                MangaPageView(urlString: urlString, pageNumber: index + 1)
                                    .tag(index)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isChromeVisible.toggle()
                                        }
                                    }
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                }
                .scaleEffect(zoomScale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { val in
                            zoomScale = max(1.0, min(3.0, val))
                        }
                        .onEnded { _ in
                            withAnimation(.spring()) {
                                zoomScale = 1.0
                            }
                        }
                )
            }

            // Minimalist Overlay Top Chrome
            if isChromeVisible {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(story.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if let chapter = currentChapter {
                                Text(chapter.title.isEmpty ? "Chapter \(chapter.chapterNumber)" : chapter.title)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.leading, 6)

                        Spacer()

                        // Mode Selector (Webtoon vs Paging)
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                readingMode = (readingMode == .webtoon) ? .paged : .webtoon
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: readingMode.iconName)
                                    .font(.system(size: 12, weight: .bold))
                                Text(readingMode.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                        }

                        // Chapter List Selector
                        if chapters.count > 1 {
                            Button(action: {
                                isShowingChapterSheet = true
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                    .padding(.bottom, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.85), Color.black.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Spacer()

                    // Minimalist Bottom Scrubber Chrome
                    VStack(spacing: 8) {
                        HStack {
                            // Prev Chapter
                            Button(action: {
                                if currentChapterIndex > 0 {
                                    currentChapterIndex -= 1
                                    currentPageIndex = 0
                                }
                            }) {
                                Image(systemName: "backward.end.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(currentChapterIndex > 0 ? .white : .gray.opacity(0.4))
                            }
                            .disabled(currentChapterIndex == 0)

                            Spacer()

                            // Page Counter
                            Text("PAGE \(currentPageIndex + 1) OF \(max(1, activePageUrls.count))")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(1.0)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())

                            Spacer()

                            // Next Chapter
                            Button(action: {
                                if currentChapterIndex < chapters.count - 1 {
                                    currentChapterIndex += 1
                                    currentPageIndex = 0
                                }
                            }) {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(currentChapterIndex < chapters.count - 1 ? .white : .gray.opacity(0.4))
                            }
                            .disabled(currentChapterIndex >= chapters.count - 1)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 36)
                    .padding(.top, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.0), Color.black.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .task {
            await loadMangaChapters()
        }
        .onChange(of: currentChapterIndex) { _, newIndex in
            prefetchPanels(around: newIndex)
            persistCurrentChapter(at: newIndex)
        }
        .sheet(isPresented: $isShowingChapterSheet) {
            NavigationStack {
                List(Array(chapters.enumerated()), id: \.element.id) { index, chap in
                    Button(action: {
                        currentChapterIndex = index
                        currentPageIndex = 0
                        isShowingChapterSheet = false
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chap.title.isEmpty ? "Chapter \(chap.chapterNumber)" : chap.title)
                                    .font(.system(size: 15, weight: index == currentChapterIndex ? .bold : .medium))
                                    .foregroundColor(index == currentChapterIndex ? FableTheme.brandPrimary : FableTheme.textPrimary)
                                Text("\(chap.pageUrls.count) panels")
                                    .font(.system(size: 12))
                                    .foregroundColor(FableTheme.textMuted)
                            }
                            Spacer()
                            if index == currentChapterIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(FableTheme.brandPrimary)
                            }
                        }
                    }
                }
                .navigationTitle("Chapters")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @MainActor
    private func loadMangaChapters() async {
        if let existing = story.chapters, !existing.isEmpty {
            self.chapters = existing
            restoreSavedChapter()
            prefetchPanels(around: currentChapterIndex)
            return
        }
        isLoading = true
        let fetched = await store.fetchChapters(for: story)
        if !fetched.isEmpty {
            self.chapters = fetched
        } else {
            // Synthesize single chapter with story pageUrls if present
            let single = Chapter(
                storyId: story.id,
                chapterNumber: 1,
                title: story.title,
                content: "",
                wordCount: 0,
                pageUrls: [
                    story.coverImageUrl,
                    "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?q=80&w=800&auto=format&fit=crop",
                    "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=800&auto=format&fit=crop"
                ].compactMap { $0 }
            )
            self.chapters = [single]
        }
        isLoading = false
        restoreSavedChapter()
        prefetchPanels(around: currentChapterIndex)
    }

    @MainActor
    private func restoreSavedChapter() {
        let progress = store.stories.first(where: { $0.id == story.id }) ?? story
        if let chapterId = progress.lastReadChapterId,
           let savedIndex = chapters.firstIndex(where: { $0.id.uuidString == chapterId }) {
            currentChapterIndex = savedIndex
        } else if let chapterNumber = progress.lastReadChapterNumber,
                  let savedIndex = chapters.firstIndex(where: { $0.chapterNumber == chapterNumber }) {
            currentChapterIndex = savedIndex
        }
    }

    @MainActor
    private func persistCurrentChapter(at index: Int) {
        guard chapters.indices.contains(index) else { return }
        let chapter = chapters[index]
        store.updateReadingProgress(
            for: story.id,
            chapterId: chapter.id.uuidString,
            chapterNumber: chapter.chapterNumber
        )
    }

    @MainActor
    private func prefetchPanels(around chapterIndex: Int) {
        let chapterIndices = [chapterIndex, chapterIndex + 1].filter {
            chapters.indices.contains($0)
        }
        let urls = chapterIndices.flatMap { index in
            chapters[index].pageUrls.compactMap { URL(string: $0) }
        }

        guard !urls.isEmpty else {
            return
        }

        Task { @MainActor in
            await DiskImageCache.shared.prefetch(urls: urls)
        }
    }
}

@MainActor
private struct MangaPageView: View {
    let urlString: String
    let pageNumber: Int

    private var imageURL: URL? {
        guard
            let url = URL(string: urlString),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return nil
        }

        return url
    }

    var body: some View {
        ZStack {
            Color.black

            if let imageURL {
                FableRemoteImageView(url: imageURL, contentMode: .fit) {
                    placeholder
                }
                .frame(maxWidth: .infinity)
                .clipped()
            } else {
                placeholder
            }
        }
        .clipped()
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 28))
                .foregroundColor(.gray)
            Text("Panel \(pageNumber) unavailable")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}
