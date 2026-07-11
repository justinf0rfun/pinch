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
        MacOSPinchIntegration.AccessibilityAncestor(frame: editor, domClasses: ["relative", "text-size-chat"]),
        MacOSPinchIntegration.AccessibilityAncestor(frame: composer, domClasses: ["composer-surface-chrome", "relative"]),
        MacOSPinchIntegration.AccessibilityAncestor(
            frame: CGRect(x: 995, y: 960, width: 768, height: 130),
            domClasses: ["px-toolbar"]
        )
    ]

    #expect(MacOSPinchIntegration.composerFrame(ancestors: ancestors) == composer)
    #expect(MacOSPinchIntegration.composerFrame(ancestors: []) == nil)
}

@Test("ChatGPT's accessible placeholder is not treated as draft text")
func chatGPTPlaceholderText() {
    #expect(MacOSPinchIntegration.chatGPTText(
        rawValue: "\nAsk for follow-up changes",
        selectionLocation: 0,
        selectionLength: 0
    ) == "")
    #expect(MacOSPinchIntegration.chatGPTText(
        rawValue: "actual draft",
        selectionLocation: 0,
        selectionLength: 0
    ) == "actual draft")
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

    #expect(field.string == "before inserted after")
}

@MainActor
@Test("ChatGPT ProseMirror accepts insertion after focus moves to the picker")
func chatGPTAccessibilityInsertionSmokeTest() throws {
    guard ProcessInfo.processInfo.environment["PINCH_RUN_CHATGPT_AX_SMOKE"] == "1" else { return }
    guard AXIsProcessTrusted() else { throw MacOSPinchIntegration.IntegrationError.accessibilityPermission }
    guard let chatGPT = NSRunningApplication.runningApplications(withBundleIdentifier: "com.openai.codex").first else {
        throw MacOSPinchIntegration.IntegrationError.noEditableTarget
    }

    chatGPT.activate()
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    guard let composer = focusedChatGPTComposer(application: chatGPT) else {
        throw MacOSPinchIntegration.IntegrationError.noEditableTarget
    }
    guard AXUIElementSetAttributeValue(
        composer,
        kAXFocusedAttribute as CFString,
        kCFBooleanTrue
    ) == .success else { throw MacOSPinchIntegration.IntegrationError.noEditableTarget }
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))

    let originalValue = accessibilityString(composer, kAXValueAttribute) ?? ""
    let originalDraft = originalValue.hasPrefix("\n") ? "" : originalValue
    let integration = MacOSPinchIntegration()
    let target = try integration.captureTarget()

    let pickerButton = NSButton(title: "Choose phrase", target: nil, action: nil)
    let pickerWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 160, height: 60),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    pickerWindow.contentView = pickerButton
    pickerWindow.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
    pickerWindow.makeFirstResponder(pickerButton)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    defer { pickerWindow.orderOut(nil) }

    let phrase = "确认，继续"
    var didRestoreDraft = false
    defer {
        if !didRestoreDraft {
            try? restoreChatGPTComposer(
                composer,
                processIdentifier: chatGPT.processIdentifier,
                draft: originalDraft
            )
        }
    }
    try integration.deliver(phrase, to: target)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    let inserted = accessibilityString(composer, kAXValueAttribute)

    try restoreChatGPTComposer(
        composer,
        processIdentifier: chatGPT.processIdentifier,
        draft: originalDraft
    )
    didRestoreDraft = true
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    let restored = accessibilityString(composer, kAXValueAttribute)

    #expect(inserted?.contains(phrase) == true)
    #expect(originalDraft.isEmpty ? (restored == "" || restored?.hasPrefix("\n") == true) : restored == originalDraft)
}

private func focusedChatGPTComposer(application: NSRunningApplication) -> AXUIElement? {
    let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
    var focusedWindowValue: CFTypeRef?
    let root = AXUIElementCopyAttributeValue(
        applicationElement,
        kAXFocusedWindowAttribute as CFString,
        &focusedWindowValue
    ) == .success ? focusedWindowValue as! AXUIElement? : applicationElement
    guard let root else { return nil }

    var queue = [root]
    while !queue.isEmpty {
        let element = queue.removeFirst()
        var domClassesValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXDOMClassListAttribute as CFString, &domClassesValue)
        if (domClassesValue as? [String] ?? []).contains("ProseMirror") { return element }

        var childrenValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &childrenValue
        ) == .success {
            queue.append(contentsOf: childrenValue as? [AXUIElement] ?? [])
        }
    }
    return nil
}

private func accessibilityString(_ element: AXUIElement, _ attribute: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value as? String
}

private func restoreChatGPTComposer(
    _ element: AXUIElement,
    processIdentifier: pid_t,
    draft: String
) throws {
    guard AXUIElementSetAttributeValue(
        element,
        kAXFocusedAttribute as CFString,
        kCFBooleanTrue
    ) == .success else { throw MacOSPinchIntegration.IntegrationError.insertionRejected }
    try postKey(0, flags: .maskCommand, to: processIdentifier)
    try postKey(51, to: processIdentifier)
    if !draft.isEmpty { try postText(draft, to: processIdentifier) }
}

private func postKey(
    _ keyCode: CGKeyCode,
    flags: CGEventFlags = [],
    to processIdentifier: pid_t
) throws {
    guard let source = CGEventSource(stateID: .combinedSessionState),
          let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
        throw MacOSPinchIntegration.IntegrationError.insertionRejected
    }
    keyDown.flags = flags
    keyUp.flags = flags
    keyDown.postToPid(processIdentifier)
    keyUp.postToPid(processIdentifier)
}

private func postText(_ text: String, to processIdentifier: pid_t) throws {
    guard let source = CGEventSource(stateID: .combinedSessionState),
          let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
        throw MacOSPinchIntegration.IntegrationError.insertionRejected
    }
    let characters = Array(text.utf16)
    characters.withUnsafeBufferPointer { buffer in
        keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
    }
    keyDown.postToPid(processIdentifier)
    keyUp.postToPid(processIdentifier)
}
