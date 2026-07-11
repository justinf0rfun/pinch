import ApplicationServices
import AppKit
import Carbon.HIToolbox

@MainActor
public final class MacOSPinchIntegration: PinchIntegration {
    public enum IntegrationError: Error {
        case accessibilityPermission, noEditableTarget, targetChanged, insertionRejected
    }

    struct AccessibilityAncestor: Equatable, Sendable {
        let frame: CGRect
        let domClasses: [String]
    }

    private struct CapturedTargetContext {
        let element: AXUIElement
        let target: PinchTarget
        let processIdentifier: pid_t
        let allowsUnicodeDelivery: Bool
        let usesUnicodeOnly: Bool
        var preparedDelivery: PreparedDelivery?
    }

    private struct PreparedDelivery {
        let selectedTextRange: AXValue
        let selectedTextMarkerRange: CFTypeRef
        let draftHash: Int
        let draftLength: Int
    }

    private let systemWide = AXUIElementCreateSystemWide()
    private var capturedContext: CapturedTargetContext?
    private var keyboardTap: CFMachPort?
    private var keyboardSource: CFRunLoopSource?
    private var keyboardHandler: (@MainActor (PinchKey) -> Void)?
    private var outsideClickMonitor: Any?

    public init() {}

    public func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public func captureTarget() throws -> PinchTarget {
        capturedContext = nil
        guard AXIsProcessTrusted() else { throw IntegrationError.accessibilityPermission }
        guard !IsSecureEventInputEnabled() else { throw IntegrationError.noEditableTarget }
        let element = try focusedEditableElement()
        var processIdentifier: pid_t = 0
        AXUIElementGetPid(element, &processIdentifier)
        let application = NSRunningApplication(processIdentifier: processIdentifier)
        let terminalApplication = Self.isTerminal(application?.bundleIdentifier)
        let warpApplication = Self.isWarp(application?.bundleIdentifier)
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        var domClassesValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXDOMClassListAttribute as CFString, &domClassesValue)
        let editorFrame = frame(of: element)
        let supportsMarker = Self.supportsMarker(
            bundleIdentifier: application?.bundleIdentifier,
            applicationName: application?.localizedName,
            role: roleValue as? String,
            domClasses: domClassesValue as? [String] ?? []
        )
        let composerSurfaceFrame = supportsMarker ? composerFrame(of: element) : nil
        let exactCaretFrame = supportsMarker ? nil : caretFrame(of: element)
        let inputAttachmentFrame = exactCaretFrame
            ?? (warpApplication ? Self.warpPromptFrame(editorFrame: editorFrame) : nil)
        let anchor: PinchTargetAnchor = supportsMarker
            ? .composer
            : exactCaretFrame != nil ? .caret : warpApplication ? .prompt : .input
        let attachmentFrame = Self.preferredAttachmentFrame(
            editorFrame: editorFrame,
            caretFrame: supportsMarker ? nil : inputAttachmentFrame,
            supportsMarker: supportsMarker,
            composerFrame: composerSurfaceFrame
        )
        let target = PinchTarget(
            identifier: UUID().uuidString,
            editableFrame: editorFrame,
            attachmentFrame: attachmentFrame,
            supportsMarker: supportsMarker,
            anchor: anchor
        )
        capturedContext = CapturedTargetContext(
            element: element,
            target: target,
            processIdentifier: processIdentifier,
            allowsUnicodeDelivery: Self.allowsUnicodeDelivery(
                bundleIdentifier: application?.bundleIdentifier,
                role: roleValue as? String
            ),
            usesUnicodeOnly: terminalApplication,
            preparedDelivery: nil
        )
        return target
    }

    public func prepareDelivery(to target: PinchTarget) throws {
        guard target.supportsMarker else { return }
        guard var capturedContext, capturedContext.target == target else {
            throw IntegrationError.targetChanged
        }
        let state = try currentChatGPTState(of: capturedContext.element)
        capturedContext.preparedDelivery = PreparedDelivery(
            selectedTextRange: state.selectedTextRange,
            selectedTextMarkerRange: state.selectedTextMarkerRange,
            draftHash: state.draft.hashValue,
            draftLength: (state.draft as NSString).length
        )
        self.capturedContext = capturedContext
    }

    public func deliver(_ phrase: String, to target: PinchTarget) throws {
        guard let capturedContext, target == capturedContext.target else {
            throw IntegrationError.targetChanged
        }
        if target.supportsMarker {
            guard !IsSecureEventInputEnabled() else { throw IntegrationError.insertionRejected }
            guard let preparedDelivery = capturedContext.preparedDelivery else {
                throw IntegrationError.insertionRejected
            }
            guard let application = NSRunningApplication(
                processIdentifier: capturedContext.processIdentifier
            ), application.activate() else { throw IntegrationError.insertionRejected }
            guard AXUIElementSetAttributeValue(
                capturedContext.element,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue
            ) == .success else { throw IntegrationError.insertionRejected }
            guard waitForFocusedElement(
                capturedContext.element,
                processIdentifier: capturedContext.processIdentifier
            ) else { throw IntegrationError.insertionRejected }
            guard AXUIElementSetAttributeValue(
                capturedContext.element,
                kAXSelectedTextMarkerRangeAttribute as CFString,
                preparedDelivery.selectedTextMarkerRange
            ) == .success, waitForSelectedTextMarkerRange(
                preparedDelivery.selectedTextMarkerRange,
                in: capturedContext.element
            ) else { throw IntegrationError.insertionRejected }
            let expectedText = try expectedChatGPTDraft(
                for: capturedContext.element,
                preparedDelivery: preparedDelivery,
                inserting: phrase
            )
            try Self.postUnicodeText(phrase, to: capturedContext.processIdentifier)
            guard waitForExpectedText(expectedText, in: capturedContext.element) else {
                throw IntegrationError.insertionRejected
            }
            return
        }
        try Self.deliverNonChatGPT(
            validateTarget: { [self] in
                waitForFocusedElement(
                    capturedContext.element,
                    processIdentifier: capturedContext.processIdentifier
                )
            },
            secureInputActive: { IsSecureEventInputEnabled() },
            directInsertion: capturedContext.usesUnicodeOnly ? nil : {
                AXUIElementSetAttributeValue(
                    capturedContext.element,
                    kAXSelectedTextAttribute as CFString,
                    phrase as CFTypeRef
                ) == .success
            },
            unicodeInsertion: {
                guard capturedContext.allowsUnicodeDelivery else { return false }
                do {
                    try Self.postUnicodeText(phrase, to: capturedContext.processIdentifier)
                    return true
                } catch {
                    return false
                }
            }
        )
    }

    private nonisolated static func postUnicodeText(_ text: String, to processIdentifier: pid_t) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw IntegrationError.insertionRejected
        }
        let characters = Array(text.utf16)
        characters.withUnsafeBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(
                stringLength: buffer.count,
                unicodeString: buffer.baseAddress
            )
        }
        keyDown.flags = []
        keyUp.flags = []
        keyDown.postToPid(processIdentifier)
        keyUp.postToPid(processIdentifier)
    }

    private func expectedChatGPTDraft(
        for element: AXUIElement,
        preparedDelivery: PreparedDelivery,
        inserting phrase: String
    ) throws -> String {
        let draft = try currentChatGPTDraft(of: element)
        guard (draft as NSString).length == preparedDelivery.draftLength,
              draft.hashValue == preparedDelivery.draftHash else {
            throw IntegrationError.targetChanged
        }
        let selectedTextRange = preparedDelivery.selectedTextRange
        var selectedRange = CFRange()
        guard AXValueGetValue(selectedTextRange, .cfRange, &selectedRange),
              selectedRange.location >= 0,
              selectedRange.length >= 0,
              selectedRange.location + selectedRange.length <= (draft as NSString).length else {
            throw IntegrationError.insertionRejected
        }
        let nsRange = NSRange(location: selectedRange.location, length: selectedRange.length)
        let expected = (draft as NSString).replacingCharacters(
            in: nsRange,
            with: phrase
        )
        return expected
    }

    private func currentChatGPTState(
        of element: AXUIElement
    ) throws -> (
        selectedTextRange: AXValue,
        selectedTextMarkerRange: CFTypeRef,
        draft: String
    ) {
        var selectedTextRangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedTextRangeValue
        ) == .success, let selectedTextRange = selectedTextRangeValue as! AXValue? else {
            throw IntegrationError.insertionRejected
        }
        var selectedTextMarkerRange: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextMarkerRangeAttribute as CFString,
            &selectedTextMarkerRange
        ) == .success, let selectedTextMarkerRange else {
            throw IntegrationError.insertionRejected
        }
        return (
            selectedTextRange,
            selectedTextMarkerRange,
            try currentChatGPTDraft(of: element)
        )
    }

    private func currentChatGPTDraft(of element: AXUIElement) throws -> String {
        guard let rawValue = stringAttribute(of: element, named: kAXValueAttribute) else {
            throw IntegrationError.insertionRejected
        }
        return Self.normalizedChatGPTDraftText(
            rawValue: rawValue,
            hasPlaceholderElement: containsDOMClass("placeholder", below: element)
        )
    }

    private func waitForExpectedText(_ expected: String, in element: AXUIElement) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.3
        repeat {
            if stringAttribute(of: element, named: kAXValueAttribute) == expected { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        } while ProcessInfo.processInfo.systemUptime < deadline
        return false
    }

    private func waitForFocusedElement(
        _ expected: AXUIElement,
        processIdentifier: pid_t
    ) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.15
        repeat {
            var value: CFTypeRef?
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == processIdentifier,
               AXUIElementCopyAttributeValue(
                   systemWide,
                   kAXFocusedUIElementAttribute as CFString,
                   &value
               ) == .success,
               let focused = value as! AXUIElement?,
               CFEqual(focused, expected) { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        } while ProcessInfo.processInfo.systemUptime < deadline
        return false
    }

    private func waitForSelectedTextMarkerRange(
        _ expected: CFTypeRef,
        in element: AXUIElement
    ) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + 0.15
        repeat {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                element,
                kAXSelectedTextMarkerRangeAttribute as CFString,
                &value
            ) == .success, let value, CFEqual(value, expected) { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        } while ProcessInfo.processInfo.systemUptime < deadline
        return false
    }

    nonisolated static func normalizedChatGPTDraftText(
        rawValue: String,
        hasPlaceholderElement: Bool
    ) -> String {
        hasPlaceholderElement ? "" : rawValue
    }

    private func containsDOMClass(_ domClass: String, below root: AXUIElement) -> Bool {
        var queue = children(of: root).map { ($0, 1) }
        while !queue.isEmpty {
            let (element, depth) = queue.removeFirst()
            var domClassesValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXDOMClassListAttribute as CFString, &domClassesValue)
            if (domClassesValue as? [String] ?? []).contains(domClass) { return true }
            if depth < 3 { queue.append(contentsOf: children(of: element).map { ($0, depth + 1) }) }
        }
        return false
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &childrenValue
        ) == .success else { return [] }
        return childrenValue as? [AXUIElement] ?? []
    }

    private func stringAttribute(of element: AXUIElement, named attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        ) == .success else { return nil }
        return value as? String
    }

    public func startKeyboardMonitor(_ handler: @escaping @MainActor (PinchKey) -> Void) {
        stopKeyboardMonitor()
        keyboardHandler = handler
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        keyboardTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let keyboardTap else { return }
        keyboardSource = CFMachPortCreateRunLoopSource(nil, keyboardTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), keyboardSource, .commonModes)
        CGEvent.tapEnable(tap: keyboardTap, enable: true)
    }

    public func stopKeyboardMonitor() {
        if let keyboardSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), keyboardSource, .commonModes) }
        if let keyboardTap { CGEvent.tapEnable(tap: keyboardTap, enable: false) }
        keyboardSource = nil
        keyboardTap = nil
        keyboardHandler = nil
    }

    public func startOutsideClickMonitor(_ handler: @escaping @MainActor () -> Void) {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    public func stopOutsideClickMonitor() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    fileprivate func handleKey(_ key: PinchKey) {
        keyboardHandler?(key)
    }

    private func focusedEditableElement() throws -> AXUIElement {
        guard !IsSecureEventInputEnabled() else { throw IntegrationError.noEditableTarget }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success, let element = value as! AXUIElement? else {
            throw IntegrationError.noEditableTarget
        }

        var subroleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue)

        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)

        var enabledValue: CFTypeRef?
        let enabled = AXUIElementCopyAttributeValue(
            element,
            kAXEnabledAttribute as CFString,
            &enabledValue
        ) != .success || (enabledValue as? Bool) == true

        var selectedTextIsSettable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextIsSettable
        )

        var valueIsSettable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &valueIsSettable
        )

        var processIdentifier: pid_t = 0
        AXUIElementGetPid(element, &processIdentifier)
        let bundleIdentifier = NSRunningApplication(
            processIdentifier: processIdentifier
        )?.bundleIdentifier
        guard Self.supportsShortcutTarget(
            bundleIdentifier: bundleIdentifier,
            role: roleValue as? String,
            subrole: subroleValue as? String,
            enabled: enabled,
            selectedTextSettable: selectedTextIsSettable.boolValue,
            valueSettable: valueIsSettable.boolValue
        ) else {
            throw IntegrationError.noEditableTarget
        }
        return element
    }

    private func frame(of element: AXUIElement) -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionAXValue = positionValue as! AXValue?,
              let sizeAXValue = sizeValue as! AXValue?,
              AXValueGetValue(positionAXValue, .cgPoint, &position),
              AXValueGetValue(sizeAXValue, .cgSize, &size) else { return .zero }
        return CGRect(origin: position, size: size)
    }

    private func caretFrame(of element: AXUIElement) -> CGRect? {
        var selectedRangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        ) == .success, let selectedRangeValue = selectedRangeValue as! AXValue? else {
            return nil
        }
        var selectedRange = CFRange()
        guard AXValueGetValue(selectedRangeValue, .cfRange, &selectedRange),
              selectedRange.location >= 0,
              selectedRange.length >= 0 else { return nil }
        var caretRange = CFRange(
            location: selectedRange.location + selectedRange.length,
            length: 0
        )
        guard let caretRangeValue = AXValueCreate(.cfRange, &caretRange) else { return nil }
        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            caretRangeValue,
            &boundsValue
        ) == .success, let boundsValue = boundsValue as! AXValue? else { return nil }
        var bounds = CGRect.zero
        guard AXValueGetValue(boundsValue, .cgRect, &bounds), !bounds.isEmpty else { return nil }
        return bounds
    }

    private func composerFrame(of element: AXUIElement) -> CGRect? {
        var current = element
        var ancestors: [AccessibilityAncestor] = []
        for _ in 0..<8 {
            var parentValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(
                current,
                kAXParentAttribute as CFString,
                &parentValue
            ) == .success, let parent = parentValue as! AXUIElement? else { break }
            var domClassesValue: CFTypeRef?
            AXUIElementCopyAttributeValue(parent, kAXDOMClassListAttribute as CFString, &domClassesValue)
            ancestors.append(AccessibilityAncestor(
                frame: frame(of: parent),
                domClasses: domClassesValue as? [String] ?? []
            ))
            current = parent
        }
        return Self.composerFrame(ancestors: ancestors)
    }

    nonisolated static func composerFrame(
        ancestors: [AccessibilityAncestor]
    ) -> CGRect? {
        ancestors.first { $0.domClasses.contains("composer-surface-chrome") }?.frame
    }

    fileprivate nonisolated static func pinchKey(for keyCode: Int) -> PinchKey? {
        switch keyCode {
        case 18, 19, 20, 21, 22, 23, 25, 26, 28:
            let numbers = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9]
            return numbers[keyCode].map(PinchKey.number)
        case 126: return .up
        case 125: return .down
        case 36, 76: return .return
        case 53: return .escape
        default: return nil
        }
    }

    nonisolated static func supportsMarker(
        bundleIdentifier: String?,
        applicationName: String?,
        role: String?,
        domClasses: [String]
    ) -> Bool {
        guard role == kAXTextAreaRole as String else { return false }
        if bundleIdentifier?.caseInsensitiveCompare("com.openai.codex") == .orderedSame {
            return true
        }
        guard domClasses.contains("ProseMirror") else { return false }
        return ["Codex", "ChatGPT"].contains {
            applicationName?.caseInsensitiveCompare($0) == .orderedSame
        }
    }

    nonisolated static func preferredAttachmentFrame(
        editorFrame: CGRect,
        caretFrame: CGRect?,
        supportsMarker: Bool,
        composerFrame: CGRect?
    ) -> CGRect {
        supportsMarker ? composerFrame ?? editorFrame : caretFrame ?? editorFrame
    }

    nonisolated static func warpPromptFrame(editorFrame: CGRect) -> CGRect {
        let lineHeight: CGFloat = 22
        return CGRect(
            x: editorFrame.minX + 16,
            y: max(editorFrame.maxY - 44, editorFrame.minY),
            width: 1,
            height: lineHeight
        )
    }

    nonisolated static func supportsShortcutTarget(
        bundleIdentifier: String?,
        role: String?,
        subrole: String?,
        enabled: Bool,
        selectedTextSettable: Bool,
        valueSettable: Bool
    ) -> Bool {
        guard enabled, subrole != kAXSecureTextFieldSubrole as String else { return false }
        let isTextControl = role == kAXTextAreaRole as String
            || role == kAXTextFieldRole as String
        guard isTextControl else { return false }
        return selectedTextSettable
            || isTerminal(bundleIdentifier)
            || (valueSettable && isSupportedBrowser(bundleIdentifier))
    }

    nonisolated static func deliverNonChatGPT(
        validateTarget: () -> Bool,
        secureInputActive: () -> Bool,
        directInsertion: (() -> Bool)?,
        unicodeInsertion: () -> Bool
    ) throws {
        if let directInsertion {
            guard validateTarget(), !secureInputActive() else {
                throw IntegrationError.targetChanged
            }
            if directInsertion() { return }
        }
        guard validateTarget(), !secureInputActive(), unicodeInsertion() else {
            throw IntegrationError.insertionRejected
        }
    }

    private nonisolated static func allowsUnicodeDelivery(
        bundleIdentifier: String?,
        role: String?
    ) -> Bool {
        guard role == kAXTextAreaRole as String || role == kAXTextFieldRole as String else {
            return false
        }
        return isSupportedBrowser(bundleIdentifier) || isTerminal(bundleIdentifier)
    }

    private nonisolated static func isSupportedBrowser(_ bundleIdentifier: String?) -> Bool {
        ["com.apple.Safari", "com.google.Chrome"].contains {
            bundleIdentifier?.caseInsensitiveCompare($0) == .orderedSame
        }
    }

    private nonisolated static func isTerminal(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.caseInsensitiveCompare("com.apple.Terminal") == .orderedSame
            || isWarp(bundleIdentifier)
    }

    private nonisolated static func isWarp(_ bundleIdentifier: String?) -> Bool {
        bundleIdentifier?.caseInsensitiveCompare("dev.warp.Warp-Stable") == .orderedSame
    }
}

private func keyboardTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
    guard let key = MacOSPinchIntegration.pinchKey(for: keyCode) else {
        return Unmanaged.passUnretained(event)
    }
    let integration = Unmanaged<MacOSPinchIntegration>.fromOpaque(userInfo).takeUnretainedValue()
    MainActor.assumeIsolated { integration.handleKey(key) }
    return nil
}
