import AppKit
import Combine

// MARK: - ClipboardItem

enum ClipboardItem: Identifiable {
    case text(String)
    case image(NSImage)

    var id: String {
        switch self {
        case .text(let s):   return "t-\(s.prefix(40))"
        case .image(let i):  return "i-\(ObjectIdentifier(i).hashValue)"
        }
    }

    var displayText: String {
        switch self {
        case .text(let s):  return s.prefix(120).replacingOccurrences(of: "\n", with: " ")
        case .image(let i): return "Image \(Int(i.size.width))×\(Int(i.size.height))"
        }
    }
}

// MARK: - ClipboardHistoryManager

/// Polls `NSPasteboard.general` for changes and maintains a capped history.
@MainActor
final class ClipboardHistoryManager: ObservableObject {

    static let shared = ClipboardHistoryManager()

    @Published private(set) var items: [ClipboardItem] = []

    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var timer: Timer?
    private let maxItems = 30

    private init() { startPolling() }

    deinit { timer?.invalidate() }

    // MARK: - Poll

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkPasteboard() }
        }
    }

    private func checkPasteboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        if let str = pb.string(forType: .string), !str.isEmpty {
            push(.text(str))
        } else if let data = pb.data(forType: .tiff),
                  let img = NSImage(data: data) {
            push(.image(img))
        } else if let data = pb.data(forType: .png),
                  let img = NSImage(data: data) {
            push(.image(img))
        }
    }

    private func push(_ item: ClipboardItem) {
        // Deduplicate by id
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        if items.count > maxItems { items = Array(items.prefix(maxItems)) }
    }

    // MARK: - Copy back

    func copyToClipboard(_ item: ClipboardItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item {
        case .text(let s):   pb.setString(s, forType: .string)
        case .image(let i):
            if let tiff = i.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
        }
        // Don't push back — it would show as a duplicate
        lastChangeCount = pb.changeCount
    }

    func clear() { items.removeAll() }
}
