import SwiftUI

struct DependencySetupView: View {
    @Environment(\.dismiss) private var dismiss
    let checker: DependencyChecker
    let packageName: String
    let packageDisplayName: String
    let onComplete: () -> Void

    @State private var isInstalling = false
    @State private var installOutput: [String] = []
    @State private var failed = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            if isInstalling || !installOutput.isEmpty {
                outputPanel
            } else {
                promptPanel
            }
        }
        .frame(width: 480, height: isInstalling || !installOutput.isEmpty ? 400 : 220)
        .background(Color.surfaceContainerLow)
    }

    private var header: some View {
        HStack {
            Image(systemName: "terminal.fill")
                .foregroundColor(.appPrimary)
                .font(.system(size: 16))
            Text("Install \(packageDisplayName)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.onSurface)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.surfaceContainer)
    }

    private var promptPanel: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: packageName == "ffmpeg" ? "film.stack" : "arrow.down.circle")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundColor(.appPrimary)

                Text("\(packageDisplayName) is not installed")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.onSurface)

                Text(packageName == "ffmpeg"
                     ? "ffmpeg is required to merge video and audio streams for best-quality MP4 downloads."
                     : "yt-dlp is required to download videos. Install it now via Homebrew?")
                    .font(.system(size: 13))
                    .foregroundColor(.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.onSurfaceVariant)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.surfaceContainerHighest)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Install via Homebrew") {
                    Task { await install() }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var outputPanel: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(installOutput.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.onSurfaceVariant)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line + "\(installOutput.count)")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(12)
                }
                .background(Color(hex: "#0e0e0e"))
                .onChange(of: installOutput.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            HStack {
                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing \(packageDisplayName)...")
                        .font(.system(size: 12))
                        .foregroundColor(.onSurfaceVariant)
                } else if failed {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text("Installation failed")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                    Spacer()
                    Button("Close") { dismiss() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurfaceVariant)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(packageDisplayName) installed successfully")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Spacer()
                    Button("Done") {
                        onComplete()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.surfaceContainer)
        }
    }

    private func install() async {
        isInstalling = true
        installOutput = []
        failed = false

        do {
            try await checker.install(package: packageName) { line in
                self.installOutput.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            isInstalling = false
        } catch {
            isInstalling = false
            failed = true
            installOutput.append("Error: \(error.localizedDescription)")
        }
    }
}

struct NoDependencyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.yellow)
            Text("Homebrew Not Found")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.onSurface)
            Text("YTGet requires Homebrew to install and manage yt-dlp.\nVisit brew.sh to install Homebrew, then relaunch YTGet.")
                .font(.system(size: 13))
                .foregroundColor(.onSurfaceVariant)
                .multilineTextAlignment(.center)
            Button("Visit brew.sh") {
                NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
        .frame(width: 400)
        .background(Color.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct UpdateBannerView: View {
    let packageName: String
    let packageDisplayName: String
    let checker: DependencyChecker
    let onDismiss: () -> Void

    @State private var isInstalling = false
    @State private var showOutput = false
    @State private var installOutput: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.appPrimary)
                    .font(.system(size: 14))
                Text("\(packageDisplayName) update available")
                    .font(.system(size: 13))
                    .foregroundColor(.onSurface)
                Spacer()
                updateButtons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if showOutput {
                ScrollView {
                    Text(installOutput.joined(separator: "\n"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(height: 80)
                .background(Color(hex: "#0e0e0e"))
            }
        }
        .background(Color.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.appPrimary.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var updateButtons: some View {
        if isInstalling {
            ProgressView().controlSize(.small)
        } else {
            HStack(spacing: 8) {
                Menu("Later") {
                    Button("Remind me tomorrow") {
                        UserDefaults.standard.set(
                            Date().timeIntervalSince1970,
                            forKey: "remindTomorrow_\(packageName)"
                        )
                        onDismiss()
                    }
                    Button("Skip this version") {
                        UserDefaults.standard.set(
                            checker.ytdlp.availableVersion ?? "",
                            forKey: "skipVersion_\(packageName)"
                        )
                        onDismiss()
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.onSurfaceVariant)

                Button("Update now") {
                    Task { await performUpdate() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .controlSize(.small)
            }
        }
    }

    private func performUpdate() async {
        isInstalling = true
        showOutput = true
        do {
            try await checker.upgrade(package: packageName) { line in
                self.installOutput.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            isInstalling = false
            await checker.checkAll()
            onDismiss()
        } catch {
            isInstalling = false
            installOutput.append("Error: \(error.localizedDescription)")
        }
    }
}
