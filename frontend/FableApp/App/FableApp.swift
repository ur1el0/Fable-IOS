import SwiftUI
import SwiftData

@main
struct FableApp: App {
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRaw: String = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearance.colorScheme)
                .onAppear {
                    appearance.applyToWindows()
                }
                .onChange(of: appAppearanceRaw) { _, _ in
                    appearance.applyToWindows()
                }
        }
        .modelContainer(PersistenceService.shared.container)
    }
}

