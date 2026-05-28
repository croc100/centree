import AppKit
import HotKey
import Defaults
import CentreeCore

/// Registers and manages global hotkeys.
@MainActor
final class HotkeyManager {

    // MARK: Actions (injected by CentreeApp)

    var onCaptureRegion: (() -> Void)?
    var onCaptureFullScreen: (() -> Void)?
    var onClipboardHistory: (() -> Void)?
    var onCaptureLastRegion: (() -> Void)?
    var onCaptureWindowPicker: (() -> Void)?

    // MARK: Private

    private var regionHotKey: HotKey?
    private var fullscreenHotKey: HotKey?
    private var clipboardHotKey: HotKey?
    private var lastRegionHotKey: HotKey?
    private var windowPickerHotKey: HotKey?
    private var observations: [Defaults.Observation] = []

    // MARK: Init

    init() {
        registerAll()
        observeChanges()
    }

    // MARK: - Registration

    func registerAll() {
        regionHotKey = makeHotKey(
            keyCode: Defaults[.regionHotkeyKeyCode],
            modifiers: Defaults[.regionHotkeyMods]
        ) { [weak self] in self?.onCaptureRegion?() }

        fullscreenHotKey = makeHotKey(
            keyCode: Defaults[.fullscreenHotkeyKeyCode],
            modifiers: Defaults[.fullscreenHotkeyMods]
        ) { [weak self] in self?.onCaptureFullScreen?() }

        // ⌘⇧V — clipboard history (hardcoded); 768 = Carbon cmdKey|shiftKey
        clipboardHotKey = makeHotKey(keyCode: 9, modifiers: 768) {
            [weak self] in self?.onClipboardHistory?()
        }

        lastRegionHotKey = makeHotKey(
            keyCode: Defaults[.lastRegionHotkeyKeyCode],
            modifiers: Defaults[.lastRegionHotkeyMods]
        ) { [weak self] in self?.onCaptureLastRegion?() }

        windowPickerHotKey = makeHotKey(
            keyCode: Defaults[.windowPickerHotkeyKeyCode],
            modifiers: Defaults[.windowPickerHotkeyMods]
        ) { [weak self] in self?.onCaptureWindowPicker?() }
    }

    // MARK: - Observe Defaults changes

    private func observeChanges() {
        observations = [
            Defaults.observe(keys: .regionHotkeyKeyCode, .regionHotkeyMods) { [weak self] in
                self?.regionHotKey = self?.makeHotKey(
                    keyCode: Defaults[.regionHotkeyKeyCode],
                    modifiers: Defaults[.regionHotkeyMods]
                ) { [weak self] in self?.onCaptureRegion?() }
            },
            Defaults.observe(keys: .fullscreenHotkeyKeyCode, .fullscreenHotkeyMods) { [weak self] in
                self?.fullscreenHotKey = self?.makeHotKey(
                    keyCode: Defaults[.fullscreenHotkeyKeyCode],
                    modifiers: Defaults[.fullscreenHotkeyMods]
                ) { [weak self] in self?.onCaptureFullScreen?() }
            },
            Defaults.observe(keys: .lastRegionHotkeyKeyCode, .lastRegionHotkeyMods) { [weak self] in
                self?.lastRegionHotKey = self?.makeHotKey(
                    keyCode: Defaults[.lastRegionHotkeyKeyCode],
                    modifiers: Defaults[.lastRegionHotkeyMods]
                ) { [weak self] in self?.onCaptureLastRegion?() }
            },
            Defaults.observe(keys: .windowPickerHotkeyKeyCode, .windowPickerHotkeyMods) { [weak self] in
                self?.windowPickerHotKey = self?.makeHotKey(
                    keyCode: Defaults[.windowPickerHotkeyKeyCode],
                    modifiers: Defaults[.windowPickerHotkeyMods]
                ) { [weak self] in self?.onCaptureWindowPicker?() }
            },
        ]
    }

    // MARK: - Factory

    private func makeHotKey(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> HotKey? {
        guard keyCode > 0, let key = Key(carbonKeyCode: keyCode) else { return nil }
        let flags = CarbonModifiers.toNSFlags(modifiers)
        let hk = HotKey(key: key, modifiers: flags)
        hk.keyDownHandler = handler
        return hk
    }
}
