import AppKit

/// Creates a floating, always-on-top window showing a captured image.
/// Multiple images can be pinned simultaneously — each call creates a new panel.
@MainActor
final class PinToScreenPanel: NSObject, NSWindowDelegate {

    // Retains all live pinned panels to prevent deallocation.
    private static var active: [PinToScreenPanel] = []

    static func pin(image: CGImage) {
        let p = PinToScreenPanel(image: image)
        active.append(p)
        p.panel.center()
        p.panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: -

    private var panel: NSPanel!

    private init(image: CGImage) {
        super.init()

        let maxW: CGFloat = 800
        let imgW = CGFloat(image.width), imgH = CGFloat(image.height)
        let scale = min(maxW / imgW, 1.0)
        let w = imgW * scale, h = imgH * scale

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.title = "Pinned Image"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let iv = NSImageView()
        iv.image = NSImage(cgImage: image, size: NSSize(width: w, height: h))
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.autoresizingMask = [.width, .height]
        panel.contentView = iv
    }

    func windowWillClose(_ notification: Notification) {
        Self.active.removeAll { $0 === self }
    }
}
