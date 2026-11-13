import SwiftUI

public enum ReaderPassageMatcher {
    public static func paragraphs(from text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public static func chapterIndex(for annotation: Annotation, in chapters: [Chapter]) -> Int? {
        guard !chapters.isEmpty else { return nil }
        if let chapterNumber = annotation.chapterNumber,
           let matchedIndex = chapters.firstIndex(where: { $0.chapterNumber == chapterNumber }) {
            return matchedIndex
        }
        let target = annotation.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return nil }
        return chapters.firstIndex { chapter in
            let normalized = chapter.content.replacingOccurrences(of: "\r\n", with: "\n")
            return normalized.contains(target)
        }
    }

    public static func paragraphIndex(for annotation: Annotation, in paragraphs: [String]) -> Int? {
        guard !paragraphs.isEmpty else { return nil }
        let target = annotation.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !target.isEmpty,
           let matchedIndex = paragraphs.firstIndex(where: { para in
               para.contains(target) || target.contains(para)
           }) {
            return matchedIndex
        }

        if annotation.utf16StartOffset >= 0 {
            var runningOffset = 0
            for (index, para) in paragraphs.enumerated() {
                let endOffset = runningOffset + para.utf16.count
                if annotation.utf16StartOffset <= endOffset {
                    return index
                }
                runningOffset = endOffset + 2 // "\n\n" separator
            }
        }
        return nil
    }

    public static func pageNumber(for annotation: Annotation, in pages: [String]) -> Int? {
        guard !pages.isEmpty else { return nil }
        let target = annotation.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !target.isEmpty,
           let matchedIndex = pages.firstIndex(where: { page in
               page.contains(target) || target.contains(page)
           }) {
            return matchedIndex + 1
        }

        if annotation.utf16StartOffset >= 0 {
            var runningOffset = 0
            for (index, page) in pages.enumerated() {
                let endOffset = runningOffset + page.utf16.count
                if annotation.utf16StartOffset <= endOffset {
                    return index + 1
                }
                runningOffset = endOffset + 2
            }
        }
        return nil
    }
}

public struct ReaderView: View {
    @EnvironmentObject var store: StoryStore
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var audioNarrator = AudioNarratorController.shared
    @StateObject private var pacingEngine = PacingEngine.shared
    
    let story: Story
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 5
    @State private var pages: [String] = []
    
    // Multi-Chapter Dynamic State
    @State private var chapters: [Chapter] = []
    @State private var currentChapterIndex: Int = 0
    @State private var isShowingChapterSheet: Bool = false
    @State private var isLoadingChapters: Bool = false
    @State private var chapterLoadError: String?
    @State private var isChromeVisible: Bool = true
    @State private var isRestoringScrollPosition: Bool = true
    @State private var scrollRestoreTrigger: Int = 0
    @State private var pendingTargetAnnotation: Annotation?
    @State private var pendingScrollParagraphId: String? = nil
    @State private var suppressNextPageTurnMetrics: Bool = false
    
    // Marginalia & Highlight Sheet State (Plan 02)
    @State private var editingAnnotation: Annotation? = nil
    @State private var selectedTextToAnnotate: String? = nil
    @State private var selectedHighlightColor: HighlightColor = .terracotta
    @State private var annotationNote: String = ""
    @State private var isPinToJournal: Bool = true
    @State private var isShowingAnnotationSheet: Bool = false
    @State private var sessionStartTime: Date = Date()
    
    public init(story: Story, initialTargetAnnotation: Annotation? = nil) {
        self.story = story
        _currentPage = State(initialValue: max(1, story.currentPage))
        _totalPages = State(initialValue: max(1, story.totalPages))
        _pendingTargetAnnotation = State(initialValue: initialTargetAnnotation)
    }
    
    private var activeChapter: Chapter? {
        chapters.indices.contains(currentChapterIndex) ? chapters[currentChapterIndex] : nil
    }
    
    private var activeChapterText: String {
        if let chap = activeChapter, chap.hasReadableText {
            return chap.content.replacingOccurrences(of: "\r\n", with: "\n")
        }
        return story.content.replacingOccurrences(of: "\r\n", with: "\n")
    }
    
    private var activeParagraphs: [String] {
        ReaderPassageMatcher.paragraphs(from: activeChapterText)
    }
    
    private var activeChapterTag: String {
        if let chap = activeChapter {
            let titleClean = chap.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return "CHAPTER \(chap.chapterNumber) • \(titleClean.uppercased())"
        }
        return "CHAPTER I • MANUSCRIPT"
    }
    
    private var currentStoryBookmarked: Bool {
        store.stories.first(where: { $0.id == story.id })?.isBookmarked ?? story.isBookmarked
    }
    
    private var readingProgressPercent: Int {
        let safeTotalChaps = max(1, chapters.count)
        let safeTotalPages = max(1, totalPages)
        let safePage = min(safeTotalPages, max(1, currentPage))
        let safeChapIdx = min(safeTotalChaps - 1, max(0, currentChapterIndex))
        if safeTotalChaps > 1 {
            let fraction = (Double(safeChapIdx) / Double(safeTotalChaps))
                + ((Double(safePage) / Double(safeTotalPages)) * (1.0 / Double(safeTotalChaps)))
            return min(100, max(1, Int((fraction * 100.0).rounded())))
        }
        return min(100, max(1, Int(((Double(safePage) / Double(safeTotalPages)) * 100.0).rounded())))
    }
    
