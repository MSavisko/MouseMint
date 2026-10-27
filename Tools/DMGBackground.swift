import AppKit

let size = NSSize(width: 680, height: 420)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 680, pixelsHigh: 420,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.96, green: 0.98, blue: 0.97, alpha: 1).setFill()
NSRect(origin: .zero, size: size).fill()
let ink = NSColor(calibratedRed: 0.12, green: 0.23, blue: 0.20, alpha: 1)
func text(_ value: String, y: CGFloat, font: NSFont, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let width = (value as NSString).size(withAttributes: attributes).width
    (value as NSString).draw(at: NSPoint(x: (680-width)/2, y: y), withAttributes: attributes)
}
text("MouseMint", y: 349, font: .systemFont(ofSize: 30, weight: .semibold), color: ink)
text("Mouse battery and scrolling controls", y: 320, font: .systemFont(ofSize: 14), color: .secondaryLabelColor)
let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 298, y: 205)); arrow.line(to: NSPoint(x: 381, y: 205))
arrow.move(to: NSPoint(x: 368, y: 216)); arrow.line(to: NSPoint(x: 381, y: 205)); arrow.line(to: NSPoint(x: 368, y: 194))
arrow.lineWidth = 3
NSColor(calibratedRed: 0.24, green: 0.60, blue: 0.46, alpha: 1).setStroke(); arrow.stroke()
text("Drag MouseMint to Applications", y: 49, font: .systemFont(ofSize: 16, weight: .medium), color: ink)
text("Then open MouseMint from Applications.", y: 25, font: .systemFont(ofSize: 12), color: .secondaryLabelColor)
NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
