import AppKit
@testable import TrailShot
import XCTest

final class CaptureStoreHistoryTests: XCTestCase {
    @MainActor
    func testRenameDeleteAndClearHistory() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotStoreHistoryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CaptureStore(captureLibraryDirectory: directory)
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
    func testFavoriteStatePersistsWithCaptureHistory() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotFavoriteHistoryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let capture = makeCapture(name: "Important")
        let store = CaptureStore(captureLibraryDirectory: directory)
        store.captures = [capture]
        store.toggleFavorite(captureID: capture.id)

        let restoredStore = CaptureStore(captureLibraryDirectory: directory)
        XCTAssertEqual(restoredStore.captures.first?.id, capture.id)
        XCTAssertEqual(restoredStore.captures.first?.isFavorite, true)
    }

    @MainActor
    func testRetentionPolicyPrunesExpiredCaptures() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotRetentionTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let now = Date(timeIntervalSince1970: 2_000_000)
        let oldCapture = makeCapture(name: "Old", createdAt: now.addingTimeInterval(-8 * 24 * 60 * 60))
        let freshCapture = makeCapture(name: "Fresh", createdAt: now.addingTimeInterval(-2 * 24 * 60 * 60))
        let store = CaptureStore(captureLibraryDirectory: directory)
        store.captures = [oldCapture, freshCapture]
        store.selectedCaptureID = oldCapture.id
        store.pinnedCaptures = [
            PinnedCapture(captureID: oldCapture.id, title: oldCapture.name, createdAt: now, pixelSize: oldCapture.pixelSize)
        ]
        store.captureRetentionPolicy = .sevenDays

        store.applyCaptureRetentionPolicy(now: now)

        XCTAssertEqual(store.captures.map(\.id), [freshCapture.id])
        XCTAssertEqual(store.selectedCaptureID, freshCapture.id)
        XCTAssertTrue(store.pinnedCaptures.isEmpty)
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

        let captureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotCaptureHistoryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: captureDirectory) }

        let store = CaptureStore(recordingsDirectory: directory, captureLibraryDirectory: captureDirectory)

        XCTAssertEqual(store.recordings.map { $0.url.resolvingSymlinksInPath() }, [newerURL, olderURL].map { $0.resolvingSymlinksInPath() })
        XCTAssertEqual(store.lastRecordingURL?.resolvingSymlinksInPath(), newerURL.resolvingSymlinksInPath())
        XCTAssertEqual(store.recordings.first?.fileSize, 24)
    }

    @MainActor
    private func makeCapture(name: String, createdAt: Date = Date()) -> CaptureItem {
        let image = NSImage(size: NSSize(width: 120, height: 80))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 120, height: 80).fill()
        image.unlockFocus()

        return CaptureItem(
            kind: .area,
            createdAt: createdAt,
            image: image,
            pixelSize: image.size,
            name: name
        )
    }
}
