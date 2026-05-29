import AppKit
@testable import TrailShot
import XCTest

final class SensitiveTextDetectionTests: XCTestCase {
    func testSensitivePatternMatcherFlagsCommonInternalRiskPatterns() {
        let sensitiveSamples = [
            "Contact admin@example.com",
            "Phone: (415) 555-0199",
            "SSN 123-45-6789",
            "Card 4242 4242 4242 4242",
            "Salesforce 0055f0000012345AAA",
            "api_key = sk_test_1234567890abcdefghijklmnopqrstuvwxyz",
            "token: abcdefghijklmnopqrstuvwxyz.abcdefghijklmnop.abcdefghijklmnop"
        ]

        for sample in sensitiveSamples {
            XCTAssertTrue(SensitivePatternMatcher.isSensitive(sample), "Expected sensitive match for: \(sample)")
        }
    }

    func testSensitivePatternMatcherIgnoresNormalUiText() {
        let safeSamples = [
            "Capture, mark, and keep moving.",
            "Choose a visible window to capture.",
            "TrailShot local screenshot workflow",
            "No captures yet"
        ]

        for sample in safeSamples {
            XCTAssertFalse(SensitivePatternMatcher.isSensitive(sample), "Expected no sensitive match for: \(sample)")
        }
    }

    @MainActor
    func testVisionFixtureFindsRedactableText() async throws {
        let image = makeFixtureImage(lines: [
            "TrailShot Safety Fixture",
            "Email admin@example.com",
            "Case 5005f0000012345AAA"
        ])

        let matches = try await SensitiveTextDetectionService().detect(in: image)
        let joinedMatches = matches.map(\.text).joined(separator: " ")

        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(joinedMatches.localizedCaseInsensitiveContains("admin@example.com"))
        XCTAssertTrue(matches.allSatisfy { !$0.boundingBox.isEmpty })
        XCTAssertTrue(matches.allSatisfy { $0.boundingBox.minX >= 0 && $0.boundingBox.maxX <= 1 })
        XCTAssertTrue(matches.allSatisfy { $0.boundingBox.minY >= 0 && $0.boundingBox.maxY <= 1 })
    }

    @MainActor
    func testTextRecognitionProducesPlainTextInReadingOrder() async throws {
        let image = makeFixtureImage(lines: [
            "TrailShot OCR Fixture",
            "Copy this text",
            "Case 5005f0000012345AAA"
        ])

        let observations = try await TextRecognitionService().recognize(in: image)
        let plainText = TextRecognitionService.plainText(from: observations)

        XCTAssertTrue(plainText.localizedCaseInsensitiveContains("TrailShot OCR Fixture"))
        XCTAssertTrue(plainText.localizedCaseInsensitiveContains("Copy this text"))
        XCTAssertTrue(plainText.localizedCaseInsensitiveContains("Case"))
        XCTAssertLessThan(
            plainText.range(of: "TrailShot", options: .caseInsensitive)?.lowerBound ?? plainText.endIndex,
            plainText.range(of: "Copy", options: .caseInsensitive)?.lowerBound ?? plainText.startIndex
        )
    }

    @MainActor
    private func makeFixtureImage(lines: [String]) -> NSImage {
        let size = NSSize(width: 980, height: 420)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 18
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 38, weight: .semibold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        lines.joined(separator: "\n").draw(
            in: NSRect(x: 48, y: 72, width: size.width - 96, height: size.height - 120),
            withAttributes: attributes
        )

        image.unlockFocus()
        return image
    }
}
