import AppKit
@testable import TrailShot
import XCTest

final class ImageExportServiceTests: XCTestCase {
    @MainActor
    func testFramedExportAddsPresentationCanvas() {
        let sourceImage = makeSourceImage()
        var capture = CaptureItem(
            kind: .area,
            createdAt: Date(),
            image: sourceImage,
            pixelSize: sourceImage.size,
            name: "Area Test"
        )
        capture.annotations = [
            CaptureAnnotation(
                tool: .step,
                start: CGPoint(x: 0.2, y: 0.25),
                end: CGPoint(x: 0.2, y: 0.25),
                stepNumber: 1
            ),
            CaptureAnnotation(
                tool: .text,
                start: CGPoint(x: 0.34, y: 0.42),
                end: CGPoint(x: 0.34, y: 0.42),
                text: "Check this"
            )
        ]

        let exportService = ImageExportService()
        let rendered = exportService.renderedImage(for: capture)
        let framed = exportService.framedImage(for: capture)

        XCTAssertGreaterThan(framed.size.width, rendered.size.width)
        XCTAssertGreaterThan(framed.size.height, rendered.size.height)
        XCTAssertNotNil(framed.pngData())
    }

    @MainActor
    func testTemporaryDragExportWritesPNGFile() throws {
        let sourceImage = makeSourceImage()
        let capture = CaptureItem(
            kind: .area,
            createdAt: Date(),
            image: sourceImage,
            pixelSize: sourceImage.size,
            name: "Opportunity / Case Screenshot"
        )

        let url = try ImageExportService().temporaryPNGURL(for: capture, variant: .annotated)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertGreaterThan((try? Data(contentsOf: url).count) ?? 0, 0)

        try? FileManager.default.removeItem(at: url)
    }

    @MainActor
    func testSuggestedExportFilenamesAreSafeAndPredictable() {
        let sourceImage = makeSourceImage()
        let capture = CaptureItem(
            kind: .area,
            createdAt: Date(),
            image: sourceImage,
            pixelSize: sourceImage.size,
            name: " Opportunity / Case: 500? "
        )
        let exportService = ImageExportService()

        XCTAssertEqual(
            exportService.suggestedFilename(for: capture, variant: .annotated),
            "Opportunity-Case-500.png"
        )
        XCTAssertEqual(
            exportService.suggestedFilename(for: capture, variant: .framed),
            "Opportunity-Case-500-framed.png"
        )
    }

    @MainActor
    func testSuggestedExportFilenameFallsBackToAppName() {
        let sourceImage = makeSourceImage()
        let capture = CaptureItem(
            kind: .area,
            createdAt: Date(),
            image: sourceImage,
            pixelSize: sourceImage.size,
            name: " / : ? "
        )

        XCTAssertEqual(
            ImageExportService().suggestedFilename(for: capture, variant: .annotated),
            "TrailShot.png"
        )
    }

    @MainActor
    func testDragItemProviderUsesSuggestedExportFilename() {
        let sourceImage = makeSourceImage()
        let capture = CaptureItem(
            kind: .area,
            createdAt: Date(),
            image: sourceImage,
            pixelSize: sourceImage.size,
            name: "Opportunity / Case"
        )
        let store = CaptureStore(captureLibraryDirectory: Self.temporaryCaptureDirectory())
        store.captures = [capture]
        store.selectedCaptureID = capture.id

        XCTAssertEqual(store.dragItemProvider(framed: false).suggestedName, "Opportunity-Case.png")
        XCTAssertEqual(store.dragItemProvider(framed: true).suggestedName, "Opportunity-Case-framed.png")
    }

    @MainActor
    private func makeSourceImage() -> NSImage {
        let size = NSSize(width: 360, height: 220)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        NSColor(calibratedRed: 0.90, green: 0.94, blue: 0.98, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 28, y: 32, width: 304, height: 156), xRadius: 12, yRadius: 12).fill()

        image.unlockFocus()
        return image
    }

    private static func temporaryCaptureDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TrailShotImageExportTests-\(UUID().uuidString)", isDirectory: true)
    }
}
