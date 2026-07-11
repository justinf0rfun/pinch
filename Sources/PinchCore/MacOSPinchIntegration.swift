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
        let selectedTextRange: AXValue?
        let processIdentifier: pid_t
        let textValue: String?
        let placeholderValue: String?
    }

    private let systemWide = AXUIElementCreateSystemWide()
    private var capturedContext: CapturedTargetContext?
    private var keyboardTap: CFMachPort?
    private var keyboardSource: CFRunLoopSource?
    private var keyboardHandler: (@MainActor (PinchKey) -> Void)?

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
        let target = PinchTarget(
            identifier: UUID().uuidString,
            editableFrame: editorFrame,
            attachmentFrame: composerSurfaceFrame ?? editorFrame,
            supportsMarker: supportsMarker && composerSurfaceFrame != nil
        )
        var selectedTextRangeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedTextRangeValue
        )
        capturedContext = CapturedTargetContext(
            element: element,
            target: target,
            selectedTextRange: selectedTextRangeValue as! AXValue?,
            processIdentifier: processIdentifier,
            textValue: stringAttribute(of: element, named: kAXValueAttribute),
            placeholderValue: stringAttribute(of: element, named: kAXPlaceholderValueAttribute)
        )
        return target
    }

    public func deliver(_ phrase: String, to target: PinchTarget) throws {
        guard let capturedContext, target == capturedContext.target else {
            throw IntegrationError.targetChanged
        }
        if target.supportsMarker {
            guard !IsSecureEventInputEnabled() else { throw IntegrationError.insertionRejected }
            guard AXUIElementSetAttributeValue(
                capturedContext.element,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue
            ) == .success else {
                throw IntegrationError.insertionRejected
            }
            if let selectedTextRange = capturedContext.selectedTextRange {
                guard AXUIElementSetAttributeValue(
                    capturedContext.element,
                    kAXSelectedTextRangeAttribute as CFString,
                    selectedTextRange
                ) == .success else {
                    throw IntegrationError.insertionRejected
                }
            }
            try postText(phrase, to: capturedContext.processIdentifier)
            guard waitForExpectedText(phrase, in: capturedContext) else {
                throw IntegrationError.insertionRejected
            }
            return
        }
        guard AXUIElementSetAttributeValue(
            capturedContext.element,
            kAXSelectedTextAttribute as CFString,
            phrase as CFTypeRef
        ) == .success else {
            throw IntegrationError.insertionRejected
        }
    }

    private func postText(_ text: String, to processIdentifier: pid_t) throws {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: 0,
                  keyDown: true
              ),
              let keyUp = CGEvent(
                  keyboardEventSource: source,
                  virtualKey: 0,
                  keyDown: false
              ) else { throw IntegrationError.insertionRejected }
        let characters = Array(text.utf16)
        characters.withUnsafeBufferPointer { buffer in
            keyDown.keyboardSetUnicodeString(
                stringLength: buffer.count,
                unicodeString: buffer.baseAddress
            )
        }
        keyDown.postToPid(processIdentifier)
        keyUp.postToPid(processIdentifier)
    }

    private func waitForExpectedText(_ phrase: String, in context: CapturedTargetContext) -> Bool {
        let rawText = context.textValue ?? ""
        let text = rawText == context.placeholderValue ? "" : rawText
        guard let selectedTextRangeValue = context.selectedTextRange else { return false }
        var selectedRange = CFRange()
        guard AXValueGetValue(selectedTextRangeValue, .cfRange, &selectedRange),
              selectedRange.location >= 0,
              selectedRange.length >= 0,
              selectedRange.location + selectedRange.length <= (text as NSString).length else { return false }
        let expected = (text as NSString).replacingCharacters(
            in: NSRange(location: selectedRange.location, length: selectedRange.length),
            with: phrase
        )
        let deadline = ProcessInfo.processInfo.systemUptime + 0.15
        repeat {
            if stringAttribute(of: context.element, named: kAXValueAttribute) == expected { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        } while ProcessInfo.processInfo.systemUptime < deadline
        return false
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
        if let subrole = subroleValue as? String, subrole == kAXSecureTextFieldSubrole as String {
            throw IntegrationError.noEditableTarget
        }

        var selectedTextIsSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextIsSettable
        ) == .success, selectedTextIsSettable.boolValue else {
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
        guard role == kAXTextAreaRole as String, domClasses.contains("ProseMirror") else { return false }
        return bundleIdentifier?.caseInsensitiveCompare("com.openai.codex") == .orderedSame
            || ["Codex", "ChatGPT"].contains { applicationName?.caseInsensitiveCompare($0) == .orderedSame }
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
