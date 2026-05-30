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

    func testExportGuardOnlyAllowsCoveredSensitiveMatches() {
        let match = SensitiveTextMatch(
            text: "admin@example.com",
            confidence: 0.98,
            boundingBox: CGRect(x: 0.24, y: 0.38, width: 0.28, height: 0.08)
        )
        let coveringRedaction = match.redactionAnnotation
        let smallRedaction = CaptureAnnotation(
            tool: .redact,
            start: CGPoint(x: 0.25, y: 0.55),
            end: CGPoint(x: 0.32, y: 0.58)
        )

        XCTAssertEqual(SensitiveExportGuard.uncoveredMatches(in: [match], annotations: [coveringRedaction]), [])
        XCTAssertEqual(SensitiveExportGuard.uncoveredMatches(in: [match], annotations: [smallRedaction]), [match])
        XCTAssertEqual(SensitiveExportGuard.uncoveredMatches(in: [match], annotations: []), [match])
    }

    func testExportGuardOnlyReturnsUncoveredSensitiveMatches() {
        let coveredMatch = SensitiveTextMatch(
            text: "admin@example.com",
            confidence: 0.98,
            boundingBox: CGRect(x: 0.24, y: 0.38, width: 0.28, height: 0.08)
        )
        let uncoveredMatch = SensitiveTextMatch(
            text: "5005f0000012345AAA",
            confidence: 0.96,
            boundingBox: CGRect(x: 0.62, y: 0.38, width: 0.24, height: 0.08)
        )

        XCTAssertEqual(
            SensitiveExportGuard.uncoveredMatches(
                in: [coveredMatch, uncoveredMatch],
                annotations: [coveredMatch.redactionAnnotation]
            ),
            [uncoveredMatch]
        )
    }

    func testSensitiveTextReviewCacheStoresAndRemovesCaptureMatches() {
        let firstCaptureID = UUID()
        let secondCaptureID = UUID()
        let firstMatch = SensitiveTextMatch(
            text: "admin@example.com",
            confidence: 0.98,
            boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.1)
        )
        let secondMatch = SensitiveTextMatch(
            text: "5005f0000012345AAA",
            confidence: 0.96,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1)
        )
        var cache = SensitiveTextReviewCache()

        XCTAssertNil(cache.matches(for: firstCaptureID))

        cache.store([firstMatch], for: firstCaptureID)
        cache.store([secondMatch], for: secondCaptureID)

        XCTAssertEqual(cache.matches(for: firstCaptureID), [firstMatch])
        XCTAssertEqual(cache.matches(for: secondCaptureID), [secondMatch])

        cache.remove(captureID: firstCaptureID)
        XCTAssertNil(cache.matches(for: firstCaptureID))
        XCTAssertEqual(cache.matches(for: secondCaptureID), [secondMatch])

        cache.remove(captureIDs: [secondCaptureID])
        XCTAssertNil(cache.matches(for: secondCaptureID))

        cache.store([firstMatch], for: firstCaptureID)
        cache.removeAll()
        XCTAssertNil(cache.matches(for: firstCaptureID))
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
