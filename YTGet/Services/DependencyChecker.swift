import Foundation

struct DependencyInfo {
    let name: String
    let executableName: String
    let brewPackage: String
    var installedVersion: String?
    var availableVersion: String?

    var isInstalled: Bool { installedVersion != nil }
    var hasUpdate: Bool {
        guard let installed = installedVersion, let available = availableVersion else { return false }
        return installed != available
    }
}

enum DependencyError: Error {
    case brewNotFound
    case installFailed(String)
    case checkFailed(String)
}

@Observable
final class DependencyChecker {
    var ytdlp = DependencyInfo(name: "yt-dlp", executableName: "yt-dlp", brewPackage: "yt-dlp")
    var ffmpeg = DependencyInfo(name: "ffmpeg", executableName: "ffmpeg", brewPackage: "ffmpeg")
    var isChecking = false
    var installOutput: [String] = []
    var isInstalling = false

    var statusBarText: String {
        var parts: [String] = []
        if let v = ytdlp.installedVersion { parts.append("yt-dlp \(v)") }
        if let v = ffmpeg.installedVersion { parts.append("ffmpeg \(v)") }
        return parts.isEmpty ? "Checking dependencies..." : parts.joined(separator: " · ")
    }

    static let brewPaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]

    var brewPath: String? {
        DependencyChecker.brewPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    func executablePath(for name: String) -> String? {
        let paths = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    @MainActor
    func checkAll() async {
        isChecking = true
        ytdlp.installedVersion = await resolvedVersion(for: ytdlp.executableName)
        ffmpeg.installedVersion = await resolvedVersion(for: ffmpeg.executableName)
        isChecking = false
    }

    private func resolvedVersion(for executableName: String) async -> String? {
        guard let path = executablePath(for: executableName) else { return nil }
        // Binary exists at the expected path — consider it installed regardless of
        // whether the version command succeeds (some ffmpeg builds write to stderr).
        return await getVersion(path: path, args: ["--version"]) ?? "installed"
    }

    private func getVersion(path: String, args: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            var env = ProcessInfo.processInfo.environment
            let existing = env["PATH"] ?? "/usr/bin:/bin"
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(existing)"
            process.environment = env
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            do {
                try process.run()
                process.waitUntilExit()
                // Try stdout first, fall back to stderr (ffmpeg writes there)
                for pipe in [outPipe, errPipe] {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let line = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: "\n").first,
                       !line.isEmpty {
                        continuation.resume(returning: line)
                        return
                    }
                }
                continuation.resume(returning: nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    @MainActor
    func checkForUpdates() async {
        guard let brew = brewPath else { return }
        for packageName in [ytdlp.brewPackage, ffmpeg.brewPackage] {
            let available = await runBrewOutdated(brew: brew, package: packageName)
            if packageName == ytdlp.brewPackage {
                ytdlp.availableVersion = available
            } else {
                ffmpeg.availableVersion = available
            }
        }
    }

    private func runBrewOutdated(brew: String, package: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = ["outdated", "--verbose", package]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                // brew outdated output: "package (current) < (latest)"
                if output.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    let parts = output.components(separatedBy: " ")
                    continuation.resume(returning: parts.last ?? output)
                }
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    func install(package: String, onOutput: @escaping (String) -> Void) async throws {
        guard let brew = brewPath else {
            throw DependencyError.brewNotFound
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brew)
        process.arguments = ["install", package]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let outputHandle = outPipe.fileHandleForReading
        let errorHandle = errPipe.fileHandleForReading

        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async { onOutput(line) }
            }
        }
        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async { onOutput(line) }
            }
        }

        try process.run()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil
                continuation.resume()
            }
        }

        if process.terminationStatus != 0 {
            throw DependencyError.installFailed("brew install \(package) exited with code \(process.terminationStatus)")
        }
    }

    func upgrade(package: String, onOutput: @escaping (String) -> Void) async throws {
        guard let brew = brewPath else {
            throw DependencyError.brewNotFound
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: brew)
        process.arguments = ["upgrade", package]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let outputHandle = outPipe.fileHandleForReading
        let errorHandle = errPipe.fileHandleForReading

        outputHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async { onOutput(line) }
            }
        }
        errorHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if let line = String(data: data, encoding: .utf8), !line.isEmpty {
                DispatchQueue.main.async { onOutput(line) }
            }
        }

        try process.run()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in
                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil
                continuation.resume()
            }
        }

        if process.terminationStatus != 0 {
            throw DependencyError.installFailed("brew upgrade \(package) exited with code \(process.terminationStatus)")
        }
    }
}
