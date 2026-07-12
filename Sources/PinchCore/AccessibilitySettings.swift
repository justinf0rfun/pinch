public enum AccessibilityStatus: Equatable, Sendable {
    case notGranted
    case notGrantedAfterSettings
    case granted
    case revoked
}

public struct AccessibilitySettings {
    public private(set) var status: AccessibilityStatus
    private let isTrusted: () -> Bool
    private var wasGranted: Bool

    public init(isTrusted: @escaping () -> Bool) {
        self.isTrusted = isTrusted
        wasGranted = isTrusted()
        status = wasGranted ? .granted : .notGranted
    }

    public mutating func refresh() {
        let trusted = isTrusted()
        if trusted {
            wasGranted = true
            status = .granted
        } else {
            status = wasGranted ? .revoked : .notGranted
        }
    }

    public mutating func didReturnFromSystemSettings() {
        refresh()
        if status == .notGranted { status = .notGrantedAfterSettings }
    }

    public var activationDecision: PinchActivationDecision {
        status == .granted ? .openPinch : .showPermissionRecovery
    }
}

public enum PinchActivationDecision: Equatable, Sendable {
    case openPinch
    case showPermissionRecovery
}
