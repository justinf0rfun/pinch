import Testing
@testable import PinchCore

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
    var currentTarget: PinchTarget? = PinchTarget(identifier: "test-composer")
    var isMonitoringKeyboard = false
    private var keyboardHandler: (@MainActor (PinchKey) -> Void)?

    func captureTarget() throws -> PinchTarget {
        captureCount += 1
        guard let currentTarget else { throw DeliveryError.rejected }
        return currentTarget
    }

    func deliver(_ phrase: String, to target: PinchTarget) throws {
        guard !shouldFail, target == currentTarget else { throw DeliveryError.rejected }
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
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for duration: Duration) async {
        await withCheckedContinuation { waiters.append($0) }
    }

    func advance() async {
        while waiters.isEmpty { await Task.yield() }
        waiters.removeFirst().resume()
    }
}
