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
    #expect(MacOSPinchIntegration.supportsMarker(bundleIdentifier: "com.openai.codex", applicationName: "Codex", role: kAXTextAreaRole, domClasses: []))
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

@Test("non-ChatGPT picker attaches to the caret instead of the whole editor")
func nonChatGPTCaretAttachment() {
    let editor = CGRect(x: 100, y: 200, width: 800, height: 500)
    let caret = CGRect(x: 420, y: 360, width: 1, height: 20)

    #expect(MacOSPinchIntegration.preferredAttachmentFrame(
        editorFrame: editor,
        caretFrame: caret,
        supportsMarker: false,
        composerFrame: nil
    ) == caret)
    #expect(MacOSPinchIntegration.preferredAttachmentFrame(
        editorFrame: editor,
        caretFrame: nil,
        supportsMarker: false,
        composerFrame: nil
    ) == editor)
}

@Test("Warp picker attaches to its bottom prompt area when caret bounds are unavailable")
func warpPromptAttachment() {
    let editor = CGRect(x: 100, y: 200, width: 800, height: 500)

    #expect(MacOSPinchIntegration.warpPromptFrame(editorFrame: editor)
        == CGRect(x: 116, y: 656, width: 1, height: 22))
}

@Test("ChatGPT's accessible placeholder is not treated as draft text")
func chatGPTPlaceholderText() {
    #expect(MacOSPinchIntegration.normalizedChatGPTDraftText(
        rawValue: "\nAsk for follow-up changes",
        hasPlaceholderElement: true
    ) == "")
    #expect(MacOSPinchIntegration.normalizedChatGPTDraftText(
        rawValue: "\nactual draft",
        hasPlaceholderElement: false
    ) == "\nactual draft")
}

@Test("non-ChatGPT delivery prefers direct Accessibility mutation")
func directAccessibilityDeliveryPolicy() throws {
    var validationCount = 0
    var directInsertionCount = 0
    var unicodeInsertionCount = 0

    try MacOSPinchIntegration.deliverNonChatGPT(
        validateTarget: { validationCount += 1; return true },
        secureInputActive: { false },
        directInsertion: { directInsertionCount += 1; return true },
        unicodeInsertion: { unicodeInsertionCount += 1; return true }
    )

    #expect(validationCount == 1)
    #expect(directInsertionCount == 1)
    #expect(unicodeInsertionCount == 0)
}

@Test("Unicode delivery revalidates the exact target after Accessibility rejects insertion")
func targetedUnicodeDeliveryPolicy() throws {
    var validationCount = 0
    var unicodeInsertionCount = 0

    try MacOSPinchIntegration.deliverNonChatGPT(
        validateTarget: { validationCount += 1; return true },
        secureInputActive: { false },
        directInsertion: { false },
        unicodeInsertion: { unicodeInsertionCount += 1; return true }
    )

    #expect(validationCount == 2)
    #expect(unicodeInsertionCount == 1)
}

@Test("non-ChatGPT delivery rejects target loss and replacement without writing")
func unsafeTargetDeliveryPolicy() {
    var directInsertionCount = 0
    var unicodeInsertionCount = 0

    #expect(throws: MacOSPinchIntegration.IntegrationError.self) {
        try MacOSPinchIntegration.deliverNonChatGPT(
            validateTarget: { false },
            secureInputActive: { false },
            directInsertion: { directInsertionCount += 1; return true },
            unicodeInsertion: { unicodeInsertionCount += 1; return true }
        )
    }
    #expect(directInsertionCount == 0)
    #expect(unicodeInsertionCount == 0)

    var validations = [true, false]
    #expect(throws: MacOSPinchIntegration.IntegrationError.self) {
        try MacOSPinchIntegration.deliverNonChatGPT(
            validateTarget: { validations.removeFirst() },
            secureInputActive: { false },
            directInsertion: { directInsertionCount += 1; return false },
            unicodeInsertion: { unicodeInsertionCount += 1; return true }
        )
    }
    #expect(directInsertionCount == 1)
    #expect(unicodeInsertionCount == 0)
}

@Test("secure input and unsupported targets reject all non-ChatGPT writes")
func rejectedNonChatGPTDeliveryPolicy() {
    var insertionCount = 0

    #expect(throws: MacOSPinchIntegration.IntegrationError.self) {
        try MacOSPinchIntegration.deliverNonChatGPT(
            validateTarget: { true },
            secureInputActive: { true },
            directInsertion: { insertionCount += 1; return true },
            unicodeInsertion: { insertionCount += 1; return true }
        )
    }
    #expect(insertionCount == 0)

    #expect(throws: MacOSPinchIntegration.IntegrationError.self) {
        try MacOSPinchIntegration.deliverNonChatGPT(
            validateTarget: { true },
            secureInputActive: { false },
            directInsertion: { insertionCount += 1; return false },
            unicodeInsertion: { insertionCount += 1; return false }
        )
    }
    #expect(insertionCount == 2)
}

