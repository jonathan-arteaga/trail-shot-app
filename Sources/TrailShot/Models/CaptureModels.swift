import AppKit
import CoreGraphics
import Foundation

enum CaptureKind: String, CaseIterable, Identifiable, Codable {
    case area = "Area"
    case fullScreen = "Full Screen"
    case window = "Window"
    case scrolling = "Scrolling"
    case recording = "Recording"
    case ocr = "OCR"

    var id: String { rawValue }
}

struct CaptureItem: Identifiable, Hashable {
    let id: UUID
    let kind: CaptureKind
    let createdAt: Date
    let image: NSImage
    let pixelSize: CGSize
    var name: String
    var isFavorite: Bool
    var annotations: [CaptureAnnotation] = []

    init(
        id: UUID = UUID(),
        kind: CaptureKind,
        createdAt: Date,
        image: NSImage,
        pixelSize: CGSize,
        name: String,
        isFavorite: Bool = false,
        annotations: [CaptureAnnotation] = []
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.image = image
        self.pixelSize = pixelSize
        self.name = name
        self.isFavorite = isFavorite
        self.annotations = annotations
    }

    static func == (lhs: CaptureItem, rhs: CaptureItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PinnedCapture: Identifiable {
    let id = UUID()
    let captureID: CaptureItem.ID?
    let title: String
    let createdAt: Date
    let pixelSize: CGSize
}

struct RecordingItem: Identifiable, Hashable {
    let url: URL
    let createdAt: Date
    let fileSize: Int64

    var id: String { url.path }

    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    var detailText: String {
        "\(createdAt.formatted(date: .abbreviated, time: .shortened)) • \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))"
    }
}

enum CaptureStatus: Equatable {
    case ready
    case selectingArea
    case working(String)
    case failed(String)
}

struct CaptureWindowCandidate: Identifiable, Hashable {
    let id: CGWindowID
    let title: String
    let appName: String
    let frame: CGRect

    var displayTitle: String {
        title.isEmpty ? appName : title
    }

    var subtitle: String {
        "\(appName) - \(Int(frame.width)) x \(Int(frame.height))"
    }

    static func == (lhs: CaptureWindowCandidate, rhs: CaptureWindowCandidate) -> Bool {
        lhs.id == rhs.id &&
            lhs.title == rhs.title &&
            lhs.appName == rhs.appName &&
            lhs.frame.equalTo(rhs.frame)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(appName)
        hasher.combine(frame.minX)
        hasher.combine(frame.minY)
        hasher.combine(frame.width)
        hasher.combine(frame.height)
    }
}

enum AnnotationTool: String, CaseIterable, Identifiable, Codable {
    case move = "Move"
    case arrow = "Arrow"
    case rectangle = "Shape"
    case text = "Text"
    case redact = "Blur"
    case step = "Step"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .move:
            "cursorarrow.motionlines"
        case .arrow:
            "arrow.up.right"
        case .rectangle:
            "rectangle"
        case .text:
            "textformat"
        case .redact:
            "eye.slash"
        case .step:
            "1.circle"
        }
    }
}

struct CaptureAnnotation: Identifiable, Hashable {
    let id: UUID
    var tool: AnnotationTool
    var start: CGPoint
    var end: CGPoint
    var text: String = ""
    var stepNumber: Int = 0

    init(
        id: UUID = UUID(),
        tool: AnnotationTool,
        start: CGPoint,
        end: CGPoint,
        text: String = "",
        stepNumber: Int = 0
    ) {
        self.id = id
        self.tool = tool
        self.start = start
        self.end = end
        self.text = text
        self.stepNumber = stepNumber
    }

    static func == (lhs: CaptureAnnotation, rhs: CaptureAnnotation) -> Bool {
        lhs.id == rhs.id &&
            lhs.tool == rhs.tool &&
            lhs.start.equalTo(rhs.start) &&
            lhs.end.equalTo(rhs.end) &&
            lhs.text == rhs.text &&
            lhs.stepNumber == rhs.stepNumber
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(tool)
        hasher.combine(start.x)
        hasher.combine(start.y)
        hasher.combine(end.x)
        hasher.combine(end.y)
        hasher.combine(text)
        hasher.combine(stepNumber)
    }
}

enum AnnotationResizeHandle {
    case start
    case end
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct ToolDescriptor: Identifiable {
    let id: String
    let title: String
    let symbolName: String
    let description: String
}

extension ToolDescriptor {
    static let plannedTools: [ToolDescriptor] = [
        ToolDescriptor(id: "arrow", title: "Arrow", symbolName: "arrow.up.right", description: "Call out a precise point"),
        ToolDescriptor(id: "rectangle", title: "Shape", symbolName: "rectangle", description: "Frame important regions"),
        ToolDescriptor(id: "text", title: "Text", symbolName: "textformat", description: "Add short context"),
        ToolDescriptor(id: "redact", title: "Blur", symbolName: "eye.slash", description: "Redact sensitive data"),
        ToolDescriptor(id: "step", title: "Step", symbolName: "1.circle", description: "Mark ordered instructions"),
        ToolDescriptor(id: "beautify", title: "Frame", symbolName: "sparkles", description: "Create a polished share image")
    ]
}
