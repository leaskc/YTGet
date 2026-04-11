import SwiftUI

struct FormatSelectorView: View {
    @Binding var format: FormatOptions.Format
    @Binding var quality: FormatOptions.VideoQuality

    var body: some View {
        HStack(spacing: 8) {
            // Format toggle
            HStack(spacing: 0) {
                FormatButton(title: "Video", systemImage: "video.fill", isSelected: format == .video) {
                    format = .video
                }
                FormatButton(title: "Audio Only", systemImage: "music.note", isSelected: format == .audioOnly) {
                    format = .audioOnly
                }
            }
            .background(Color(hex: "#0e0e0e"))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Quality picker — only shown for video
            if format == .video {
                HStack(spacing: 0) {
                    ForEach(FormatOptions.VideoQuality.allCases, id: \.self) { q in
                        FormatButton(title: q.rawValue, systemImage: "", isSelected: quality == q) {
                            quality = q
                        }
                    }
                }
                .background(Color(hex: "#0e0e0e"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: format)
    }
}

private struct FormatButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if !systemImage.isEmpty {
                    Image(systemName: systemImage)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .onSurface : .onSurfaceVariant)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.surfaceBright : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .padding(1)
        }
        .buttonStyle(.plain)
    }
}
