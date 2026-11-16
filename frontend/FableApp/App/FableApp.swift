import SwiftUI
import SwiftData

@main
struct FableApp: App {
    @AppStorage(AppAppearance.storageKey) private var appAppearanceRaw: String = AppAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme((AppAppearance(rawValue: appAppearanceRaw) ?? .system).colorScheme)
        }
        .modelContainer(PersistenceService.shared.container)
    }
}

