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
        attachmentFrame: composerFrame
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
        attachmentFrame: composerFrame
    )
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.refreshMarker()
    session.activateMarker()
    #expect(session.phase == .hovering)
    #expect(integration.prepareCount == 1)
    await Task.yield()
    #expect(await clock.nextDuration() == .milliseconds(120))
    await clock.advance()
    while session.phase == .hovering { await Task.yield() }

    #expect(session.phase == .open)
    #expect(session.attachmentFrame == composerFrame)
    #expect(integration.isMonitoringKeyboard)
}

@MainActor
@Test("remaining over the Codex marker for 300 ms opens the picker")
func markerHoverActivation() async {
    let integration = TestIntegration()
    integration.currentTarget = PinchTarget(identifier: "codex-composer")
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.refreshMarker()
    session.beginMarkerHover()
    await Task.yield()
    #expect(await clock.nextDuration() == .milliseconds(300))
    await clock.advance()
    while session.phase == .hovering { await Task.yield() }

    #expect(session.phase == .open)
}

@MainActor
@Test("secure input does not latch an invisible session failure")
func secureInputIsRejected() {
    let integration = TestIntegration()
    integration.secureInputIsActive = true
    let session = PinchSession(integration: integration)

    session.open()

    #expect(session.phase == .idle)
    #expect(!integration.isMonitoringKeyboard)
}

@MainActor
@Test("returning to ChatGPT restores the marker and global shortcut")
func appSwitchRestoresMarkerAndShortcut() {
    let integration = TestIntegration()
    integration.currentTarget = nil
    let session = PinchSession(integration: integration)

    session.open()
    #expect(session.phase == .idle)

    let composerFrame = CGRect(x: 10, y: 20, width: 300, height: 96)
    integration.currentTarget = PinchTarget(
        identifier: "chatgpt-composer",
        editableFrame: composerFrame,
        attachmentFrame: composerFrame
    )
    session.refreshMarker()
    #expect(session.markerFrame == composerFrame)

    session.open()

    #expect(session.phase == .open)
    #expect(integration.captureCount == 3)
    #expect(integration.isMonitoringKeyboard)
}

@MainActor
@Test("clicking outside an open picker dismisses the session")
func outsideClickDismissesOpenPicker() {
    let integration = TestIntegration()
    let session = PinchSession(integration: integration)

    session.open()
    #expect(session.phase == .open)
    #expect(integration.isMonitoringOutsideClicks)

    integration.clickOutside()

    #expect(session.phase == .idle)
    #expect(!integration.isMonitoringKeyboard)
    #expect(!integration.isMonitoringOutsideClicks)
}

@MainActor
@Test("a marker preparation miss remains retryable")
func markerPreparationMissCanRetry() async {
    let integration = TestIntegration()
    integration.currentTarget = PinchTarget(
        identifier: "chatgpt-composer"
    )
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.refreshMarker()
    session.beginMarkerHover()
    await Task.yield()
    #expect(await clock.nextDuration() == .milliseconds(300))

    integration.shouldFailPrepare = true
    session.activateMarker()
    #expect(session.phase == .idle)
    await clock.advance()
    await Task.yield()
    #expect(session.phase == .idle)
    #expect(!integration.isMonitoringKeyboard)
    #expect(!integration.isMonitoringOutsideClicks)

    integration.shouldFailPrepare = false
    session.activateMarker()

    #expect(session.phase == .hovering)
    session.cancel()
}

@MainActor
@Test("keyboard selection stays cancellable until insertion begins")
func numberedSelection() async {
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    #expect(integration.isMonitoringKeyboard)
    integration.press(.number(4))
    #expect(session.phase == .pinching)
    #expect(integration.isMonitoringKeyboard)
    #expect(integration.isMonitoringOutsideClicks)

    await Task.yield()
    await clock.advance()
    while session.phase == .pinching { await Task.yield() }
    #expect(integration.text == session.phrases[3].insertionText)
    #expect(!integration.isMonitoringKeyboard)
    #expect(!integration.isMonitoringOutsideClicks)
}

@MainActor
@Test("picker shortcuts immediately use the first nine ordered library phrases")
func customPhraseSelection() async throws {
    let fixtureURL = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "phrases.json")
    let library = try PhraseLibrary(fileURL: fixtureURL, localeIdentifier: "en")
    let custom = try library.create(displayName: "Custom", insertionText: "Insert this custom phrase")
    try library.move(fromOffsets: IndexSet(integer: library.phrases.count - 1), toOffset: 0)
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, phraseLibrary: library, clock: clock)

    session.open()
    integration.press(.number(1))
    await clock.advance()
    while session.phase == .pinching { await Task.yield() }

    #expect(session.selectedPhrase == custom.insertionText)
    #expect(integration.text == custom.insertionText)
}

@MainActor
@Test("Escape cancels the pinching phase before it writes")
func pinchingCanBeCancelled() async {
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    session.choose(session.phrases[0])
    await Task.yield()
    integration.press(.escape)

    #expect(session.phase == .idle)
    #expect(integration.text.isEmpty)
    #expect(!integration.isMonitoringKeyboard)
    #expect(!integration.isMonitoringOutsideClicks)

    await clock.advance()
    await Task.yield()
    #expect(integration.text.isEmpty)
}

