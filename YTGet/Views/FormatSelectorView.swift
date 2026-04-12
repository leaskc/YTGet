import SwiftUI

struct FormatSelectorView: View {
    @Binding var format: FormatOptions.Format
    @Binding var quality: FormatOptions.VideoQuality
    @Binding var audioQuality: FormatOptions.AudioQuality
    @Binding var subtitleLanguage: String

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
                FormatButton(title: "Transcript", systemImage: "text.bubble", isSelected: format == .transcript) {
                    format = .transcript
                }
            }
            .background(Color(hex: "#0e0e0e"))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Secondary picker — quality for video/audio, language for transcript
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
            } else if format == .audioOnly {
                HStack(spacing: 0) {
                    ForEach(FormatOptions.AudioQuality.allCases, id: \.self) { q in
                        FormatButton(title: q.rawValue, systemImage: "", isSelected: audioQuality == q) {
                            audioQuality = q
                        }
                    }
                }
                .background(Color(hex: "#0e0e0e"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                HStack(spacing: 6) {
                    Text("Lang:")
                        .font(.system(size: 12))
                        .foregroundColor(.onSurfaceVariant)
                    TextField("en", text: $subtitleLanguage)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.onSurface)
                        .frame(width: 40)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(hex: "#0e0e0e"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .move(edge: .trailing)))
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
