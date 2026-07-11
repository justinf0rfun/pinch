import Testing
@testable import PinchCore

@MainActor
@Test("a complete session delivers a phrase and returns to idle")
func successfulSession() async throws {
    let target = TestTarget()
    let clock = TestClock()
    let session = PinchSession(target: target, clock: clock)

    session.open()
    #expect(session.phase == .open)

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
    let target = TestTarget()
    target.shouldFail = true
    let clock = TestClock()
    let session = PinchSession(target: target, clock: clock)

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
private final class TestTarget: PhraseTarget {
    var text = ""
    var shouldFail = false

    func insert(_ phrase: String) throws {
        if shouldFail { throw DeliveryError.rejected }
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
