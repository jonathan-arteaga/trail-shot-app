import CoreGraphics
@testable import TrailShot
import XCTest

final class ScreenCaptureServiceTests: XCTestCase {
    func testDisplaySlicesStitchSelectionAcrossDisplays() {
        let displayFrames = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 0, width: 1280, height: 900)
        ]
        let selection = CGRect(x: 1300, y: 120, width: 300, height: 220)

        let slices = ScreenCaptureService.displaySlices(for: selection, displayFrames: displayFrames)

        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices[0].sourceRect, CGRect(x: 1300, y: 120, width: 140, height: 220))
        XCTAssertEqual(slices[0].destinationRect, CGRect(x: 0, y: 0, width: 140, height: 220))
        XCTAssertEqual(slices[1].sourceRect, CGRect(x: 1440, y: 120, width: 160, height: 220))
        XCTAssertEqual(slices[1].destinationRect, CGRect(x: 140, y: 0, width: 160, height: 220))
    }

    func testDisplaySlicesIgnoreDisplaysOutsideSelection() {
        let displayFrames = [
            CGRect(x: -1280, y: 0, width: 1280, height: 720),
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 0, width: 1280, height: 900)
        ]
        let selection = CGRect(x: 100, y: 80, width: 420, height: 260)

        let slices = ScreenCaptureService.displaySlices(for: selection, displayFrames: displayFrames)

        XCTAssertEqual(slices, [
            ScreenCaptureDisplaySlice(
                displayFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                sourceRect: selection,
                destinationRect: CGRect(origin: .zero, size: selection.size)
            )
        ])
    }

    func testDesktopFrameUnionsDisplaysForFullScreenCapture() {
        let displayFrames = [
            CGRect(x: -1280, y: 160, width: 1280, height: 720),
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 80, width: 1280, height: 800)
        ]

        let desktopFrame = ScreenCaptureService.desktopFrame(displayFrames: displayFrames)

        XCTAssertEqual(desktopFrame, CGRect(x: -1280, y: 0, width: 4000, height: 900))
    }

    func testDisplaySlicesCoverAllDisplaysFromDesktopFrame() throws {
        let displayFrames = [
            CGRect(x: -1280, y: 160, width: 1280, height: 720),
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 80, width: 1280, height: 800)
        ]
        let desktopFrame = try XCTUnwrap(ScreenCaptureService.desktopFrame(displayFrames: displayFrames))

        let slices = ScreenCaptureService.displaySlices(for: desktopFrame, displayFrames: displayFrames)

        XCTAssertEqual(slices.count, 3)
        XCTAssertEqual(slices[0].sourceRect, CGRect(x: -1280, y: 160, width: 1280, height: 720))
        XCTAssertEqual(slices[0].destinationRect, CGRect(x: 0, y: 160, width: 1280, height: 720))
        XCTAssertEqual(slices[1].sourceRect, CGRect(x: 0, y: 0, width: 1440, height: 900))
        XCTAssertEqual(slices[1].destinationRect, CGRect(x: 1280, y: 0, width: 1440, height: 900))
        XCTAssertEqual(slices[2].sourceRect, CGRect(x: 1440, y: 80, width: 1280, height: 800))
        XCTAssertEqual(slices[2].destinationRect, CGRect(x: 2720, y: 80, width: 1280, height: 800))
    }
}
