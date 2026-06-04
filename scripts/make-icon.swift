// scripts/make-icon.swift
//
// Renders the DiskSpace app icon into a .iconset directory using only AppKit
// (no ImageMagick / external tooling). The motif echoes the menu-bar gauge:
// a rounded-rect tile with a blue→indigo gradient and a centered capsule
// progress bar with a green "used" fill.
//
// Usage: swift make-icon.swift <output-iconset-dir>
// Then:  iconutil -c icns <output-iconset-dir> -o AppIcon.icns

import AppKit
import Foundation

// (filename, pixel size) — the standard macOS iconset set.
let variants: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func renderPNG(px: Int) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("Could not create bitmap rep") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(px)

    // Rounded-rect app tile (leave a small transparent margin like macOS icons).
    let inset = s * 0.055
    let tile = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = tile.width * 0.225
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.22, green: 0.45, blue: 0.97, alpha: 1.0),
        NSColor(srgbRed: 0.36, green: 0.24, blue: 0.86, alpha: 1.0),
    ])!
    gradient.draw(in: tilePath, angle: -90)

    // Centered capsule gauge (track + green used-fill), echoing StatusBarView.
    let barW = tile.width * 0.62
    let barH = tile.height * 0.165
    let barRect = NSRect(
        x: tile.midX - barW / 2,
        y: tile.midY - barH / 2,
        width: barW, height: barH
    )
    let trackPath = NSBezierPath(roundedRect: barRect, xRadius: barH / 2, yRadius: barH / 2)
    NSColor.white.withAlphaComponent(0.28).setFill()
    trackPath.fill()

    let fillRect = NSRect(x: barRect.minX, y: barRect.minY, width: barW * 0.66, height: barH)
    let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: barH / 2, yRadius: barH / 2)
    NSColor(srgbRed: 0.26, green: 0.90, blue: 0.52, alpha: 1.0).setFill()
    fillPath.fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return data
}

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output-iconset-dir>\n".utf8))
    exit(2)
}
let outDir = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for v in variants {
    let data = renderPNG(px: v.px)
    let path = (outDir as NSString).appendingPathComponent(v.name)
    try data.write(to: URL(fileURLWithPath: path))
}
print("Wrote \(variants.count) icon variants to \(outDir)")
