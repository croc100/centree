import AppKit

// MARK: - Tool

public enum AnnotationTool: String, CaseIterable {
    case region        = "region"       // crosshair — drag to select capture area
    case select        = "select"       // move / delete existing annotations
    case rect          = "rectangle"
    case ellipse       = "ellipse"
    case line          = "line"
    case arrow         = "arrow"
    case text          = "text"
    case highlight     = "highlight"
    case pen           = "pen"
    case step          = "step"
    case blur          = "blur"         // Gaussian blur (redaction)
    case pixelate      = "pixelate"     // Mosaic / pixelate (redaction)
    case blackout      = "blackout"     // Solid fill
    case speechBalloon = "speechBalloon"// Rounded-rect speech bubble with text
    case spotlight     = "spotlight"    // Darken everything outside this region
    case magnify       = "magnify"      // Zoom loupe showing region at larger scale
}

// MARK: - Base

/// All coordinates stored in flipped view-point space (top-left origin, points).
class Annotation: NSObject {
    var color: NSColor
    var lineWidth: CGFloat

    init(color: NSColor, lineWidth: CGFloat) {
        self.color = color
        self.lineWidth = lineWidth
    }

    func draw(in rect: NSRect) {}
    func hitTest(_ point: NSPoint) -> Bool { false }
}

// MARK: - Rectangle

final class RectAnnotation: Annotation {
    var rect: NSRect

    init(rect: NSRect, color: NSColor, lineWidth: CGFloat) {
        self.rect = rect
        super.init(color: color, lineWidth: lineWidth)
    }

    override func draw(in _: NSRect) {
        color.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    override func hitTest(_ p: NSPoint) -> Bool {
        rect.insetBy(dx: -6, dy: -6).contains(p) &&
        !rect.insetBy(dx: lineWidth + 4, dy: lineWidth + 4).contains(p)
    }
}

// MARK: - Ellipse

final class EllipseAnnotation: Annotation {
    var rect: NSRect

    init(rect: NSRect, color: NSColor, lineWidth: CGFloat) {
        self.rect = rect
        super.init(color: color, lineWidth: lineWidth)
    }

    override func draw(in _: NSRect) {
        color.setStroke()
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = lineWidth
        path.stroke()
    }

    override func hitTest(_ p: NSPoint) -> Bool {
        NSBezierPath(ovalIn: rect.insetBy(dx: -6, dy: -6)).contains(p) &&
        !NSBezierPath(ovalIn: rect.insetBy(dx: lineWidth + 4, dy: lineWidth + 4)).contains(p)
    }
}

// MARK: - Line

final class LineAnnotation: Annotation {
    var start: NSPoint
    var end: NSPoint

    init(start: NSPoint, end: NSPoint, color: NSColor, lineWidth: CGFloat) {
        self.start = start; self.end = end
        super.init(color: color, lineWidth: lineWidth)
    }

    override func draw(in _: NSRect) {
        guard hypot(end.x - start.x, end.y - start.y) > 2 else { return }
        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.move(to: start)
        path.line(to: end)
        path.stroke()
    }

    override func hitTest(_ p: NSPoint) -> Bool { distanceToSegment(p, a: start, b: end) < 8 }
}

// MARK: - Arrow

final class ArrowAnnotation: Annotation {
    var start: NSPoint
    var end: NSPoint

    init(start: NSPoint, end: NSPoint, color: NSColor, lineWidth: CGFloat) {
        self.start = start; self.end = end
        super.init(color: color, lineWidth: lineWidth)
    }

    override func draw(in _: NSRect) {
        guard hypot(end.x - start.x, end.y - start.y) > 4 else { return }
        color.setStroke(); color.setFill()
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.move(to: start); path.line(to: end)
        path.stroke()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let hl: CGFloat = max(12, lineWidth * 4), ha: CGFloat = .pi / 6
        let p1 = NSPoint(x: end.x - hl * cos(angle - ha), y: end.y - hl * sin(angle - ha))
        let p2 = NSPoint(x: end.x - hl * cos(angle + ha), y: end.y - hl * sin(angle + ha))
        let head = NSBezierPath(); head.move(to: end); head.line(to: p1); head.line(to: p2); head.close()
        head.fill()
    }

    override func hitTest(_ p: NSPoint) -> Bool { distanceToSegment(p, a: start, b: end) < 8 }
}

// MARK: - Text

final class TextAnnotation: Annotation {
    var origin: NSPoint
    var text: String
    var fontSize: CGFloat

