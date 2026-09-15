import SwiftUI

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
    
    var loadingMessage: String {
        switch self {
        case .library: return "Opening Library..."
        case .explore: return "Discovering Tales..."
        case .write: return "Preparing Parchment..."
        case .shelf: return "Opening Shelves..."
        }
    }
}

struct ContentView: View {
    @StateObject private var store = StoryStore()
    @ObservedObject private var auth = AuthManager.shared
    
    @State private var isPageNavigating: Bool = false
    @State private var navigationMessage: String = "Opening Library..."
    
    var body: some View {
        Group {
            if auth.isAuthenticated {
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
                                    if store.selectedTab != tab {
                                        navigationMessage = tab.loadingMessage
                                        withAnimation(.easeInOut(duration: 0.12)) {
                                            isPageNavigating = true
                                        }
                                        store.selectedTab = tab
                                        Task {
                                            try? await Task.sleep(nanoseconds: 240_000_000)
                                            withAnimation(.easeInOut(duration: 0.18)) {
                                                isPageNavigating = false
                                            }
                                        }
                                    }
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
                    
                    // Donut Refresh Page Navigation Indicator
                    if isPageNavigating {
                        PageTransitionDonutOverlay(message: navigationMessage)
                            .zIndex(100)
                    }
                }
                .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.isAuthenticated)
        .environmentObject(store)
    }
}

#Preview {
    ContentView()
}
