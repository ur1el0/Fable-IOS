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
            await authVM.checkExistingSession()
        }
        .animation(.easeInOut(duration: 0.25), value: authVM.authState)
        .environmentObject(store)
    }

    private var splashLoadingView: some View {
        ZStack {
            FableTheme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Fable")
                    .font(.system(size: 40, weight: .black))
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

            // Custom Prototype Bottom Tab Bar
            VStack(spacing: 0) {
                Divider()
                    .background(FableTheme.lightBorder)

                HStack(spacing: 0) {
                    ForEach(FableTab.allCases, id: \.self) { tab in
                        Button(action: {
                            store.selectedTab = tab
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 20, weight: store.selectedTab == tab ? .semibold : .regular))

                                Text(tab.title)
                                    .font(.system(size: 11, weight: store.selectedTab == tab ? .semibold : .medium))
                            }
                            .foregroundColor(store.selectedTab == tab ? FableTheme.terracotta : FableTheme.subtleSlate)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .background(Color.white.ignoresSafeArea(edges: .bottom))
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceService.shared.container)
}