@Test("only editable controls and Terminal text areas support shortcut capture")
func shortcutTargetSupport() {
    #expect(MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.TextEdit",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        selectedTextSettable: true,
        valueSettable: true
    ))
    #expect(MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.Terminal",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        selectedTextSettable: false,
        valueSettable: false
    ))
    #expect(MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "dev.warp.Warp-Stable",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        selectedTextSettable: false,
        valueSettable: false
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.TextEdit",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        selectedTextSettable: false,
        valueSettable: false
    ))
    #expect(MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.Safari",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        selectedTextSettable: false,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.Safari",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        selectedTextSettable: false,
        valueSettable: false
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.TextEdit",
        role: kAXTextAreaRole,
        subrole: kAXSecureTextFieldSubrole,
        enabled: true,
        selectedTextSettable: true,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.TextEdit",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: false,
        selectedTextSettable: true,
        valueSettable: true
    ))
}

@Test("terminal applications skip Accessibility mutation and use targeted Unicode only")
func terminalUnicodeOnlyDeliveryPolicy() throws {
    var unicodeInsertionCount = 0

    try MacOSPinchIntegration.deliverNonChatGPT(
        validateTarget: { true },
        secureInputActive: { false },
        directInsertion: nil,
        unicodeInsertion: { unicodeInsertionCount += 1; return true }
    )

    #expect(unicodeInsertionCount == 1)
}

@MainActor
@Test(
    "direct Accessibility insertion works with a non-activating picker",
    .enabled(if: ProcessInfo.processInfo.environment["PINCH_RUN_AX_SMOKE"] == "1")
)
func directAccessibilityInsertionSmokeTest() throws {
    guard AXIsProcessTrusted() else { throw MacOSPinchIntegration.IntegrationError.accessibilityPermission }
    let application = NSApplication.shared
    application.setActivationPolicy(.regular)
    application.finishLaunching()

    let field = NSTextView(frame: NSRect(x: 20, y: 20, width: 320, height: 28))
    field.string = "before selection after"
    let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 96))
    contentView.addSubview(field)
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
    let picker = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 160, height: 60),
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    picker.orderFrontRegardless()
    defer { picker.orderOut(nil) }
    try integration.deliver("inserted", to: target)

    #expect(field.string == "before inserted after")
}

@MainActor
@Test(
    "ChatGPT ProseMirror replaces the captured selection after picker focus",
    .enabled(if: ProcessInfo.processInfo.environment["PINCH_RUN_CHATGPT_AX_SMOKE"] == "1")
)
func chatGPTAccessibilityInsertionSmokeTest() throws {
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
    let originalDraft = composerContainsDOMClass("placeholder", below: composer) ? "" : originalValue
    var didRestoreDraft = false
    defer {
        if !didRestoreDraft {
            do {
                try restoreChatGPTComposer(
                    composer,
                    processIdentifier: chatGPT.processIdentifier,
                    draft: originalDraft
                )
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                if !composerMatchesDraft(composer, draft: originalDraft) {
                    Issue.record("Failed to restore the original ChatGPT draft")
                }
            } catch {
                Issue.record("Failed to restore the original ChatGPT draft: \(error)")
            }
        }
    }

    let fixture = "before SELECTED after"
    try restoreChatGPTComposer(
        composer,
        processIdentifier: chatGPT.processIdentifier,
        draft: fixture
    )
    try selectChatGPTText(
        composer,
        processIdentifier: chatGPT.processIdentifier,
        location: 7,
        length: 8,
        expectedSelection: "SELECTED"
    )

    let integration = MacOSPinchIntegration()
    let target = try integration.captureTarget()
    try integration.prepareDelivery(to: target)

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
    try integration.deliver(phrase, to: target)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    let inserted = accessibilityString(composer, kAXValueAttribute)

    try restoreChatGPTComposer(
        composer,
        processIdentifier: chatGPT.processIdentifier,
        draft: originalDraft
    )
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    didRestoreDraft = composerMatchesDraft(composer, draft: originalDraft)

    #expect(inserted == "before \(phrase) after")
    #expect(didRestoreDraft)
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

private func composerMatchesDraft(_ element: AXUIElement, draft: String) -> Bool {
    draft.isEmpty
        ? composerContainsDOMClass("placeholder", below: element)
        : accessibilityString(element, kAXValueAttribute) == draft
}

private func selectChatGPTText(
    _ element: AXUIElement,
    processIdentifier: pid_t,
    location: Int,
    length: Int,
    expectedSelection: String
) throws {
    for _ in 0..<3 {
        try postKey(0, flags: .maskCommand, to: processIdentifier)
        RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        try postKey(123, to: processIdentifier)
        RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        for _ in 0..<location {
            try postKey(124, to: processIdentifier)
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        for _ in 0..<length {
            try postKey(124, flags: .maskShift, to: processIdentifier)
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        if accessibilityString(element, kAXSelectedTextAttribute) == expectedSelection { return }
    }
    throw MacOSPinchIntegration.IntegrationError.insertionRejected
}

private func composerContainsDOMClass(_ domClass: String, below root: AXUIElement) -> Bool {
    var queue = [root]
    while !queue.isEmpty {
        let element = queue.removeFirst()
        var classesValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXDOMClassListAttribute as CFString, &classesValue)
        if (classesValue as? [String] ?? []).contains(domClass) { return true }
        var childrenValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue) == .success {
            queue.append(contentsOf: childrenValue as? [AXUIElement] ?? [])
        }
    }
    return false
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
    RunLoop.main.run(until: Date().addingTimeInterval(0.03))
    try postKey(51, to: processIdentifier)
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    if !draft.isEmpty {
        try postText(draft, to: processIdentifier)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
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
