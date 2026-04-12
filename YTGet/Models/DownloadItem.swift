import Foundation
import AppKit

enum DownloadStatus: Equatable {
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
}

struct FormatOptions {
    enum Format {
        case video
        case audioOnly
    }
    enum VideoQuality: String, CaseIterable {
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

    enum AudioQuality: String, CaseIterable {
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
    var filenameTemplate: String = "%(title)s.%(ext)s"
    var embedThumbnail: Bool = true
    var embedMetadata: Bool = true
}

@Observable
final class DownloadItem: Identifiable {
    let id = UUID()
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

    init(url: String, formatOptions: FormatOptions = FormatOptions()) {
        self.url = url
        self.formatOptions = formatOptions
    }
}
