import AVFoundation
import Foundation

enum RecordingTrimError: LocalizedError {
    case invalidRange
    case exportUnavailable
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .invalidRange:
            "Choose a valid trim range."
        case .exportUnavailable:
            "TrailShot could not prepare a trimmed recording."
        case .exportFailed:
            "TrailShot could not export the trimmed recording."
        }
    }
}

struct RecordingTrimService {
    func duration(of url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)

        guard let duration = try? await asset.load(.duration) else {
            return 0
        }

        let seconds = duration.seconds
        return seconds.isFinite ? max(seconds, 0) : 0
    }

    func trim(url: URL, start: TimeInterval, end: TimeInterval) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let duration = await self.duration(of: url)
        let timeRange = try Self.validatedTimeRange(start: start, end: end, duration: duration)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw RecordingTrimError.exportUnavailable
        }

        let outputURL = try makeTrimmedOutputURL(for: url)
        exportSession.timeRange = timeRange
        exportSession.shouldOptimizeForNetworkUse = true

        try await exportSession.export(to: outputURL, as: .mov)

        return outputURL
    }

    static func validatedTimeRange(start: TimeInterval, end: TimeInterval, duration: TimeInterval) throws -> CMTimeRange {
        guard duration.isFinite, duration > 0 else {
            throw RecordingTrimError.invalidRange
        }

        let clampedStart = min(max(start, 0), duration)
        let clampedEnd = min(max(end, 0), duration)
        guard clampedEnd - clampedStart >= 0.25 else {
            throw RecordingTrimError.invalidRange
        }

        let startTime = CMTime(seconds: clampedStart, preferredTimescale: 600)
        let endTime = CMTime(seconds: clampedEnd, preferredTimescale: 600)
        return CMTimeRange(start: startTime, end: endTime)
    }

    private func makeTrimmedOutputURL(for url: URL) throws -> URL {
        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let outputURL = directory.appendingPathComponent("\(baseName)-trimmed-\(Self.timestamp()).mov")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        return outputURL
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
