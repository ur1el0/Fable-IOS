import SafariServices
import SwiftUI

public enum MangaReadingMode: String, CaseIterable, Identifiable {
    case webtoon = "Webtoon"
    case paged = "Paging"
    case rightToLeft = "Manga (RTL)"

    public var id: String { rawValue }
    public var iconName: String {
        switch self {
        case .webtoon: return "arrow.up.and.down"
        case .paged: return "arrow.left.and.right"
        case .rightToLeft: return "arrow.right.to.line"
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
    @State private var isShowingPublisherReader: Bool = false
    @State private var isInvertedColor: Bool = false

    private enum ReaderTapZone {
        case left
        case center
        case right
    }

    public init(story: Story) {
        self.story = story
    }

    private var currentChapter: Chapter? {
        if chapters.indices.contains(currentChapterIndex) {
            return chapters[currentChapterIndex]
        }
        return nil
    }

    private var externalChapterURL: URL? {
        currentChapter?.externalSourceURL
    }

    private var externalPublisherName: String {
        guard let url = externalChapterURL, let host = url.host?.lowercased() else {
            return "Official Publisher"
        }
        if host.contains("manga-up") {
            return "Manga UP (Square Enix)"
        } else if host.contains("mangaplus") {
            return "MANGA Plus (Shueisha)"
        } else if host.contains("viz.com") {
            return "VIZ Media"
        } else if host.contains("kodansha") {
            return "Kodansha"
        } else if host.contains("webtoons") {
            return "WEBTOON"
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    private var activePageUrls: [String] {
        currentChapter?.pageUrls ?? []
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
                if let externalURL = externalChapterURL {
                    VStack(spacing: 20) {
                        FableImageView(
                            name: story.coverImageUrl,
                            title: story.title,
                            placeholderIcon: "book.pages",
                            contentMode: .fill
                        )
                        .frame(width: 140, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.6), radius: 16, x: 0, y: 8)

                        VStack(spacing: 8) {
                            Text(currentChapter?.title ?? "Official Chapter")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)

                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(FableTheme.brandPrimary)
                                Text("Official Licensed Release")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(FableTheme.brandPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(FableTheme.brandPrimary.opacity(0.15))
                            .clipShape(Capsule())

                            Text("This chapter is licensed and published by \(externalPublisherName). Read the official release here in Fable.")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        Button {
                            isShowingPublisherReader = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Read in Fable")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(FableTheme.brandPrimary)
                            .clipShape(Capsule())
                            .shadow(color: FableTheme.brandPrimary.opacity(0.4), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Read chapter on \(externalPublisherName) in Fable")
                        .accessibilityHint("Opens the official publisher in an in-app browser.")
                        .sheet(isPresented: $isShowingPublisherReader) {
                            InAppPublisherBrowser(url: externalURL)
                                .ignoresSafeArea()
                        }
                    }
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 16) {
                        FableImageView(
                            name: story.coverImageUrl,
                            title: story.title,
                            placeholderIcon: "photo.stack",
                            contentMode: .fill
                        )
                        .frame(width: 120, height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )

                        Text("No pages available")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("This manga chapter has no published image panels yet.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            } else {
                GeometryReader { geo in
                    ZStack {
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
                                // Horizontal Page Flip (Paging LTR or RTL)
                                TabView(selection: $currentPageIndex) {
                                    ForEach(Array(activePageUrls.enumerated()), id: \.offset) { index, urlString in
                                        MangaPageView(urlString: urlString, pageNumber: index + 1)
                                            .tag(index)
                                    }
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                .environment(\.layoutDirection, readingMode == .rightToLeft ? .rightToLeft : .leftToRight)
                            }
                        }
                        .applyColorInvert(isInvertedColor)
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

                        // Tachiyomi 3-Zone Tap Navigation Overlay (Active in Paged Modes)
                        if readingMode != .webtoon {
                            HStack(spacing: 0) {
                                // Left 30% Zone (Prev in LTR; Next in RTL)
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleTapZone(.left)
                                    }
                                    .frame(width: geo.size.width * 0.30)

                                // Center 40% Zone (Menu Toggle)
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleTapZone(.center)
                                    }
                                    .frame(width: geo.size.width * 0.40)

                                // Right 30% Zone (Next in LTR; Prev in RTL)
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleTapZone(.right)
                                    }
                                    .frame(width: geo.size.width * 0.30)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }

            // Minimalist Overlay Floating Chrome
            if isChromeVisible {
                VStack(spacing: 0) {
                    // Floating Top Navigation Bar
                    HStack(alignment: .center, spacing: 12) {
                        Button(action: {
                            FableHaptics.light()
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Circle())
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(story.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if let chapter = currentChapter {
                                Text(chapter.title.isEmpty ? "Chapter \(chapter.chapterNumber)" : chapter.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // Ink Inversion (Night Contrast Filter)
                        Button(action: {
                            if store.hapticFeedback {
                                HapticManager.selection()
                            }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isInvertedColor.toggle()
                            }
                        }) {
                            Image(systemName: isInvertedColor ? "circle.righthalf.filled.inverse" : "circle.righthalf.filled")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isInvertedColor ? FableTheme.brandPrimary : .white)
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Circle())
                        }

                        // Mode Selector Menu (Webtoon vs Paging vs RTL)
                        Menu {
                            ForEach(MangaReadingMode.allCases) { mode in
                                Button(action: {
                                    if store.hapticFeedback {
                                        HapticManager.selection()
                                    }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        readingMode = mode
                                    }
                                }) {
                                    HStack {
                                        Label(mode.rawValue, systemImage: mode.iconName)
                                        if readingMode == mode {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: readingMode.iconName)
                                    .font(.system(size: 11, weight: .bold))
                                Text(readingMode.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.16))
                            .clipShape(Capsule())
                        }

                        // Chapter List Selector
                        if chapters.count > 1 {
                            Button(action: {
                                if store.hapticFeedback {
                                    HapticManager.selection()
                                }
                                isShowingChapterSheet = true
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 38)
                                    .background(Color.white.opacity(0.14))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                    .padding(.bottom, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.9), Color.black.opacity(0.4), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Spacer()

                    // Minimalist Bottom Scrubber Chrome
                    VStack(spacing: 12) {
                        // Interactive Page Scrubber Slider (Tachiyomi-style scrubber)
                        if activePageUrls.count > 1 {
                            HStack(spacing: 12) {
                                Text("\(currentPageIndex + 1)")
                                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                                    .frame(width: 32, alignment: .trailing)

                                Slider(
                                    value: Binding(
                                        get: { Double(currentPageIndex) },
                                        set: { newVal in
                                            let rounded = Int(newVal.rounded())
                                            if rounded != currentPageIndex && activePageUrls.indices.contains(rounded) {
                                                currentPageIndex = rounded
                                                if store.hapticFeedback {
                                                    HapticManager.selection()
                                                }
                                            }
                                        }
                                    ),
                                    in: 0...Double(max(1, activePageUrls.count - 1)),
                                    step: 1
                                )
                                .tint(FableTheme.brandPrimary)

                                Text("\(activePageUrls.count)")
                                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 32, alignment: .leading)
                            }
                            .padding(.horizontal, 24)
                        }

                        HStack {
                            // Prev Chapter
                            Button(action: {
                                if currentChapterIndex > 0 {
                                    if store.hapticFeedback {
                                        HapticManager.impact(style: .light)
                                    }
                                    currentChapterIndex -= 1
                                    currentPageIndex = 0
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "backward.end.fill")
                                        .font(.system(size: 10))
                                    Text("Prev")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(currentChapterIndex > 0 ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(currentChapterIndex > 0 ? 0.12 : 0.04))
                                .clipShape(Capsule())
                            }
                            .disabled(currentChapterIndex == 0)

                            Spacer()

                            // Page Counter or External Release Tag
                            if !activePageUrls.isEmpty {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(FableTheme.brandPrimary)
                                        .frame(width: 5, height: 5)
                                    Text("\(readingMode.rawValue.uppercased()) • \(currentPageIndex + 1) / \(activePageUrls.count)")
                                        .font(.system(size: 11, weight: .heavy))
                                        .tracking(0.5)
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.65))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                                )
                                .clipShape(Capsule())
                            } else if externalChapterURL != nil {
                                Text("OFFICIAL RELEASE")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.brandPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(FableTheme.brandPrimary.opacity(0.18))
                                    .clipShape(Capsule())
                            }

                            Spacer()

                            // Next Chapter
                            Button(action: {
                                if currentChapterIndex < chapters.count - 1 {
                                    if store.hapticFeedback {
                                        HapticManager.impact(style: .light)
                                    }
                                    currentChapterIndex += 1
                                    currentPageIndex = 0
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("Next")
                                        .font(.system(size: 12, weight: .semibold))
                                    Image(systemName: "forward.end.fill")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(currentChapterIndex < chapters.count - 1 ? .white : .white.opacity(0.3))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(currentChapterIndex < chapters.count - 1 ? 0.12 : 0.04))
                                .clipShape(Capsule())
                            }
                            .disabled(currentChapterIndex >= chapters.count - 1)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 38)
                    .padding(.top, 18)
                    .background(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.5), Color.black.opacity(0.9)],
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
            persistReadingProgress(chapterIndex: newIndex, pageIndex: currentPageIndex)
        }
        .onChange(of: currentPageIndex) { _, newPage in
            persistReadingProgress(chapterIndex: currentChapterIndex, pageIndex: newPage)
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
                                if chap.pageUrls.isEmpty, chap.externalSourceURL != nil {
                                    Text("Official Release")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(FableTheme.brandPrimary)
                                } else {
                                    Text("\(chap.pageUrls.count) panels")
                                        .font(.system(size: 12))
                                        .foregroundColor(FableTheme.textMuted)
                                }
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
    private func handleTapZone(_ zone: ReaderTapZone) {
        switch zone {
        case .left:
            if readingMode == .rightToLeft {
                advancePage()
            } else {
                backtrackPage()
            }
        case .right:
            if readingMode == .rightToLeft {
                backtrackPage()
            } else {
                advancePage()
            }
        case .center:
            if store.hapticFeedback {
                HapticManager.selection()
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                isChromeVisible.toggle()
            }
        }
    }

    @MainActor
    private func advancePage() {
        if currentPageIndex < activePageUrls.count - 1 {
            if store.hapticFeedback {
                HapticManager.impact(style: .light)
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                currentPageIndex += 1
            }
        } else if currentChapterIndex < chapters.count - 1 {
            if store.hapticFeedback {
                HapticManager.impact(style: .medium)
            }
            currentChapterIndex += 1
            currentPageIndex = 0
        }
    }

    @MainActor
    private func backtrackPage() {
        if currentPageIndex > 0 {
            if store.hapticFeedback {
                HapticManager.impact(style: .light)
            }
            withAnimation(.easeInOut(duration: 0.18)) {
                currentPageIndex -= 1
            }
        } else if currentChapterIndex > 0 {
            if store.hapticFeedback {
                HapticManager.impact(style: .medium)
            }
            currentChapterIndex -= 1
            currentPageIndex = 0
        }
    }

    @MainActor
    private func loadMangaChapters() async {
        let hasReadableChapter = story.chapters?.contains {
            !$0.pageUrls.isEmpty || $0.externalSourceURL != nil
        } ?? false
        if let existing = story.chapters, !existing.isEmpty, hasReadableChapter {
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
                pageUrls: []
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
        if progress.currentPage > 1 {
            let restoredPage = progress.currentPage - 1
            if activePageUrls.indices.contains(restoredPage) {
                currentPageIndex = restoredPage
            }
        }
    }

    @MainActor
    private func persistReadingProgress(chapterIndex: Int, pageIndex: Int) {
        guard chapters.indices.contains(chapterIndex) else { return }
        let chapter = chapters[chapterIndex]
        let totalPagesInChap = max(1, activePageUrls.count)
        let pageNumber = min(totalPagesInChap, max(1, pageIndex + 1))

        store.updateMangaProgress(
            for: story.id,
            page: pageNumber,
            totalPages: totalPagesInChap,
            chapterIndex: chapterIndex,
            totalChapters: max(1, chapters.count),
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

private extension View {
    @ViewBuilder
    func applyColorInvert(_ active: Bool) -> some View {
        if active {
            self.colorInvert()
        } else {
            self
        }
    }
}

private struct InAppPublisherBrowser: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let browser = SFSafariViewController(url: url)
        browser.dismissButtonStyle = .done
        return browser
    }

    func updateUIViewController(_ browser: SFSafariViewController, context: Context) {}
}

