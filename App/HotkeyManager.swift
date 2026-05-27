import AppKit
import HotKey
import Defaults
import CentreeCore

/// Registers and manages global hotkeys. Reads key combos from `Defaults`
/// and re-registers whenever the user changes them in Settings.
@MainActor
final class HotkeyManager {

    // MARK: Actions (injected by CentreeApp)

    var onCaptureRegion: (() -> Void)?
    var onCaptureFullScreen: (() -> Void)?

    // MARK: Private

    private var regionHotKey: HotKey?
    private var fullscreenHotKey: HotKey?
    private var observations: [Defaults.Observation] = []

    // MARK: Init

    init() {
        registerAll()
        observeChanges()
    }

    // MARK: - Registration

    func registerAll() {
        regionHotKey = makeHotKey(
            keyCode:   Defaults[.regionHotkeyKeyCode],
            modifiers: Defaults[.regionHotkeyMods]
        ) { [weak self] in self?.onCaptureRegion?() }

        fullscreenHotKey = makeHotKey(
            keyCode:   Defaults[.fullscreenHotkeyKeyCode],
            modifiers: Defaults[.fullscreenHotkeyMods]
        ) { [weak self] in self?.onCaptureFullScreen?() }
    }

    // MARK: - Observe Defaults changes

    private func observeChanges() {
        observations = [
            Defaults.observe(keys: .regionHotkeyKeyCode, .regionHotkeyMods) { [weak self] in
                self?.regionHotKey = self?.makeHotKey(
                    keyCode:   Defaults[.regionHotkeyKeyCode],
                    modifiers: Defaults[.regionHotkeyMods]
                ) { [weak self] in self?.onCaptureRegion?() }
            },
            Defaults.observe(keys: .fullscreenHotkeyKeyCode, .fullscreenHotkeyMods) { [weak self] in
                self?.fullscreenHotKey = self?.makeHotKey(
                    keyCode:   Defaults[.fullscreenHotkeyKeyCode],
                    modifiers: Defaults[.fullscreenHotkeyMods]
                ) { [weak self] in self?.onCaptureFullScreen?() }
            },
        ]
    }

    // MARK: - Factory

    private func makeHotKey(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> HotKey? {
        guard let key = Key(carbonKeyCode: keyCode) else { return nil }
        let flags = CarbonModifiers.toNSFlags(modifiers)
        let hk = HotKey(key: key, modifiers: flags)
        hk.keyDownHandler = handler
        return hk
    }
}
