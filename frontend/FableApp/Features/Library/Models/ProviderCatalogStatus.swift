import Foundation

enum CatalogProvider: String, CaseIterable, Hashable {
    case gutenberg = "Project Gutenberg"
    case mangaDex = "MangaDex"
}

struct ProviderCatalogStatus: Equatable {
    private(set) var failedProviders: Set<CatalogProvider> = []

    var warningMessage: String? {
        let providers = CatalogProvider.allCases
            .filter { failedProviders.contains($0) }
            .map(\.rawValue)
        guard !providers.isEmpty else { return nil }
        return "\(providers.joined(separator: " and ")) couldn't refresh. Saved results may be out of date."
    }

    mutating func record(_ provider: CatalogProvider, succeeded: Bool) {
        if succeeded {
            failedProviders.remove(provider)
        } else {
            failedProviders.insert(provider)
        }
    }
}
