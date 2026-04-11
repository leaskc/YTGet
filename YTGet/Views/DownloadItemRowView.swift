import SwiftUI

struct DownloadItemRowView: View {
    let item: DownloadItem
    let onCancel: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
            VStack(alignment: .leading, spacing: 6) {
                titleAndStatus
                progressSection
            }
            Spacer(minLength: 0)
            actionButton
        }
        .padding(12)
        .background(Color.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: Color(hex: "#0e0e0e").opacity(0.4), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if let image = item.thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
            } else {
                ZStack {
                    Color.surfaceContainerHighest
                    Image(systemName: "video.fill")
                        .foregroundColor(.onSurfaceVariant.opacity(0.5))
                        .font(.system(size: 18))
                }
            }
        }
        .frame(width: 80, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var titleAndStatus: some View {
        HStack(spacing: 8) {
            Text(displayTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.onSurface)
                .lineLimit(1)

            statusBadge
        }
    }

    private var displayTitle: String {
        if item.title.isEmpty {
            return item.url
        }
        return item.title
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .fetchingInfo:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Fetching info...")
                    .font(.system(size: 11))
                    .foregroundColor(.onSurfaceVariant)
            }
        case .pending:
            Text("Queued")
                .font(.system(size: 11))
                .foregroundColor(.onSurfaceVariant)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.surfaceContainerHighest)
                .clipShape(Capsule())
        case .downloading:
            EmptyView()
        case .completed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                Text("Complete")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            }
        case .failed(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                Text(msg.isEmpty ? "Failed" : msg)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        case .cancelled:
            Text("Cancelled")
                .font(.system(size: 11))
                .foregroundColor(.onSurfaceVariant)
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        switch item.status {
        case .downloading:
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: item.progress)
                    .tint(.appPrimary)
                    .frame(maxWidth: .infinity)
                HStack {
                    Text("\(Int(item.progress * 100))%")
                        .font(.system(size: 11))
                        .foregroundColor(.onSurfaceVariant)
                    if !item.speed.isEmpty {
                        Text("·")
                            .foregroundColor(.onSurfaceVariant.opacity(0.5))
                        Text(item.speed)
                            .font(.system(size: 11))
                            .foregroundColor(.onSurfaceVariant)
                    }
                    if !item.eta.isEmpty {
                        Spacer()
                        Text("ETA \(item.eta)")
                            .font(.system(size: 11))
                            .foregroundColor(.onSurfaceVariant)
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch item.status {
        case .downloading, .pending, .fetchingInfo:
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.onSurfaceVariant.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Cancel download")

        case .failed:
            Button(action: onRetry) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.appPrimary)
            }
            .buttonStyle(.plain)
            .help("Retry download")

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundColor(.green.opacity(0.7))

        case .cancelled:
            EmptyView()
        }
    }
}