@MainActor
@Test("clicking outside cancels the pinching phase before it writes")
func outsideClickCancelsPinching() async {
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    session.choose(session.phrases[0])
    await Task.yield()
    integration.clickOutside()

    #expect(session.phase == .idle)
    #expect(integration.text.isEmpty)

    await clock.advance()
    await Task.yield()
    #expect(integration.text.isEmpty)
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
    #expect(session.highlightedPhrase == session.phrases[1].insertionText)
    integration.press(.return)
    await Task.yield()
    await clock.advance()
    await Task.yield()
    #expect(integration.text == session.phrases[1].insertionText)

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
    session.choose(session.phrases[0])
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
    session.choose(session.phrases[0])
    await Task.yield()
    await clock.advance()
    await Task.yield()

    #expect(session.phase == .failed)
    #expect(integration.text.isEmpty)
}

@MainActor
@Test("secure input appearing before insertion fails without writing")
func secureInputDuringDelivery() async {
    let integration = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    session.choose(session.phrases[0])
    integration.secureInputIsActive = true
    await clock.advance()
    while session.phase == .pinching { await Task.yield() }

    #expect(session.phase == .failed)
    #expect(integration.text.isEmpty)
}

@MainActor
@Test("cancelling after a failed delivery removes temporary monitors")
func failedDeliveryMonitorCleanup() async {
    let integration = TestIntegration()
    integration.shouldFail = true
    let clock = TestClock()
    let session = PinchSession(integration: integration, clock: clock)

    session.open()
    session.choose(session.phrases[0])
    await clock.advance()
    while session.phase == .pinching { await Task.yield() }
    #expect(integration.isMonitoringKeyboard)
    #expect(integration.isMonitoringOutsideClicks)

    session.cancel()

    #expect(!integration.isMonitoringKeyboard)
    #expect(!integration.isMonitoringOutsideClicks)
}

@MainActor
@Test("a complete session delivers a phrase and returns to idle")
func successfulSession() async throws {
    let target = TestIntegration()
    let clock = TestClock()
    let session = PinchSession(integration: target, clock: clock)

    #expect(session.phrases.count == 6)
    session.open()
    #expect(session.phase == .open)
    #expect(target.captureCount == 1)
    #expect(target.prepareCount == 1)

    session.choose(session.phrases[3])
    #expect(session.phase == .pinching)

    await Task.yield()
    #expect(await clock.nextDuration() == .milliseconds(240))
    await clock.advance()
    while session.phase == .pinching { await Task.yield() }
    #expect(session.phase == .delivered)
    #expect(target.text == "按你的最佳判断继续")

    await Task.yield()
    #expect(await clock.nextDuration() == .milliseconds(150))
    await clock.advance()
    while session.phase == .delivered { await Task.yield() }
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
    session.choose(session.phrases[0])
    #expect(session.phase == .pinching)

    await clock.advance()
    while session.phase == .pinching { await Task.yield() }
    #expect(session.phase == .failed)

    session.recover()
    #expect(session.phase == .open)
    #expect(target.prepareCount == 2)
    target.shouldFail = false
    session.choose(session.phrases[0])
    await clock.advance()
    while session.phase == .pinching { await Task.yield() }
    #expect(session.phase == .delivered)
}

@MainActor
@Test("failed selection refresh cancels the session cleanly")
func failedSelectionRefreshCancelsSession() async {
    let target = TestIntegration()
    target.shouldFail = true
    let clock = TestClock()
    let session = PinchSession(integration: target, clock: clock)

    session.open()
    session.choose(session.phrases[0])
    await clock.advance()
    while session.phase == .pinching { await Task.yield() }
    target.shouldFailPrepare = true

    session.recover()

    #expect(session.phase == .idle)
    #expect(session.selectedPhrase == nil)
    #expect(session.highlightedPhrase == nil)
    #expect(!target.isMonitoringKeyboard)
}

@MainActor
private final class TestIntegration: PinchIntegration {
    var text = ""
    var shouldFail = false
    var shouldFailPrepare = false
    var captureCount = 0
    var prepareCount = 0
    var secureInputIsActive = false
    var currentTarget: PinchTarget? = PinchTarget(identifier: "test-composer")
    var isMonitoringKeyboard = false
    var isMonitoringOutsideClicks = false
    private var keyboardHandler: (@MainActor (PinchKey) -> Void)?
    private var outsideClickHandler: (@MainActor () -> Void)?

    func captureTarget() throws -> PinchTarget {
        captureCount += 1
        guard !secureInputIsActive else { throw DeliveryError.rejected }
        guard let currentTarget else { throw DeliveryError.rejected }
        return currentTarget
    }

    func prepareDelivery(to target: PinchTarget) throws {
        guard !shouldFailPrepare else { throw DeliveryError.rejected }
        prepareCount += 1
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

    func startOutsideClickMonitor(_ handler: @escaping @MainActor () -> Void) {
        outsideClickHandler = handler
        isMonitoringOutsideClicks = true
    }

    func stopOutsideClickMonitor() {
        outsideClickHandler = nil
        isMonitoringOutsideClicks = false
    }

    func press(_ key: PinchKey) {
        keyboardHandler?(key)
    }

    func clickOutside() {
        outsideClickHandler?()
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
