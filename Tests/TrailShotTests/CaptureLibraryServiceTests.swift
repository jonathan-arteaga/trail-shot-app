import AppKit
@testable import TrailShot
import XCTest

final class CaptureLibraryServiceTests: XCTestCase {
    @MainActor
    func testSaveAndLoadCapturesWithAnnotations() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotCaptureLibraryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let service = CaptureLibraryService(directory: directory)
        let captureID = UUID()
        let annotationID = UUID()
        let capture = CaptureItem(
            id: captureID,
            kind: .area,
            createdAt: Date(timeIntervalSince1970: 123),
            image: Self.makeImage(),
            pixelSize: CGSize(width: 80, height: 50),
            name: "Persisted",
            isFavorite: true,
            annotations: [
                CaptureAnnotation(
                    id: annotationID,
                    tool: .text,
                    start: CGPoint(x: 0.2, y: 0.3),
                    end: CGPoint(x: 0.2, y: 0.3),
                    text: "Hello",
                    stepNumber: 0
                )
            ]
        )

        try service.saveCaptures([capture])
        let loaded = service.loadCaptures()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, captureID)
        XCTAssertEqual(loaded.first?.name, "Persisted")
        XCTAssertEqual(loaded.first?.isFavorite, true)
        XCTAssertEqual(loaded.first?.annotations.first?.id, annotationID)
        XCTAssertEqual(loaded.first?.annotations.first?.text, "Hello")
        XCTAssertEqual(loaded.first?.pixelSize.width ?? 0, 80, accuracy: 0.1)
    }

    @MainActor
    private static func makeImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 80, height: 50))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 80, height: 50).fill()
        image.unlockFocus()
        return image
    }
}
