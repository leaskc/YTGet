import Foundation
import AppKit

enum DownloadStatus: Equatable, Codable {
    case pending
    case fetchingInfo
    case downloading
    case completed
    case failed(String)
    case cancelled

    var isFinal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        default: return false
        }
    }

    // MARK: Codable
    private enum CodingKeys: String, CodingKey { case type, message }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pending:      try c.encode("pending",      forKey: .type)
        case .fetchingInfo: try c.encode("fetchingInfo", forKey: .type)
        case .downloading:  try c.encode("downloading",  forKey: .type)
        case .completed:    try c.encode("completed",    forKey: .type)
        case .cancelled:    try c.encode("cancelled",    forKey: .type)
        case .failed(let msg):
            try c.encode("failed", forKey: .type)
            try c.encode(msg,      forKey: .message)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "pending":      self = .pending
        case "fetchingInfo": self = .fetchingInfo
        case "downloading":  self = .downloading
        case "completed":    self = .completed
        case "cancelled":    self = .cancelled
        case "failed":
            let msg = try c.decodeIfPresent(String.self, forKey: .message) ?? ""
            self = .failed(msg)
        default:             self = .failed("Unknown")
        }
    }
}

struct FormatOptions: Codable {
    enum Format: String, Codable {
        case video
        case audioOnly
        case transcript
    }
    enum VideoQuality: String, CaseIterable, Codable {
        case best   = "Best"
        case q2160  = "4K"
        case q1080  = "1080p"
        case q720   = "720p"

        var formatString: String {
            switch self {
            case .best:  return "bestvideo+bestaudio/best"
            case .q2160: return "bestvideo[height<=2160]+bestaudio/best[height<=2160]/best"
            case .q1080: return "bestvideo[height<=1080]+bestaudio/best[height<=1080]/best"
            case .q720:  return "bestvideo[height<=720]+bestaudio/best[height<=720]/best"
            }
        }
    }

    enum AudioQuality: String, CaseIterable, Codable {
        case best  = "Best"
        case q320  = "320k"
        case q192  = "192k"
        case q128  = "128k"

        var audioQualityFlag: String {
            switch self {
            case .best: return "0"
            case .q320: return "320K"
            case .q192: return "192K"
            case .q128: return "128K"
            }
        }
    }

    var format: Format = .video
    var quality: VideoQuality = .best
    var audioQuality: AudioQuality = .best
    var subtitleLanguage: String = "en"
    var includeTimestamps: Bool = false
    var filenameTemplate: String = "%(title)s.%(ext)s"
    var embedThumbnail: Bool = true
    var embedMetadata: Bool = true
}

// Codable snapshot of a DownloadItem for queue persistence.
struct PersistedItem: Codable {
    let id: UUID
    let url: String
    let title: String
    let thumbnailURL: URL?
    let status: DownloadStatus
    let formatOptions: FormatOptions
    let outputPath: URL?
    let progress: Double
}

@Observable
final class DownloadItem: Identifiable {
    let id: UUID
    let url: String
    var title: String = ""
    var thumbnailURL: URL?
    var thumbnailImage: NSImage?
    var progress: Double = 0
    var speed: String = ""
    var eta: String = ""
    var status: DownloadStatus = .pending
    var formatOptions: FormatOptions
    var outputPath: URL?
    var process: Process?
    /// Set at runtime when the user chooses to overwrite an existing file.
    /// Not persisted — resets to false on restore so the conflict prompt reruns if needed.
    var forceOverwrite: Bool = false

    init(url: String, formatOptions: FormatOptions = FormatOptions(), id: UUID = UUID()) {
        self.id = id
        self.url = url
        self.formatOptions = formatOptions
    }

    func toPersistedItem() -> PersistedItem {
        PersistedItem(
            id: id,
            url: url,
            title: title,
            thumbnailURL: thumbnailURL,
            status: status,
            formatOptions: formatOptions,
            outputPath: outputPath,
            progress: progress
        )
    }

    static func from(_ persisted: PersistedItem) -> DownloadItem {
        let item = DownloadItem(url: persisted.url, formatOptions: persisted.formatOptions, id: persisted.id)
        item.title = persisted.title.isEmpty ? persisted.url : persisted.title
        item.thumbnailURL = persisted.thumbnailURL
        item.outputPath = persisted.outputPath
        item.progress = persisted.progress

        switch persisted.status {
        case .downloading, .pending, .fetchingInfo:
            item.status = .failed("Interrupted")
        default:
            item.status = persisted.status
        }

        return item
    }
}
