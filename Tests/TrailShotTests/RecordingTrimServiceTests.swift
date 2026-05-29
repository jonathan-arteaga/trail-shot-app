@testable import TrailShot
import XCTest

final class RecordingTrimServiceTests: XCTestCase {
    func testValidatedTimeRangeClampsToDuration() throws {
        let range = try RecordingTrimService.validatedTimeRange(start: -2, end: 12, duration: 10)

        XCTAssertEqual(range.start.seconds, 0, accuracy: 0.001)
        XCTAssertEqual(range.end.seconds, 10, accuracy: 0.001)
    }

    func testValidatedTimeRangeRejectsTinyOrMissingRanges() {
        XCTAssertThrowsError(try RecordingTrimService.validatedTimeRange(start: 2, end: 2.1, duration: 10))
        XCTAssertThrowsError(try RecordingTrimService.validatedTimeRange(start: 0, end: 1, duration: 0))
    }
}
