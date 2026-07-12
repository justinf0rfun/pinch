import Carbon.HIToolbox
import Foundation
import PinchCore
import Testing

@Test("shortcut recording can cancel, restore the default, and reject invalid combinations")
func shortcutRecordingState() {
    var recorder = ShortcutRecorderState(active: .default)

    recorder.beginRecording()
    recorder.record(Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: [.command]))
    #expect(recorder.draft?.displayName == "⌘K")
    recorder.cancel()
    #expect(recorder.draft == .default)

    recorder.beginRecording()
    recorder.record(Shortcut(keyCode: UInt32(kVK_Space), modifiers: []))
    #expect(recorder.validation == .reserved)

    recorder.restoreDefault()
    #expect(recorder.draft == .default)
}

@Test("saving a conflicting shortcut preserves the last working combination")
func shortcutConflictPreservesActiveShortcut() {
    var activated: [Shortcut] = []
    var settings = ShortcutSettings(active: .default)
    let candidate = Shortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: [.command, .shift])

    let saved = settings.save(candidate) { shortcut in
        activated.append(shortcut)
        return false
    }

    #expect(!saved)
    #expect(settings.active == .default)
    #expect(settings.error == .registrationConflict)
    #expect(activated == [candidate])
}

@Test("saving a valid shortcut activates and persists it")
func shortcutSaveAndPersistence() throws {
    let suite = "ShortcutSettingsTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = ShortcutStore(defaults: defaults)
    var settings = ShortcutSettings(active: store.load())
    let candidate = Shortcut(keyCode: UInt32(kVK_ANSI_P), modifiers: [.control, .option])

    #expect(settings.save(candidate) { _ in true })
    store.save(settings.active)

    #expect(ShortcutStore(defaults: defaults).load() == candidate)
    #expect(settings.error == nil)
}

@Test("saving the active shortcut is reported as a duplicate")
func duplicateShortcut() {
    var settings = ShortcutSettings(active: .default)
    #expect(!settings.save(.default) { _ in true })
    #expect(settings.error == .duplicate)
}
