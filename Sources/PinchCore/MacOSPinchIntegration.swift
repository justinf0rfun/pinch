import ApplicationServices
import AppKit

@MainActor
public final class MacOSPinchIntegration: PinchIntegration {
    public enum IntegrationError: Error {
        case accessibilityPermission, noEditableTarget, targetChanged, insertionRejected
    }

    private let systemWide = AXUIElementCreateSystemWide()
    private var capturedElement: AXUIElement?
    private var capturedTarget: PinchTarget?
    private var keyboardTap: CFMachPort?
    private var keyboardSource: CFRunLoopSource?
    private var keyboardHandler: (@MainActor (PinchKey) -> Void)?

    public init() {}

    public func requestAccessibilityPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public func captureTarget() throws -> PinchTarget {
        guard AXIsProcessTrusted() else { throw IntegrationError.accessibilityPermission }
        let element = try focusedEditableElement()
        let target = PinchTarget(identifier: UUID().uuidString, frame: frame(of: element))
        capturedElement = element
        capturedTarget = target
        return target
    }

    public func deliver(_ phrase: String, to target: PinchTarget) throws {
        guard let capturedElement, target == capturedTarget else {
            throw IntegrationError.targetChanged
        }
        let focused = try focusedEditableElement()
        guard CFEqual(focused, capturedElement) else { throw IntegrationError.targetChanged }
        guard AXUIElementSetAttributeValue(
            capturedElement,
            kAXSelectedTextAttribute as CFString,
            phrase as CFTypeRef
        ) == .success else {
            throw IntegrationError.insertionRejected
        }
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
