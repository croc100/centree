import AppKit
import CoreImage

// MARK: - OverlayViewModel

/// Shared observable state between the overlay NSView and the SwiftUI toolbar.
@MainActor
final class OverlayViewModel: ObservableObject {

    // MARK: Tool state

    @Published var activeTool: AnnotationTool = .region
    @Published var strokeColor: NSColor = .systemRed
    @Published var lineWidth: CGFloat = 2
    @Published var fontSize: CGFloat = 18
    @Published var blurRadius: CGFloat = 20
    @Published var pixelateSize: CGFloat = 12

    // MARK: Annotations

    @Published var annotations: [Annotation] = []
    @Published var canUndo: Bool = false

    // MARK: Selection

    @Published var selectionRect: NSRect? = nil
    var hasSelection: Bool { selectionRect != nil }

    // MARK: Callbacks (set by OverlayWindowController)

    var onDone: (() -> Void)?
    var onCancel: (() -> Void)?

    // MARK: Undo

    private var undoStack: [[Annotation]] = []

    func pushUndo() {
        undoStack.append(annotations)
        canUndo = true
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        annotations = last
        canUndo = !undoStack.isEmpty
    }

    func addAnnotation(_ ann: Annotation) {
        pushUndo()
        annotations.append(ann)
    }

    var nextStepNumber: Int {
        (annotations.compactMap { ($0 as? StepAnnotation)?.number }.max() ?? 0) + 1
    }

    // MARK: - CoreImage context (shared, GPU-accelerated)

    static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Final render

    /// Crops `baseCGImage` to `selectionRect` and composites all annotations.
    ///
    /// - Parameters:
    ///   - baseCGImage: Full-display frozen screenshot.
    ///   - selectionRect: Selection in overlay view coords (isFlipped=true, points).
    ///   - scaleFactor: Points → pixels multiplier.
    func renderFinalImage(
        baseCGImage: CGImage,
        selectionRect sel: NSRect,
        scaleFactor: CGFloat
    ) -> CGImage? {
        let w = Int(sel.width  * scaleFactor)
        let h = Int(sel.height * scaleFactor)
        guard w > 0, h > 0 else { return nil }

        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // 1. Draw base cropped image
        // Overlay view is isFlipped=true: pixel(sel.minX * sf, sel.minY * sf) = top-left of selection
        let pixelOrigin = CGPoint(x: sel.minX * scaleFactor, y: sel.minY * scaleFactor)
        let pixelSize   = CGSize(width: CGFloat(w), height: CGFloat(h))
        let pixelRect   = CGRect(origin: pixelOrigin, size: pixelSize)

        if let cropped = baseCGImage.cropping(to: pixelRect) {
            ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: w, height: h))
        }

        // 2. Effect annotations (blur / pixelate / blackout) — operate in pixel space
        //    These are drawn BEFORE the transform below because they rely on the base pixels.
        for ann in annotations {
            let relPixelRect = pixelRelative(ann: ann, sel: sel, scale: scaleFactor)
            guard !relPixelRect.isEmpty else { continue }

            if let blur = ann as? BlurAnnotation {
                if let blurredCG = applyBlur(baseCGImage: baseCGImage,
                                             absolutePixelRect: relPixelRect.offsetBy(dx: pixelOrigin.x, dy: pixelOrigin.y),
                                             radius: Float(blur.radius * scaleFactor / 4)) {
                    ctx.draw(blurredCG, in: relPixelRect)
                }

            } else if let pix = ann as? PixelateAnnotation {
                if let pixelatedCG = applyPixelate(baseCGImage: baseCGImage,
                                                   absolutePixelRect: relPixelRect.offsetBy(dx: pixelOrigin.x, dy: pixelOrigin.y),
                                                   scale: Float(pix.pixelSize * scaleFactor / 4)) {
                    ctx.draw(pixelatedCG, in: relPixelRect)
                }

            } else if ann is BlackoutAnnotation {
                ctx.setFillColor(CGColor.black)
                ctx.fill(relPixelRect)
            }
        }

        // 3. Vector annotations — set up transform so annotations draw in flipped-view coords
        ctx.saveGState()
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: scaleFactor, y: -scaleFactor)
        ctx.translateBy(x: -sel.minX, y: -sel.minY)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

        let overlayBounds = NSRect(x: 0, y: 0, width: CGFloat(baseCGImage.width) / scaleFactor,
                                                height: CGFloat(baseCGImage.height) / scaleFactor)
        for ann in annotations {
            if ann is BlurAnnotation || ann is PixelateAnnotation || ann is BlackoutAnnotation { continue }
            ann.draw(in: overlayBounds)
        }

        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()

        return ctx.makeImage()
    }

    // MARK: - Helpers

    /// Rect of an annotation relative to selection top-left, in pixels.
    private func pixelRelative(ann: Annotation, sel: NSRect, scale: CGFloat) -> CGRect {
        var r: NSRect?
        if let a = ann as? BlurAnnotation      { r = a.rect }
        else if let a = ann as? PixelateAnnotation { r = a.rect }
        else if let a = ann as? BlackoutAnnotation { r = a.rect }
        guard let viewRect = r else { return .zero }

        let clipped = viewRect.intersection(sel)
        guard !clipped.isEmpty else { return .zero }

        return CGRect(
            x: (clipped.minX - sel.minX) * scale,
            y: (clipped.minY - sel.minY) * scale,
            width:  clipped.width  * scale,
            height: clipped.height * scale
        )
    }

    private func applyBlur(baseCGImage: CGImage, absolutePixelRect: CGRect, radius: Float) -> CGImage? {
        guard let cropped = baseCGImage.cropping(to: absolutePixelRect) else { return nil }
        let ci = CIImage(cgImage: cropped)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(max(radius, 1), forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage else { return nil }
        let dest = CGRect(origin: .zero, size: CGSize(width: absolutePixelRect.width,
                                                       height: absolutePixelRect.height))
        return Self.ciContext.createCGImage(output.cropped(to: dest.offsetBy(dx: -output.extent.origin.x,
                                                                             dy: -output.extent.origin.y)),
                                            from: dest)
    }

    private func applyPixelate(baseCGImage: CGImage, absolutePixelRect: CGRect, scale: Float) -> CGImage? {
        guard let cropped = baseCGImage.cropping(to: absolutePixelRect) else { return nil }
        let ci = CIImage(cgImage: cropped)
        guard let filter = CIFilter(name: "CIPixellate") else { return nil }
        filter.setValue(ci, forKey: kCIInputImageKey)
        filter.setValue(max(scale, 2), forKey: kCIInputScaleKey)
        guard let output = filter.outputImage else { return nil }
        let dest = CGRect(origin: .zero, size: CGSize(width: absolutePixelRect.width,
                                                       height: absolutePixelRect.height))
        return Self.ciContext.createCGImage(output, from: dest)
    }
}
