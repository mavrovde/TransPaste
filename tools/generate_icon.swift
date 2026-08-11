// Generates the TransPaste app icon as code — no binary assets in the repo.
// Design: blue macOS squircle, two speech bubbles ("A" and "文") for
// translation, with paste-back arrows between them.
// Usage: swift tools/generate_icon.swift <output-iconset-dir>

import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

// All geometry is designed on a 1024pt canvas and scaled per size.
func drawDesign(canvas: CGFloat) {
    let s = canvas / 1024.0

    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }

    // Background squircle with vertical gradient (standard macOS icon margin)
    let bg = rect(100, 100, 824, 824)
    let bgPath = NSBezierPath(roundedRect: bg, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(
        starting: NSColor(calibratedRed: 0.28, green: 0.62, blue: 1.00, alpha: 1.0),
        ending: NSColor(calibratedRed: 0.03, green: 0.29, blue: 0.75, alpha: 1.0)
    )!.draw(in: bgPath, angle: -90)

    func drawGlyph(_ text: String, center: CGPoint, size: CGFloat, color: NSColor) {
        let font = NSFont.systemFont(ofSize: size * s, weight: .bold)
        let str = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let sz = str.size()
        str.draw(at: CGPoint(x: center.x * s - sz.width / 2, y: center.y * s - sz.height / 2))
    }

    func bubble(_ body: CGRect, radius: CGFloat, tail: (CGPoint, CGPoint, CGPoint)) -> NSBezierPath {
        let path = NSBezierPath(roundedRect: body, xRadius: radius * s, yRadius: radius * s)
        let tailPath = NSBezierPath()
        tailPath.move(to: CGPoint(x: tail.0.x * s, y: tail.0.y * s))
        tailPath.line(to: CGPoint(x: tail.1.x * s, y: tail.1.y * s))
        tailPath.line(to: CGPoint(x: tail.2.x * s, y: tail.2.y * s))
        tailPath.close()
        path.append(tailPath)
        return path
    }

    // Source bubble (top-left, white, tail pointing down-left) — "A"
    let deepBlue = NSColor(calibratedRed: 0.04, green: 0.26, blue: 0.64, alpha: 1.0)
    let b1 = bubble(rect(180, 480, 420, 300), radius: 80,
                    tail: (CGPoint(x: 250, y: 500), CGPoint(x: 210, y: 400), CGPoint(x: 350, y: 480)))
    NSColor.white.setFill()
    b1.fill()
    drawGlyph("A", center: CGPoint(x: 390, y: 640), size: 210, color: deepBlue)

    // Target bubble (bottom-right, deep blue with white stroke; no tail —
    // the overlap with the source bubble already reads as a conversation)
    let b2Rect = rect(430, 230, 420, 300)
    let b2 = NSBezierPath(roundedRect: b2Rect, xRadius: 80 * s, yRadius: 80 * s)
    deepBlue.setFill()
    b2.fill()
    NSColor.white.setStroke()
    b2.lineWidth = 14 * s
    b2.stroke()
    drawGlyph("文", center: CGPoint(x: 640, y: 390), size: 200, color: .white)

    // Exchange arrows in the open top-right corner
    drawGlyph("⇄", center: CGPoint(x: 705, y: 672), size: 130, color: NSColor.white.withAlphaComponent(0.95))
}

func writePNG(pixels: Int, name: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawDesign(canvas: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(outputDir)/\(name)"))
}

let entries: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (px, name) in entries {
    writePNG(pixels: px, name: name)
}
print("iconset written to \(outputDir)")
