import CoreGraphics
@testable import TrailShot
import XCTest

final class WindowPickerTests: XCTestCase {
    func testWindowCandidateSearchMatchesTitleAppAndSize() {
        let candidate = CaptureWindowCandidate(
            id: 42,
            title: "Opportunity Workspace",
            appName: "Safari",
            frame: CGRect(x: 20, y: 40, width: 1440, height: 900)
        )

        XCTAssertTrue(candidate.matchesWindowSearch(""))
        XCTAssertTrue(candidate.matchesWindowSearch("opportunity"))
        XCTAssertTrue(candidate.matchesWindowSearch("safari"))
        XCTAssertTrue(candidate.matchesWindowSearch("1440 x 900"))
        XCTAssertFalse(candidate.matchesWindowSearch("slack"))
    }

    func testWindowCandidateSearchUsesAppNameWhenTitleIsEmpty() {
        let candidate = CaptureWindowCandidate(
            id: 7,
            title: "",
            appName: "Code",
            frame: CGRect(x: 0, y: 0, width: 900, height: 600)
        )

        XCTAssertEqual(candidate.displayTitle, "Code")
        XCTAssertTrue(candidate.matchesWindowSearch("code"))
        XCTAssertTrue(candidate.matchesWindowSearch("900"))
    }
}
