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
}

struct ContentView: View {
    @StateObject private var store = StoryStore()
    @State private var selectedTab: FableTab = .library
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Contents
            Group {
                switch selectedTab {
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
                            selectedTab = tab
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 20, weight: selectedTab == tab ? .semibold : .regular))
                                
                                Text(tab.title)
                                    .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
                            }
                            .foregroundColor(selectedTab == tab ? FableTheme.terracotta : FableTheme.subtleSlate)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .background(Color.white.ignoresSafeArea(edges: .bottom))
            }
        }
        .environmentObject(store)
    }
}

#Preview {
    ContentView()
}