    private var dynamicMinutesRemaining: Int {
        let remainingWords: Int
        if pages.isEmpty {
            remainingWords = (activeChapter?.wordCount ?? (story.readTimeMinutes * 180))
        } else {
            let unreadPages = pages.dropFirst(max(0, currentPage - 1))
            remainingWords = unreadPages.reduce(0) { $0 + PacingEngine.countWords(in: $1) }
        }
        return pacingEngine.estimatedMinutesRemaining(remainingWords: max(40, remainingWords))
    }
    
    public var body: some View {
        if story.contentFormat == .manga {
            MangaReaderView(story: story)
        } else {
            proseReaderBody
        }
    }

    private var proseReaderBody: some View {
        ZStack(alignment: .bottom) {
            // Background according to selected theme
            store.readerTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar (FIGMA.md Frame 2: 1:159)
                if isChromeVisible {
                    HStack(spacing: 12) {
                        Button(action: {
                            FableHaptics.light()
                            audioNarrator.stop()
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .fableFont(size: 15, weight: .bold)
                                .foregroundColor(store.readerTheme.textColor)
                                .frame(width: 40, height: 40)
                                .background(store.readerTheme.textColor.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Close reader")
                        
                        Spacer()
                        
                        // Chapter / Folio Tag (Interactive TOC Trigger)
                        Button(action: {
                            FableHaptics.selection()
                            isShowingChapterSheet = true
                        }) {
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(activeChapterTag)
                                        .fableFont(size: 10, weight: .bold)
                                        .tracking(1.0)
                                        .foregroundColor(FableTheme.brandPrimary)
                                        .lineLimit(1)
                                    
                                    if !chapters.isEmpty {
                                        Image(systemName: "chevron.down")
                                            .fableFont(size: 8, weight: .bold)
                                            .foregroundColor(FableTheme.brandPrimary)
                                    }
                                }
                                
                                Text(story.title)
                                    .fableFont(size: 13, weight: .medium, design: .serif)
                                    .foregroundColor(store.readerTheme.textColor.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Chapters and table of contents")
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            // Table of Contents Sheet Button
                            Button(action: {
                                FableHaptics.selection()
                                isShowingChapterSheet = true
                            }) {
                                Image(systemName: "list.bullet.rectangle")
                                    .fableFont(size: 14, weight: .semibold)
                                    .foregroundColor(store.readerTheme.textColor)
                                    .frame(width: 40, height: 40)
                                    .background(store.readerTheme.textColor.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Table of contents")
                            
                            // Oral Folklore Audio Synthesizer Toggle (Plan 04)
                            Button(action: {
                                FableHaptics.medium()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    audioNarrator.togglePlayback(for: story, chapter: activeChapter)
                                }
                            }) {
                                Image(systemName: audioNarrator.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                                    .fableFont(size: 14, weight: .semibold)
                                    .foregroundColor(audioNarrator.isPlaying ? FableTheme.brandPrimary : store.readerTheme.textColor)
                                    .frame(width: 40, height: 40)
                                    .background(audioNarrator.isPlaying ? FableTheme.brandPrimary.opacity(0.15) : store.readerTheme.textColor.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel(audioNarrator.isPlaying ? "Pause narration" : "Start audio narration")
                            
                            // Bookmark Toggle
                            Button(action: {
                                FableHaptics.light()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    store.toggleBookmark(for: story)
                                }
                            }) {
                                Image(systemName: currentStoryBookmarked ? "bookmark.fill" : "bookmark")
                                    .fableFont(size: 14, weight: .semibold)
                                    .foregroundColor(currentStoryBookmarked ? FableTheme.brandPrimary : store.readerTheme.textColor)
                                    .frame(width: 40, height: 40)
                                    .background(currentStoryBookmarked ? FableTheme.brandPrimary.opacity(0.12) : store.readerTheme.textColor.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel(currentStoryBookmarked ? "Remove bookmark" : "Bookmark story")
                            
                            // Typography Options
                            Button(action: {
                                FableHaptics.selection()
                                store.isShowingDisplayOptions = true
                            }) {
                                Image(systemName: "textformat.size")
                                    .fableFont(size: 14, weight: .semibold)
                                    .foregroundColor(store.readerTheme.textColor)
                                    .frame(width: 40, height: 40)
                                    .background(store.readerTheme.textColor.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Reading appearance options")
                            
                            // Native Share Link
                            ShareLink(
                                item: "\(story.title) by \(story.author)\n\n\(story.synopsis)\n\nRead on Fable."
                            ) {
                                Image(systemName: "square.and.arrow.up")
                                    .fableFont(size: 14, weight: .semibold)
                                    .foregroundColor(store.readerTheme.textColor)
                                    .frame(width: 40, height: 40)
                                    .background(store.readerTheme.textColor.opacity(0.08))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Share story")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Active Spoken Audio Narration Banner (Plan 04)
                if audioNarrator.isPlaying || audioNarrator.isPaused {
                    HStack(spacing: 10) {
                        Image(systemName: audioNarrator.isPlaying ? "waveform" : "pause.fill")
                            .fableFont(size: 12, weight: .bold)
                            .foregroundColor(FableTheme.brandPrimary)
                        
                        Text(audioNarrator.isPlaying ? "Narrating Spoken Folklore" : "Audio Paused")
                            .fableFont(size: 12, weight: .semibold)
                            .foregroundColor(FableTheme.textPrimary)
                        
                        Spacer()
                        
                        // Speed multiplier button
                        Button(action: {
                            let nextRate: Float = audioNarrator.playbackRateMultiplier >= 1.25 ? 0.85 : (audioNarrator.playbackRateMultiplier + 0.2)
                            audioNarrator.setRateMultiplier(nextRate)
                        }) {
                            Text(String(format: "%.1fx", audioNarrator.playbackRateMultiplier))
                                .fableFont(size: 11, weight: .bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(FableTheme.brandPrimary.opacity(0.12))
                                .foregroundColor(FableTheme.brandPrimary)
                                .clipShape(Capsule())
                        }
                        
                        Button(action: {
                            audioNarrator.stop()
                        }) {
                            Image(systemName: "xmark")
                                .fableFont(size: 11, weight: .bold)
                                .foregroundColor(FableTheme.textMuted)
                                .padding(4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(FableTheme.surface)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Reading progress track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.12))
                            .frame(height: 2.5)
                        
                        Rectangle()
                            .fill(FableTheme.brandPrimary)
                            .frame(width: geo.size.width * CGFloat(readingProgressPercent) / 100.0, height: 2.5)
                            .animation(.easeInOut(duration: 0.2), value: readingProgressPercent)
                    }
                }
                .frame(height: 2.5)
                
                // Content Viewport: Paginated Mode vs Continuous Scroll Mode (Plan 03)
                if store.isPaginatedMode {
                    ZStack {
                        TabView(selection: $currentPage) {
                            ForEach(1...max(1, totalPages), id: \.self) { pageNum in
                                ScrollView(showsIndicators: false) {
                                    ZStack(alignment: .topLeading) {
                                        Color.clear
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if store.hapticFeedback {
                                                    HapticManager.selection()
                                                }
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    isChromeVisible.toggle()
                                                }
                                            }

                                        VStack(alignment: .leading, spacing: 20) {
                                            HStack {
                                                Text("PAGE \(pageNum) OF \(totalPages)")
                                                    .fableFont(size: 10, weight: .bold)
                                                    .tracking(1.2)
                                                    .foregroundColor(FableTheme.brandPrimary)
                                                Spacer()
                                                Text("Tap paragraph to annotate")
                                                    .fableFont(size: 11)
                                                    .foregroundColor(store.readerTheme.isDark ? Color.white.opacity(0.75) : FableTheme.textMuted)
                                            }
                                            .padding(.top, 14)

                                            if pages.indices.contains(pageNum - 1) {
                                                let pageParas = ReaderPassageMatcher.paragraphs(from: pages[pageNum - 1])
                                                ForEach(Array(pageParas.enumerated()), id: \.offset) { _, para in
                                                    paragraphView(para)
                                                }
                                            }

                                            Spacer().frame(height: 120)
                                        }
                                        .padding(.horizontal, 32)
                                    }
                                }
                                .tag(pageNum)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .onChange(of: currentPage) { oldPage, newPage in
                            guard oldPage != newPage else { return }
                            if suppressNextPageTurnMetrics {
                                suppressNextPageTurnMetrics = false
                            } else {
                                let wordCount = pages.indices.contains(newPage - 1) ? PacingEngine.countWords(in: pages[newPage - 1]) : 180
                                pacingEngine.recordPageTurn(wordsOnPage: wordCount)
                            }
                            persistCurrentProseProgress()
                        }
                    }
                    .overlay(alignment: .leading) {
                        Color.clear
                            .frame(width: 28)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                turnPageBack()
                            }
                    }
                    .overlay(alignment: .trailing) {
                        Color.clear
                            .frame(width: 28)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                turnPageForward()
                            }
                    }
                } else {
                    // Scrollable Editorial Manuscript Body
                    ScrollViewReader { scrollProxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .center, spacing: 20) {
                                // Open Book Filigree Ornament
                                HStack(spacing: 16) {
                                    Rectangle()
                                        .fill(FableTheme.divider)
                                        .frame(height: 1)
                                    
                                    Image(systemName: "book.pages")
                                        .fableFont(size: 13)
                                        .foregroundColor(FableTheme.brandPrimary)
                                    
                                    Rectangle()
                                        .fill(FableTheme.divider)
                                        .frame(height: 1)
                                }
                                .padding(.horizontal, 60)
                                .padding(.top, 16)
                                
                                // Story Title
                                Text(story.title)
                                    .fableFont(
                                        size: 30,
                                        scale: CGFloat(store.readerFontSize / 100.0),
                                        weight: .bold,
                                        design: store.readerFont.design,
                                        relativeTo: .title
                                    )
                                    .foregroundColor(store.readerTheme.textColor)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                
                                // Author & Read Time Metadata Pill
                                HStack(spacing: 12) {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(FableTheme.brandPrimary.opacity(0.15))
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Text(String(story.author.prefix(1)))
                                                    .fableFont(size: 10, weight: .bold)
                                                    .foregroundColor(FableTheme.brandPrimary)
                                            )
                                        Text(story.author)
                                            .fableFont(size: 13, weight: .medium)
                                            .foregroundColor(store.readerTheme.textColor.opacity(0.85))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.08))
                                    .clipShape(Capsule())
                                    
                                    Text("•")
                                        .foregroundColor(store.readerTheme.isDark ? Color.white.opacity(0.75) : FableTheme.textMuted)
                                    
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .fableFont(size: 11)
                                        Text("~\(dynamicMinutesRemaining)m remaining")
                                            .fableFont(size: 12, weight: .medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.08))
                                    .clipShape(Capsule())
                                    .foregroundColor(store.readerTheme.textColor.opacity(0.85))
                                }
                                
                                // Editorial Engraving Vignette (FIGMA.md Frame 2: 1:159)
                                VStack(spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        FableImageView(name: story.effectiveCoverImage ?? story.effectiveHeroImage, placeholderIcon: "photo")
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
                                        
                                        Text("FOLIO \(max(1, currentPage))")
                                            .fableFont(size: 10, weight: .bold)
                                            .tracking(1.0)
                                            .foregroundColor(FableTheme.brandPrimary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.white.opacity(0.95))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .padding(12)
                                    }
                                    
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .id("para-top")
                                
                                // Typographical Manuscript Body with Marginalia highlight capability
                                if isLoadingChapters && activeParagraphs.isEmpty {
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .tint(FableTheme.brandPrimary)
                                        Text("Loading manuscript chapters...")
                                            .fableFont(size: 13, weight: .medium)
                                            .foregroundColor(store.readerTheme.textColor.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 48)
                                } else if let chapterLoadError, activeParagraphs.isEmpty {
                                    VStack(spacing: 12) {
                                        Text(chapterLoadError)
                                            .fableFont(size: 14, weight: .medium)
                                            .foregroundColor(store.readerTheme.textColor.opacity(0.75))
                                            .multilineTextAlignment(.center)
                                        Button("Retry") {
                                            Task { await loadChapters() }
                                        }
                                        .frame(minWidth: 44, minHeight: 44)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 48)
                                } else {
                                    let paragraphs = activeParagraphs
                                    LazyVStack(alignment: .leading, spacing: 18 + store.readerLineSpacing.points) {
                                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, para in
                                            paragraphView(para)
                                                .id("para-\(index)")
                                                .onAppear {
                                                    handleParagraphAppear(index: index, totalParagraphs: paragraphs.count)
                                                }
                                        }
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.top, 8)
                                }
                                
                                // Multi-Chapter Footer Navigation Controls
                                if chapters.count > 1 {
                                    VStack(spacing: 16) {
                                        Divider()
                                            .background(FableTheme.divider)
                                            .padding(.horizontal, 24)
                                        
                                        HStack(spacing: 14) {
                                            if currentChapterIndex > 0 {
                                                Button(action: {
                                                    if store.hapticFeedback {
                                                        HapticManager.impact(style: .light)
                                                    }
                                                    selectChapter(at: currentChapterIndex - 1)
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "chevron.left")
                                                        Text("Chapter \(chapters[currentChapterIndex - 1].chapterNumber)")
                                                    }
                                                    .fableFont(size: 12, weight: .semibold)
                                                    .foregroundColor(FableTheme.textPrimary)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(FableTheme.surface)
                                                    .clipShape(Capsule())
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if currentChapterIndex < chapters.count - 1 {
                                                Button(action: {
                                                    if store.hapticFeedback {
                                                        HapticManager.impact(style: .light)
                                                    }
                                                    selectChapter(at: currentChapterIndex + 1)
                                                }) {
                                                    HStack(spacing: 6) {
                                                        Text("Chapter \(chapters[currentChapterIndex + 1].chapterNumber)")
                                                        Image(systemName: "chevron.right")
                                                    }
                                                    .fableFont(size: 12, weight: .semibold)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(FableTheme.brandPrimary)
                                                    .clipShape(Capsule())
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 24)
                                    }
                                    .padding(.top, 16)
                                }
                                
                                Spacer().frame(height: 130) // spacing for floating HUD
                            }
                        }
                        .onChange(of: scrollRestoreTrigger) { _, _ in
                            if let targetParaId = pendingScrollParagraphId {
                                pendingScrollParagraphId = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        scrollProxy.scrollTo(targetParaId, anchor: .center)
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        isRestoringScrollPosition = false
                                    }
                                }
                            } else {
                                let totalParas = activeParagraphs.count
                                if currentPage > 1 && totalParas > 1 {
                                    let targetIdx = min(
                                        totalParas - 1,
                                        max(0, Int(((Double(currentPage - 1) / Double(max(1, totalPages))) * Double(totalParas)).rounded()))
                                    )
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            scrollProxy.scrollTo("para-\(targetIdx)", anchor: .top)
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                            isRestoringScrollPosition = false
                                        }
                                    }
                                } else {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        scrollProxy.scrollTo("para-top", anchor: .top)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                            isRestoringScrollPosition = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Floating Reading HUD Pill (FIGMA.md Frame 2 HUD + Pacing Engine)
            if isChromeVisible {
                VStack(spacing: 8) {
                    // Precision Page Scrubber Slider (Kindle / Tachiyomi style)
                    if store.isPaginatedMode && totalPages > 1 {
                        HStack(spacing: 12) {
                            Text("\(currentPage)")
                                .fableFont(size: 12, weight: .bold, design: .monospaced)
                                .foregroundColor(FableTheme.brandPrimary)
                                .frame(width: 32, alignment: .trailing)

                            Slider(
                                value: Binding(
                                    get: { Double(currentPage) },
                                    set: { newVal in
                                        let target = Int(newVal.rounded())
                                        if target != currentPage && target >= 1 && target <= totalPages {
                                            suppressNextPageTurnMetrics = true
                                            currentPage = target
                                            if store.hapticFeedback {
                                                HapticManager.selection()
                                            }
                                        }
                                    }
                                ),
                                in: 1...Double(max(1, totalPages)),
                                step: 1
                            )
                            .tint(FableTheme.brandPrimary)

                            Text("\(totalPages)")
                                .fableFont(size: 12, weight: .bold, design: .monospaced)
                                .foregroundColor(store.readerTheme.isDark ? Color.white.opacity(0.7) : FableTheme.textMuted)
                                .frame(width: 32, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(store.readerTheme.isDark ? Color(red: 0.16, green: 0.18, blue: 0.22) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(store.readerTheme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 0.8)
                                )
                                .shadow(color: Color.black.opacity(store.readerTheme.isDark ? 0.35 : 0.08), radius: 10, y: 3)
                        )
                        .padding(.horizontal, 24)
                    }

                    // Floating Reading HUD Pill (FIGMA.md Frame 2 HUD + Pacing Engine)
                    HStack(spacing: 12) {
                        // Page Back Button
                        Button(action: {
                            turnPageBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .fableFont(size: 12, weight: .bold)
                                .foregroundColor((currentPage > 1 || currentChapterIndex > 0) ? FableTheme.brandPrimary : (store.readerTheme.isDark ? Color.white.opacity(0.2) : Color.gray.opacity(0.4)))
                                .frame(width: 28, height: 28)
                                .background(store.readerTheme.isDark ? Color.white.opacity(0.1) : Color.gray.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .disabled(currentPage <= 1 && currentChapterIndex <= 0)
                        
                        // Page Indicator & Dynamic Pacing
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Ch. \(activeChapter?.chapterNumber ?? 1) • Page \(currentPage)/\(totalPages)")
                                .fableFont(size: 12, weight: .semibold)
                                .monospacedDigit()
                                .foregroundColor(store.readerTheme.isDark ? Color.white : FableTheme.textPrimary)
                            
                            Text("~\(dynamicMinutesRemaining) mins left in chapter")
                                .fableFont(size: 10, weight: .medium)
                                .monospacedDigit()
                                .foregroundColor(store.readerTheme.isDark ? Color.white.opacity(0.65) : FableTheme.textMuted)
                        }
                        
                        // Page Forward Button
                        Button(action: {
                            turnPageForward()
                        }) {
                            Image(systemName: "chevron.right")
                                .fableFont(size: 12, weight: .bold)
                                .foregroundColor((currentPage < totalPages || currentChapterIndex < chapters.count - 1) ? FableTheme.brandPrimary : (store.readerTheme.isDark ? Color.white.opacity(0.2) : Color.gray.opacity(0.4)))
                                .frame(width: 28, height: 28)
                                .background(store.readerTheme.isDark ? Color.white.opacity(0.1) : Color.gray.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .disabled(currentPage >= totalPages && currentChapterIndex >= chapters.count - 1)
                        
                        Text("•")
                            .foregroundColor(store.readerTheme.isDark ? Color.white.opacity(0.3) : Color.gray.opacity(0.4))
                        
                        // Progress percentage
                        Text("\(readingProgressPercent)%")
                            .fableFont(size: 12, weight: .bold)
                            .monospacedDigit()
                            .foregroundColor(FableTheme.brandPrimary)
                        
                        Spacer()
                        
                        // Layout Mode Toggle Button (Scroll vs Paginated)
                        Button(action: {
                            FableHaptics.selection()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.isPaginatedMode.toggle()
                            }
                        }) {
                            Image(systemName: store.isPaginatedMode ? "book.pages" : "scroll")
                                .fableFont(size: 13, weight: .semibold)
                                .foregroundColor(store.readerTheme.isDark ? Color.white : FableTheme.textPrimary)
                                .frame(width: 32, height: 32)
                                .background(store.readerTheme.isDark ? Color.white.opacity(0.12) : FableTheme.surface)
                                .clipShape(Circle())
                        }
                        
                        // Display options toggle button
                        Button(action: {
                            FableHaptics.selection()
                            store.isShowingDisplayOptions = true
                        }) {
                            Text("TT")
                                .fableFont(size: 13, weight: .bold, design: .serif)
                                .foregroundColor(store.readerTheme.isDark ? Color.white : FableTheme.textPrimary)
                                .frame(width: 34, height: 34)
                                .background(store.readerTheme.isDark ? Color.white.opacity(0.12) : FableTheme.surface)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(store.readerTheme.isDark ? Color(red: 0.16, green: 0.18, blue: 0.22) : Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30)
                                    .stroke(store.readerTheme.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06), lineWidth: 0.8)
                            )
                            .shadow(color: Color.black.opacity(store.readerTheme.isDark ? 0.35 : 0.1), radius: 12, y: 4)
                    )
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            self.sessionStartTime = Date()
            pacingEngine.startSession()
            let isUsable = story.chapters?.contains(where: \.hasReadableText) ?? false
            if let existing = story.chapters, !existing.isEmpty, isUsable {
                self.chapters = existing
                restoreSavedChapter()
                loadCurrentChapterPages(preserveCurrentPage: true)
                applyPendingAnnotationTargetIfReady()
                persistCurrentProseProgress()
                triggerScrollRestore()
            } else {
                restoreSavedChapter()
                loadCurrentChapterPages(preserveCurrentPage: true)
                if story.sourceProvider == .fableOriginal && !activeParagraphs.isEmpty {
                    applyPendingAnnotationTargetIfReady()
                    triggerScrollRestore()
                }
                Task {
                    await loadChapters()
                }
            }
        }
        .onChange(of: store.isPaginatedMode) { _, isPaginated in
            if !isPaginated {
                triggerScrollRestore()
            }
        }
        .onDisappear {
            let elapsed = Int(Date().timeIntervalSince(sessionStartTime))
            store.logReadingSession(for: story, seconds: elapsed)
            audioNarrator.stop()
        }
        .sheet(isPresented: $store.isShowingDisplayOptions) {
            DisplayOptionsSheet()
                .environmentObject(store)
        }
        .onChange(of: store.readerFontSize) { _, _ in
            loadCurrentChapterPages(preserveCurrentPage: true)
        }
        .sheet(isPresented: $isShowingAnnotationSheet, onDismiss: {
            resetAnnotationState()
        }) {
            annotationSheetView
                .presentationDetents([.medium, .large])
                .background(Color.white)
        }
        .sheet(isPresented: $isShowingChapterSheet) {
            tableOfContentsSheetView
                .presentationDetents([.medium, .large])
        }
        .onChange(of: store.isShowingChapterIndexSheet) { _, newValue in
            isShowingChapterSheet = newValue
        }
    }

    private func matchingAnnotation(for para: String) -> Annotation? {
        store.activeStoryAnnotations.first { annot in
            if let annotChapter = annot.chapterNumber,
               let currentChapterNum = activeChapter?.chapterNumber,
               annotChapter != currentChapterNum {
                return false
            }
            return para.contains(annot.selectedText) || annot.selectedText.contains(para)
        }
    }
    
    // View helper for rendered manuscript paragraph with marginalia highlighting & oral audio sync
    @ViewBuilder
    private func paragraphView(_ para: String) -> some View {
        let matchingAnnotation = matchingAnnotation(for: para)
        
        let isSpokenParagraph: Bool = {
            guard audioNarrator.isPlaying, audioNarrator.activeStoryId == story.id else { return false }
            let fullText = activeChapterText
            guard let spokenRange = audioNarrator.currentSpokenRange,
                  spokenRange.location != NSNotFound else { return false }
            let nsFullText = fullText as NSString
            let paraRange = nsFullText.range(of: para)
            if paraRange.location != NSNotFound {
                return spokenRange.location >= paraRange.location && spokenRange.location < (paraRange.location + paraRange.length)
            }
            return false
        }()
        
        Text(para)
            .fableFont(
                size: 17,
                scale: CGFloat(store.readerFontSize / 100.0),
                design: store.readerFont.design,
                relativeTo: .body
            )
            .lineSpacing(store.readerLineSpacing.points)
            .foregroundColor(store.readerTheme.textColor)
            .padding(matchingAnnotation != nil || isSpokenParagraph ? 6 : 0)
            .background(
                matchingAnnotation != nil
                    ? matchingAnnotation!.color.displayColor
                    : (isSpokenParagraph ? FableTheme.brandPrimary.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSpokenParagraph ? FableTheme.brandPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .fixedSize(horizontal: false, vertical: true)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.25), value: isSpokenParagraph)
            .onTapGesture {
                self.editingAnnotation = matchingAnnotation
                self.selectedTextToAnnotate = para
                if let existing = matchingAnnotation {
                    self.selectedHighlightColor = existing.color
                    self.annotationNote = existing.note ?? ""
                    self.isPinToJournal = existing.isPinnedToJournal
                } else {
                    self.selectedHighlightColor = .terracotta
                    self.annotationNote = ""
                    self.isPinToJournal = true
                }
                self.isShowingAnnotationSheet = true
            }
    }
    
    // Marginalia & Passage Annotation Modal (Plan 02)
    private var annotationSheetView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            
            HStack {
                Text(editingAnnotation != nil ? "Edit Annotation" : "Annotate Passage")
                    .fableFont(size: 18, weight: .bold, design: .serif)
                    .foregroundColor(FableTheme.deepCharcoal)
                
                Spacer()
                
                Button(action: {
                    isShowingAnnotationSheet = false
                    resetAnnotationState()
                }) {
                    Image(systemName: "xmark")
                        .fableFont(size: 13, weight: .bold)
                        .foregroundColor(FableTheme.subtleSlate)
                        .padding(6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            
            if let excerpt = selectedTextToAnnotate {
                Text("“\(excerpt.prefix(120))...”")
                    .fableFont(size: 13, weight: .regular, design: .serif)
                    .italic()
                    .foregroundColor(FableTheme.textSecondary)
                    .lineLimit(2)
                    .padding(12)
                    .background(FableTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
            }
            
            // Highlight color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("HIGHLIGHT COLOR")
                    .fableFont(size: 10, weight: .bold)
                    .tracking(1.0)
                    .foregroundColor(FableTheme.subtleSlate)
                    .padding(.horizontal, 20)
                
                HStack(spacing: 12) {
                    ForEach(HighlightColor.allCases) { colorToken in
                        Button(action: {
                            selectedHighlightColor = colorToken
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(colorToken.displayColor.opacity(1.0))
                                    .frame(width: 16, height: 16)
                                Text(colorToken.displayName)
                                    .fableFont(size: 13, weight: .medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedHighlightColor == colorToken ? FableTheme.softPeach : Color.gray.opacity(0.08))
                            .foregroundColor(selectedHighlightColor == colorToken ? FableTheme.terracotta : FableTheme.deepCharcoal)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedHighlightColor == colorToken ? FableTheme.terracotta : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Optional note field
            VStack(alignment: .leading, spacing: 6) {
                Text("NOTE (OPTIONAL)")
                    .fableFont(size: 10, weight: .bold)
                    .tracking(1.0)
                    .foregroundColor(FableTheme.subtleSlate)
                    .padding(.horizontal, 20)
                
                TextField("Add your thoughts...", text: $annotationNote, axis: .vertical)
                    .fableFont(size: 14)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.gray.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
            }
            
            // Pin to Shelf Reading Journal Quote Deck Toggle
            Toggle(isOn: $isPinToJournal) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pin to Shelf Journal Deck")
                        .fableFont(size: 14, weight: .semibold)
                        .foregroundColor(FableTheme.textPrimary)
                    Text("Promotes excerpt as a quote card on your shelf")
                        .fableFont(size: 11)
                        .foregroundColor(FableTheme.textMuted)
                }
            }
            .tint(FableTheme.brandPrimary)
            .padding(.horizontal, 20)
            
            // Save / Update Action Button
            VStack(spacing: 10) {
                Button(action: {
                    let cleanNote = annotationNote.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalNote = cleanNote.isEmpty ? nil : cleanNote
                    if let existing = editingAnnotation {
                        store.updateAnnotation(
                            existing,
                            story: story,
                            color: selectedHighlightColor,
                            note: finalNote,
                            pinToJournal: isPinToJournal
                        )
                    } else if let text = selectedTextToAnnotate {
                        let fullText = activeChapterText
                        let nsText = fullText as NSString
                        let targetRange = nsText.range(of: text)
                        let startOffset = targetRange.location != NSNotFound ? targetRange.location : 0
                        let endOffset = targetRange.location != NSNotFound ? (targetRange.location + targetRange.length) : text.utf16.count
                        
                        store.addAnnotation(
                            story: story,
                            text: text,
                            chapterNumber: activeChapter?.chapterNumber,
                            startOffset: startOffset,
                            endOffset: endOffset,
                            color: selectedHighlightColor,
                            note: finalNote,
                            pinToJournal: isPinToJournal
                        )
                    }
                    isShowingAnnotationSheet = false
                    resetAnnotationState()
                }) {
                    Text(editingAnnotation != nil ? "Update Annotation" : "Save Annotation")
                        .fableFont(size: 15, weight: .semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(FableTheme.brandPrimary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let existing = editingAnnotation {
                    Button(role: .destructive) {
                        store.deleteAnnotation(id: existing.id, storyId: story.id)
                        isShowingAnnotationSheet = false
                        resetAnnotationState()
                    } label: {
                        Text("Delete Annotation")
                            .fableFont(size: 14, weight: .semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
    
    // Helper to reset annotation state
    private func resetAnnotationState() {
        editingAnnotation = nil
        selectedTextToAnnotate = nil
        annotationNote = ""
        selectedHighlightColor = .terracotta
        isPinToJournal = true
    }

    private func setCurrentPageProgrammatically(_ targetPage: Int) {
        let clamped = min(max(1, targetPage), max(1, totalPages))
        guard clamped != currentPage else { return }
        suppressNextPageTurnMetrics = true
        currentPage = clamped
    }

    private func turnPageBack() {
        if store.hapticFeedback {
            HapticManager.selection()
        }
        if currentPage > 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentPage -= 1
            }
        } else if currentChapterIndex > 0 {
            if store.hapticFeedback {
                HapticManager.notification(type: .success)
            }
            selectChapter(at: currentChapterIndex - 1, startAtLastPage: true)
        }
    }

    private func turnPageForward() {
        if store.hapticFeedback {
            HapticManager.selection()
        }
        if currentPage < totalPages {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentPage += 1
            }
        } else if currentChapterIndex < chapters.count - 1 {
            if store.hapticFeedback {
                HapticManager.notification(type: .success)
            }
            selectChapter(at: currentChapterIndex + 1, startAtLastPage: false)
        }
    }
    
    // Multi-Chapter Synchronization Helpers
    @MainActor
    private func loadChapters() async {
        guard !isLoadingChapters else { return }
        isLoadingChapters = true
        chapterLoadError = nil
        defer { isLoadingChapters = false }

        do {
            let fetched = try await store.fetchChapters(for: story)
            if !fetched.isEmpty {
                chapters = fetched.sorted(by: { $0.chapterNumber < $1.chapterNumber })
                restoreSavedChapter()
                loadCurrentChapterPages(preserveCurrentPage: true)
            }
            applyPendingAnnotationTargetIfReady()
            persistCurrentProseProgress()
            triggerScrollRestore()
        } catch {
            chapterLoadError = "Couldn't load chapters. Check your connection and try again."
        }
    }

    private func applyPendingAnnotationTargetIfReady() {
        guard let target = pendingTargetAnnotation else { return }
        if !chapters.isEmpty,
           let matchedChapterIdx = ReaderPassageMatcher.chapterIndex(for: target, in: chapters),
           matchedChapterIdx != currentChapterIndex {
            currentChapterIndex = matchedChapterIdx
            loadCurrentChapterPages(preserveCurrentPage: false)
        }
        if let page = ReaderPassageMatcher.pageNumber(for: target, in: pages) {
            setCurrentPageProgrammatically(page)
        }
        if let paraIdx = ReaderPassageMatcher.paragraphIndex(for: target, in: activeParagraphs) {
            pendingScrollParagraphId = "para-\(paraIdx)"
        }
        if !chapters.isEmpty || !activeParagraphs.isEmpty {
            pendingTargetAnnotation = nil
        }
    }

    private func loadCurrentChapterPages(preserveCurrentPage: Bool = false, startAtLastPage: Bool = false) {
        let text = activeChapterText
        let chunked = PacingEngine.chunkIntoPages(text: text, fontSizePercentage: store.readerFontSize)
        self.pages = chunked
        self.totalPages = max(1, chunked.count)
        if preserveCurrentPage {
            setCurrentPageProgrammatically(self.currentPage)
        } else if startAtLastPage {
            setCurrentPageProgrammatically(chunked.count)
        } else {
            setCurrentPageProgrammatically(1)
        }
        store.loadAnnotations(for: story.id)
    }
    
    private func selectChapter(at index: Int, startAtLastPage: Bool = false) {
        guard chapters.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentChapterIndex = index
            let chapter = chapters[index]
            store.updateReadingProgress(
                for: story.id,
                chapterId: chapter.id.uuidString,
                chapterNumber: chapter.chapterNumber
            )
            loadCurrentChapterPages(startAtLastPage: startAtLastPage)
            pacingEngine.startSession()
            persistCurrentProseProgress()
            triggerScrollRestore()
            if audioNarrator.isPlaying {
                audioNarrator.speak(story: story, chapter: chapter)
            }
        }
    }

    private func restoreSavedChapter() {
        let progress = store.stories.first(where: { $0.id == story.id }) ?? story
        if let chapterId = progress.lastReadChapterId,
           let savedIndex = chapters.firstIndex(where: { $0.id.uuidString == chapterId }) {
            currentChapterIndex = savedIndex
        } else if let chapterNumber = progress.lastReadChapterNumber,
                  let savedIndex = chapters.firstIndex(where: { $0.chapterNumber == chapterNumber }) {
            currentChapterIndex = savedIndex
        } else {
            currentChapterIndex = 0
        }
        if !chapters.indices.contains(currentChapterIndex) {
            currentChapterIndex = 0
        }
        if progress.currentPage > 0 {
            currentPage = progress.currentPage
        } else {
            currentPage = 1
        }
    }

    private func persistCurrentProseProgress() {
        let chap = activeChapter
        store.updateProgress(
            for: story.id,
            page: currentPage,
            totalPages: totalPages,
            chapterIndex: currentChapterIndex,
            totalChapters: max(1, chapters.count),
            chapterId: chap?.id.uuidString,
            chapterNumber: chap?.chapterNumber ?? (currentChapterIndex + 1)
        )
    }

    private func triggerScrollRestore() {
        isRestoringScrollPosition = true
        scrollRestoreTrigger += 1
    }

    private func handleParagraphAppear(index: Int, totalParagraphs: Int) {
        guard !store.isPaginatedMode, !isRestoringScrollPosition, totalParagraphs > 0 else { return }
        let mappedPage = min(
            totalPages,
            max(1, Int(ceil((Double(index + 1) / Double(totalParagraphs)) * Double(max(1, totalPages)))))
        )
        if mappedPage != currentPage {
            currentPage = mappedPage
            persistCurrentProseProgress()
        }
    }
    
    // Table of Contents Sheet View
    private var tableOfContentsSheetView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TABLE OF CONTENTS")
                            .fableFont(size: 11, weight: .bold)
                            .tracking(1.2)
                            .foregroundColor(FableTheme.brandPrimary)
                        
                        Text(story.title)
                            .fableFont(size: 18, weight: .bold, design: .serif)
                            .foregroundColor(FableTheme.textPrimary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isShowingChapterSheet = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .fableFont(size: 20)
                            .foregroundColor(FableTheme.textMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                
                if isLoadingChapters {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading live chapters...")
                            .fableFont(size: 13)
                            .foregroundColor(FableTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 36)
                } else if let chapterLoadError {
                    VStack(spacing: 12) {
                        Text(chapterLoadError)
                            .fableFont(size: 14, weight: .medium)
                            .foregroundColor(FableTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await loadChapters() }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else if chapters.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "book.pages")
                            .fableFont(size: 28)
                            .foregroundColor(FableTheme.brandPrimary.opacity(0.6))
                        Text("Single Chapter Manuscript")
                            .fableFont(size: 15, weight: .semibold, design: .serif)
                            .foregroundColor(FableTheme.textPrimary)
                        Text("This title is preserved as a single unbroken folio.")
                            .fableFont(size: 12)
                            .foregroundColor(FableTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    List {
                        ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                            Button(action: {
                                isShowingChapterSheet = false
                                selectChapter(at: index)
                            }) {
                                HStack(spacing: 14) {
                                    Text("\(chapter.chapterNumber)")
                                        .fableFont(size: 12, weight: .bold, design: .monospaced)
                                        .foregroundColor(index == currentChapterIndex ? .white : FableTheme.brandPrimary)
                                        .frame(width: 28, height: 28)
                                        .background(index == currentChapterIndex ? FableTheme.brandPrimary : FableTheme.brandPrimary.opacity(0.12))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(chapter.title.isEmpty ? "Chapter \(chapter.chapterNumber)" : chapter.title)
                                            .fableFont(size: 14, weight: index == currentChapterIndex ? .bold : .medium, design: .serif)
                                            .foregroundColor(index == currentChapterIndex ? FableTheme.brandPrimary : FableTheme.textPrimary)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 8) {
                                            Text("\(chapter.wordCount) words")
                                                .fableFont(size: 11)
                                                .foregroundColor(FableTheme.textMuted)
                                            
                                            Text("•")
                                                .foregroundColor(FableTheme.textMuted)
                                            
                                            Text("~\(max(1, chapter.wordCount / 200)) min read")
                                                .fableFont(size: 11)
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if index == currentChapterIndex {
                                        Image(systemName: "checkmark")
                                            .fableFont(size: 13, weight: .bold)
                                            .foregroundColor(FableTheme.brandPrimary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }
}
