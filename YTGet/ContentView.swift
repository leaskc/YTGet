import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(DownloadManager.self) private var manager
    @Environment(DependencyChecker.self) private var checker

    @State private var urlInput = ""
    @State private var urlError: String? = nil
    @FocusState private var urlFieldFocused: Bool
    @State private var showDependencySheet = false
    @State private var pendingInstallPackage: String? = nil
    @State private var pendingInstallDisplayName: String? = nil
    @State private var showBrewMissingAlert = false
    @State private var dismissedYTDLPWarning = false
    @State private var dismissedFFmpegWarning = false
    @State private var showYTDLPUpdateBanner = false
    @State private var showFFmpegUpdateBanner = false

    var body: some View {
        @Bindable var m = manager

        VStack(spacing: 0) {
            warningBanners
            updateBanners

            toolbar
            divider

            urlInputBar
            divider

            formatBar
            divider

            DownloadQueueView(
                items: manager.items,
                onCancel: { manager.cancelItem($0) },
                onRetry: { manager.retryItem($0) }
            )

            divider
            statusBar
        }
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showDependencySheet) {
            if let pkg = pendingInstallPackage, let display = pendingInstallDisplayName {
                DependencySetupView(
                    checker: checker,
                    packageName: pkg,
                    packageDisplayName: display,
                    onComplete: {}
                )
            }
        }
        .onChange(of: showDependencySheet) { _, isPresented in
            guard !isPresented else { return }
            Task {
                await checker.checkAll()
                checkUpdateBanners()
            }
        }
        .alert("Homebrew Not Found", isPresented: $showBrewMissingAlert) {
            Button("Visit brew.sh") {
                NSWorkspace.shared.open(URL(string: "https://brew.sh")!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("YTGet requires Homebrew to install yt-dlp. Visit brew.sh to install Homebrew, then relaunch YTGet.")
        }
        .onAppear {
            Task {
                await checker.checkAll()
                handleDependencyCheck()
                Task {
                    await checker.checkForUpdates()
                    checkUpdateBanners()
                }
            }
            requestNotificationPermission()
        }
    }

    // MARK: - Warning Banners

    @ViewBuilder
    private var warningBanners: some View {
        if !checker.ytdlp.isInstalled && !dismissedYTDLPWarning && checker.isChecking == false {
            BannerView(
                message: "yt-dlp is not installed. Downloads will not work.",
                icon: "exclamationmark.triangle.fill",
                color: .yellow,
                actionLabel: "Install",
                onAction: { triggerInstall(package: "yt-dlp", display: "yt-dlp") },
                onDismiss: { dismissedYTDLPWarning = true }
            )
        }
        if checker.ytdlp.isInstalled && !checker.ffmpeg.isInstalled && !dismissedFFmpegWarning && checker.isChecking == false {
            BannerView(
                message: "ffmpeg not found — video downloads may fail.",
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                actionLabel: "Install",
                onAction: { triggerInstall(package: "ffmpeg", display: "ffmpeg") },
                onDismiss: { dismissedFFmpegWarning = true }
            )
        }
    }

    // MARK: - Update Banners

    @ViewBuilder
    private var updateBanners: some View {
        if showYTDLPUpdateBanner {
            UpdateBannerView(
                packageName: "yt-dlp",
                packageDisplayName: "yt-dlp",
                checker: checker,
                onDismiss: { showYTDLPUpdateBanner = false }
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        if showFFmpegUpdateBanner {
            UpdateBannerView(
                packageName: "ffmpeg",
                packageDisplayName: "ffmpeg",
                checker: checker,
                onDismiss: { showFFmpegUpdateBanner = false }
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: chooseOutputFolder) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.appPrimary)
                    Text(manager.outputFolder.path)
                        .font(.system(size: 12))
                        .foregroundColor(.onSurfaceVariant)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 280, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .help("Choose output folder")

            Spacer()

            Text(checker.statusBarText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.onSurfaceVariant.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.surfaceContainerLow)
    }

    // MARK: - URL Input

    private var urlInputBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Paste a URL to download...", text: $urlInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.onSurface)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.surfaceContainerHighest)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit { addURL() }
                    .focused($urlFieldFocused)
                    .onChange(of: urlFieldFocused) { _, focused in
                        if focused { checkClipboard() }
                    }

                if let error = urlError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .padding(.horizontal, 4)
                }
            }

            Button("Add") { addURL() }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: [])
                .disabled(urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Format Bar

    private var formatBar: some View {
        @Bindable var m = manager
        return HStack {
            Text("Format:")
                .font(.system(size: 13))
                .foregroundColor(.onSurfaceVariant)
            FormatSelectorView(format: $m.globalFormat, quality: $m.globalQuality, audioQuality: $m.globalAudioQuality, subtitleLanguage: $m.globalSubtitleLanguage)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Text(statusText)
                .font(.system(size: 12))
                .foregroundColor(.onSurfaceVariant.opacity(0.8))
            Spacer()
            if manager.items.contains(where: { $0.status.isFinal }) {
                Button("Clear completed") {
                    manager.clearCompleted()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.appPrimary.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.surfaceContainerLow)
    }

    private var statusText: String {
        let downloading = manager.items.filter { $0.status == .downloading }
        let pending = manager.items.filter { $0.status == .pending || $0.status == .fetchingInfo }
        let total = downloading.count + pending.count
        if total == 0 {
            return manager.items.isEmpty ? "Ready" : "All downloads complete"
        }
        if downloading.count > 0 {
            return "Downloading \(downloading.count) of \(total + manager.items.filter { $0.status.isFinal }.count) items..."
        }
        return "\(pending.count) item\(pending.count == 1 ? "" : "s") queued"
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.outlineVariant)
            .frame(height: 1)
    }

    // MARK: - Actions

    private func addURL() {
        let url = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }

        guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
            urlError = "URL must start with http:// or https://"
            return
        }
        urlError = nil
        manager.addURL(url)
        urlInput = ""
    }

    private func checkClipboard() {
        if let clipboard = NSPasteboard.general.string(forType: .string),
           (clipboard.hasPrefix("http://") || clipboard.hasPrefix("https://")) {
            urlInput = clipboard
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Folder"
        if panel.runModal() == .OK, let url = panel.url {
            manager.saveOutputFolder(url)
        }
    }

    private func handleDependencyCheck() {
        if !checker.ytdlp.isInstalled {
            if checker.brewPath != nil {
                triggerInstall(package: "yt-dlp", display: "yt-dlp")
            } else {
                showBrewMissingAlert = true
            }
            return
        }
        if !checker.ffmpeg.isInstalled {
            if checker.brewPath != nil {
                triggerInstall(package: "ffmpeg", display: "ffmpeg")
            }
        }
    }

    private func triggerInstall(package: String, display: String) {
        pendingInstallPackage = package
        pendingInstallDisplayName = display
        showDependencySheet = true
    }

    private func checkUpdateBanners() {
        if let avail = checker.ytdlp.availableVersion, !avail.isEmpty {
            let skipKey = "skipVersion_yt-dlp"
            let remindKey = "remindTomorrow_yt-dlp"
            let skipped = UserDefaults.standard.string(forKey: skipKey) ?? ""
            let remindTime = UserDefaults.standard.double(forKey: remindKey)
            let now = Date().timeIntervalSince1970
            if skipped != avail && (remindTime == 0 || now - remindTime > 86400) {
                showYTDLPUpdateBanner = true
            }
        }
        if let avail = checker.ffmpeg.availableVersion, !avail.isEmpty {
            let skipKey = "skipVersion_ffmpeg"
            let remindKey = "remindTomorrow_ffmpeg"
            let skipped = UserDefaults.standard.string(forKey: skipKey) ?? ""
            let remindTime = UserDefaults.standard.double(forKey: remindKey)
            let now = Date().timeIntervalSince1970
            if skipped != avail && (remindTime == 0 || now - remindTime > 86400) {
                showFFmpegUpdateBanner = true
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}

struct BannerView: View {
    let message: String
    let icon: String
    let color: Color
    let actionLabel: String?
    let onAction: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.onSurface)
            Spacer()
            if let label = actionLabel, let action = onAction {
                Button(label, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appPrimary)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundColor(.onSurfaceVariant.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
    }
}
