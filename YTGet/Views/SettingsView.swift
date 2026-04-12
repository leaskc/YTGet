import SwiftUI

struct SettingsView: View {
    @Environment(DownloadManager.self) private var manager

    @State private var filenameTemplate: String = ""
    @State private var embedThumbnail: Bool = true
    @State private var embedMetadata: Bool = true
    @State private var transcriptIncludeTimestamps: Bool = false
    @State private var showDedication = false

    var body: some View {
        @Bindable var m = manager

        VStack(spacing: 0) {
            settingsHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    generalSection
                    downloadsSection
                    transcriptsSection
                    aboutSection
                    creditsSection
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 480)
        .background(Color.appBackground)
        .onAppear {
            filenameTemplate = manager.filenameTemplate
            embedThumbnail = manager.embedThumbnail
            embedMetadata = manager.embedMetadata
            transcriptIncludeTimestamps = manager.transcriptIncludeTimestamps
        }
    }

    private var settingsHeader: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.onSurface)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.surfaceContainerLow)
    }

    private var generalSection: some View {
        SettingsSectionView(title: "General") {
            SettingsRow(label: "Output Folder") {
                HStack(spacing: 8) {
                    Text(manager.outputFolder.path)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurfaceVariant)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 220, alignment: .leading)

                    Button("Choose...") {
                        chooseFolder()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.appPrimary)
                }
            }

            SettingsRow(label: "Concurrent Downloads") {
                HStack(spacing: 8) {
                    Text("1")
                        .font(.system(size: 13))
                        .foregroundColor(.onSurfaceVariant.opacity(0.5))
                    Text("(coming soon)")
                        .font(.system(size: 11))
                        .foregroundColor(.onSurfaceVariant.opacity(0.4))
                }
            }
        }
    }

    private var downloadsSection: some View {
        SettingsSectionView(title: "Downloads") {
            SettingsRow(label: "Filename Template") {
                TextField("%(title)s.%(ext)s", text: $filenameTemplate)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.onSurfaceVariant)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.surfaceContainerHighest)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(width: 240)
                    .onChange(of: filenameTemplate) { _, newValue in
                        manager.filenameTemplate = newValue
                    }
            }

            SettingsRow(label: "Embed Thumbnail in Audio Files") {
                Toggle("", isOn: $embedThumbnail)
                    .toggleStyle(.switch)
                    .tint(.appPrimary)
                    .onChange(of: embedThumbnail) { _, newValue in
                        manager.embedThumbnail = newValue
                    }
            }

            SettingsRow(label: "Embed Metadata") {
                Toggle("", isOn: $embedMetadata)
                    .toggleStyle(.switch)
                    .tint(.appPrimary)
                    .onChange(of: embedMetadata) { _, newValue in
                        manager.embedMetadata = newValue
                    }
            }
        }
    }

    private var transcriptsSection: some View {
        SettingsSectionView(title: "Transcripts") {
            SettingsRow(label: "Include Timestamps") {
                Toggle("", isOn: $transcriptIncludeTimestamps)
                    .toggleStyle(.switch)
                    .tint(.appPrimary)
                    .onChange(of: transcriptIncludeTimestamps) { _, newValue in
                        manager.transcriptIncludeTimestamps = newValue
                    }
            }
            SettingsRow(label: "") {
                Text(transcriptIncludeTimestamps
                     ? "Saves an .srt file with timing data."
                     : "Saves a clean .md file with text only.")
                    .font(.system(size: 11))
                    .foregroundColor(.onSurfaceVariant.opacity(0.6))
            }
        }
    }

    private var aboutSection: some View {
        SettingsSectionView(title: "About") {
            HStack {
                Spacer()
                Button(action: { showDedication = true }) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 80, height: 80)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)
                Spacer()
            }
            .sheet(isPresented: $showDedication) {
                DedicationView()
            }

            SettingsRow(label: "Version") {
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(.system(size: 13))
                    .foregroundColor(.onSurfaceVariant)
            }

        }
    }

    private var creditsSection: some View {
        SettingsSectionView(title: "Open Source Credits") {
            CreditRow(
                name: "yt-dlp",
                description: "Video downloader",
                license: "The Unlicense",
                url: "https://github.com/yt-dlp/yt-dlp"
            )
            CreditRow(
                name: "ffmpeg",
                description: "Audio/video processing",
                license: "LGPL 2.1+",
                url: "https://ffmpeg.org"
            )
            CreditRow(
                name: "Homebrew",
                description: "Package management",
                license: "BSD 2-Clause",
                url: "https://brew.sh"
            )
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        if panel.runModal() == .OK, let url = panel.url {
            manager.saveOutputFolder(url)
        }
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.onSurfaceVariant.opacity(0.6))
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .background(Color.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.onSurface)
            Spacer()
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceContainerLow)
    }
}

struct DedicationView: View {
    @Environment(\.dismiss) private var dismiss
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .padding(.bottom, 28)
            }

            Text("YTGet \(version)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.onSurface)

            Text("For Amanda")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.onSurfaceVariant.opacity(0.7))
                .padding(.top, 6)

            Spacer()

            Button("Close") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(.appPrimary)
                .padding(.bottom, 24)
        }
        .frame(width: 300, height: 280)
        .background(Color.appBackground)
    }
}

struct CreditRow: View {
    let name: String
    let description: String
    let license: String
    let url: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Button(name) {
                    NSWorkspace.shared.open(URL(string: url)!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.appPrimary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.onSurfaceVariant.opacity(0.7))
            }
            Spacer()
            Text(license)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.onSurfaceVariant.opacity(0.6))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.surfaceContainerHighest)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surfaceContainerLow)
    }
}
