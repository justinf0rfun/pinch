import Foundation

@MainActor
public protocol PhraseTarget: AnyObject {
    func insert(_ phrase: String) throws
}

public protocol SessionClock: Sendable {
    func sleep(for duration: Duration) async
}

public struct ContinuousSessionClock: SessionClock {
    public init() {}

    public func sleep(for duration: Duration) async {
        try? await Task.sleep(for: duration)
    }
}

@MainActor
@Observable
public final class PinchSession {
    public enum Phase: Equatable {
        case idle, open, pinching, delivered, failed
    }

    public static let builtInPhrases = [
        "确认，继续",
        "允许本次操作",
        "使用推荐选项",
        "按你的最佳判断继续",
        "暂不执行，请先解释风险",
        "取消"
    ]

    public private(set) var phase = Phase.idle
    private let target: PhraseTarget
    private let clock: SessionClock

    public init(target: PhraseTarget, clock: SessionClock = ContinuousSessionClock()) {
        self.target = target
        self.clock = clock
    }

    public func open() {
        phase = .open
    }

    public func choose(_ phrase: String) {
        guard phase == .open else { return }
        phase = .pinching

        Task {
            await clock.sleep(for: .milliseconds(240))
            do {
                try target.insert(phrase)
                phase = .delivered
                await clock.sleep(for: .milliseconds(500))
                phase = .idle
            } catch {
                phase = .failed
            }
        }
    }

    public func recover() {
        guard phase == .failed else { return }
        phase = .open
    }
}
