// Draws the flat layers used by Resources/Tuck.icon (Icon Composer).
// Layers hold shape only: Liquid Glass supplies all light, shadow, and depth.
// The picture is Tuck itself: a menu bar at the top, one item dropping out of
// a gap in it, and a pocket below that already holds another.
// Usage: swift scripts/make-icon.swift <output-directory>
import AppKit

let canvas: CGFloat = 1024
/// The menu bar and the pocket share these edges so their widths line up.
let left: CGFloat = -330
let right: CGFloat = 330

guard CommandLine.arguments.count > 1 else {
    print("usage: make-icon.swift <output-directory>")
    exit(1)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])

/// A rounded rectangle with continuous-curvature corners, the way Apple draws them:
/// each corner is a quarter superellipse spread over 1.3 × the radius, so the
/// straight edge bends in gradually instead of meeting a circular arc at a kink.
func continuousRect(_ rect: NSRect, radius: CGFloat, corners: Set<Int> = [0, 1, 2, 3]) -> NSBezierPath {
    let extent = min(radius * 1.3, rect.width / 2, rect.height / 2)
    let exponent: CGFloat = 4
    let steps = 24
    // Counter-clockwise from bottom-right: where each corner's curve is centred, and the rect corner it replaces.
    let centres = [
        NSPoint(x: rect.maxX - extent, y: rect.minY + extent),
        NSPoint(x: rect.maxX - extent, y: rect.maxY - extent),
        NSPoint(x: rect.minX + extent, y: rect.maxY - extent),
        NSPoint(x: rect.minX + extent, y: rect.minY + extent),
    ]
    let squares = [
        NSPoint(x: rect.maxX, y: rect.minY), NSPoint(x: rect.maxX, y: rect.maxY),
        NSPoint(x: rect.minX, y: rect.maxY), NSPoint(x: rect.minX, y: rect.minY),
    ]
    func signedPower(_ value: CGFloat) -> CGFloat {
        (value < 0 ? -1 : 1) * pow(abs(value), 2 / exponent)
    }
    var points: [NSPoint] = []
    for index in 0..<4 {
        guard corners.contains(index) else {
            points.append(squares[index])
            continue
        }
        let start = -CGFloat.pi / 2 + CGFloat(index) * .pi / 2
        for step in 0...steps {
            let angle = start + CGFloat(step) / CGFloat(steps) * .pi / 2
            points.append(NSPoint(
                x: centres[index].x + extent * signedPower(cos(angle)),
                y: centres[index].y + extent * signedPower(sin(angle))
            ))
        }
    }
    let path = NSBezierPath()
    path.move(to: points[0])
    points.dropFirst().forEach(path.line)
    path.close()
    return path
}

/// A menu bar item. Circles, because they sit concentric inside the capsule bar.
func item(x: CGFloat, y: CGFloat, shade: CGFloat) {
    NSColor(white: shade, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: x - itemSize / 2, y: y - itemSize / 2, width: itemSize, height: itemSize)).fill()
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
    placement.translateX(by: canvas / 2, yBy: canvas / 2)
    placement.concat()
    draw()
    NSGraphicsContext.current = nil

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
}

// One grid: the bar is a capsule, items sit inside it with equal padding all round,
// and every item, in the bar or out of it, is the same size.
let barHeight: CGFloat = 150
let padding: CGFloat = 26
let itemSize = barHeight - padding * 2
let pitch = itemSize + padding
let barTop: CGFloat = 340
let barMid = barTop - barHeight / 2
let pocketTop: CGFloat = -60
let pocketBottom: CGFloat = -340
/// The icon's own corner, read off Icon Composer's macOS mask, minus the pocket's inset,
/// keeps the pocket's bottom corners concentric with the icon.
let pocketCorner: CGFloat = 110
/// The empty slot in the bar, third from the right, that the falling item came from.
let slotX = right - padding - itemSize / 2 - pitch * 2

try renderLayer("bar") {
    NSColor(white: 0.68, alpha: 1).setFill()
    let rect = NSRect(x: left, y: barTop - barHeight, width: right - left, height: barHeight)
    NSBezierPath(roundedRect: rect, xRadius: barHeight / 2, yRadius: barHeight / 2).fill()
}
try renderLayer("baritems") {
    for index in 0..<2 {
        item(x: right - padding - itemSize / 2 - pitch * CGFloat(index), y: barMid, shade: 0.97)
    }
}
try renderLayer("falling") {
    item(x: slotX, y: barTop - barHeight - pitch * 0.9, shade: 0.94)
    item(x: left + padding + itemSize / 2 + pitch * 0.4, y: pocketTop + itemSize * 0.05, shade: 0.88)
}
try renderLayer("front") {
    NSColor(white: 0.6, alpha: 1).setFill()
    let rect = NSRect(x: left, y: pocketBottom, width: right - left, height: pocketTop - pocketBottom)
    continuousRect(rect, radius: pocketCorner, corners: [0, 3]).fill()
}
try renderLayer("back") {
    NSColor(white: 0.25, alpha: 1).setFill()
    let rect = NSRect(x: left, y: pocketBottom, width: right - left, height: pocketTop - pocketBottom + 90)
    continuousRect(rect, radius: pocketCorner).fill()
}
