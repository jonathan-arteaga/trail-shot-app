import AppKit
import CoreGraphics
import ScreenCaptureKit

enum ScreenCaptureError: LocalizedError {
    case captureUnavailable
    case invalidSelection
    case windowUnavailable

    var errorDescription: String? {
        switch self {
        case .captureUnavailable:
            "TrailShot could not capture the screen. Check Screen Recording permission in System Settings."
        case .invalidSelection:
            "The selected area was too small to capture."
        case .windowUnavailable:
            "TrailShot could not find a frontmost window to capture."
        }
    }
}

struct ScreenCaptureService {
    func captureMainDisplay() async throws -> NSImage {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else {
            throw ScreenCaptureError.captureUnavailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = CGDisplayPixelsWide(display.displayID)
        configuration.height = CGDisplayPixelsHigh(display.displayID)
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.captureResolution = .best

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
    }

    func captureMainDisplay(rect: CGRect) async throws -> NSImage {
        guard rect.width >= 8, rect.height >= 8 else {
            throw ScreenCaptureError.invalidSelection
        }

        let content = try await SCShareableContent.current
        guard let display = Self.display(for: rect, in: content.displays) else {
            throw ScreenCaptureError.captureUnavailable
        }

        let sourceRect = rect.intersection(display.frame)
        guard sourceRect.width >= 8, sourceRect.height >= 8 else {
            throw ScreenCaptureError.invalidSelection
        }

        let localSourceRect = CGRect(
            x: sourceRect.minX - display.frame.minX,
            y: sourceRect.minY - display.frame.minY,
            width: sourceRect.width,
            height: sourceRect.height
        ).integral
        let scale = display.frame.width > 0 ? CGFloat(CGDisplayPixelsWide(display.displayID)) / display.frame.width : (NSScreen.main?.backingScaleFactor ?? 2)
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int(localSourceRect.width * scale), 1)
        configuration.height = max(Int(localSourceRect.height * scale), 1)
        configuration.sourceRect = localSourceRect
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.captureResolution = .best

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return NSImage(cgImage: cgImage, size: rect.size)
    }

    func captureFrontmostWindow() async throws -> NSImage {
        guard let candidate = try await availableWindows().first else {
            throw ScreenCaptureError.windowUnavailable
        }

        return try await captureWindow(id: candidate.id)
    }

    func availableWindows() async throws -> [CaptureWindowCandidate] {
        let content = try await SCShareableContent.current
        let appPID = pid_t(ProcessInfo.processInfo.processIdentifier)
        return content.windows
            .filter { window in
                guard let app = window.owningApplication else { return false }
                return app.processID != appPID
                    && window.isOnScreen
                    && window.windowLayer == 0
                    && window.frame.width >= 160
                    && window.frame.height >= 120
            }
            .map { window in
                CaptureWindowCandidate(
                    id: window.windowID,
                    title: window.title ?? "",
                    appName: window.owningApplication?.applicationName ?? "Window",
                    frame: window.frame
                )
            }
            .sorted { lhs, rhs in
                let leftArea = lhs.frame.width * lhs.frame.height
                let rightArea = rhs.frame.width * rhs.frame.height
                return leftArea > rightArea
            }
    }

    func captureWindow(id: CGWindowID) async throws -> NSImage {
        try await captureWindow(id: id, maxPixelWidth: nil)
    }

    func captureWindowThumbnail(id: CGWindowID) async throws -> NSImage {
        try await captureWindow(id: id, maxPixelWidth: 360)
    }

    private func captureWindow(id: CGWindowID, maxPixelWidth: CGFloat?) async throws -> NSImage {
        let content = try await SCShareableContent.current
        guard let window = content.windows.first(where: { $0.windowID == id }) else {
            throw ScreenCaptureError.windowUnavailable
        }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        let scale = filter.pointPixelScale > 0 ? CGFloat(filter.pointPixelScale) : (NSScreen.main?.backingScaleFactor ?? 2)
        let pixelWidth = max(window.frame.width * scale, 1)
        let pixelHeight = max(window.frame.height * scale, 1)
        let thumbnailScale = maxPixelWidth.map { min($0 / pixelWidth, 1) } ?? 1
        configuration.width = max(Int(pixelWidth * thumbnailScale), 1)
        configuration.height = max(Int(pixelHeight * thumbnailScale), 1)
        configuration.scalesToFit = false
        configuration.preservesAspectRatio = true
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.ignoreShadowsSingleWindow = false
        configuration.captureResolution = .best

        let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return NSImage(cgImage: cgImage, size: CGSize(width: cgImage.width, height: cgImage.height))
    }

    private static func display(for rect: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        displays
            .map { display in
                (display: display, area: display.frame.intersection(rect).area)
            }
            .filter { $0.area > 0 }
            .max { lhs, rhs in lhs.area < rhs.area }?
            .display
            ?? displays.first(where: { $0.displayID == CGMainDisplayID() })
            ?? displays.first
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
