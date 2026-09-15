import SwiftUI
import SwiftData

@main
struct FableApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(PersistenceService.shared.container)
    }
}

