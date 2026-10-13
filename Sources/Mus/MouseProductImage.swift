import AppKit
import SwiftUI

struct MouseProductImage: View {
    var learningRear: Bool? = nil
    var highlightColor: Color = .accentColor
    private static let displaySize = NSSize(width: 120, height: 155)
    private static let productImage: NSImage? = {
        guard let url = AppResources.bundle.url(forResource: "MXAnywhere3S-LineArt", withExtension: "png"),
              let source = NSImage(contentsOf: url) else { return nil }
        let image = NSImage(size: displaySize)
        // Pre-filter at both screen densities so thin contours are averaged before
        // SwiftUI composites the image, rather than undersampled by the GPU.
        for scale in [1, 2] {
            let width = Int(displaySize.width) * scale
            let height = Int(displaySize.height) * scale
            guard let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.imageInterpolation = .high
            context.shouldAntialias = true
            let factor = max(CGFloat(width) / source.size.width, CGFloat(height) / source.size.height)
            let size = NSSize(width: source.size.width * factor, height: source.size.height * factor)
            source.draw(in: NSRect(x: (CGFloat(width) - size.width) / 2,
                                  y: (CGFloat(height) - size.height) / 2,
                                  width: size.width, height: size.height),
                        from: .zero, operation: .copy, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            bitmap.size = displaySize
            image.addRepresentation(bitmap)
        }
        return image.representations.isEmpty ? source : image
    }()

    var body: some View {
        image
            .interpolation(.high)
            .frame(width: Self.displaySize.width, height: Self.displaySize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                if let rear = learningRear {
                    sideButtonPath(rear: rear)
                        .fill(highlightColor.opacity(0.35))
                    sideButtonPath(rear: rear)
                        .stroke(highlightColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
            .allowsHitTesting(false)
    }

    // Trace the two visible side buttons in the 1254 × 1254 source image.
    // Apply the same centered aspect-fill transform as the cached bitmap above.
    private func sideButtonPath(rear: Bool) -> Path {
        var path = Path()
        if rear {
            path.move(to: CGPoint(x: 431, y: 661))
            path.addLine(to: CGPoint(x: 459, y: 652))
            path.addLine(to: CGPoint(x: 491, y: 817))
            path.addCurve(to: CGPoint(x: 448, y: 760), control1: CGPoint(x: 468, y: 807), control2: CGPoint(x: 454, y: 786))
        } else {
            path.move(to: CGPoint(x: 421, y: 479))
            path.addLine(to: CGPoint(x: 453, y: 624))
            path.addLine(to: CGPoint(x: 426, y: 632))
            path.addCurve(to: CGPoint(x: 404, y: 525), control1: CGPoint(x: 414, y: 591), control2: CGPoint(x: 403, y: 550))
            path.addQuadCurve(to: CGPoint(x: 421, y: 479), control: CGPoint(x: 400, y: 498))
        }
        path.closeSubpath()
        let scale = Self.displaySize.height / 1254
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                              tx: (Self.displaySize.width - Self.displaySize.height) / 2, ty: 0))
    }

    private var image: Image {
        if let productImage = Self.productImage { return Image(nsImage: productImage) }
        return Image(systemName: "computermouse")
    }
}
