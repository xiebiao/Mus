import AppKit

// Lucide mouse icon (ISC), adapted to a macOS app icon with a Mus background.
// Original geometry: rect x=5 y=2 width=14 height=20 rx=7; path M12 6v4.
// Copyright and license: Sources/Mus/Resources/ThirdParty/Lucide-LICENSE.txt.
let destination = CommandLine.arguments[1]
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.shouldAntialias = true
let background = NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 210, yRadius: 210)
NSColor(calibratedRed: 0.07, green: 0.38, blue: 0.34, alpha: 1).setFill()
background.fill()
// Center a 24-unit SVG viewport in a 672 px square. AppKit's Y axis is flipped.
let scale: CGFloat = 28
let origin: CGFloat = (1024 - 24 * scale) / 2
let body = NSBezierPath(roundedRect: NSRect(x: origin + 5 * scale, y: origin + 2 * scale,
    width: 14 * scale, height: 20 * scale), xRadius: 7 * scale, yRadius: 7 * scale)
let wheel = NSBezierPath()
wheel.move(to: NSPoint(x: origin + 12 * scale, y: origin + (24 - 6) * scale))
wheel.line(to: NSPoint(x: origin + 12 * scale, y: origin + (24 - 10) * scale))
NSColor.white.setStroke()
for path in [body, wheel] {
    path.lineWidth = 2 * scale
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Icon rendering failed") }
try png.write(to: URL(fileURLWithPath: destination))