    init(origin: NSPoint, text: String, color: NSColor, fontSize: CGFloat) {
        self.origin = origin; self.text = text; self.fontSize = fontSize
        super.init(color: color, lineWidth: 1)
    }

    private var attrs: [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: fontSize, weight: .semibold), .foregroundColor: color]
    }

    override func draw(in _: NSRect) {
        guard !text.isEmpty else { return }
        NSAttributedString(string: text, attributes: attrs).draw(at: origin)
    }

    override func hitTest(_ p: NSPoint) -> Bool {
        let sz = (text as NSString).size(withAttributes: attrs)
        return NSRect(origin: origin, size: sz).insetBy(dx: -4, dy: -4).contains(p)
    }
}

// MARK: - Highlight

final class HighlightAnnotation: Annotation {
    var rect: NSRect

    init(rect: NSRect, color: NSColor) {
        self.rect = rect
        super.init(color: color, lineWidth: 0)
    }

    override func draw(in _: NSRect) {
        color.withAlphaComponent(0.35).setFill()
        NSBezierPath(rect: rect).fill()
    }

    override func hitTest(_ p: NSPoint) -> Bool { rect.insetBy(dx: -4, dy: -4).contains(p) }
}

// MARK: - Pen

final class PenAnnotation: Annotation {
    var points: [NSPoint] = []

    override init(color: NSColor, lineWidth: CGFloat) { super.init(color: color, lineWidth: lineWidth) }

    func addPoint(_ p: NSPoint) { points.append(p) }

    override func draw(in _: NSRect) {
        guard points.count > 1 else { return }
        color.setStroke()
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round; path.lineJoinStyle = .round
        path.move(to: points[0])
        points.dropFirst().forEach { path.line(to: $0) }
        path.stroke()
    }

    override func hitTest(_ p: NSPoint) -> Bool {
        guard points.count > 1 else { return false }
        for i in 1..<points.count {
            if distanceToSegment(p, a: points[i-1], b: points[i]) < 8 { return true }
        }
        return false
    }
}

// MARK: - Step

final class StepAnnotation: Annotation {
    var center: NSPoint
    var number: Int
    private let r: CGFloat = 12

    init(center: NSPoint, number: Int, color: NSColor) {
        self.center = center; self.number = number
        super.init(color: color, lineWidth: 2)
    }

    override func draw(in _: NSRect) {
        let circle = NSRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2)
        color.setFill(); NSBezierPath(ovalIn: circle).fill()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let label = "\(number)"
        let sz = (label as NSString).size(withAttributes: attrs)
        label.draw(at: NSPoint(x: center.x - sz.width/2, y: center.y - sz.height/2), withAttributes: attrs)
    }

    override func hitTest(_ p: NSPoint) -> Bool { hypot(p.x - center.x, p.y - center.y) <= r + 6 }
}

// MARK: - Blackout

final class BlackoutAnnotation: Annotation {
    var rect: NSRect

    init(rect: NSRect) {
        self.rect = rect
        super.init(color: .black, lineWidth: 0)
    }

    override func draw(in _: NSRect) {
        NSColor.black.setFill()
        NSBezierPath(rect: rect).fill()
    }

    override func hitTest(_ p: NSPoint) -> Bool { rect.insetBy(dx: -4, dy: -4).contains(p) }
}

// MARK: - Blur (CoreImage rendering handled by canvas)

final class BlurAnnotation: Annotation {
    var rect: NSRect
    var radius: CGFloat

    init(rect: NSRect, radius: CGFloat = 20) {
        self.rect = rect; self.radius = radius
        super.init(color: .clear, lineWidth: 0)
    }

    override func draw(in _: NSRect) {
        // Fallback when CoreImage path is unavailable
        NSColor.black.withAlphaComponent(0.25).setFill()
        NSBezierPath(rect: rect).fill()
    }

    override func hitTest(_ p: NSPoint) -> Bool { rect.insetBy(dx: -4, dy: -4).contains(p) }
}

// MARK: - Pixelate (CoreImage rendering handled by canvas)

final class PixelateAnnotation: Annotation {
    var rect: NSRect
    var pixelSize: CGFloat

    init(rect: NSRect, pixelSize: CGFloat = 12) {
        self.rect = rect; self.pixelSize = pixelSize
        super.init(color: .clear, lineWidth: 0)
    }

    override func draw(in _: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        NSBezierPath(rect: rect).fill()
    }

