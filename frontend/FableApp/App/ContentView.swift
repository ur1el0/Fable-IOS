import SwiftUI
import SwiftData

enum FableTab: Int, CaseIterable {
    case library = 0
    case explore = 1
    case write = 2
    case shelf = 3
    
    var title: String {
        switch self {
        case .library: return "Library"
        case .explore: return "Explore"
        case .write: return "Write"
        case .shelf: return "Shelf"
        }
    }
    
    var iconName: String {
        switch self {
        case .library: return "book.pages"
        case .explore: return "magnifyingglass"
        case .write: return "square.and.pencil"
        case .shelf: return "bookmark"
        }
    }

    var activeIconName: String {
        switch self {
        case .library: return "book.pages.fill"
        case .explore: return "sparkle.magnifyingglass"
        case .write: return "pencil.and.scribble"
        case .shelf: return "bookmark.fill"
        }
    }
}

struct ContentView: View {
    @StateObject private var store = StoryStore()
    @StateObject private var authVM = AuthViewModel.shared
    @ObservedObject private var auth = AuthManager.shared

    var body: some View {
        Group {
            switch authVM.authState {
            case .checkingSession:
                splashLoadingView
            case .signedOut:
                WelcomeView()
                    .transition(.opacity)
            case .signedIn:
                mainAppTabView
                    .transition(.opacity)
            }
        }
        .task {
#if DEBUG
            if ProcessInfo.processInfo.environment["AUTO_UI_TOUR"] == "1" {
                await runAutomatedUITour()
                return
            }
#endif
            await authVM.checkExistingSession()
#if DEBUG
            if case .signedOut = authVM.authState,
               ProcessInfo.processInfo.environment["AUTO_GUEST_LOGIN"] == "1" {
                authVM.continueAsGuest()
            }
#endif
        }
        .animation(.easeInOut(duration: 0.25), value: authVM.authState)
        .onChange(of: auth.currentSession?.id) { _, _ in
            store.sessionDidChange()
        }
        .environmentObject(store)
    }

