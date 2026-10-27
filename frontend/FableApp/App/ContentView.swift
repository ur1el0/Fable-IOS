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
            await authVM.checkExistingSession()
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
                                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? FableTheme.brandPrimary : FableTheme.textMuted)
                            }
                            .frame(height: 38)

                            Text(tab.title)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
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
}

#Preview {
    ContentView()
        .modelContainer(PersistenceService.shared.container)
}
