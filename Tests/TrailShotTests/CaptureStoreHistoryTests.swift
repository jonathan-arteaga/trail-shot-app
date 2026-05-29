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
    func testRecordingHistoryLoadsFromDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let olderURL = directory.appendingPathComponent("older.mov")
        let newerURL = directory.appendingPathComponent("newer.mov")
        let ignoredURL = directory.appendingPathComponent("notes.txt")
        try Data(repeating: 1, count: 12).write(to: olderURL)
        try Data(repeating: 2, count: 24).write(to: newerURL)
        try Data("ignore".utf8).write(to: ignoredURL)

        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        try FileManager.default.setAttributes([.creationDate: olderDate, .modificationDate: olderDate], ofItemAtPath: olderURL.path)
        try FileManager.default.setAttributes([.creationDate: newerDate, .modificationDate: newerDate], ofItemAtPath: newerURL.path)

        let store = CaptureStore(recordingsDirectory: directory)

        XCTAssertEqual(store.recordings.map { $0.url.resolvingSymlinksInPath() }, [newerURL, olderURL].map { $0.resolvingSymlinksInPath() })
        XCTAssertEqual(store.lastRecordingURL?.resolvingSymlinksInPath(), newerURL.resolvingSymlinksInPath())
        XCTAssertEqual(store.recordings.first?.fileSize, 24)
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
