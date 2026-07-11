import AppKit
import ApplicationServices
import Testing
@testable import PinchCore

@Test("only the ChatGPT app supports an attached composer marker")
func chatGPTMarkerSupport() {
    #expect(MacOSPinchIntegration.supportsMarker(bundleIdentifier: "com.openai.codex", applicationName: "Codex", role: kAXTextAreaRole, domClasses: ["ProseMirror", "ProseMirror-focused"]))
    #expect(MacOSPinchIntegration.supportsMarker(bundleIdentifier: nil, applicationName: "ChatGPT", role: kAXTextAreaRole, domClasses: ["ProseMirror"]))
    #expect(MacOSPinchIntegration.supportsMarker(bundleIdentifier: "com.openai.codex", applicationName: "ChatGPT", role: kAXTextAreaRole, domClasses: ["ProseMirror"]))
    #expect(!MacOSPinchIntegration.supportsMarker(bundleIdentifier: "com.openai.codex", applicationName: "Codex", role: kAXTextFieldRole, domClasses: ["ProseMirror"]))
    #expect(!MacOSPinchIntegration.supportsMarker(bundleIdentifier: "com.openai.codex", applicationName: "Codex", role: kAXTextAreaRole, domClasses: []))
    #expect(!MacOSPinchIntegration.supportsMarker(bundleIdentifier: nil, applicationName: "ChatGPT", role: kAXTextFieldRole, domClasses: ["ProseMirror"]))
    #expect(!MacOSPinchIntegration.supportsMarker(bundleIdentifier: nil, applicationName: "ChatGPT", role: kAXTextAreaRole, domClasses: []))
    #expect(!MacOSPinchIntegration.supportsMarker(bundleIdentifier: "com.apple.Terminal", applicationName: "Terminal", role: kAXTextAreaRole, domClasses: ["ProseMirror"]))
    #expect(!MacOSPinchIntegration.supportsMarker(bundleIdentifier: "com.example.codex-helper", applicationName: "Codex Helper", role: kAXTextAreaRole, domClasses: ["ProseMirror"]))
}

@Test("the ChatGPT composer surface, not its editor, anchors the marker")
func chatGPTComposerFrame() {
    let editor = CGRect(x: 1023, y: 1006, width: 712, height: 44)
    let composer = CGRect(x: 1011, y: 992, width: 736, height: 98)
    let ancestors = [
        (frame: editor, domClasses: ["relative", "text-size-chat"]),
        (frame: composer, domClasses: ["composer-surface-chrome", "relative"]),
        (frame: CGRect(x: 995, y: 960, width: 768, height: 130), domClasses: ["px-toolbar"])
    ]

    #expect(MacOSPinchIntegration.composerFrame(editorFrame: editor, ancestors: ancestors) == composer)
    #expect(MacOSPinchIntegration.composerFrame(editorFrame: editor, ancestors: []) == editor)
}

@MainActor
@Test("direct Accessibility insertion survives focus moving to the picker")
func directAccessibilityInsertionSmokeTest() throws {
    guard ProcessInfo.processInfo.environment["PINCH_RUN_AX_SMOKE"] == "1" else { return }
    guard AXIsProcessTrusted() else { throw MacOSPinchIntegration.IntegrationError.accessibilityPermission }
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    application.finishLaunching()

    let field = NSTextView(frame: NSRect(x: 20, y: 20, width: 320, height: 28))
    field.string = "before selection after"
    let pickerButton = NSButton(title: "Choose phrase", target: nil, action: nil)
    pickerButton.frame = NSRect(x: 20, y: 56, width: 120, height: 24)
    let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 96))
    contentView.addSubview(field)
    contentView.addSubview(pickerButton)
    let window = NSWindow(
        contentRect: contentView.frame,
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)
    application.activate(ignoringOtherApps: true)
    window.makeFirstResponder(field)
    field.selectedRange = NSRange(location: 7, length: 9)
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    defer { window.orderOut(nil) }

    let integration = MacOSPinchIntegration()
    let target = try integration.captureTarget()
    window.makeFirstResponder(pickerButton)
    try integration.deliver("inserted", to: target)

    #expect(window.firstResponder === field)
    #expect(field.string == "before inserted after")
}
