import Carbon.HIToolbox
import Foundation

public struct ShortcutModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let command = Self(rawValue: 1 << 0)
    public static let control = Self(rawValue: 1 << 1)
    public static let option = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
}

public struct Shortcut: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: ShortcutModifiers

    public init(keyCode: UInt32, modifiers: ShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let `default` = Shortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: [.option]
    )

    public var displayName: String {
        let prefix = [
            modifiers.contains(.control) ? "⌃" : "",
            modifiers.contains(.option) ? "⌥" : "",
            modifiers.contains(.shift) ? "⇧" : "",
            modifiers.contains(.command) ? "⌘" : ""
        ].joined()
        return prefix + Self.keyName(keyCode)
    }

    public var carbonModifiers: UInt32 {
        (modifiers.contains(.command) ? UInt32(cmdKey) : 0)
            | (modifiers.contains(.control) ? UInt32(controlKey) : 0)
            | (modifiers.contains(.option) ? UInt32(optionKey) : 0)
            | (modifiers.contains(.shift) ? UInt32(shiftKey) : 0)
    }

    public var validation: ShortcutValidation {
        if modifiers.intersection([.command, .control, .option]).isEmpty { return .reserved }
        return .valid
    }

    private static func keyName(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Delete: "Delete"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        default:
            keyCodeToString(keyCode) ?? "Key \(keyCode)"
        }
    }

    private static func keyCodeToString(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let data = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = unsafeBitCast(data, to: CFData.self) as Data
        return layoutData.withUnsafeBytes { bytes in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return nil
            }
            var deadKeyState: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, characters.count, &length, &characters
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length).uppercased()
        }
    }
}

public enum ShortcutValidation: Equatable, Sendable {
    case valid
    case reserved
}

public enum ShortcutSettingsError: Equatable, Sendable {
    case duplicate
    case reserved
    case registrationConflict
}

public struct ShortcutRecorderState: Equatable, Sendable {
    private let active: Shortcut
    public private(set) var draft: Shortcut?
    public private(set) var isRecording = false

    public init(active: Shortcut) {
        self.active = active
        draft = active
    }

    public var validation: ShortcutValidation? { draft?.validation }

    public mutating func beginRecording() { isRecording = true }
    public mutating func record(_ shortcut: Shortcut) {
        draft = shortcut
        isRecording = false
    }
    public mutating func cancel() {
        draft = active
        isRecording = false
    }
    public mutating func restoreDefault() {
        draft = .default
        isRecording = false
    }
}

public struct ShortcutSettings: Sendable {
    public private(set) var active: Shortcut
    public private(set) var error: ShortcutSettingsError?

    public init(active: Shortcut) { self.active = active }

    public mutating func save(
        _ candidate: Shortcut,
        activate: (Shortcut) -> Bool
    ) -> Bool {
        guard candidate != active else {
            error = .duplicate
            return false
        }
        guard candidate.validation == .valid else {
            error = .reserved
            return false
        }
        guard activate(candidate) else {
            error = .registrationConflict
            return false
        }
        active = candidate
        error = nil
        return true
    }

    public mutating func replaceActive(with shortcut: Shortcut) {
        active = shortcut
        error = nil
    }
}

public struct ShortcutStore {
    private static let key = "globalShortcut"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> Shortcut {
        guard let data = defaults.data(forKey: Self.key),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data),
              shortcut.validation == .valid else { return .default }
        return shortcut
    }

    public func save(_ shortcut: Shortcut) {
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: Self.key)
    }
}
