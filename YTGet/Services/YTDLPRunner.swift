import Foundation

struct VideoInfo {
    let title: String
    let thumbnailURL: URL?
    let duration: Int?
}

enum YTDLPError: Error {
    case notFound
    case fetchFailed(String)
    case downloadFailed(String)
    case processKilled
}

final class YTDLPRunner {

    static func executablePath() -> String? {
        let paths = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp"]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Returns a Process with PATH augmented to include Homebrew bin dirs,
    /// so yt-dlp can find ffmpeg and other tools at runtime.
    private static func makeProcess(path: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        var env = ProcessInfo.processInfo.environment
        let existing = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(existing)"
        process.environment = env
        return process
    }

    func buildArgs(for item: DownloadItem, outputDir: URL) -> [String] {
        let opts = item.formatOptions
        var args: [String] = []

        switch opts.format {
        case .video:
            args += ["--format", opts.quality.formatString]
            args += ["--merge-output-format", "mp4"]
            if opts.embedMetadata { args += ["--embed-metadata"] }
        case .audioOnly:
            args += ["--extract-audio", "--audio-format", "mp3", "--audio-quality", opts.audioQuality.audioQualityFlag]
            if opts.embedThumbnail { args += ["--embed-thumbnail"] }
            if opts.embedMetadata { args += ["--embed-metadata"] }
        case .transcript:
            let lang = opts.subtitleLanguage.trimmingCharacters(in: .whitespaces).isEmpty ? "en" : opts.subtitleLanguage
            args += ["--write-subs", "--write-auto-subs", "--sub-langs", lang]
            args += ["--convert-subs", "srt", "--skip-download"]
        }

        let template = opts.filenameTemplate.isEmpty ? "%(title)s.%(ext)s" : opts.filenameTemplate
        let outputTemplate = outputDir.path + "/" + template
        args += ["--output", outputTemplate]
        args += ["--newline"]
        if item.forceOverwrite { args += ["--force-overwrites"] }
        args += [item.url]

        return args
    }

    func fetchInfo(url: String) async throws -> VideoInfo {
        guard let ytdlpPath = YTDLPRunner.executablePath() else {
            throw YTDLPError.notFound
        }

        let process = YTDLPRunner.makeProcess(path: ytdlpPath)
        process.arguments = ["--dump-json", "--no-playlist", url]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw YTDLPError.fetchFailed("Failed to launch yt-dlp: \(error.localizedDescription)")
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n").first ?? "Unknown error"
            throw YTDLPError.fetchFailed(String(errMsg.prefix(120)))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YTDLPError.fetchFailed("Could not parse video info")
        }

        let title = json["title"] as? String ?? url
        let thumbnailStr = json["thumbnail"] as? String
        let thumbnailURL = thumbnailStr.flatMap { URL(string: $0) }
        let duration = json["duration"] as? Int

        return VideoInfo(title: title, thumbnailURL: thumbnailURL, duration: duration)
    }

    func download(item: DownloadItem, outputDir: URL) -> AsyncStream<ProgressUpdate> {
        AsyncStream { continuation in
            guard let ytdlpPath = YTDLPRunner.executablePath() else {
                continuation.finish()
                return
            }

            let process = YTDLPRunner.makeProcess(path: ytdlpPath)
            process.arguments = self.buildArgs(for: item, outputDir: outputDir)

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            item.process = process

            do {
                try process.run()
            } catch {
                continuation.finish()
                return
            }

            // Read stdout in a detached task so the pipe is drained continuously.
            // readabilityHandler can stall when the pipe buffer fills faster than
            // the GCD callback queue drains it (common for multi-stream video).
            Task.detached {
                var lineBuffer = ""
                // yt-dlp downloads video and audio as separate streams for bestvideo+bestaudio.
                // Each stream progresses 0→100%, so we normalise across streams to get a
                // single smooth 0→100% in the UI.
                // We detect stream boundaries via "[download] Destination: ...fNNN..." lines.
                var streamIndex = 0      // which stream we're currently on (0-based)
                var isMultiStream = false
                let handle = outPipe.fileHandleForReading

                while true {
                    let chunk = handle.availableData   // blocks until data arrives or EOF
                    guard !chunk.isEmpty else { break }
                    guard let text = String(data: chunk, encoding: .utf8) else { continue }

                    lineBuffer += text
                    while let nl = lineBuffer.firstIndex(of: "\n") {
                        let line = String(lineBuffer[lineBuffer.startIndex..<nl])
                            .trimmingCharacters(in: .whitespaces)
                        lineBuffer.removeSubrange(lineBuffer.startIndex...nl)

                        // "[download] Destination: title.fNNN.ext" → fragment file = multi-stream
                        if line.hasPrefix("[download] Destination:") {
                            let isFragment = line.range(of: #"\.f\d+\."#, options: .regularExpression) != nil
                            if isFragment {
                                if isMultiStream {
                                    streamIndex += 1   // second stream starting
                                } else {
                                    isMultiStream = true
                                    streamIndex = 0
                                }
                            }
                            continue
                        }

                        if var update = ProgressParser.parse(line) {
                            if let pct = update.percentage, isMultiStream {
                                // Map each stream's 0–100 into its half of the overall bar.
                                // Stream 0 → 0–50%, stream 1 → 50–100%.
                                update.percentage = Double(streamIndex) * 50.0 + pct * 0.5
                            }
                            continuation.yield(update)
                        }
                    }
                }

                // Drain any remaining stderr for error messages
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errText = String(data: errData, encoding: .utf8) ?? ""

                process.waitUntilExit()

                if process.terminationReason == .uncaughtSignal {
                    var errUpdate = ProgressUpdate()
                    errUpdate.errorMessage = "Process ended unexpectedly"
                    continuation.yield(errUpdate)
                    continuation.finish()
                    return
                }

                if process.terminationStatus == 0 {
                    continuation.yield(ProgressUpdate(
                        percentage: 100, fileSize: nil, speed: nil, eta: nil, isComplete: true
                    ))
                } else {
                    let rawError = errText
                        .components(separatedBy: "\n")
                        .first(where: { $0.contains("ERROR:") })?
                        .replacingOccurrences(of: "ERROR: ", with: "")
                        .trimmingCharacters(in: .whitespaces)
                        ?? "Download failed (exit \(process.terminationStatus))"

                    let errorLine: String
                    let lower = rawError.lowercased()
                    if lower.contains("network") || lower.contains("connection") ||
                       lower.contains("timed out") || lower.contains("no route") ||
                       lower.contains("name or service not known") || lower.contains("unreachable") {
                        errorLine = "No network connection"
                    } else {
                        errorLine = String(rawError.prefix(120))
                    }

                    var errUpdate = ProgressUpdate()
                    errUpdate.errorMessage = errorLine
                    continuation.yield(errUpdate)
                }
                continuation.finish()
            }
        }
    }
}
