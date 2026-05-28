import AppKit
import CoreImage
import ScreenCaptureKit
import UniformTypeIdentifiers

// MARK: - Delegate

@MainActor
protocol OverlayViewDelegate: AnyObject {
    func overlayView(_ view: OverlayView, didFinish image: CGImage,
                     sourceRect: CGRect, scaleFactor: CGFloat)
    func overlayViewDidCancel(_ view: OverlayView)
}

// MARK: - OverlayView

final class OverlayView: NSView {

    weak var delegate: OverlayViewDelegate?
    var viewModel: OverlayViewModel?
    var scWindows: [SCWindow] = []

    private var baseCGImage: CGImage
    private var scaleFactor: CGFloat = 2.0

    private var dragStart: NSPoint?
    private var inProgressAnnotation: Annotation?
    private var liveSelectionRect: NSRect?
    private var hoveredWindowRect: NSRect?
    private var mousePos: NSPoint = .zero
    private var selectedAnnotation: Annotation?
    private var moveOrigin: NSPoint?
    private var editingTextField: NSTextField?
    private var eraserDidPushUndo = false
    private var editingObserver: NSObjectProtocol?

    init(backgroundImage: CGImage, scaleFactor: CGFloat) {
        self.baseCGImage = backgroundImage
        self.scaleFactor = scaleFactor
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    func requestFinish() {
        guard let vm = viewModel, let sel = vm.selectionRect else { return }
        // Apply crop if the user set one
        let effectiveSel: NSRect
        if let crop = vm.cropRect {
            let intersection = crop.intersection(sel)
            effectiveSel = intersection.isEmpty ? sel : intersection
        } else {
            effectiveSel = sel
        }
        guard let final = vm.renderFinalImage(baseCGImage: baseCGImage,
                                              selectionRect: effectiveSel,
                                              scaleFactor: scaleFactor) else { return }
        delegate?.overlayView(self, didFinish: final, sourceRect: toScreen(effectiveSel), scaleFactor: scaleFactor)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext,
              let vm = viewModel else { return }

        drawBackground(in: ctx)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.fill(bounds)

        let displaySel = vm.selectionRect ?? liveSelectionRect
        if let sel = displaySel, sel.width > 2, sel.height > 2 {
            drawBackground(in: ctx, clippedTo: sel)
            ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineWidth(1.5)
            ctx.stroke(sel.insetBy(dx: 0.75, dy: 0.75))
            drawHandles(sel, ctx: ctx); drawSizeLabel(sel, showCoords: true)
        } else if let win = hoveredWindowRect, vm.activeTool == .region {
            drawBackground(in: ctx, clippedTo: win)
            let p = NSBezierPath(rect: win.insetBy(dx: 1, dy: 1))
            p.lineWidth = 2; NSColor.systemBlue.setStroke(); p.stroke()
            drawSizeLabel(win)
        }

        // Collect spotlights separately — drawn as a unified overlay at end
        let spotlights = vm.annotations.compactMap { $0 as? SpotlightAnnotation }
        for ann in vm.annotations where !(ann is SpotlightAnnotation) { drawAnnotation(ann) }
        if let ip = inProgressAnnotation, !(ip is SpotlightAnnotation) { drawAnnotation(ip) }

        // Spotlight overlay (dark with holes)
        var allSpotlights = spotlights
        if let sp = inProgressAnnotation as? SpotlightAnnotation { allSpotlights.append(sp) }
        if !allSpotlights.isEmpty { drawSpotlightOverlay(allSpotlights) }

        // Crop preview overlay
        if let crop = vm.cropRect, !crop.isEmpty {
            if let sel = vm.selectionRect {
                NSGraphicsContext.saveGraphicsState()
                let dimPath = NSBezierPath(rect: sel)
                dimPath.append(NSBezierPath(rect: crop))
                dimPath.windingRule = .evenOdd
                NSColor.black.withAlphaComponent(0.4).setFill()
                dimPath.fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            NSColor.systemYellow.setStroke()
            let cropPath = NSBezierPath(rect: crop)
            cropPath.lineWidth = 2
            cropPath.setLineDash([6, 4], count: 2, phase: 0)
            cropPath.stroke()
        }

        if vm.activeTool == .region {
            // Full-screen crosshair (always, thin)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(0.5); ctx.beginPath()
            ctx.move(to: .init(x: 0, y: mousePos.y))
            ctx.addLine(to: .init(x: bounds.width, y: mousePos.y))
            ctx.move(to: .init(x: mousePos.x, y: 0))
            ctx.addLine(to: .init(x: mousePos.x, y: bounds.height))
            ctx.strokePath()

            // Magnifier loupe (before final selection)
            if vm.selectionRect == nil {
                drawMagnifier(at: mousePos, in: ctx)
            }
        }
    }

    // NSImage.draw applies an extra vertical flip in a flipped NSView (it "corrects"
    // for CG's bottom-origin, but the CTM already handles that → double-flip → upside down).
    // Draw CGImage directly: the flipped CTM maps row 0 to visual-top, which is correct
    // because the SCK-captured CGImage stores the screen top in row 0.
    private func drawBackground(in ctx: CGContext, clippedTo clip: CGRect? = nil) {
        ctx.saveGState()
        if let clip { ctx.clip(to: clip) }
        ctx.draw(baseCGImage, in: CGRect(origin: .zero, size: bounds.size))
        ctx.restoreGState()
    }

    private func drawAnnotation(_ ann: Annotation) {
        if let blur = ann as? BlurAnnotation      { drawBlur(blur);     return }
        if let pix  = ann as? PixelateAnnotation  { drawPixelate(pix);  return }
        if let mag  = ann as? MagnifyAnnotation   { drawMagnify(mag);   return }
        ann.draw(in: bounds)
    }

    private func drawBlur(_ ann: BlurAnnotation) {
        guard ann.rect.width > 4, ann.rect.height > 4 else { return }
        let pr = pixelRect(ann.rect)
        guard let cropped = baseCGImage.cropping(to: pr) else { return }
        let ci = CIImage(cgImage: cropped)
        guard let f = CIFilter(name: "CIGaussianBlur") else { return }
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(max(ann.radius, 1.0), forKey: kCIInputRadiusKey)
        guard let out = f.outputImage else { return }
        let sz = CGSize(width: pr.width, height: pr.height)
        let shifted = out.transformed(by: .init(translationX: -out.extent.minX, y: -out.extent.minY))
        if let cg = OverlayViewModel.ciContext.createCGImage(shifted, from: CGRect(origin: .zero, size: sz)) {
            NSImage(cgImage: cg, size: ann.rect.size)
                .draw(in: ann.rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    private func drawPixelate(_ ann: PixelateAnnotation) {
        guard ann.rect.width > 4, ann.rect.height > 4 else { return }
        let pr = pixelRect(ann.rect)
        guard let cropped = baseCGImage.cropping(to: pr) else { return }
        let ci = CIImage(cgImage: cropped)
        guard let f = CIFilter(name: "CIPixellate") else { return }
        f.setValue(ci, forKey: kCIInputImageKey)
        f.setValue(max(ann.pixelSize * scaleFactor / 2, 2.0), forKey: kCIInputScaleKey)
        guard let out = f.outputImage else { return }
        let sz = CGSize(width: pr.width, height: pr.height)
        if let cg = OverlayViewModel.ciContext.createCGImage(out, from: CGRect(origin: .zero, size: sz)) {
            NSImage(cgImage: cg, size: ann.rect.size)
                .draw(in: ann.rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    private func drawMagnify(_ ann: MagnifyAnnotation) {
        guard ann.rect.width > 4, ann.rect.height > 4 else { return }
        let srcW = ann.rect.width  / ann.scale
        let srcH = ann.rect.height / ann.scale
        let srcRect = NSRect(x: ann.rect.midX - srcW/2, y: ann.rect.midY - srcH/2, width: srcW, height: srcH)
        let pr = pixelRect(srcRect)
        guard let cropped = baseCGImage.cropping(to: pr),
              let ctx = NSGraphicsContext.current?.cgContext else {
            ann.draw(in: bounds); return
        }
        ctx.saveGState()
        NSBezierPath(ovalIn: ann.rect).addClip()
        NSImage(cgImage: cropped, size: ann.rect.size)
            .draw(in: ann.rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.restoreGState()
        // Border
        ann.color.setStroke()
        let border = NSBezierPath(ovalIn: ann.rect)
        border.lineWidth = ann.lineWidth; border.stroke()
    }

    private func drawSpotlightOverlay(_ spotlights: [SpotlightAnnotation]) {
        let fullPath = NSBezierPath(rect: bounds)
        for sp in spotlights { fullPath.append(NSBezierPath(ovalIn: sp.rect)) }
        fullPath.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.65).setFill()
        fullPath.fill()
        // Stroke border of each spotlight circle
        for sp in spotlights {
            sp.color.setStroke()
            let p = NSBezierPath(ovalIn: sp.rect)
            p.lineWidth = max(sp.lineWidth, 2); p.stroke()
        }
    }

    private func pixelRect(_ r: NSRect) -> CGRect {
        CGRect(x: r.minX * scaleFactor, y: r.minY * scaleFactor,
               width: r.width * scaleFactor, height: r.height * scaleFactor)
    }

    private func drawHandles(_ rect: NSRect, ctx: CGContext) {
        let s: CGFloat = 6
        ctx.setFillColor(NSColor.white.cgColor)
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
         CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)].forEach {
            ctx.fill(CGRect(x: $0.x - s/2, y: $0.y - s/2, width: s, height: s))
        }
    }

    private func drawSizeLabel(_ rect: NSRect, showCoords: Bool = false) {
        let sf = scaleFactor
        let text: String
        if showCoords {
            text = "X: \(Int(rect.minX * sf))  Y: \(Int(rect.minY * sf))  W: \(Int(rect.width * sf))  H: \(Int(rect.height * sf))"
        } else {
            text = "\(Int(rect.width * sf)) × \(Int(rect.height * sf))"
        }
        let str = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                         .foregroundColor: NSColor.white])
        let sz = str.size(); let pad: CGFloat = 5
        let lx = max(2, min(rect.midX - sz.width/2 - pad, bounds.width - sz.width - pad*2 - 2))
        let ly = rect.maxY + 6 > bounds.height - 24 ? rect.minY - sz.height - 10 : rect.maxY + 6
        let bg = NSBezierPath(roundedRect: NSRect(x: lx, y: ly, width: sz.width+pad*2, height: sz.height+pad),
                              xRadius: 4, yRadius: 4)
        NSColor(white: 0, alpha: 0.7).setFill()
        bg.fill()
        str.draw(at: NSPoint(x: lx + pad, y: ly + pad/2))
    }

    // ShareX-style pixel magnifier with coordinate readout.
    // Crops pixelCount×pixelCount pixels from baseCGImage around the cursor,
    // scales them up with nearest-neighbor, overlays a grid and crosshair.
    private func drawMagnifier(at pos: NSPoint, in ctx: CGContext) {
        let pixelCount = 11          // source pixels per side (must be odd)
        let zoom: CGFloat = 8        // each source pixel → zoom×zoom points
        let half = pixelCount / 2    // = 5
        let magW = CGFloat(pixelCount) * zoom   // 88
        let magH = CGFloat(pixelCount) * zoom

        // Crop region in baseCGImage coords (y=0=top, same as view coords × sf)
        let cx = (pos.x * scaleFactor).rounded()
        let cy = (pos.y * scaleFactor).rounded()
        let imgW = CGFloat(baseCGImage.width)
        let imgH = CGFloat(baseCGImage.height)
        let srcRect = CGRect(x: max(0, cx - CGFloat(half)),
                             y: max(0, cy - CGFloat(half)),
                             width: CGFloat(pixelCount),
                             height: CGFloat(pixelCount))
            .intersection(CGRect(x: 0, y: 0, width: imgW, height: imgH))
        guard let cropped = baseCGImage.cropping(to: srcRect) else { return }

        // Position near cursor; flip sides to stay on screen
        let gap: CGFloat = 20
        let labelH: CGFloat = 22
        var mx = pos.x + gap
        var my = pos.y + gap
        if mx + magW > bounds.width  - 8 { mx = pos.x - gap - magW }
        if my + magH + labelH > bounds.height - 8 { my = pos.y - gap - magH - labelH }
        let magRect = CGRect(x: mx, y: my, width: magW, height: magH)

        // ── Draw zoomed pixels (nearest-neighbor) ──────────────────────────
        ctx.saveGState()
        ctx.clip(to: magRect)
        ctx.interpolationQuality = .none
        ctx.draw(cropped, in: magRect)
        ctx.restoreGState()

        // ── Grid lines ─────────────────────────────────────────────────────
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.3).cgColor)
        ctx.setLineWidth(0.5)
        for i in 1..<pixelCount {
            let x = mx + CGFloat(i) * zoom
            ctx.move(to: CGPoint(x: x, y: my)); ctx.addLine(to: CGPoint(x: x, y: my + magH))
        }
        for i in 1..<pixelCount {
            let y = my + CGFloat(i) * zoom
            ctx.move(to: CGPoint(x: mx, y: y)); ctx.addLine(to: CGPoint(x: mx + magW, y: y))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // ── Center crosshair bars (light-blue tint, ShareX style) ──────────
        let cpx = mx + CGFloat(half) * zoom
        let cpy = my + CGFloat(half) * zoom
        ctx.saveGState()
        ctx.setFillColor(NSColor(red: 0.6, green: 0.88, blue: 1.0, alpha: 0.45).cgColor)
        ctx.fill(CGRect(x: mx, y: cpy, width: cpx - mx, height: zoom))             // left
        ctx.fill(CGRect(x: cpx + zoom, y: cpy, width: mx + magW - cpx - zoom, height: zoom)) // right
        ctx.fill(CGRect(x: cpx, y: my, width: zoom, height: cpy - my))             // top
        ctx.fill(CGRect(x: cpx, y: cpy + zoom, width: zoom, height: my + magH - cpy - zoom)) // bottom
        ctx.restoreGState()

        // ── Center pixel highlight (black outer + white inner border) ───────
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.black.cgColor); ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: cpx - 1, y: cpy - 1, width: zoom + 2, height: zoom + 2))
        ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineWidth(0.5)
        ctx.stroke(CGRect(x: cpx, y: cpy, width: zoom - 1, height: zoom - 1))
        ctx.restoreGState()

        // ── Magnifier border (white 2pt outer, black 1pt inner) ────────────
        ctx.saveGState()
        ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineWidth(2)
        ctx.stroke(magRect.insetBy(dx: -1, dy: -1))
        ctx.setStrokeColor(NSColor.black.cgColor); ctx.setLineWidth(1)
        ctx.stroke(magRect)
        ctx.restoreGState()

        // ── Coordinate label below magnifier ───────────────────────────────
        let screenX = Int(pos.x * scaleFactor)
        let screenY = Int(pos.y * scaleFactor)
        let coordStr = NSAttributedString(
            string: "X: \(screenX)  Y: \(screenY)",
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                         .foregroundColor: NSColor.white])
        let csz = coordStr.size(); let cpad: CGFloat = 4
        let lbX = mx + (magW - csz.width) / 2 - cpad
        let lbY = my + magH + 3
        let lbBg = NSRect(x: lbX, y: lbY, width: csz.width + cpad * 2, height: csz.height + cpad)
        NSColor(white: 0, alpha: 0.72).setFill()
        NSBezierPath(roundedRect: lbBg, xRadius: 3, yRadius: 3).fill()
        coordStr.draw(at: NSPoint(x: lbX + cpad, y: lbY + cpad / 2))
    }

    override func mouseDown(with event: NSEvent) {
        guard let vm = viewModel else { return }
        let pt = convert(event.locationInWindow, from: nil)
        dragStart = pt

        switch vm.activeTool {
        case .region:
            liveSelectionRect = nil; hoveredWindowRect = nil
        case .select:
            selectedAnnotation = vm.annotations.last(where: { $0.hitTest(pt) })
            moveOrigin = pt
        case .text:
            beginTextInput(at: pt, vm: vm)
        case .step:
            vm.addAnnotation(StepAnnotation(center: pt, number: vm.nextStepNumber, color: vm.strokeColor))
        case .rect:
            inProgressAnnotation = RectAnnotation(rect: .init(origin: pt, size: .zero),
                                                  color: vm.strokeColor, lineWidth: vm.lineWidth)
        case .ellipse:
            inProgressAnnotation = EllipseAnnotation(rect: .init(origin: pt, size: .zero),
                                                     color: vm.strokeColor, lineWidth: vm.lineWidth)
        case .line:
            inProgressAnnotation = LineAnnotation(start: pt, end: pt,
                                                  color: vm.strokeColor, lineWidth: vm.lineWidth)
        case .arrow:
            inProgressAnnotation = ArrowAnnotation(start: pt, end: pt,
                                                   color: vm.strokeColor, lineWidth: vm.lineWidth)
        case .highlight:
            inProgressAnnotation = HighlightAnnotation(rect: .init(origin: pt, size: .zero),
                                                       color: vm.strokeColor)
        case .pen:
            let pen = PenAnnotation(color: vm.strokeColor, lineWidth: vm.lineWidth)
            pen.addPoint(pt); vm.pushUndo(); vm.annotations.append(pen)
            inProgressAnnotation = nil
        case .blur:
            inProgressAnnotation = BlurAnnotation(rect: .init(origin: pt, size: .zero),
                                                  radius: vm.blurRadius)
        case .pixelate:
            inProgressAnnotation = PixelateAnnotation(rect: .init(origin: pt, size: .zero),
                                                      pixelSize: vm.pixelateSize)
        case .blackout:
            inProgressAnnotation = BlackoutAnnotation(rect: .init(origin: pt, size: .zero))
        case .speechBalloon:
            inProgressAnnotation = SpeechBalloonAnnotation(
                rect: .init(origin: pt, size: .zero), color: vm.strokeColor, fontSize: vm.fontSize)
        case .spotlight:
            inProgressAnnotation = SpotlightAnnotation(
                rect: .init(origin: pt, size: .zero), color: vm.strokeColor, lineWidth: vm.lineWidth)
        case .magnify:
            inProgressAnnotation = MagnifyAnnotation(
                rect: .init(origin: pt, size: .zero),
                scale: vm.magnifyScale, color: vm.strokeColor, lineWidth: vm.lineWidth)
        case .emoji:
            beginEmojiInput(at: pt, vm: vm)
        case .cursor:
            vm.addAnnotation(CursorAnnotation(origin: pt, size: vm.cursorSize))
        case .image:
            openImagePicker(at: pt, vm: vm)
        case .crop:
            vm.cropRect = nil
        case .eraser:
            if !eraserDidPushUndo { vm.pushUndo(); eraserDidPushUndo = true }
            eraseAnnotation(at: pt, vm: vm)
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let vm = viewModel else { return }
        let cur = convert(event.locationInWindow, from: nil)

        switch vm.activeTool {
        case .region:
            if let s = dragStart { liveSelectionRect = makeRect(s, cur) }
        case .select:
            if let sel = selectedAnnotation, let o = moveOrigin {
                moveAnnotation(sel, dx: cur.x - o.x, dy: cur.y - o.y); moveOrigin = cur
            }
        case .rect:
            if let s = dragStart { inProgressAnnotation = RectAnnotation(rect: makeRect(s, cur), color: vm.strokeColor, lineWidth: vm.lineWidth) }
        case .ellipse:
            if let s = dragStart { inProgressAnnotation = EllipseAnnotation(rect: makeRect(s, cur), color: vm.strokeColor, lineWidth: vm.lineWidth) }
        case .line:
            if let s = dragStart { inProgressAnnotation = LineAnnotation(start: s, end: cur, color: vm.strokeColor, lineWidth: vm.lineWidth) }
        case .arrow:
            if let s = dragStart { inProgressAnnotation = ArrowAnnotation(start: s, end: cur, color: vm.strokeColor, lineWidth: vm.lineWidth) }
        case .highlight:
            if let s = dragStart { inProgressAnnotation = HighlightAnnotation(rect: makeRect(s, cur), color: vm.strokeColor) }
        case .pen:
            (vm.annotations.last as? PenAnnotation)?.addPoint(cur)
        case .blur:
            if let s = dragStart { inProgressAnnotation = BlurAnnotation(rect: makeRect(s, cur), radius: vm.blurRadius) }
        case .pixelate:
            if let s = dragStart { inProgressAnnotation = PixelateAnnotation(rect: makeRect(s, cur), pixelSize: vm.pixelateSize) }
        case .blackout:
            if let s = dragStart { inProgressAnnotation = BlackoutAnnotation(rect: makeRect(s, cur)) }
        case .speechBalloon:
            if let s = dragStart { inProgressAnnotation = SpeechBalloonAnnotation(
                rect: makeRect(s, cur), color: vm.strokeColor, fontSize: vm.fontSize) }
        case .spotlight:
            if let s = dragStart { inProgressAnnotation = SpotlightAnnotation(
                rect: makeRect(s, cur), color: vm.strokeColor, lineWidth: vm.lineWidth) }
        case .magnify:
            if let s = dragStart { inProgressAnnotation = MagnifyAnnotation(
                rect: makeRect(s, cur), scale: vm.magnifyScale, color: vm.strokeColor, lineWidth: vm.lineWidth) }
        case .crop:
            if let s = dragStart, let sel = vm.selectionRect {
                let raw = makeRect(s, cur)
                let clipped = raw.intersection(sel)
                vm.cropRect = clipped.isEmpty ? nil : clipped
            }
        case .eraser:
            eraseAnnotation(at: cur, vm: vm)
        case .text, .step, .emoji, .cursor, .image: break
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let vm = viewModel else { return }
        switch vm.activeTool {
        case .region:
            if let live = liveSelectionRect, live.width > 5, live.height > 5 {
                vm.selectionRect = live
            } else if let win = hoveredWindowRect {
                vm.selectionRect = toViewRect(win)
                if vm.windowPickerMode { requestFinish(); return }
            }
            liveSelectionRect = nil
        case .select:
            moveOrigin = nil
        case .pen:
            break
        case .rect, .ellipse, .line, .arrow, .highlight, .blur, .pixelate, .blackout, .spotlight, .magnify:
            if let ann = inProgressAnnotation { vm.addAnnotation(ann) }
            inProgressAnnotation = nil
        case .speechBalloon:
            if let ann = inProgressAnnotation as? SpeechBalloonAnnotation,
               ann.rect.width > 20, ann.rect.height > 20 {
                vm.addAnnotation(ann)
                beginBalloonTextInput(balloon: ann, vm: vm)
            }
            inProgressAnnotation = nil
        case .eraser:
            eraserDidPushUndo = false
        case .text, .step, .emoji, .cursor, .image, .crop:
            break
        }
        dragStart = nil; needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        mousePos = convert(event.locationInWindow, from: nil)
        if viewModel?.activeTool == .region { updateHoveredWindow() }
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) { delegate?.overlayViewDidCancel(self) }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {   // ESC
            if editingTextField != nil { window?.makeFirstResponder(self) }
            else { delegate?.overlayViewDidCancel(self) }
            return
        }
        if event.keyCode == 36 || event.keyCode == 76 { requestFinish(); return }  // Return
        if (event.keyCode == 51 || event.keyCode == 117), let vm = viewModel, let sel = selectedAnnotation {
            vm.pushUndo(); vm.annotations.removeAll { $0 === sel }; selectedAnnotation = nil
            needsDisplay = true; return
        }
        super.keyDown(with: event)
    }

    private func beginTextInput(at pt: NSPoint, vm: OverlayViewModel) {
        guard editingTextField == nil else { return }
        let field = NSTextField(frame: NSRect(x: pt.x, y: pt.y, width: 200, height: 32))
        field.isBordered = true; field.backgroundColor = NSColor(white:0,alpha:0.5)
        field.textColor = vm.strokeColor
        field.font = NSFont.systemFont(ofSize: vm.fontSize, weight: .semibold)
        field.placeholderString = "Type…"; field.focusRingType = .none
        addSubview(field); editingTextField = field; window?.makeFirstResponder(field)
        editingObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification, object: field, queue: .main
        ) { [weak self, weak field] _ in
            guard let self, let field else { return }
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            field.removeFromSuperview(); self.editingTextField = nil
            if !text.isEmpty {
                vm.addAnnotation(TextAnnotation(origin: pt, text: text,
                                                color: vm.strokeColor, fontSize: vm.fontSize))
            }
            self.needsDisplay = true
            if let obs = self.editingObserver { NotificationCenter.default.removeObserver(obs) }
            self.editingObserver = nil
        }
    }

    private func beginBalloonTextInput(balloon: SpeechBalloonAnnotation, vm: OverlayViewModel) {
        guard editingTextField == nil else { return }
        let pad: CGFloat = 10
        let fieldRect = balloon.rect.insetBy(dx: pad, dy: pad)
        let field = NSTextField(frame: fieldRect)
        field.isBordered = false; field.drawsBackground = false
        field.textColor = balloon.color
        field.font = NSFont.systemFont(ofSize: balloon.fontSize, weight: .regular)
        field.placeholderString = "Type…"; field.focusRingType = .none
        addSubview(field); editingTextField = field; window?.makeFirstResponder(field)
        editingObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification, object: field, queue: .main
        ) { [weak self, weak field, weak balloon] _ in
            guard let self, let field, let balloon else { return }
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                vm.undo()
            } else {
                balloon.text = text
            }
            field.removeFromSuperview(); self.editingTextField = nil
            self.needsDisplay = true
            if let obs = self.editingObserver { NotificationCenter.default.removeObserver(obs) }
            self.editingObserver = nil
        }
    }

    private func updateHoveredWindow() {
        guard let w = window else { hoveredWindowRect = nil; return }
        let sp = w.convertToScreen(NSRect(origin: mousePos.unflipped(in: bounds), size: .zero)).origin
        // SCK returns windows front-to-back — first match is topmost
        let hit = scWindows.first { $0.frame.contains(sp) && $0.frame.width > 10 }
        hoveredWindowRect = hit.map { $0.frame }
    }

    private func moveAnnotation(_ ann: Annotation, dx: CGFloat, dy: CGFloat) {
        switch ann {
        case let r as RectAnnotation:      r.rect   = r.rect.offsetBy(dx: dx, dy: dy)
        case let e as EllipseAnnotation:   e.rect   = e.rect.offsetBy(dx: dx, dy: dy)
        case let a as ArrowAnnotation:     a.start  = .init(x: a.start.x+dx, y: a.start.y+dy); a.end = .init(x: a.end.x+dx, y: a.end.y+dy)
        case let l as LineAnnotation:      l.start  = .init(x: l.start.x+dx, y: l.start.y+dy); l.end = .init(x: l.end.x+dx, y: l.end.y+dy)
        case let t as TextAnnotation:      t.origin = .init(x: t.origin.x+dx, y: t.origin.y+dy)
        case let h as HighlightAnnotation: h.rect   = h.rect.offsetBy(dx: dx, dy: dy)
        case let p as PenAnnotation:       p.points = p.points.map { .init(x: $0.x+dx, y: $0.y+dy) }
        case let s as StepAnnotation:      s.center = .init(x: s.center.x+dx, y: s.center.y+dy)
        case let b as BlurAnnotation:           b.rect = b.rect.offsetBy(dx: dx, dy: dy)
        case let x as PixelateAnnotation:       x.rect = x.rect.offsetBy(dx: dx, dy: dy)
        case let k as BlackoutAnnotation:       k.rect = k.rect.offsetBy(dx: dx, dy: dy)
        case let sb as SpeechBalloonAnnotation: sb.rect = sb.rect.offsetBy(dx: dx, dy: dy)
        case let sp as SpotlightAnnotation:     sp.rect = sp.rect.offsetBy(dx: dx, dy: dy)
        case let m as MagnifyAnnotation:        m.rect  = m.rect.offsetBy(dx: dx, dy: dy)
        case let em as EmojiAnnotation:         em.origin = .init(x: em.origin.x+dx, y: em.origin.y+dy)
        case let cu as CursorAnnotation:        cu.origin = .init(x: cu.origin.x+dx, y: cu.origin.y+dy)
        case let im as ImageAnnotation:         im.origin = .init(x: im.origin.x+dx, y: im.origin.y+dy)
        default: break
        }
    }

    private func beginEmojiInput(at pt: NSPoint, vm: OverlayViewModel) {
        guard editingTextField == nil else { return }
        let field = NSTextField(frame: NSRect(x: pt.x, y: pt.y, width: 80, height: CGFloat(vm.emojiSize) + 16))
        field.isBordered = true
        field.backgroundColor = NSColor(white: 0, alpha: 0.5)
        field.textColor = .white
        field.font = NSFont.systemFont(ofSize: vm.emojiSize)
        field.placeholderString = "🙂"
        field.focusRingType = .none
        field.alignment = .center
        addSubview(field); editingTextField = field; window?.makeFirstResponder(field)
        editingObserver = NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification, object: field, queue: .main
        ) { [weak self, weak field] _ in
            guard let self, let field else { return }
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            field.removeFromSuperview(); self.editingTextField = nil
            if !text.isEmpty {
                vm.addAnnotation(EmojiAnnotation(origin: pt, emoji: text, fontSize: vm.emojiSize))
            }
            self.needsDisplay = true
            if let obs = self.editingObserver { NotificationCenter.default.removeObserver(obs) }
            self.editingObserver = nil
        }
    }

    private func eraseAnnotation(at pt: NSPoint, vm: OverlayViewModel) {
        if let hit = vm.annotations.last(where: { $0.hitTest(pt) }) {
            vm.annotations.removeAll { $0 === hit }
            needsDisplay = true
        }
    }

    private func openImagePicker(at pt: NSPoint, vm: OverlayViewModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff, .heic]
        panel.canChooseFiles = true; panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url,
                  let img = NSImage(contentsOf: url) else { return }
            Task { @MainActor [weak self, weak vm] in
                guard let self, let vm else { return }
                vm.addAnnotation(ImageAnnotation(origin: pt, image: img))
                self.needsDisplay = true
            }
        }
    }

    private func toScreen(_ r: NSRect) -> CGRect {
        guard let w = window else { return r }
        return w.convertToScreen(NSRect(x: r.minX, y: bounds.height - r.maxY,
                                        width: r.width, height: r.height))
    }

    private func toViewRect(_ s: CGRect) -> NSRect {
        guard let w = window else { return s }
        let l = CGRect(x: s.minX - w.frame.minX, y: s.minY - w.frame.minY,
                       width: s.width, height: s.height)
        return NSRect(x: l.minX, y: bounds.height - l.maxY, width: l.width, height: l.height)
    }

    private func makeRect(_ a: NSPoint, _ b: NSPoint) -> NSRect {
        NSRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(b.x-a.x), height: abs(b.y-a.y))
    }
}

private extension NSPoint {
    func unflipped(in bounds: NSRect) -> NSPoint { NSPoint(x: x, y: bounds.height - y) }
}

