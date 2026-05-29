#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make_icon.swift <output.icns>\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = outputURL
    .deletingPathExtension()
    .appendingPathExtension("iconset")

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for size in sizes {
    let pixels = Int(size.points * size.scale)
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    let radius = CGFloat(pixels) * 0.22
    let background = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(pixels) * 0.04, dy: CGFloat(pixels) * 0.04), xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.02, green: 0.34, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.13, green: 0.70, blue: 0.94, alpha: 1)
    ])
    gradient?.draw(in: background, angle: -35)

    let markRect = rect.insetBy(dx: CGFloat(pixels) * 0.25, dy: CGFloat(pixels) * 0.25)
    let mark = NSBezierPath(roundedRect: NSRect(
        x: markRect.minX + markRect.width * 0.12,
        y: markRect.minY + markRect.height * 0.23,
        width: markRect.width * 0.76,
        height: markRect.height * 0.54
    ), xRadius: markRect.width * 0.26, yRadius: markRect.height * 0.26)

    NSColor.white.setStroke()
    mark.lineWidth = max(CGFloat(pixels) * 0.045, 1.5)
    mark.stroke()

    let line = NSBezierPath()
    line.lineWidth = max(CGFloat(pixels) * 0.045, 1.5)
    line.lineCapStyle = .round
    line.move(to: CGPoint(x: markRect.minX + markRect.width * 0.24, y: markRect.minY + markRect.height * 0.21))
    line.line(to: CGPoint(x: markRect.minX + markRect.width * 0.10, y: markRect.minY + markRect.height * 0.08))
    line.move(to: CGPoint(x: markRect.minX + markRect.width * 0.76, y: markRect.minY + markRect.height * 0.21))
    line.line(to: CGPoint(x: markRect.minX + markRect.width * 0.90, y: markRect.minY + markRect.height * 0.08))
    line.move(to: CGPoint(x: markRect.minX + markRect.width * 0.28, y: markRect.minY + markRect.height * 0.16))
    line.line(to: CGPoint(x: markRect.minX + markRect.width * 0.72, y: markRect.minY + markRect.height * 0.16))
    line.stroke()

    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(
        x: markRect.minX + markRect.width * 0.59,
        y: markRect.minY + markRect.height * 0.46,
        width: markRect.width * 0.14,
        height: markRect.width * 0.14
    )).fill()

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("Failed to render \(size.name)\n", stderr)
        exit(1)
    }

    try png.write(to: iconsetURL.appendingPathComponent(size.name), options: .atomic)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fputs("iconutil failed\n", stderr)
    exit(Int32(process.terminationStatus))
}
