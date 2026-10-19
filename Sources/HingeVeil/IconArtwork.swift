import AppKit

enum IconArtwork {
    /// Original vector construction: a curved veil and its hinge point.
    /// No downloaded image, competitor icon, or font glyph is used.
    static func image(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            draw(in: rect)
            return true
        }
    }

    private static func draw(in rect: NSRect) {
        let s = rect.width
        let background = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.04, dy: s * 0.04), xRadius: s * 0.22, yRadius: s * 0.22)
        NSGradient(starting: NSColor(red: 0.08, green: 0.18, blue: 0.24, alpha: 1),
                   ending: NSColor(red: 0.025, green: 0.08, blue: 0.11, alpha: 1))?.draw(in: background, angle: -70)
        let veil = NSBezierPath()
        veil.move(to: NSPoint(x: s * 0.28, y: s * 0.24))
        veil.curve(to: NSPoint(x: s * 0.73, y: s * 0.78),
                   controlPoint1: NSPoint(x: s * 0.71, y: s * 0.27), controlPoint2: NSPoint(x: s * 0.39, y: s * 0.76))
        veil.line(to: NSPoint(x: s * 0.48, y: s * 0.78))
        veil.curve(to: NSPoint(x: s * 0.28, y: s * 0.24),
                   controlPoint1: NSPoint(x: s * 0.20, y: s * 0.62), controlPoint2: NSPoint(x: s * 0.64, y: s * 0.35))
        veil.close()
        NSGradient(starting: NSColor(red: 0.32, green: 0.94, blue: 0.73, alpha: 1),
                   ending: NSColor(red: 0.27, green: 0.60, blue: 0.95, alpha: 1))?.draw(in: veil, angle: 75)
        NSColor(red: 0.63, green: 0.98, blue: 0.84, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: s * 0.23, y: s * 0.18, width: s * 0.12, height: s * 0.12)).fill()
    }

    static func exportIconset(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for size in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let pixels = size * scale
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32),
                      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw IconFailure.render }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
                NSGraphicsContext.restoreGraphicsState()
                guard let data = bitmap.representation(using: .png, properties: [:]) else { throw IconFailure.render }
                let suffix = scale == 2 ? "@2x" : ""
                try data.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
            }
        }
    }
    enum IconFailure: Error { case render }
}
