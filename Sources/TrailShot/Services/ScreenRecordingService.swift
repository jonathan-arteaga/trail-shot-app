@preconcurrency import AVFoundation
import CoreMedia
@preconcurrency import ScreenCaptureKit

enum ScreenRecordingError: LocalizedError {
    case displayUnavailable
    case invalidSelection
    case alreadyRecording
    case notRecording
    case writerUnavailable

    var errorDescription: String? {
        switch self {
        case .displayUnavailable:
            "TrailShot could not find a display to record."
        case .invalidSelection:
            "The selected area was too small to record."
        case .alreadyRecording:
            "TrailShot is already recording."
        case .notRecording:
            "TrailShot is not recording."
        case .writerUnavailable:
            "TrailShot could not prepare the recording file."
        }
    }
}

final class ScreenRecordingService: NSObject, @unchecked Sendable {
    static var defaultRecordingsDirectory: URL {
        let moviesDirectory = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return moviesDirectory.appendingPathComponent("TrailShot", isDirectory: true)
    }

    private let outputQueue = DispatchQueue(label: "com.salesforce.trailshot.recording")
    private let outputDirectory: URL
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var startTime: CMTime?
    private var outputURL: URL?

    init(outputDirectory: URL = ScreenRecordingService.defaultRecordingsDirectory) {
        self.outputDirectory = outputDirectory
        super.init()
    }

    var isRecording: Bool {
        stream != nil
    }

    func startMainDisplayRecording() async throws -> URL {
        try await startRecording(sourceRect: nil)
    }

    func startAreaRecording(rect: CGRect) async throws -> URL {
        guard rect.width >= 32, rect.height >= 32 else {
            throw ScreenRecordingError.invalidSelection
        }

        return try await startRecording(sourceRect: rect.integral)
    }

    private func startRecording(sourceRect: CGRect?) async throws -> URL {
        guard stream == nil else {
            throw ScreenRecordingError.alreadyRecording
        }

        let content = try await SCShareableContent.current
        guard let display = Self.display(for: sourceRect, in: content.displays) else {
            throw ScreenRecordingError.displayUnavailable
        }

        let displayFrame = display.frame
        let localSourceRect = sourceRect.map { rect in
            rect.intersection(displayFrame).offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY).integral
        }
        guard localSourceRect.map({ $0.width >= 32 && $0.height >= 32 }) ?? true else {
            throw ScreenRecordingError.invalidSelection
        }

        let width = Int(localSourceRect?.width ?? CGFloat(CGDisplayPixelsWide(display.displayID)))
        let height = Int(localSourceRect?.height ?? CGFloat(CGDisplayPixelsHigh(display.displayID)))
        let url = try makeOutputURL()
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(width * height * 4, 8_000_000),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ])
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw ScreenRecordingError.writerUnavailable
        }

        writer.add(input)
        guard writer.startWriting() else {
            throw writer.error ?? ScreenRecordingError.writerUnavailable
        }

        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.captureResolution = .best
        if let localSourceRect {
            configuration.sourceRect = localSourceRect
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)

        self.stream = stream
        assetWriter = writer
        videoInput = input
        outputURL = url
        startTime = nil

        do {
            try await stream.startCapture()
            return url
        } catch {
            reset()
            throw error
        }
    }

    func stopRecording() async throws -> URL {
        guard let stream, assetWriter != nil, videoInput != nil, outputURL != nil else {
            throw ScreenRecordingError.notRecording
        }

        try await stream.stopCapture()

        return try await withCheckedThrowingContinuation { continuation in
            outputQueue.async { [self] in
                finishRecordingOnOutputQueue(continuation: continuation)
            }
        }
    }

    private func finishRecordingOnOutputQueue(continuation: CheckedContinuation<URL, Error>) {
        guard let writer = assetWriter, let input = videoInput, let outputURL else {
            continuation.resume(throwing: ScreenRecordingError.notRecording)
            return
        }

        input.markAsFinished()
        writer.finishWriting { [self] in
            let status = assetWriter?.status
            let error = assetWriter?.error
            let completedURL = outputURL
            reset()

            if status == .completed {
                continuation.resume(returning: completedURL)
            } else {
                continuation.resume(throwing: error ?? ScreenRecordingError.writerUnavailable)
            }
        }
    }

    private func reset() {
        stream = nil
        assetWriter = nil
        videoInput = nil
        startTime = nil
        outputURL = nil
    }

    private func makeOutputURL() throws -> URL {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let filename = "TrailShot-Recording-\(Self.timestamp()).mov"
        let url = outputDirectory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        return url
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func display(for sourceRect: CGRect?, in displays: [SCDisplay]) -> SCDisplay? {
        guard let sourceRect else {
            return displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? displays.first
        }

        return displays
            .map { display in
                (display: display, area: display.frame.intersection(sourceRect).area)
            }
            .filter { $0.area > 0 }
            .max { $0.area < $1.area }?
            .display
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}

extension ScreenRecordingService: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard
            type == .screen,
            sampleBuffer.isValid,
            let assetWriter,
            let videoInput,
            assetWriter.status == .writing
        else {
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if startTime == nil {
            startTime = presentationTime
            assetWriter.startSession(atSourceTime: presentationTime)
        }

        if videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
        }
    }
}
