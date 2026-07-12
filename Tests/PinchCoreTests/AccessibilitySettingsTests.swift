import PinchCore
import Testing

@Test("permission settings report denied, granted, revoked, and settings return")
func permissionTransitions() {
    var trusted = false
    var settings = AccessibilitySettings(isTrusted: { trusted })

    #expect(settings.status == .notGranted)
    settings.didReturnFromSystemSettings()
    #expect(settings.status == .notGrantedAfterSettings)

    trusted = true
    settings.refresh()
    #expect(settings.status == .granted)

    trusted = false
    settings.refresh()
    #expect(settings.status == .revoked)
}
