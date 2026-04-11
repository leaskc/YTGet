import SwiftUI

struct DownloadQueueView: View {
    let items: [DownloadItem]
    let onCancel: (DownloadItem) -> Void
    let onRetry: (DownloadItem) -> Void

    var body: some View {
        if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        DownloadItemRowView(
                            item: item,
                            onCancel: { onCancel(item) },
                            onRetry: { onRetry(item) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(.onSurfaceVariant.opacity(0.4))
            Text("Paste a URL above to start downloading")
                .font(.system(size: 13))
                .foregroundColor(.onSurfaceVariant.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
