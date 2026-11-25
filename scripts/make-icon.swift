// Draws the flat layers used by Resources/Tuck.icon (Icon Composer).
// Layers hold shape only: Liquid Glass supplies all light, shadow, and depth.
// The picture is Tuck itself: a divider, one item that stays on its right,
// and two items shrinking away to its left as they are tucked off screen.
// Usage: swift scripts/make-icon.swift <output-directory>
import AppKit

let canvas: CGFloat = 1024

guard CommandLine.arguments.count > 1 else {
    print("usage: make-icon.swift <output-directory>")
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])

/// A menu bar item: a rounded square centred at (x, 0).
func item(x: CGFloat, size: CGFloat, shade: CGFloat) {
    NSColor(white: shade, alpha: 1).setFill()
    let rect = NSRect(x: x - size / 2, y: -size / 2, width: size, height: size)
    NSBezierPath(roundedRect: rect, xRadius: size * 0.28, yRadius: size * 0.28).fill()
}

/// Renders one transparent, full-canvas layer with the origin at the canvas centre.
func renderLayer(_ name: String, draw: () -> Void) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.current = context
    let placement = NSAffineTransform()
    placement.translateX(by: canvas / 2 + 20, yBy: canvas / 2)
    placement.concat()
    draw()
    NSGraphicsContext.current = nil

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
}

try renderLayer("tucked") {
    item(x: -335, size: 96, shade: 0.55)
    item(x: -170, size: 150, shade: 0.66)
}
try renderLayer("divider") {
    NSColor(white: 0.92, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: -21, y: -230, width: 42, height: 460), xRadius: 21, yRadius: 21).fill()
}
try renderLayer("shown") {
    item(x: 205, size: 220, shade: 0.80)
}
