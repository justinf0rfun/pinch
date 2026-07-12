import ApplicationServices
import AppKit
import Observation
import PinchCore

@MainActor @Observable
final class AppSettings {
    var shortcut: ShortcutSettings
    var recorder: ShortcutRecorderState
    var permissionStatus: AccessibilityStatus
    var activateShortcut: (Shortcut) -> Bool = { _ in false }

    private let shortcutStore = ShortcutStore()
    private var permission: PinchCore.AccessibilitySettings
    private var openedAccessibilitySettings = false

    init(shortcut: Shortcut) {
        self.shortcut = ShortcutSettings(active: shortcut)
        recorder = ShortcutRecorderState(active: shortcut)
        let permission = PinchCore.AccessibilitySettings(isTrusted: AXIsProcessTrusted)
        self.permission = permission
        permissionStatus = permission.status
    }

    func refreshPermission(returnedFromSettings: Bool = false) {
        if returnedFromSettings || openedAccessibilitySettings {
            permission.didReturnFromSystemSettings()
            openedAccessibilitySettings = false
        } else {
            permission.refresh()
        }
        permissionStatus = permission.status
    }

    func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        refreshPermission()
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        openedAccessibilitySettings = true
        NSWorkspace.shared.open(url)
    }

    func beginRecording() { recorder.beginRecording() }
    func cancelRecording() { recorder.cancel() }
    func restoreDefault() { recorder.restoreDefault() }
    func record(_ candidate: Shortcut) { recorder.record(candidate) }

    func saveShortcut() {
        guard let candidate = recorder.draft,
              shortcut.save(candidate, activate: activateShortcut) else { return }
        shortcutStore.save(shortcut.active)
        recorder = ShortcutRecorderState(active: shortcut.active)
    }

    func useFallbackShortcut(_ fallback: Shortcut) {
        shortcut.replaceActive(with: fallback)
        shortcutStore.save(fallback)
        recorder = ShortcutRecorderState(active: fallback)
    }
}
