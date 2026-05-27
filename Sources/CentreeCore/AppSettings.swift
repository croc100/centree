import AppKit
import Foundation
import Defaults

// MARK: - Defaults Keys

public extension Defaults.Keys {

    // MARK: Output

    /// Directory where screenshots are saved.
    static let screenshotsDirectory = Key<URL>(
        "screenshotsDirectory",
        default: FileManager.default
            .urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Centree")
    )

    /// Filename token pattern (see NameParser for supported tokens).
    static let filenamePattern = Key<String>(
        "filenamePattern",
        default: "%year%-%month%-%day%_%hour%%minute%%second%_%counter%.png"
    )

    // MARK: Sound

    /// Play shutter sound after a successful capture.
    static let captureSoundEnabled = Key<Bool>("captureSoundEnabled", default: true)

    /// NSSound name to play. Empty string = system "Grab" sound.
    static let captureSoundName = Key<String>("captureSoundName", default: "")

    // MARK: Hotkeys — Region capture (⌘⇧4 default = keyCode 21, mods 1179648)

    static let regionHotkeyKeyCode  = Key<UInt32>("regionHotkeyKeyCode",  default: 21)
    static let regionHotkeyMods     = Key<UInt32>("regionHotkeyMods",     default: 1_179_648)

    // MARK: Hotkeys — Full-screen capture (⌘⇧3 default = keyCode 20, mods 1179648)

    static let fullscreenHotkeyKeyCode = Key<UInt32>("fullscreenHotkeyKeyCode", default: 20)
    static let fullscreenHotkeyMods    = Key<UInt32>("fullscreenHotkeyMods",    default: 1_179_648)
}

// MARK: - Carbon modifier helpers

/// Converts Carbon-style modifier flags (stored in Defaults) ↔ NSEvent.ModifierFlags.
public enum CarbonModifiers {
    // Carbon modifier constants
    static let cmdKey:   UInt32 = 1 << 8   // 256
    static let shiftKey: UInt32 = 1 << 9   // 512
    static let optKey:   UInt32 = 1 << 11  // 2048
    static let ctrlKey:  UInt32 = 1 << 12  // 4096

    public static func toNSFlags(_ carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & cmdKey   != 0 { flags.insert(.command) }
        if carbon & shiftKey != 0 { flags.insert(.shift) }
        if carbon & optKey   != 0 { flags.insert(.option) }
        if carbon & ctrlKey  != 0 { flags.insert(.control) }
        return flags
    }

    public static func fromNSFlags(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= cmdKey }
        if flags.contains(.shift)   { carbon |= shiftKey }
        if flags.contains(.option)  { carbon |= optKey }
        if flags.contains(.control) { carbon |= ctrlKey }
        return carbon
    }

    /// Human-readable string like "⌘⇧".
    public static func symbol(_ carbon: UInt32) -> String {
        var s = ""
        if carbon & ctrlKey  != 0 { s += "⌃" }
        if carbon & optKey   != 0 { s += "⌥" }
        if carbon & shiftKey != 0 { s += "⇧" }
        if carbon & cmdKey   != 0 { s += "⌘" }
        return s
    }
}
