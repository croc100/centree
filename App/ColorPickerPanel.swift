import AppKit

/// Floating magnified color loupe that follows the cursor.
/// Left-click copies HEX to clipboard and dismisses.
/// Right-click or Escape dismisses without copying.
@MainActor
final class ColorPickerPanel: NSObject, NSWindowDelegate {
    static let shared = ColorPickerPanel()
    private override init() { super.init() }

    private var panel: NSPanel?
    private var loupeView: LoupeView?
    private var moveMonitor: Any?
    private var leftClickMonitor: Any?
    private var rightClickMonitor: Any?
    private var keyMonitor: Any?

    // MARK: - Activate / deactivate

    func activate() {
        guard panel == nil else { return }

        let sz: CGFloat = 160
        let infoH: CGFloat = 24

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: sz, height: sz + infoH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.isMovable = false
        p.ignoresMouseEvents = true
        p.isReleasedWhenClosed = false
        p.hasShadow = false
        p.delegate = self
        p.sharingType = .none  // exclude from CGWindowListCreateImage captures

        let lv = LoupeView(frame: NSRect(x: 0, y: 0, width: sz, height: sz + infoH))
        p.contentView = lv
        loupeView = lv
        panel = p

        refreshLoupe()
        p.makeKeyAndOrderFront(nil)

        moveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.refreshLoupe() }
        }
        leftClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor in self?.confirmPick() }
        }
        rightClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .rightMouseDown) { [weak self] _ in
            Task { @MainActor in self?.deactivate() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard self?.panel != nil else { return event }
            if event.keyCode == 53 { Task { @MainActor in self?.deactivate() }; return nil }
            return event
        }
    }

    func deactivate() {
        [moveMonitor, leftClickMonitor, rightClickMonitor, keyMonitor].forEach {
            if let m = $0 { NSEvent.removeMonitor(m) }
        }
        moveMonitor = nil; leftClickMonitor = nil
        rightClickMonitor = nil; keyMonitor = nil
        panel?.close()
        panel = nil; loupeView = nil
    }

    // MARK: - Internal

    private func refreshLoupe() {
        let cursor = NSEvent.mouseLocation

        // Convert AppKit (bottom-left) → Quartz (top-left) using the main screen height.
        let mainH = NSScreen.screens.first?.frame.height ?? 1080
        let cgCursor = CGPoint(x: cursor.x, y: mainH - cursor.y)
        loupeView?.update(at: cgCursor)

        // Position panel offset from cursor, staying on screen.
        guard let panel, let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main else { return }
        let sz = panel.frame.size
        var origin = NSPoint(x: cursor.x + 20, y: cursor.y + 20)
        if origin.x + sz.width  > screen.frame.maxX { origin.x = cursor.x - 20 - sz.width  }
        if origin.y + sz.height > screen.frame.maxY { origin.y = cursor.y - 20 - sz.height }
        panel.setFrameOrigin(origin)
    }

    private func confirmPick() {
        guard let hex = loupeView?.colorHex else { deactivate(); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
        deactivate()
    }

    func windowWillClose(_ notification: Notification) { deactivate() }
}

// MARK: - LoupeView

private final class LoupeView: NSView {
    private(set) var colorHex: String?
    private var loupeImage: CGImage?
    private var centerColor: NSColor?

    private let captureHalf: CGFloat = 10  // capture 20×20 pts → 8× magnification in 160×160 view
    private let infoH: CGFloat = 24

    func update(at cgPoint: CGPoint) {
        let cap = captureHalf
        let rect = CGRect(x: cgPoint.x - cap, y: cgPoint.y - cap, width: cap * 2, height: cap * 2)
        guard let img = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) else { return }
        loupeImage = img

        let rep = NSBitmapImageRep(cgImage: img)
        let cx = max(0, rep.pixelsWide / 2), cy = max(0, rep.pixelsHigh / 2)
        if let c = rep.colorAt(x: cx, y: cy)?.usingColorSpace(.sRGB) {
            centerColor = c
            colorHex = String(format: "#%02X%02X%02X",
                Int((c.redComponent   * 255).rounded()),
                Int((c.greenComponent * 255).rounded()),
                Int((c.blueComponent  * 255).rounded()))
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let sz     = bounds.width
        let loupeR = NSRect(x: 0, y: infoH, width: sz, height: sz)
        let infoR  = NSRect(x: 0, y: 0,     width: sz, height: infoH)

        // Clipped circular loupe
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: loupeR.insetBy(dx: 1, dy: 1)).setClip()
        if let img = loupeImage {
            NSImage(cgImage: img, size: loupeR.size).draw(in: loupeR)
        } else {
            NSColor.black.setFill()
            NSBezierPath(rect: loupeR).fill()
        }
        NSGraphicsContext.restoreGraphicsState()

        // Outer ring
        NSColor.white.setStroke()
        let ring = NSBezierPath(ovalIn: loupeR.insetBy(dx: 1, dy: 1))
        ring.lineWidth = 2; ring.stroke()

        // Crosshair
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: loupeR.insetBy(dx: 1, dy: 1)).setClip()
        let cx = loupeR.midX, cy = loupeR.midY
        let cross = NSBezierPath()
        cross.move(to: NSPoint(x: cx - 8, y: cy)); cross.line(to: NSPoint(x: cx + 8, y: cy))
        cross.move(to: NSPoint(x: cx, y: cy - 8)); cross.line(to: NSPoint(x: cx, y: cy + 8))
        cross.lineWidth = 1
        NSColor.white.withAlphaComponent(0.9).setStroke()
        cross.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // Info bar background
        NSColor(white: 0.1, alpha: 0.88).setFill()
        NSBezierPath(roundedRect: infoR, xRadius: 4, yRadius: 4).fill()

        // Color swatch
        if let c = centerColor {
            c.setFill()
            NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: 16, height: infoH - 8), xRadius: 2, yRadius: 2).fill()
        }

        // Hex label
        if let hex = colorHex {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            NSAttributedString(string: hex, attributes: attrs).draw(at: NSPoint(x: 24, y: 5))
        }
    }
}
