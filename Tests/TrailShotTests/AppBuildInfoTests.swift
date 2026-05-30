@testable import TrailShot
import XCTest

final class AppBuildInfoTests: XCTestCase {
    func testBuildInfoReadsBundleMetadata() {
        let info = AppBuildInfo(infoDictionary: [
            "CFBundleDisplayName": "TrailShot",
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "45",
            "TrailShotBuildCommit": "abc1234",
            "TrailShotReleaseChannel": "internal"
        ])

        XCTAssertEqual(info.name, "TrailShot")
        XCTAssertEqual(info.displayVersion, "1.2.3 (45)")
        XCTAssertEqual(info.releaseSummary, "Internal - abc1234")
    }

    func testBuildInfoUsesStableFallbacks() {
        let info = AppBuildInfo(infoDictionary: [:])

        XCTAssertEqual(info.name, "TrailShot")
        XCTAssertEqual(info.displayVersion, "0.1.0 (0)")
        XCTAssertEqual(info.releaseSummary, "Development - unknown")
        XCTAssertEqual(AppBuildInfo.releasesURL.absoluteString, "https://github.com/jonathan-arteaga/trail-shot-app/releases")
    }
}
