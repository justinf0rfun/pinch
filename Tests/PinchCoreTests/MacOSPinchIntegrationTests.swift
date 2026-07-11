import AppKit
import ApplicationServices
import Testing
@testable import PinchCore

@MainActor
@Test("direct Accessibility insertion replaces the selection in a native text field")
func directAccessibilityInsertionSmokeTest() throws {
    guard ProcessInfo.processInfo.environment["PINCH_RUN_AX_SMOKE"] == "1" else { return }
    guard AXIsProcessTrusted() else { throw MacOSPinchIntegration.IntegrationError.accessibilityPermission }
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    application.finishLaunching()

    let field = NSTextField(frame: NSRect(x: 20, y: 20, width: 320, height: 28))
    field.stringValue = "before selection after"
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 360, height: 80),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.contentView = field
    window.makeKeyAndOrderFront(nil)
    application.activate()
    window.makeFirstResponder(field)
    field.selectText(nil)
    field.currentEditor()?.selectedRange = NSRange(location: 7, length: 9)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    defer { window.orderOut(nil) }

    let integration = MacOSPinchIntegration()
    let target = try integration.captureTarget()
    try integration.deliver("inserted", to: target)

    #expect(field.currentEditor()?.string == "before inserted after")
}
