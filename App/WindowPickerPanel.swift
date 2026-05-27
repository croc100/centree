import AppKit
import SwiftUI
import ScreenCaptureKit

// MARK: - WindowPickerPanel

/// Shows a list of open windows. Await `pick(from:)` — returns the chosen SCWindow or nil.
@MainActor
final class WindowPickerPanel {

    static let shared = WindowPickerPanel()

    private var panel: NSPanel?
    private var continuation: CheckedContinuation<SCWindow?, Never>?

    func pick(from windows: [SCWindow]) async -> SCWindow? {
        return await withCheckedContinuation { cont in
            continuation = cont
            showPanel(windows: filtered(windows))
        }
    }

    private func filtered(_ windows: [SCWindow]) -> [SCWindow] {
        let selfID = Bundle.main.bundleIdentifier ?? ""
        return windows
            .filter {
                $0.isOnScreen &&
                $0.frame.width  > 80 &&
                $0.frame.height > 80 &&
                $0.owningApplication?.bundleIdentifier != selfID &&
                $0.owningApplication?.applicationName != "Dock" &&
                $0.owningApplication?.applicationName != "Window Server"
            }
            .sorted {
                ($0.owningApplication?.applicationName ?? "") <
                ($1.owningApplication?.applicationName ?? "")
            }
    }

    private func showPanel(windows: [SCWindow]) {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.title = "Select Window to Capture"
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.contentView = NSHostingView(
            rootView: WindowListView(windows: windows, onPick: { [weak self] result in
                self?.panel?.close()
                self?.panel = nil
                self?.continuation?.resume(returning: result)
                self?.continuation = nil
            })
        )
        p.center()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = p
    }
}

// MARK: - SwiftUI list

private struct WindowListView: View {
    let windows: [SCWindow]
    let onPick: (SCWindow?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(windows, id: \.windowID) { win in
                Button { onPick(win) } label: {
                    HStack(spacing: 10) {
                        appIcon(for: win)
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(win.title ?? win.owningApplication?.applicationName ?? "Untitled")
                                .lineLimit(1)
                            if let app = win.owningApplication {
                                Text(app.applicationName)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(Int(win.frame.width)) × \(Int(win.frame.height))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { onPick(nil) }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(10)
        }
        .frame(width: 600, height: 460)
    }

    private func appIcon(for win: SCWindow) -> Image {
        guard let bundleID = win.owningApplication?.bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else {
            return Image(systemName: "app")
        }
        return Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
    }
}
