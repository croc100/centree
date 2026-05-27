import SwiftUI
import Defaults

/// SwiftUI content for the MenuBarExtra dropdown.
struct MenuBarMenuView: View {
    @EnvironmentObject var coordinator: CaptureCoordinator
    @Default(.savedRegions)    var savedRegions
    @Default(.lastCaptureRect) var lastCaptureRect
    @ObservedObject private var autoCapture = AutoCaptureManager.shared

    var body: some View {
        Button("Capture Region        ⌘⇧4") { coordinator.captureWithOverlay() }
        Button("Capture Full Screen   ⌘⇧3") { coordinator.captureFullScreen() }
        Button("Capture Window…")            { coordinator.captureWindowPicker() }

        Button("Repeat Last Region") { coordinator.captureLastRegion() }
            .disabled(lastCaptureRect == nil)

        if !savedRegions.isEmpty {
            Divider()
            Menu("Saved Regions") {
                ForEach(savedRegions) { region in
                    Button(region.name) { coordinator.captureSavedRegion(id: region.id) }
                }
            }
        }

        Divider()

        Button("Color Picker") { ColorPickerPanel.shared.activate() }

        Button(autoCapture.isRunning ? "Stop Auto Capture" : "Start Auto Capture") {
            autoCapture.toggle()
        }

        Divider()

        Button("Clipboard History    ⌘⇧V") { ClipboardHistoryPanel.shared.toggle() }

        Divider()

        Button("Settings…") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Centree") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
