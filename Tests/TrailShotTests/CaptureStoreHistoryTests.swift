import AppKit
@testable import TrailShot
import XCTest

final class CaptureStoreHistoryTests: XCTestCase {
    @MainActor
    func testRenameDeleteAndClearHistory() {
        let store = CaptureStore()
        let first = makeCapture(name: "First")
        let second = makeCapture(name: "Second")
        store.captures = [first, second]
        store.selectedCaptureID = first.id
        store.pinnedCaptures = [
            PinnedCapture(captureID: first.id, title: first.name, createdAt: Date(), pixelSize: first.pixelSize)
        ]

        store.renameSelectedCapture("  Updated  ")
        XCTAssertEqual(store.captures.first?.name, "Updated")

        store.deleteSelectedCapture()
        XCTAssertEqual(store.captures.map(\.id), [second.id])
        XCTAssertEqual(store.selectedCaptureID, second.id)
        XCTAssertTrue(store.pinnedCaptures.isEmpty)

        store.clearCaptureHistory()
        XCTAssertTrue(store.captures.isEmpty)
        XCTAssertNil(store.selectedCaptureID)
    }

    @MainActor
    private func makeCapture(name: String) -> CaptureItem {
        let image = NSImage(size: NSSize(width: 120, height: 80))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 120, height: 80).fill()
        image.unlockFocus()

        return CaptureItem(
            kind: .area,
            createdAt: Date(),
            image: image,
            pixelSize: image.size,
            name: name
        )
    }
}
