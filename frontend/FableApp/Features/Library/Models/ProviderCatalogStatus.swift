import Foundation

enum CatalogProvider: String, CaseIterable, Hashable {
    case gutenberg = "Project Gutenberg"
    case standardEbooks = "Standard Ebooks"
    case mangaDex = "MangaDex"
}

struct ProviderCatalogStatus: Equatable {
    static let maximumFreshnessInterval: TimeInterval = 24 * 60 * 60

    private(set) var failedProviders: Set<CatalogProvider> = []
    private(set) var lastSuccessfulRefresh: [CatalogProvider: Date]

    init(lastSuccessfulRefresh: [CatalogProvider: Date] = [:]) {
        self.lastSuccessfulRefresh = lastSuccessfulRefresh
    }

    var warningMessage: String? {
        let failed = CatalogProvider.allCases.filter { failedProviders.contains($0) }
        if !failed.isEmpty {
            return "\(failed.map(\.rawValue).joined(separator: " and ")) couldn't refresh. Saved results may be out of date."
        }

        let stale = CatalogProvider.allCases.filter { provider in
            guard let refreshedAt = lastSuccessfulRefresh[provider] else { return false }
            return Date().timeIntervalSince(refreshedAt) > Self.maximumFreshnessInterval
        }
        guard !stale.isEmpty else { return nil }
        return "Saved results from \(stale.map(\.rawValue).joined(separator: " and ")) are more than 24 hours old."
    }

    mutating func record(_ provider: CatalogProvider, succeeded: Bool, at date: Date = Date()) {
        if succeeded {
            failedProviders.remove(provider)
            lastSuccessfulRefresh[provider] = date
        } else {
            failedProviders.insert(provider)
        }
    }
}
