import SwiftUI

struct ProviderCatalogStatusView: View {
    @EnvironmentObject private var store: StoryStore

    var body: some View {
        Group {
            if let warning = store.providerCatalogStatus.warningMessage {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundColor(FableTheme.brandPrimary)
                        .accessibilityHidden(true)
                    Text(warning)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(FableTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        Task { await store.refreshProviderCatalogs() }
                    } label: {
                        if store.isRefreshingProviderCatalogs {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Retry")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .disabled(store.isRefreshingProviderCatalogs)
                    .accessibilityLabel(store.isRefreshingProviderCatalogs ? "Refreshing catalogs" : "Retry catalog update")
                    .accessibilityHint("Fetch the latest live catalog data.")
                }
                .padding(14)
                .background(FableTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .contain)
            }
        }
        .padding(.horizontal, 20)
    }
}
