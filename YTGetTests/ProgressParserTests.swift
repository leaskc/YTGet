import XCTest
@testable import YTGet

final class ProgressParserTests: XCTestCase {

    func testParsesStandardProgressLine() {
        let line = "[download]  45.3% of 123.45MiB at 2.50MiB/s ETA 00:30"
        let update = ProgressParser.parse(line)
        XCTAssertNotNil(update)
        XCTAssertEqual(update?.percentage, 45.3)
        XCTAssertEqual(update?.fileSize, "123.45MiB")
        XCTAssertEqual(update?.speed, "2.50MiB/s")
        XCTAssertEqual(update?.eta, "00:30")
        XCTAssertFalse(update?.isComplete ?? true)
    }

    func testParsesCompletionLine() {
        let line = "[download] 100% of 123.45MiB at 5.00MiB/s ETA 00:00"
        let update = ProgressParser.parse(line)
        XCTAssertNotNil(update)
        XCTAssertEqual(update?.percentage, 100.0)
        XCTAssertTrue(update?.isComplete ?? false)
    }

    func testReturnsNilForIrrelevantLines() {
        let lines = [
            "[info] Downloading...",
            "[ffmpeg] Merging formats into output.mp4",
            "Deleting original file",
            "",
            "Some random text"
        ]
        for line in lines {
            XCTAssertNil(ProgressParser.parse(line), "Expected nil for: \(line)")
        }
    }

    func testParsesKibibyteSpeeds() {
        let line = "[download]   5.0% of 50.00MiB at 512.00KiB/s ETA 01:39"
        let update = ProgressParser.parse(line)
        XCTAssertNotNil(update)
        XCTAssertEqual(update?.percentage, 5.0)
        XCTAssertEqual(update?.speed, "512.00KiB/s")
    }

    func testExtractsErrorMessage() {
        let line = "ERROR: Video unavailable. The uploader has not made this video available."
        let msg = ProgressParser.extractErrorMessage(line)
        XCTAssertNotNil(msg)
        XCTAssertTrue(msg?.contains("Video unavailable") ?? false)
    }

    func testErrorMessageTruncatedTo120Chars() {
        let longError = "ERROR: " + String(repeating: "x", count: 200)
        let msg = ProgressParser.extractErrorMessage(longError)
        XCTAssertNotNil(msg)
        XCTAssertLessThanOrEqual(msg?.count ?? 0, 120)
    }

    func testHandlesLeadingWhitespace() {
        let line = "  [download]  89.9% of 200.00MiB at 3.10MiB/s ETA 00:10  "
        let update = ProgressParser.parse(line.trimmingCharacters(in: .whitespaces))
        XCTAssertNotNil(update)
        XCTAssertEqual(update?.percentage, 89.9)
    }
}
