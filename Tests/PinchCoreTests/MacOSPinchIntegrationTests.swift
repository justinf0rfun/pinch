import AppKit
import ApplicationServices
import Testing
@testable import PinchCore

@Test("only the ChatGPT app supports an attached composer marker")
func chatGPTMarkerSupport() {
    #expect(MacOSPinchIntegration.isChatGPTComposer(bundleIdentifier: "com.openai.codex", role: kAXTextAreaRole))
    #expect(!MacOSPinchIntegration.isChatGPTComposer(bundleIdentifier: nil, role: kAXTextAreaRole))
    #expect(!MacOSPinchIntegration.isChatGPTComposer(bundleIdentifier: "com.openai.codex", role: kAXTextFieldRole))
    #expect(!MacOSPinchIntegration.isChatGPTComposer(bundleIdentifier: "com.apple.Terminal", role: kAXTextAreaRole))
    #expect(!MacOSPinchIntegration.isChatGPTComposer(bundleIdentifier: "com.example.codex-helper", role: kAXTextAreaRole))
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
    #expect(MacOSPinchIntegration.normalizedChatGPTDraftText(
        rawValue: "\nAsk for follow-up changes",
        hasPlaceholderElement: true
    ) == "")
    #expect(MacOSPinchIntegration.normalizedChatGPTDraftText(
        rawValue: "\nactual draft",
        hasPlaceholderElement: false
    ) == "\nactual draft")
}

@Test("only the ChatGPT composer supports shortcut capture")
func shortcutTargetSupport() {
    #expect(MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.openai.codex",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.Safari",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.google.Chrome",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.Terminal",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "dev.warp.Warp-Stable",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.TextEdit",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.TextEdit",
        role: kAXTextAreaRole,
        subrole: kAXSecureTextFieldSubrole,
        enabled: true,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.apple.TextEdit",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: false,
        valueSettable: true
    ))
    #expect(!MacOSPinchIntegration.supportsShortcutTarget(
        bundleIdentifier: "com.openai.codex",
        role: kAXTextAreaRole,
        subrole: nil,
        enabled: true,
        valueSettable: false
    ))
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
    let insertionPoint = accessibilityRange(composer, kAXSelectedTextRangeAttribute)

    try restoreChatGPTComposer(
        composer,
        processIdentifier: chatGPT.processIdentifier,
        draft: originalDraft
    )
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    didRestoreDraft = composerMatchesDraft(composer, draft: originalDraft)

    #expect(inserted == "before \(phrase) after")
    #expect(insertionPoint?.location == 7 + (phrase as NSString).length)
    #expect(insertionPoint?.length == 0)
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

private func accessibilityRange(_ element: AXUIElement, _ attribute: String) -> CFRange? {
    var value: CFTypeRef?
    var range = CFRange()
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
          let value = value as! AXValue?,
          AXValueGetValue(value, .cfRange, &range) else { return nil }
    return range
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
