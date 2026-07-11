import Foundation
import Testing
@testable import PinchCore

@MainActor
@Test("leaving the Codex marker before its dwell cancels reveal")
func markerHoverCancellation() async {
    let integration = TestIntegration()
    let editorFrame = CGRect(x: 10, y: 20, width: 300, height: 44)
    let composerFrame = CGRect(x: 0, y: 8, width: 324, height: 96)
    integration.currentTarget = PinchTarget(
        identifier: "codex-composer",
        editableFrame: editorFrame,
        attachmentFrame: composerFrame,
        supportsMarker: true
    )
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.refreshMarker()
    #expect(session.markerFrame == composerFrame)
    session.beginMarkerHover()
    #expect(session.phase == .hovering)
    session.endMarkerHover()
    await Task.yield()
    await clock.advance()
    await Task.yield()

    #expect(session.phase == .idle)
    #expect(!integration.isMonitoringKeyboard)
}

@MainActor
@Test("clicking the Codex marker performs a pre-pinch and opens the picker")
func markerClickActivation() async {
    let integration = TestIntegration()
    let composerFrame = CGRect(x: 0, y: 8, width: 324, height: 96)
    integration.currentTarget = PinchTarget(
        identifier: "codex-composer",
        editableFrame: CGRect(x: 10, y: 20, width: 300, height: 44),
        attachmentFrame: composerFrame,
        supportsMarker: true
    )
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.refreshMarker()
    session.activateMarker()
    #expect(session.phase == .hovering)
    await Task.yield()
    #expect(await clock.nextDuration() == .milliseconds(120))
    await clock.advance()
    await Task.yield()

    #expect(session.phase == .open)
    #expect(session.attachmentFrame == composerFrame)
    #expect(integration.isMonitoringKeyboard)
}

@MainActor
@Test("remaining over the Codex marker for 300 ms opens the picker")
func markerHoverActivation() async {
    let integration = TestIntegration()
    integration.currentTarget = PinchTarget(identifier: "codex-composer", supportsMarker: true)
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.refreshMarker()
    session.beginMarkerHover()
    await Task.yield()
    #expect(await clock.nextDuration() == .milliseconds(300))
    await clock.advance()
    await Task.yield()

    #expect(session.phase == .open)
}

@MainActor
@Test("a session does not open while secure input is active")
func secureInputIsRejected() {
    let integration = TestIntegration()
    integration.secureInputIsActive = true
    let session = PinchSession(integration: integration)

    session.open()

    #expect(session.phase == .failed)
    #expect(!integration.isMonitoringKeyboard)
}

@MainActor
@Test("keyboard selection delivers a numbered phrase and removes its monitor")
func numberedSelection() async {
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    #expect(integration.isMonitoringKeyboard)
    integration.press(.number(4))
    #expect(session.phase == .pinching)
    #expect(!integration.isMonitoringKeyboard)

    await Task.yield()
    await clock.advance()
    await Task.yield()
    #expect(integration.text == PinchSession.builtInPhrases[3])
}

@MainActor
@Test("arrow navigation, Return, and Escape complete or cancel a session")
func keyboardNavigationAndCancellation() async {
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    integration.press(.down)
    integration.press(.down)
    integration.press(.up)
    #expect(session.highlightedPhrase == PinchSession.builtInPhrases[1])
    integration.press(.return)
    await Task.yield()
    await clock.advance()
    await Task.yield()
    #expect(integration.text == PinchSession.builtInPhrases[1])

    await Task.yield()
    await clock.advance()
    await Task.yield()
    session.open()
    integration.press(.escape)
    #expect(session.phase == .idle)
    #expect(!integration.isMonitoringKeyboard)
}

@MainActor
@Test("delivery fails when the captured target disappears")
func targetDisappears() async {
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    integration.currentTarget = nil
    session.choose(PinchSession.builtInPhrases[0])
    await Task.yield()
    await clock.advance()
    await Task.yield()

    #expect(session.phase == .failed)
    #expect(integration.text.isEmpty)
    #expect(integration.isMonitoringKeyboard)
}

@MainActor
@Test("delivery never substitutes a replacement target")
func targetIsReplaced() async {
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    integration.currentTarget = PinchTarget(identifier: "replacement")
    session.choose(PinchSession.builtInPhrases[0])
    await Task.yield()
    await clock.advance()
    await Task.yield()

    #expect(session.phase == .failed)
    #expect(integration.text.isEmpty)
}

@MainActor
@Test("a complete session delivers a phrase and returns to idle")
func successfulSession() async throws {
    let target = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: target, clock: clock)

    #expect(PinchSession.builtInPhrases.count == 6)
    session.open()
    #expect(session.phase == .open)
    #expect(target.captureCount == 1)

    session.choose(PinchSession.builtInPhrases[3])
    #expect(session.phase == .pinching)

    await Task.yield()
    #expect(await clock.nextDuration() == .milliseconds(240))
    await clock.advance()
    await Task.yield()
    #expect(session.phase == .delivered)
    #expect(target.text == "按你的最佳判断继续")

    await Task.yield()
    await clock.advance()
    await Task.yield()
    #expect(session.phase == .idle)
}

@MainActor
@Test("a failed delivery stays recoverable")
func failedSessionCanRecover() async {
    let target = TestIntegration()
    target.shouldFail = true
    let clock = TestClock()
    let session = PinchSession(integration: target, clock: clock)

    session.open()
    session.choose(PinchSession.builtInPhrases[0])
    #expect(session.phase == .pinching)

    await clock.advance()
    while session.phase == .pinching { await Task.yield() }
    #expect(session.phase == .failed)

    session.recover()
    #expect(session.phase == .open)
    target.shouldFail = false
    session.choose(PinchSession.builtInPhrases[0])
    await clock.advance()
    while session.phase == .pinching { await Task.yield() }
    #expect(session.phase == .delivered)
}

@MainActor
private final class TestIntegration: PinchIntegration {
    var text = ""
    var shouldFail = false
    var captureCount = 0
    var secureInputIsActive = false
    var currentTarget: PinchTarget? = PinchTarget(identifier: "test-composer")
    var isMonitoringKeyboard = false
    private var keyboardHandler: (@MainActor (PinchKey) -> Void)?

    func captureTarget() throws -> PinchTarget {
        captureCount += 1
        guard !secureInputIsActive else { throw DeliveryError.rejected }
        guard let currentTarget else { throw DeliveryError.rejected }
        return currentTarget
    }

    func deliver(_ phrase: String, to target: PinchTarget) throws {
        guard !shouldFail, !secureInputIsActive, target == currentTarget else {
            throw DeliveryError.rejected
        }
        text = phrase
    }

    func startKeyboardMonitor(_ handler: @escaping @MainActor (PinchKey) -> Void) {
        keyboardHandler = handler
        isMonitoringKeyboard = true
    }

    func stopKeyboardMonitor() {
        keyboardHandler = nil
        isMonitoringKeyboard = false
    }

    func press(_ key: PinchKey) {
        keyboardHandler?(key)
    }

    private enum DeliveryError: Error { case rejected }
}

private actor TestClock: SessionClock {
    private var waiters: [(Duration, CheckedContinuation<Void, Never>)] = []

    func sleep(for duration: Duration) async {
        await withCheckedContinuation { waiters.append((duration, $0)) }
    }

    func advance() async {
        while waiters.isEmpty { await Task.yield() }
        waiters.removeFirst().1.resume()
    }

    func nextDuration() async -> Duration {
        while waiters.isEmpty { await Task.yield() }
        return waiters[0].0
    }
}
