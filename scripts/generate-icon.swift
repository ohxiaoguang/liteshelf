#!/usr/bin/env swift
// Deterministic, code-drawn app icon. Run from the repository root only when changing the design.
import AppKit
let directory = URL(fileURLWithPath: "LiteShelf/Resources/Assets.xcassets/AppIcon.appiconset")
let sizes = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
for (points, scale) in sizes {
    let pixels = points * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let factor = CGFloat(pixels) / 1024
    let transform = NSAffineTransform(); transform.scale(by: factor); transform.concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 188, yRadius: 188)
    NSColor(calibratedRed: 0.12, green: 0.18, blue: 0.24, alpha: 1).setFill(); background.fill()
    let colors = [NSColor(calibratedRed: 0.48, green: 0.78, blue: 0.70, alpha: 1),
                  NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.45, alpha: 1),
                  NSColor(calibratedRed: 0.53, green: 0.68, blue: 0.89, alpha: 1)]
    for i in 0..<3 {
        colors[i].setFill()
        NSBezierPath(roundedRect: NSRect(x: 224 + i * 200, y: 350, width: 160, height: 340 + (i == 1 ? 80 : 0)),
                     xRadius: 28, yRadius: 28).fill()
        NSColor.white.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: NSRect(x: 264 + i * 200, y: 390, width: 80, height: 14), xRadius: 7, yRadius: 7).fill()
    }
    NSColor.white.withAlphaComponent(0.92).setFill()
    NSBezierPath(roundedRect: NSRect(x: 204, y: 282, width: 616, height: 36), xRadius: 18, yRadius: 18).fill()
    NSGraphicsContext.restoreGraphicsState()
    let filename = "icon_\(points)x\(points)@\(scale)x.png"
    try rep.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(filename))
    images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": filename])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: directory.appendingPathComponent("Contents.json"))
