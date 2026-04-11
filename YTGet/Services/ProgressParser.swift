import Foundation

struct ProgressUpdate {
    var percentage: Double?
    var fileSize: String?
    var speed: String?
    var eta: String?
    var isComplete: Bool = false
    var errorMessage: String? = nil
}

struct ProgressParser {
    // Matches: [download]  45.3% of 123.45MiB at 2.50MiB/s ETA 00:30
    private static let downloadPattern = #/\[download\]\s+([\d.]+)%\s+of\s+([\d.]+\w+)\s+at\s+([\d.]+\w+/s)\s+ETA\s+([\d:]+)/#

    // Matches completion: [download] 100% of ...
    private static let completePattern = #/\[download\]\s+100%/#

    static func parse(_ line: String) -> ProgressUpdate? {
        if let match = line.firstMatch(of: downloadPattern) {
            var update = ProgressUpdate()
            update.percentage = Double(match.output.1)
            update.fileSize = String(match.output.2)
            update.speed = String(match.output.3)
            update.eta = String(match.output.4)
            update.isComplete = update.percentage == 100.0
            return update
        }
        if line.contains("[download] 100%") {
            return ProgressUpdate(percentage: 100, fileSize: nil, speed: nil, eta: "00:00", isComplete: true)
        }
        return nil
    }

    static func extractErrorMessage(_ line: String) -> String? {
        let errorPrefixes = ["ERROR:", "error:", "Warning:"]
        for prefix in errorPrefixes {
            if line.contains(prefix) {
                let parts = line.components(separatedBy: prefix)
                if let message = parts.last?.trimmingCharacters(in: .whitespaces) {
                    return String(message.prefix(120))
                }
            }
        }
        return nil
    }
}
