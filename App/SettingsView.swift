import SwiftUI
import Defaults
import HotKey
import CentreeCore

// MARK: - Root

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            HotkeysTab()
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            OutputTab()
                .tabItem { Label("Output", systemImage: "square.and.arrow.down") }
        }
        .frame(width: 520, height: 340)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Default(.captureSoundEnabled) var soundEnabled
    @Default(.captureSoundName)    var soundName

    private let sounds = ["", "Grab", "Glass", "Blow", "Funk", "Pop", "Tink"]

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Play sound after capture", isOn: $soundEnabled)

                if soundEnabled {
                    Picker("Sound", selection: $soundName) {
                        ForEach(sounds, id: \.self) { name in
                            Text(name.isEmpty ? "Default (Grab)" : name).tag(name)
                        }
                    }
                    .onChange(of: soundName) { new in
                        let name = new.isEmpty ? "Grab" : new
                        NSSound(named: name)?.play()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Hotkeys Tab

private struct HotkeysTab: View {
    @Default(.regionHotkeyKeyCode)     var regionCode
    @Default(.regionHotkeyMods)        var regionMods
    @Default(.fullscreenHotkeyKeyCode) var fullCode
    @Default(.fullscreenHotkeyMods)    var fullMods

    var body: some View {
        Form {
            Section("Capture") {
                HotkeyRow(
                    label: "Capture Region",
                    keyCode: $regionCode,
                    modifiers: $regionMods
                )
                HotkeyRow(
                    label: "Capture Full Screen",
                    keyCode: $fullCode,
                    modifiers: $fullMods
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Output Tab

private struct OutputTab: View {
    @Default(.screenshotsDirectory) var directory
    @Default(.filenamePattern)      var pattern

    var body: some View {
        Form {
            Section("Save Location") {
                HStack {
                    Text(directory.path(percentEncoded: false))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Choose…") { pickDirectory() }
                }
            }

            Section {
                TextField("Pattern", text: $pattern)
                    .fontDesign(.monospaced)
                Text("Tokens: %year% %month% %day% %hour% %minute% %second% %counter% %uuid%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Filename Pattern")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            directory = url
        }
    }
}

// MARK: - HotkeyRow

private struct HotkeyRow: View {
    let label: String
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    @State private var isRecording = false

    private var displayString: String {
        guard let key = Key(carbonKeyCode: keyCode) else { return "–" }
        return CarbonModifiers.symbol(modifiers) + key.description.uppercased()
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HotkeyRecorderView(
                keyCode: $keyCode,
                modifiers: $modifiers,
                isRecording: $isRecording,
                displayString: displayString
            )
            .frame(width: 130, height: 24)
        }
    }
}

// MARK: - HotkeyRecorderView (NSViewRepresentable)

private struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @Binding var isRecording: Bool
    let displayString: String

    func makeNSView(context: Context) -> RecorderButton {
        let btn = RecorderButton()
        btn.coordinator = context.coordinator
        return btn
    }

    func updateNSView(_ btn: RecorderButton, context: Context) {
        btn.title = isRecording ? "Press keys…" : displayString
        btn.isRecording = isRecording
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Coordinator

    final class Coordinator: NSObject {
        var parent: HotkeyRecorderView
        init(_ parent: HotkeyRecorderView) { self.parent = parent }

        func didRecord(keyCode: UInt32, modifiers: UInt32) {
            parent.keyCode    = keyCode
            parent.modifiers  = modifiers
            parent.isRecording = false
        }
        func startRecording()  { parent.isRecording = true }
        func cancelRecording() { parent.isRecording = false }
    }

    // MARK: RecorderButton

    final class RecorderButton: NSButton {
        weak var coordinator: Coordinator?
        var isRecording: Bool = false
        private var monitor: Any?

        override init(frame: NSRect) {
            super.init(frame: frame)
            bezelStyle = .rounded
            target = self
            action = #selector(toggle)
        }
        required init?(coder: NSCoder) { fatalError() }

        @objc private func toggle() {
            isRecording ? stopMonitor() : startMonitor()
        }

        private func startMonitor() {
            coordinator?.startRecording()
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isRecording else { return event }
                let carbon = CarbonModifiers.fromNSFlags(event.modifierFlags)
                self.coordinator?.didRecord(keyCode: UInt32(event.keyCode), modifiers: carbon)
                self.stopMonitor()
                return nil   // consume the event
            }
        }

        private func stopMonitor() {
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
            coordinator?.cancelRecording()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { stopMonitor() }
        }
    }
}

// MARK: - Key description helper

extension Key: CustomStringConvertible {
    public var description: String {
        switch self {
        case .a: return "A"; case .b: return "B"; case .c: return "C"
        case .d: return "D"; case .e: return "E"; case .f: return "F"
        case .g: return "G"; case .h: return "H"; case .i: return "I"
        case .j: return "J"; case .k: return "K"; case .l: return "L"
        case .m: return "M"; case .n: return "N"; case .o: return "O"
        case .p: return "P"; case .q: return "Q"; case .r: return "R"
        case .s: return "S"; case .t: return "T"; case .u: return "U"
        case .v: return "V"; case .w: return "W"; case .x: return "X"
        case .y: return "Y"; case .z: return "Z"
        case .zero: return "0"; case .one: return "1"; case .two: return "2"
        case .three: return "3"; case .four: return "4"; case .five: return "5"
        case .six: return "6"; case .seven: return "7"; case .eight: return "8"
        case .nine: return "9"
        case .space: return "Space"
        case .return: return "↩"; case .tab: return "⇥"
        case .delete: return "⌫"; case .escape: return "⎋"
        case .leftArrow: return "←"; case .rightArrow: return "→"
        case .upArrow: return "↑"; case .downArrow: return "↓"
        case .f1: return "F1"; case .f2: return "F2"; case .f3: return "F3"
        case .f4: return "F4"; case .f5: return "F5"; case .f6: return "F6"
        case .f7: return "F7"; case .f8: return "F8"; case .f9: return "F9"
        case .f10: return "F10"; case .f11: return "F11"; case .f12: return "F12"
        default: return "?"
        }
    }
}
