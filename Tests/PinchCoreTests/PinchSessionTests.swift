import Testing
@testable import PinchCore

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
    await Task.yield()
    #expect(session.phase == .failed)

    session.recover()
    #expect(session.phase == .open)
    target.shouldFail = false
    session.choose(PinchSession.builtInPhrases[0])
    await clock.advance()
    await Task.yield()
    #expect(session.phase == .delivered)
}

@MainActor
private final class TestIntegration: PinchIntegration {
    var text = ""
    var shouldFail = false
    var captureCount = 0
    private let target = PinchTarget(identifier: "test-composer")

    func captureTarget() -> PinchTarget {
        captureCount += 1
        return target
    }

    func deliver(_ phrase: String, to target: PinchTarget) throws {
        if shouldFail { throw DeliveryError.rejected }
        #expect(target == self.target)
        text = phrase
    }

    private enum DeliveryError: Error { case rejected }
}

private actor TestClock: SessionClock {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var pendingAdvances = 0

    func sleep(for duration: Duration) async {
        if pendingAdvances > 0 {
            pendingAdvances -= 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func advance() {
        if waiters.isEmpty {
            pendingAdvances += 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
