import AppKit
import SwiftUI

// MARK: - Panel

@MainActor
final class OCRResultPanel {
    static let shared = OCRResultPanel()
    private init() {}

    private var panel: NSPanel?
    private let model = OCRResultModel()

    func show(text: String) {
        model.text = text
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 340),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        p.title = "OCR Result"
        p.contentViewController = NSHostingController(rootView: OCRResultView(model: model))
        p.isReleasedWhenClosed = false
        p.level = .floating
        p.center()
        panel = p
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Model

@MainActor
private final class OCRResultModel: ObservableObject {
    @Published var text = ""
}

// MARK: - View

private struct OCRResultView: View {
    @ObservedObject var model: OCRResultModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Text(model.text.isEmpty ? "(No text found)" : model.text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            Divider()
            HStack {
                Text("\(model.text.count) characters")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Copy All") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(model.text, forType: .string)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.text.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 300, minHeight: 200)
    }
}
