import AppKit
import Vision

struct SensitiveTextMatch: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let confidence: VNConfidence
    let boundingBox: CGRect

    var redactionAnnotation: CaptureAnnotation {
        CaptureAnnotation(
            tool: .redact,
            start: CGPoint(x: boundingBox.minX, y: 1 - boundingBox.maxY),
            end: CGPoint(x: boundingBox.maxX, y: 1 - boundingBox.minY),
            text: "",
            stepNumber: 0
        )
    }
}

struct SensitiveTextDetectionService {
    func detect(in image: NSImage) async throws -> [SensitiveTextMatch] {
        guard let cgImage = image.cgImageForVision else {
            return []
        }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.012

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            guard let observations = request.results else {
                return []
            }

            return observations.compactMap { observation in
                guard
                    let candidate = observation.topCandidates(1).first,
                    candidate.confidence >= 0.45,
                    SensitivePatternMatcher.isSensitive(candidate.string)
                else {
                    return nil
                }

                return SensitiveTextMatch(
                    text: candidate.string,
                    confidence: candidate.confidence,
                    boundingBox: observation.boundingBox.expandedBy(dx: 0.006, dy: 0.006)
                )
            }
        }.value
    }
}

enum SensitivePatternMatcher {
    private static let patterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: #"\b(?:\+?1[\s.-]?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}\b"#),
        try! NSRegularExpression(pattern: #"\b\d{3}[- ]?\d{2}[- ]?\d{4}\b"#),
        try! NSRegularExpression(pattern: #"\b(?:\d[ -]*?){13,19}\b"#),
        try! NSRegularExpression(pattern: #"\b(?:00D|005|006|500|501|701|003)[A-Za-z0-9]{12,15}\b"#),
        try! NSRegularExpression(pattern: #"\b(?:api[_-]?key|secret|token|password|passwd|pwd)\b\s*[:=]\s*\S+"#, options: [.caseInsensitive]),
        try! NSRegularExpression(pattern: #"\b[A-Za-z0-9_\-]{24,}\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}\b"#)
    ]

    static func isSensitive(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return patterns.contains { pattern in
            pattern.firstMatch(in: text, range: range) != nil
        }
    }
}

private extension CGRect {
    func expandedBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        let minX = max(self.minX - dx, 0)
        let minY = max(self.minY - dy, 0)
        let maxX = min(self.maxX + dx, 1)
        let maxY = min(self.maxY + dy, 1)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
