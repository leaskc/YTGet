import Foundation

struct TranscriptProcessor {

    /// Converts SRT subtitle content into clean readable markdown,
    /// grouping text into paragraphs by sentence boundaries.
    static func toMarkdown(from srt: String, title: String = "", sourceURL: String = "") -> String {
        let textLines = extractLines(from: srt)
        guard !textLines.isEmpty else { return "" }

        var header = ""
        if !title.isEmpty { header += "# \(title)\n" }
        if !sourceURL.isEmpty { header += "url: \(sourceURL)\n" }
        if !header.isEmpty { header += "\n" }

        // Join all caption fragments into one continuous string
        let fullText = textLines.joined(separator: " ")

        // Split into sentences at . ! ? boundaries
        let sentences = splitIntoSentences(fullText)

        // Group sentences into paragraphs (~5 sentences each)
        // If no sentence boundaries were found, fall back to grouping raw lines
        let body: String
        if sentences.count > 1 {
            body = sentences
                .chunked(by: 5)
                .map { $0.joined(separator: " ") }
                .joined(separator: "\n\n")
        } else {
            // No punctuation (common in auto-captions) — group every 8 lines
            body = textLines
                .chunked(by: 8)
                .map { $0.joined(separator: " ") }
                .joined(separator: "\n\n")
        }

        return header + body
    }

    // MARK: - Private

    private static let timestampRegex = try! NSRegularExpression(
        pattern: #"^\d{2}:\d{2}:\d{2}[,\.]\d{3} --> \d{2}:\d{2}:\d{2}[,\.]\d{3}"#
    )
    private static let indexRegex = try! NSRegularExpression(pattern: #"^\d+$"#)
    private static let htmlTagRegex = try! NSRegularExpression(pattern: #"<[^>]+>"#)

    private static func extractLines(from srt: String) -> [String] {
        var lines: [String] = []
        var last = ""

        for raw in srt.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let range = NSRange(line.startIndex..., in: line)
            if indexRegex.firstMatch(in: line, range: range) != nil { continue }
            if timestampRegex.firstMatch(in: line, range: range) != nil { continue }

            var cleaned = htmlTagRegex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
            cleaned = cleaned
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .trimmingCharacters(in: .whitespaces)

            guard !cleaned.isEmpty, cleaned != last else { continue }
            last = cleaned
            lines.append(cleaned)
        }

        return lines
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if (char == "." || char == "!" || char == "?"), current.count > 15 {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }
        let remainder = current.trimmingCharacters(in: .whitespaces)
        if !remainder.isEmpty { sentences.append(remainder) }

        return sentences
    }
}

private extension Array {
    func chunked(by size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
