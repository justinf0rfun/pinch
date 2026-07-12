import AppKit
import PinchCore
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let isRecording: Bool
    let record: (Shortcut) -> Void
    let cancel: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        RecorderNSView(record: record, cancel: cancel)
    }

    func updateNSView(_ view: RecorderNSView, context: Context) {
        view.record = record
        view.cancel = cancel
        if isRecording, view.window?.firstResponder !== view {
            view.window?.makeFirstResponder(view)
        }
    }
}

final class RecorderNSView: NSView {
    var record: (Shortcut) -> Void
    var cancel: () -> Void

    init(record: @escaping (Shortcut) -> Void, cancel: @escaping () -> Void) {
        self.record = record
        self.cancel = cancel
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            cancel()
            return
        }
        record(Shortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: event.modifierFlags.shortcutModifiers
        ))
    }
}

private extension NSEvent.ModifierFlags {
    var shortcutModifiers: ShortcutModifiers {
        var result: ShortcutModifiers = []
        if contains(.command) { result.insert(.command) }
        if contains(.control) { result.insert(.control) }
        if contains(.option) { result.insert(.option) }
        if contains(.shift) { result.insert(.shift) }
        return result
    }
}