    private var splashLoadingView: some View {
        ZStack {
            FableTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("FableLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .accessibilityLabel("Fable logo")

                Text("Fable")
                    .fableFont(size: 40, weight: .black)
                    .foregroundColor(FableTheme.brandPrimary)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: FableTheme.brandPrimary))
            }
        }
    }

    private var mainAppTabView: some View {
        ZStack(alignment: .bottom) {
            // Tab Contents
            Group {
                switch store.selectedTab {
                case .library:
                    LibraryView()
                case .explore:
                    ExploreView()
                case .write:
                    WriteView()
                case .shelf:
                    ShelfView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Modern Floating Translucent Glass Navigation Pill
            HStack(spacing: 0) {
                ForEach(FableTab.allCases, id: \.self) { tab in
                    let isSelected = store.selectedTab == tab
                    Button {
                        FableHaptics.selection()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                            store.selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 3) {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(FableTheme.brandPrimary.opacity(0.12))
                                        .frame(width: 38, height: 38)
                                }
                                Image(systemName: isSelected ? tab.activeIconName : tab.iconName)
                                    .fableFont(size: 18, weight: isSelected ? .bold : .medium)
                                    .foregroundColor(isSelected ? FableTheme.brandPrimary : FableTheme.textMuted)
                            }
                            .frame(height: 38)

                            Text(tab.title)
                                .fableFont(size: 10, weight: isSelected ? .bold : .medium)
                                .foregroundColor(isSelected ? FableTheme.brandPrimary : FableTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tab.title) tab")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.55), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
                    .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

#if DEBUG
    @MainActor
    private func signalCaptureAndWait(_ filename: String, settleDelayMs: UInt64 = 900) async {
        try? await Task.sleep(nanoseconds: settleDelayMs * 1_000_000)
        let markerURL = FileManager.default.temporaryDirectory.appendingPathComponent("tour_step.txt")
        try? filename.data(using: .utf8)?.write(to: markerURL, options: .atomic)
        for _ in 0..<50 {
            if !FileManager.default.fileExists(atPath: markerURL.path) {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    @MainActor
    private func runAutomatedUITour() async {
        // 1. Welcome & Auth Screens
        authVM.logout()
        await signalCaptureAndWait("01_welcome_screen.png", settleDelayMs: 1200)

        NotificationCenter.default.post(name: Notification.Name("FableTourWelcomeState"), object: "signIn")
        await signalCaptureAndWait("02_auth_sign_in_sheet.png", settleDelayMs: 1000)

        NotificationCenter.default.post(name: Notification.Name("FableTourWelcomeState"), object: "signUp")
        await signalCaptureAndWait("03_auth_create_account_sheet.png", settleDelayMs: 1200)

        NotificationCenter.default.post(name: Notification.Name("FableTourWelcomeState"), object: "none")
        try? await Task.sleep(nanoseconds: 400_000_000)

        // 2. Sign In as Guest & Sync Library Catalog
        authVM.continueAsGuest()
        await store.syncWithCloudBackend()
        store.selectedTab = .library
        store.selectedCategory = "All"
        await signalCaptureAndWait("04_library_filter_all.png", settleDelayMs: 1200)

        // 3. Library Category Filters
        let libraryFilters: [(String, String)] = [
            ("Fables", "05_library_filter_fables.png"),
            ("Classics", "06_library_filter_classics.png"),
            ("Mystery", "07_library_filter_mystery.png"),
            ("Fiction", "08_library_filter_fiction.png"),
            ("Gothic", "09_library_filter_gothic.png"),
            ("Romance", "10_library_filter_romance.png"),
            ("Adventure", "11_library_filter_adventure.png")
        ]
        for (cat, file) in libraryFilters where store.genres.contains(where: { $0.name.caseInsensitiveCompare(cat) == .orderedSame }) {
            store.selectedCategory = cat
            await signalCaptureAndWait(file, settleDelayMs: 800)
        }
        store.selectedCategory = "All"
        try? await Task.sleep(nanoseconds: 400_000_000)

        // 4. Reader View — Classic Fable (Chapter 1)
        if let fable = store.stories.first(where: { $0.title.localizedCaseInsensitiveContains("Tortoise") }) ?? store.stories.first {
            store.activeReaderStory = fable
            await signalCaptureAndWait("12_reader_fable_chapter_1.png", settleDelayMs: 1600)
            store.activeReaderStory = nil
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        // 5. Reader View — Classic Gutenberg Book (Chapter 1, TOC, Typography, Dark Mode)
        if let classicBook = store.stories.first(where: { $0.title.localizedCaseInsensitiveContains("Alice") || $0.title.localizedCaseInsensitiveContains("Pride") }) ?? store.stories.first {
            store.activeReaderStory = classicBook
            await signalCaptureAndWait("13_reader_classic_book_chapter_1.png", settleDelayMs: 1600)

            store.isShowingChapterIndexSheet = true
            await signalCaptureAndWait("14_reader_table_of_contents_sheet.png", settleDelayMs: 1000)
            store.isShowingChapterIndexSheet = false
            try? await Task.sleep(nanoseconds: 600_000_000)

            store.isShowingDisplayOptions = true
            await signalCaptureAndWait("15_reader_display_options_sheet.png", settleDelayMs: 1000)
            store.isShowingDisplayOptions = false
            try? await Task.sleep(nanoseconds: 600_000_000)

            store.readerTheme = .midnight
            await signalCaptureAndWait("16_reader_dark_theme_mode.png", settleDelayMs: 900)
            store.readerTheme = .sepia
            store.activeReaderStory = nil
            try? await Task.sleep(nanoseconds: 800_000_000)
        }

        // 6. Explore Tab — Filters, Live Search, Genre Detail, Author Detail
        store.selectedTab = .explore
        store.tourExploreFilter = "All"
        await signalCaptureAndWait("17_explore_discovery_all.png", settleDelayMs: 1000)

        store.tourExploreFilter = "Under 5 mins"
        await signalCaptureAndWait("18_explore_filter_under_5_mins.png", settleDelayMs: 800)

        store.tourExploreFilter = "Community Favorites"
        await signalCaptureAndWait("19_explore_filter_community_favorites.png", settleDelayMs: 800)

        store.tourExploreFilter = "Quick Reads"
        await signalCaptureAndWait("20_explore_filter_quick_reads.png", settleDelayMs: 800)
        store.tourExploreFilter = "All"

        store.tourExploreSearchText = "Sherlock"
        await signalCaptureAndWait("21_explore_live_search_results.png", settleDelayMs: 1200)
        store.tourExploreSearchText = ""
        try? await Task.sleep(nanoseconds: 500_000_000)

        if let firstGenre = store.genres.first {
            store.selectedGenre = firstGenre
            await signalCaptureAndWait("22_explore_genre_detail_view.png", settleDelayMs: 1000)
            store.selectedGenre = nil
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        if let firstWriter = store.writers.first {
            store.tourSelectedWriter = firstWriter
            await signalCaptureAndWait("23_explore_author_detail_sheet.png", settleDelayMs: 1200)
            store.tourSelectedWriter = nil
            try? await Task.sleep(nanoseconds: 700_000_000)
        }

        // 7. Write Studio Tab
        store.draftTitle = "The Clockwork Nightingale"
        store.draftGenre = "Fables"
        store.draftChapter = "Chapter I: The Gilded Cage"
        store.draftSynopsis = "An emperor trades a living songbird for a jeweled automaton, only to learn that true song cannot be wound with a key."
        store.draftManuscript = "In the marble courts of the Eastern Palace, a small gray nightingale sang beside the sea.\n\nFishermen paused their nets at midnight just to hear a single note drift across the water."
        store.selectedTab = .write
        await signalCaptureAndWait("24_write_studio_editor.png", settleDelayMs: 1000)

        // 8. Shelf Tab — Saved, Finished, My Drafts, Profile, Settings
        if !store.stories.isEmpty {
            store.stories[0].isBookmarked = true
            if store.stories.count > 1 {
                store.stories[1].isCompleted = true
                store.stories[1].progressPercent = 100
            }
        }
        store.selectedTab = .shelf
        store.tourShelfTab = "Saved"
        await signalCaptureAndWait("25_shelf_tab_saved.png", settleDelayMs: 1000)

        store.tourShelfTab = "Finished"
        await signalCaptureAndWait("26_shelf_tab_finished.png", settleDelayMs: 800)

        store.tourShelfTab = "My Drafts"
        await signalCaptureAndWait("27_shelf_tab_my_drafts.png", settleDelayMs: 800)
        store.tourShelfTab = "Saved"

        store.isShowingProfile = true
        await signalCaptureAndWait("28_profile_sheet.png", settleDelayMs: 1000)
        store.isShowingProfile = false
        try? await Task.sleep(nanoseconds: 700_000_000)

        store.isShowingSettings = true
        await signalCaptureAndWait("29_settings_sheet.png", settleDelayMs: 1000)
        store.isShowingSettings = false
        try? await Task.sleep(nanoseconds: 700_000_000)

        // Restore clean state
        store.draftTitle = ""
        store.draftGenre = ""
        store.draftChapter = ""
        store.draftSynopsis = ""
        store.draftManuscript = ""
        store.selectedTab = .library
        store.selectedCategory = "All"
        await signalCaptureAndWait("COMPLETE", settleDelayMs: 600)
    }
#endif
}

#Preview {
    ContentView()
        .modelContainer(PersistenceService.shared.container)
}