    override func hitTest(_ p: NSPoint) -> Bool { rect.insetBy(dx: -4, dy: -4).contains(p) }
}

// MARK: - Speech Balloon

final class SpeechBalloonAnnotation: Annotation {
    var rect: NSRect
    var text: String
    var fontSize: CGFloat

    init(rect: NSRect, text: String = "", color: NSColor, fontSize: CGFloat) {
        self.rect = rect; self.text = text; self.fontSize = fontSize
        super.init(color: color, lineWidth: 2)
    }

    override func draw(in _: NSRect) {
        guard rect.width > 8, rect.height > 8 else { return }

        // Body
        let bodyPath = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSColor.white.withAlphaComponent(0.92).setFill()
        bodyPath.fill()

        // Tail — triangle below bottom-left of body
        let tailPath = NSBezierPath()
        let bx = rect.minX + 18; let by = rect.maxY
        tailPath.move(to: NSPoint(x: bx,      y: by))
        tailPath.line(to: NSPoint(x: rect.minX - 6, y: by + 16))
        tailPath.line(to: NSPoint(x: bx + 14, y: by))
        tailPath.close()
        NSColor.white.withAlphaComponent(0.92).setFill()
        tailPath.fill()

        // Stroke body + tail outline
        color.setStroke()
        bodyPath.lineWidth = lineWidth; bodyPath.stroke()
        let tailStroke = NSBezierPath()
        tailStroke.move(to: NSPoint(x: bx, y: by))
        tailStroke.line(to: NSPoint(x: rect.minX - 6, y: by + 16))
        tailStroke.line(to: NSPoint(x: bx + 14, y: by))
        tailStroke.lineWidth = lineWidth; color.setStroke(); tailStroke.stroke()

        // Text
        let pad: CGFloat = 8
        let textRect = rect.insetBy(dx: pad, dy: pad)
        let str = text.isEmpty ? "Type…" : text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: text.isEmpty ? NSColor.placeholderTextColor : color
        ]
        NSAttributedString(string: str, attributes: attrs).draw(in: textRect)
    }

    override func hitTest(_ p: NSPoint) -> Bool { rect.insetBy(dx: -6, dy: -6).contains(p) }
}

// MARK: - Spotlight
// Rendering is handled at the canvas level (unified dark overlay with holes).
// draw() is intentionally empty.

final class SpotlightAnnotation: Annotation {
    var rect: NSRect

    init(rect: NSRect, color: NSColor = .white, lineWidth: CGFloat = 2) {
        self.rect = rect
        super.init(color: color, lineWidth: lineWidth)
    }

    // No-op — OverlayView / renderFinalImage draw the composite overlay.
    override func draw(in _: NSRect) {}
    override func hitTest(_ p: NSPoint) -> Bool { rect.insetBy(dx: -6, dy: -6).contains(p) }
}

// MARK: - Magnify (Loupe)
// Actual pixel content is drawn by OverlayView / renderFinalImage (needs base image).

final class MagnifyAnnotation: Annotation {
    var rect: NSRect
    var scale: CGFloat   // 2 = 2× zoom

    init(rect: NSRect, scale: CGFloat = 2, color: NSColor, lineWidth: CGFloat) {
        self.rect = rect; self.scale = scale
        super.init(color: color, lineWidth: lineWidth)
    }

    // Fallback when base image is unavailable
    override func draw(in _: NSRect) {
        guard rect.width > 4, rect.height > 4 else { return }
        color.setStroke()
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = lineWidth; path.stroke()
        // Draw ×N label
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: color
        ]
        let label = "×\(Int(scale))"
        let sz = (label as NSString).size(withAttributes: attrs)
        label.draw(at: NSPoint(x: rect.midX - sz.width/2, y: rect.midY - sz.height/2),
                   withAttributes: attrs)
    }

    override func hitTest(_ p: NSPoint) -> Bool {
        NSBezierPath(ovalIn: rect.insetBy(dx: -6, dy: -6)).contains(p)
    }
}

// MARK: - Geometry helper

private func distanceToSegment(_ p: NSPoint, a: NSPoint, b: NSPoint) -> CGFloat {
    let dx = b.x - a.x, dy = b.y - a.y
    let lenSq = dx*dx + dy*dy
    guard lenSq > 0 else { return hypot(p.x - a.x, p.y - a.y) }
    let t = max(0, min(1, ((p.x - a.x)*dx + (p.y - a.y)*dy) / lenSq))
    return hypot(p.x - (a.x + t*dx), p.y - (a.y + t*dy))
}
