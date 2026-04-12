import Foundation
import AppKit
import UserNotifications

@Observable
@MainActor
final class DownloadManager {
    var items: [DownloadItem] = []
    var outputFolder: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    var globalFormat: FormatOptions.Format = .video
    var globalQuality: FormatOptions.VideoQuality = .best
    var globalAudioQuality: FormatOptions.AudioQuality = .best
    var globalSubtitleLanguage: String = "en"
    var isProcessingQueue = false

    private let runner = YTDLPRunner()
    private let outputFolderKey = "outputFolder"
    private let filenameTemplateKey = "filenameTemplate"
    private let embedThumbnailKey = "embedThumbnail"
    private let embedMetadataKey = "embedMetadata"
    private let transcriptIncludeTimestampsKey = "transcriptIncludeTimestamps"
    private let queueKey = "downloadQueue"

    var filenameTemplate: String {
        get { UserDefaults.standard.string(forKey: filenameTemplateKey) ?? "%(title)s.%(ext)s" }
        set { UserDefaults.standard.set(newValue, forKey: filenameTemplateKey) }
    }
    var embedThumbnail: Bool {
        get { UserDefaults.standard.object(forKey: embedThumbnailKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: embedThumbnailKey) }
    }
    var embedMetadata: Bool {
        get { UserDefaults.standard.object(forKey: embedMetadataKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: embedMetadataKey) }
    }
    var transcriptIncludeTimestamps: Bool {
        get { UserDefaults.standard.object(forKey: transcriptIncludeTimestampsKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: transcriptIncludeTimestampsKey) }
    }

    init() {
        loadPreferences()
        loadQueue()
    }

