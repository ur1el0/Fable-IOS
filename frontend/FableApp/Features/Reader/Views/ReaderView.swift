import SwiftUI

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
    
    // Marginalia & Highlight Sheet State (Plan 02)
    @State private var selectedTextToAnnotate: String? = nil
    @State private var selectedHighlightColor: HighlightColor = .terracotta
    @State private var annotationNote: String = ""
    @State private var isPinToJournal: Bool = true
    @State private var isShowingAnnotationSheet: Bool = false
    @State private var sessionStartTime: Date = Date()
    
    public init(story: Story) {
        self.story = story
        _currentPage = State(initialValue: max(1, story.currentPage))
        _totalPages = State(initialValue: max(1, story.totalPages))
    }
    
    private var activeChapter: Chapter? {
        chapters.indices.contains(currentChapterIndex) ? chapters[currentChapterIndex] : nil
    }
    
    private var activeChapterText: String {
        if let chap = activeChapter, !chap.content.isEmpty {
            return chap.content
        }
        return story.content.isEmpty ? story.synopsis : story.content
    }
    
    private var activeParagraphs: [String] {
        let split = activeChapterText.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return split.isEmpty ? (story.synopsis.isEmpty ? [] : [story.synopsis]) : split
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
        min(100, max(0, Int((Double(currentPage) / Double(max(1, totalPages))) * 100)))
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
                HStack(spacing: 12) {
                    Button(action: {
                        audioNarrator.stop()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(store.readerTheme.textColor)
                            .padding(8)
                            .background(store.readerTheme.textColor.opacity(0.06))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Chapter / Folio Tag (Interactive TOC Trigger)
                    Button(action: {
                        isShowingChapterSheet = true
                    }) {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text(activeChapterTag)
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.0)
                                    .foregroundColor(FableTheme.brandPrimary)
                                    .lineLimit(1)
                                
                                if !chapters.isEmpty {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(FableTheme.brandPrimary)
                                }
                            }
                            
                            Text(story.title)
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(store.readerTheme.textColor.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        // Table of Contents Sheet Button
                        Button(action: {
                            isShowingChapterSheet = true
                        }) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(store.readerTheme.textColor)
                                .padding(8)
                                .background(store.readerTheme.textColor.opacity(0.06))
                                .clipShape(Circle())
                        }
                        
                        // Oral Folklore Audio Synthesizer Toggle (Plan 04)
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                audioNarrator.togglePlayback(for: story, chapter: activeChapter)
                            }
                        }) {
                            Image(systemName: audioNarrator.isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(audioNarrator.isPlaying ? FableTheme.brandPrimary : store.readerTheme.textColor)
                                .padding(8)
                                .background(audioNarrator.isPlaying ? FableTheme.brandPrimary.opacity(0.15) : store.readerTheme.textColor.opacity(0.06))
                                .clipShape(Circle())
                        }
                        
                        // Bookmark Toggle
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                store.toggleBookmark(for: story)
                            }
                        }) {
                            Image(systemName: currentStoryBookmarked ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(currentStoryBookmarked ? FableTheme.brandPrimary : store.readerTheme.textColor)
                                .padding(8)
                                .background(store.readerTheme.textColor.opacity(0.06))
                                .clipShape(Circle())
                        }
                        
                        // Typography Options
                        Button(action: {
                            store.isShowingDisplayOptions = true
                        }) {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(store.readerTheme.textColor)
                                .padding(8)
                                .background(store.readerTheme.textColor.opacity(0.06))
                                .clipShape(Circle())
                        }
                        
                        // Native Share Link
                        ShareLink(
                            item: "\(story.title) by \(story.author)\n\n\(story.synopsis)\n\nRead on Fable."
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(store.readerTheme.textColor)
                                .padding(8)
                                .background(store.readerTheme.textColor.opacity(0.06))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Active Spoken Audio Narration Banner (Plan 04)
                if audioNarrator.isPlaying || audioNarrator.isPaused {
                    HStack(spacing: 10) {
                        Image(systemName: audioNarrator.isPlaying ? "waveform" : "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(FableTheme.brandPrimary)
                        
                        Text(audioNarrator.isPlaying ? "Narrating Spoken Folklore" : "Audio Paused")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(FableTheme.textPrimary)
                        
                        Spacer()
                        
                        // Speed multiplier button
                        Button(action: {
                            let nextRate: Float = audioNarrator.playbackRateMultiplier >= 1.25 ? 0.85 : (audioNarrator.playbackRateMultiplier + 0.2)
                            audioNarrator.setRateMultiplier(nextRate)
                        }) {
                            Text(String(format: "%.1fx", audioNarrator.playbackRateMultiplier))
                                .font(.system(size: 11, weight: .bold))
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
                                .font(.system(size: 11, weight: .bold))
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
                    TabView(selection: $currentPage) {
                        ForEach(1...max(1, totalPages), id: \.self) { pageNum in
                            ScrollView(showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 20) {
                                    HStack {
                                        Text("PAGE \(pageNum) OF \(totalPages)")
                                            .font(.system(size: 10, weight: .bold))
                                            .tracking(1.2)
                                            .foregroundColor(FableTheme.brandPrimary)
                                        Spacer()
                                        Text("Tap paragraph to annotate")
                                            .font(.system(size: 11))
                                            .foregroundColor(FableTheme.textMuted)
                                    }
                                    .padding(.top, 14)
                                    
                                    if pages.indices.contains(pageNum - 1) {
                                        let pageText = pages[pageNum - 1]
                                        let pageParas = pageText.components(separatedBy: "\n\n")
                                        ForEach(pageParas, id: \.self) { para in
                                            paragraphView(para)
                                        }
                                    }
                                    
                                    Spacer().frame(height: 120)
                                }
                                .padding(.horizontal, 24)
                            }
                            .tag(pageNum)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentPage) { oldPage, newPage in
                        let wordCount = pages.indices.contains(newPage - 1) ? PacingEngine.countWords(in: pages[newPage - 1]) : 180
                        pacingEngine.recordPageTurn(wordsOnPage: wordCount)
                        store.updateProgress(for: story.id, page: newPage, totalPages: totalPages)
                    }
                } else {
                    // Scrollable Editorial Manuscript Body
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .center, spacing: 20) {
                            // Open Book Filigree Ornament
                            HStack(spacing: 16) {
                                Rectangle()
                                    .fill(FableTheme.divider)
                                    .frame(height: 1)
                                
                                Image(systemName: "book.pages")
                                    .font(.system(size: 13))
                                    .foregroundColor(FableTheme.brandPrimary)
                                
                                Rectangle()
                                    .fill(FableTheme.divider)
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 60)
                            .padding(.top, 16)
                            
                            // Story Title
                            Text(story.title)
                                .font(store.readerFont.font(size: 30 * (store.readerFontSize / 100.0)))
                                .fontWeight(.bold)
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
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(FableTheme.brandPrimary)
                                        )
                                    Text(story.author)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(store.readerTheme.textColor.opacity(0.85))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.gray.opacity(0.08))
                                .clipShape(Capsule())
                                
                                Text("•")
                                    .foregroundColor(FableTheme.textMuted)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11))
                                    Text("~\(dynamicMinutesRemaining)m remaining")
                                        .font(.system(size: 12, weight: .medium))
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
                                    FableImageView(name: story.effectiveCoverImage ?? story.heroImageName, placeholderIcon: "photo")
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
                                    
                                    Text("FOLIO 82")
                                        .font(.system(size: 10, weight: .bold))
                                        .tracking(1.0)
                                        .foregroundColor(FableTheme.brandPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.95))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .padding(12)
                                }
                                
                                Text("“\(story.synopsis.isEmpty ? story.excerpt : story.synopsis)”")
                                    .font(.system(size: 13, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundColor(store.readerTheme.textColor.opacity(0.75))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            
                            // Typographical Manuscript Body with Marginalia highlight capability
                            VStack(alignment: .leading, spacing: 18 + store.readerLineSpacing.points) {
                                ForEach(activeParagraphs, id: \.self) { para in
                                    paragraphView(para)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            
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
                                                .font(.system(size: 12, weight: .semibold))
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
                                                .font(.system(size: 12, weight: .semibold))
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
                }
            }
            
            // Floating Reading HUD Pill (FIGMA.md Frame 2 HUD + Pacing Engine)
            HStack(spacing: 12) {
                // Page Back Button
                Button(action: {
                    if currentPage > 1 {
                        currentPage -= 1
                        let wordCount = pages.indices.contains(currentPage - 1) ? pages[currentPage - 1].split(separator: " ").count : 180
                        pacingEngine.recordPageTurn(wordsOnPage: wordCount)
                        store.updateProgress(for: story.id, page: currentPage, totalPages: totalPages)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(currentPage > 1 ? FableTheme.brandPrimary : Color.gray.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Circle())
                }
                .disabled(currentPage <= 1)
                
                // Page Indicator & Dynamic Pacing
                VStack(alignment: .leading, spacing: 1) {
                    Text("Ch. \(activeChapter?.chapterNumber ?? 1) • Page \(currentPage)/\(totalPages)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FableTheme.textPrimary)
                    
                    Text("~\(dynamicMinutesRemaining) mins left in chapter")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(FableTheme.textMuted)
                }
                
                // Page Forward Button
                Button(action: {
                    if currentPage < totalPages {
                        currentPage += 1
                        let wordCount = pages.indices.contains(currentPage - 1) ? pages[currentPage - 1].split(separator: " ").count : 180
                        pacingEngine.recordPageTurn(wordsOnPage: wordCount)
                        store.updateProgress(for: story.id, page: currentPage, totalPages: totalPages)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(currentPage < totalPages ? FableTheme.brandPrimary : Color.gray.opacity(0.4))
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(Circle())
                }
                .disabled(currentPage >= totalPages)
                
                Text("•")
                    .foregroundColor(Color.gray.opacity(0.4))
                
                // Progress percentage
                Text("\(readingProgressPercent)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(FableTheme.brandPrimary)
                
                Spacer()
                
                // Layout Mode Toggle Button (Scroll vs Paginated)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.isPaginatedMode.toggle()
                    }
                }) {
                    Image(systemName: store.isPaginatedMode ? "book.pages" : "scroll")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(FableTheme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(FableTheme.surface)
                        .clipShape(Circle())
                }
                
                // Display options toggle button
                Button(action: {
                    store.isShowingDisplayOptions = true
                }) {
                    Text("TT")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundColor(FableTheme.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(FableTheme.surface)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.12), radius: 12, y: 4)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            self.sessionStartTime = Date()
            pacingEngine.startSession()
            if let existing = story.chapters, !existing.isEmpty {
                self.chapters = existing
                restoreSavedChapter()
                loadCurrentChapterPages()
            } else {
                loadCurrentChapterPages()
                isLoadingChapters = true
                Task {
                    let fetched = await store.fetchChapters(for: story)
                    await MainActor.run {
                        self.isLoadingChapters = false
                        if !fetched.isEmpty {
                            self.chapters = fetched
                            restoreSavedChapter()
                            loadCurrentChapterPages()
                        }
                    }
                }
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
        .sheet(isPresented: $isShowingAnnotationSheet) {
            annotationSheetView
                .presentationDetents([.fraction(0.48), .medium])
                .background(Color.white)
        }
        .sheet(isPresented: $isShowingChapterSheet) {
            tableOfContentsSheetView
                .presentationDetents([.medium, .large])
        }
    }
    
    // View helper for rendered manuscript paragraph with marginalia highlighting & oral audio sync
    @ViewBuilder
    private func paragraphView(_ para: String) -> some View {
        let matchingAnnotation = store.activeStoryAnnotations.first { annot in
            para.contains(annot.selectedText) || annot.selectedText.contains(para)
        }
        
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
            .font(store.readerFont.font(size: 17 * (store.readerFontSize / 100.0)))
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
                self.selectedTextToAnnotate = para
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
                Text("Annotate Passage")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(FableTheme.deepCharcoal)
                
                Spacer()
                
                Button(action: {
                    isShowingAnnotationSheet = false
                    resetAnnotationState()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(FableTheme.subtleSlate)
                        .padding(6)
                        .background(Color.gray.opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            
            if let excerpt = selectedTextToAnnotate {
                Text("“\(excerpt.prefix(120))...”")
                    .font(.system(size: 13, weight: .regular, design: .serif))
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
                    .font(.system(size: 10, weight: .bold))
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
                                    .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(FableTheme.subtleSlate)
                    .padding(.horizontal, 20)
                
                TextField("Add your thoughts...", text: $annotationNote, axis: .vertical)
                    .font(.system(size: 14))
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(FableTheme.textPrimary)
                    Text("Promotes excerpt as a quote card on your shelf")
                        .font(.system(size: 11))
                        .foregroundColor(FableTheme.textMuted)
                }
            }
            .tint(FableTheme.brandPrimary)
            .padding(.horizontal, 20)
            
            // Save Action Button
            Button(action: {
                if let text = selectedTextToAnnotate {
                    let fullText = activeChapterText
                    let nsText = fullText as NSString
                    let targetRange = nsText.range(of: text)
                    let startOffset = targetRange.location != NSNotFound ? targetRange.location : 0
                    let endOffset = targetRange.location != NSNotFound ? (targetRange.location + targetRange.length) : text.utf16.count
                    
                    store.addAnnotation(
                        story: story,
                        text: text,
                        startOffset: startOffset,
                        endOffset: endOffset,
                        color: selectedHighlightColor,
                        note: annotationNote.isEmpty ? nil : annotationNote,
                        pinToJournal: isPinToJournal
                    )
                }
                isShowingAnnotationSheet = false
                resetAnnotationState()
            }) {
                Text("Save Annotation")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(FableTheme.brandPrimary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
    
    // Helper to reset annotation state
    private func resetAnnotationState() {
        selectedTextToAnnotate = nil
        annotationNote = ""
        selectedHighlightColor = .terracotta
        isPinToJournal = true
    }
    
    // Multi-Chapter Synchronization Helpers
    private func loadCurrentChapterPages(preserveCurrentPage: Bool = false) {
        let text = activeChapterText
        let chunked = PacingEngine.chunkIntoPages(text: text, fontSizePercentage: store.readerFontSize)
        self.pages = chunked
        self.totalPages = max(1, chunked.count)
        if preserveCurrentPage {
            self.currentPage = min(max(1, self.currentPage), self.totalPages)
        } else {
            self.currentPage = 1
        }
        store.loadAnnotations(for: story.id)
    }
    
    private func selectChapter(at index: Int) {
        guard chapters.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            currentChapterIndex = index
            let chapter = chapters[index]
            store.updateReadingProgress(
                for: story.id,
                chapterId: chapter.id.uuidString,
                chapterNumber: chapter.chapterNumber
            )
            loadCurrentChapterPages()
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
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.2)
                            .foregroundColor(FableTheme.brandPrimary)
                        
                        Text(story.title)
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(FableTheme.textPrimary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        isShowingChapterSheet = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(FableTheme.textMuted)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                
                if isLoadingChapters {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Loading live chapters...")
                            .font(.system(size: 13))
                            .foregroundColor(FableTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 36)
                } else if chapters.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 28))
                            .foregroundColor(FableTheme.brandPrimary.opacity(0.6))
                        Text("Single Chapter Manuscript")
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundColor(FableTheme.textPrimary)
                        Text("This title is preserved as a single unbroken folio.")
                            .font(.system(size: 12))
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
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(index == currentChapterIndex ? .white : FableTheme.brandPrimary)
                                        .frame(width: 28, height: 28)
                                        .background(index == currentChapterIndex ? FableTheme.brandPrimary : FableTheme.brandPrimary.opacity(0.12))
                                        .clipShape(Circle())
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(chapter.title.isEmpty ? "Chapter \(chapter.chapterNumber)" : chapter.title)
                                            .font(.system(size: 14, weight: index == currentChapterIndex ? .bold : .medium, design: .serif))
                                            .foregroundColor(index == currentChapterIndex ? FableTheme.brandPrimary : FableTheme.textPrimary)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 8) {
                                            Text("\(chapter.wordCount) words")
                                                .font(.system(size: 11))
                                                .foregroundColor(FableTheme.textMuted)
                                            
                                            Text("•")
                                                .foregroundColor(FableTheme.textMuted)
                                            
                                            Text("~\(max(1, chapter.wordCount / 200)) min read")
                                                .font(.system(size: 11))
                                                .foregroundColor(FableTheme.textMuted)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if index == currentChapterIndex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
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

#Preview {
    ReaderView(story: Story.defaultSeedStories[0])
        .environmentObject(StoryStore())
}
