import AppKit

enum ModeIcon {
    static func image(for mode: ConnectionMode?) -> NSImage {
        guard let mode else {
            return NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Mouse not connected")!
        }
        if mode == .cable {
            return NSImage(systemSymbolName: "cable.connector", accessibilityDescription: mode.title)!
        }
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.labelColor.setStroke()
            let path = NSBezierPath()
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            if mode == .bluetooth {
                // The Bluetooth rune has no equivalent public SF Symbol.
                path.move(to: NSPoint(x: 5, y: 5))
                path.line(to: NSPoint(x: 13, y: 12))
                path.line(to: NSPoint(x: 9, y: 16))
                path.line(to: NSPoint(x: 9, y: 2))
                path.line(to: NSPoint(x: 13, y: 6))
                path.line(to: NSPoint(x: 5, y: 13))
            } else {
                // A USB receiver: metal plug above a compact plastic body.
                path.appendRoundedRect(NSRect(x: 5, y: 2, width: 8, height: 10), xRadius: 2, yRadius: 2)
                path.move(to: NSPoint(x: 6, y: 12))
                path.line(to: NSPoint(x: 6, y: 16))
                path.line(to: NSPoint(x: 12, y: 16))
                path.line(to: NSPoint(x: 12, y: 12))
                path.move(to: NSPoint(x: 8, y: 14))
                path.line(to: NSPoint(x: 8, y: 15))
                path.move(to: NSPoint(x: 10, y: 14))
                path.line(to: NSPoint(x: 10, y: 15))
            }
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = mode.title
        return image
    }
}