    func loadPreferences() {
        if let bookmarkData = UserDefaults.standard.data(forKey: outputFolderKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData,
                                  options: .withSecurityScope,
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) {
                outputFolder = url
                return
            }
        }
        if let path = UserDefaults.standard.string(forKey: outputFolderKey + "_path") {
            outputFolder = URL(fileURLWithPath: path)
        }
    }

    func saveOutputFolder(_ url: URL) {
        outputFolder = url
        UserDefaults.standard.set(url.path, forKey: outputFolderKey + "_path")
        if let bookmarkData = try? url.bookmarkData(options: .withSecurityScope,
                                                     includingResourceValuesForKeys: nil,
                                                     relativeTo: nil) {
            UserDefaults.standard.set(bookmarkData, forKey: outputFolderKey)
        }
    }

    func addURL(_ urlString: String) {
        let url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else { return }

        var opts = FormatOptions()
        opts.format = globalFormat
        opts.quality = globalQuality
        opts.audioQuality = globalAudioQuality
        opts.subtitleLanguage = globalSubtitleLanguage
        opts.includeTimestamps = transcriptIncludeTimestamps
        opts.filenameTemplate = filenameTemplate
        opts.embedThumbnail = embedThumbnail
        opts.embedMetadata = embedMetadata

        let item = DownloadItem(url: url, formatOptions: opts)
        item.status = .fetchingInfo
        items.append(item)
        saveQueue()

        Task { await fetchInfo(for: item) }
    }

    private func fetchInfo(for item: DownloadItem) async {
        do {
            let info = try await runner.fetchInfo(url: item.url)
            item.title = info.title
            item.thumbnailURL = info.thumbnailURL
            if let thumbURL = info.thumbnailURL {
                await loadThumbnail(for: item, from: thumbURL)
            }
        } catch {
            item.title = item.url
        }
        // Always transition to pending and kick the queue,
        // regardless of whether info fetch succeeded.
        item.status = .pending
        await processQueue()
    }

    private func loadThumbnail(for item: DownloadItem, from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                item.thumbnailImage = image
            }
        } catch {}
    }

    func processQueue() async {
        guard !isProcessingQueue else { return }
        isProcessingQueue = true
        defer { isProcessingQueue = false }

        while let next = items.first(where: { $0.status == .pending }) {
            await downloadItem(next)
        }
    }

    private func downloadItem(_ item: DownloadItem) async {
        let downloadStartTime = Date()
        item.status = .downloading
        item.progress = 0

        let stream = runner.download(item: item, outputDir: outputFolder)

        var lastUpdate = Date()
        var failureMessage: String? = nil
        for await update in stream {
            if let errMsg = update.errorMessage {
                failureMessage = errMsg
                continue
            }
            let now = Date()
            if now.timeIntervalSince(lastUpdate) >= 0.1 || update.isComplete {
                if let pct = update.percentage {
                    item.progress = pct / 100.0
                }
                if let speed = update.speed { item.speed = speed }
                if let eta = update.eta { item.eta = eta }
                lastUpdate = now
            }
        }

        if item.status == .downloading {
            if item.process?.terminationReason == .uncaughtSignal {
                item.status = .cancelled
            } else if item.process?.terminationStatus == 0 {
                item.status = .completed
                item.progress = 1.0
                item.speed = ""
                item.eta = ""
                if item.formatOptions.format == .transcript && !item.formatOptions.includeTimestamps {
                    processTranscripts(for: item, startedAfter: downloadStartTime)
                }
                sendNotification(for: item)
            } else {
                item.status = .failed(failureMessage ?? "Download failed")
            }
            saveQueue()
        }
    }

    func cancelItem(_ item: DownloadItem) {
        item.process?.terminate()
        item.status = .cancelled
        items.removeAll { $0.id == item.id }
        saveQueue()
        Task { cleanupPartialFiles(for: item) }
    }

    private func cleanupPartialFiles(for item: DownloadItem) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: outputFolder,
            includingPropertiesForKeys: nil
        ) else { return }

        for url in contents {
            let name = url.lastPathComponent
            // yt-dlp partial download files and temp fragment files
            let isPartial = name.hasSuffix(".part")
                || name.hasSuffix(".ytdl")
                || name.range(of: #"\.f\d+\.\w+$"#, options: .regularExpression) != nil
            if isPartial {
                try? fm.removeItem(at: url)
            }
        }
    }

    func retryItem(_ item: DownloadItem) {
        item.status = .pending
        item.progress = 0
        item.speed = ""
        item.eta = ""
        Task { await processQueue() }
    }

    func clearCompleted() {
        items.removeAll { $0.status.isFinal && $0.status != .failed("") }
        saveQueue()
    }

    // MARK: - Queue Persistence

    private func saveQueue() {
        let persisted = items.map { $0.toPersistedItem() }
        if let data = try? JSONEncoder().encode(persisted) {
            UserDefaults.standard.set(data, forKey: queueKey)
        }
    }

    private func loadQueue() {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let persisted = try? JSONDecoder().decode([PersistedItem].self, from: data) else { return }

        items = persisted.map { DownloadItem.from($0) }

        // Re-fetch thumbnail images in the background
        for item in items where item.thumbnailURL != nil {
            Task { await loadThumbnail(for: item, from: item.thumbnailURL!) }
        }
    }

    private func processTranscripts(for item: DownloadItem, startedAfter startTime: Date) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: outputFolder,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        for url in contents where url.pathExtension == "srt" {
            guard let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modDate = attrs.contentModificationDate,
                  modDate >= startTime else { continue }

            guard let srtContent = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let markdown = TranscriptProcessor.toMarkdown(from: srtContent, title: item.title, sourceURL: item.url)

            // VideoTitle.en.srt → VideoTitle.md
            let mdURL = url.deletingPathExtension().deletingPathExtension().appendingPathExtension("md")
            try? markdown.write(to: mdURL, atomically: true, encoding: .utf8)
            try? fm.removeItem(at: url)
            item.outputPath = mdURL
        }
    }

    private func sendNotification(for item: DownloadItem) {
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = item.title.isEmpty ? "Your download is ready." : item.title
        content.sound = .default

        if let outputPath = item.outputPath {
            content.userInfo = ["outputPath": outputPath.path]
        } else {
            content.userInfo = ["outputFolder": outputFolder.path]
        }

        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
