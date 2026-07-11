import Foundation

public struct PinchTarget: Equatable, Sendable {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

@MainActor
public protocol PinchIntegration: AnyObject {
    func captureTarget() throws -> PinchTarget
    func deliver(_ phrase: String, to target: PinchTarget) throws
}

protocol SessionClock: Sendable {
    func sleep(for duration: Duration) async
}

private struct ContinuousSessionClock: SessionClock {
    func sleep(for duration: Duration) async {
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
    public private(set) var selectedPhrase: String?
    private let integration: PinchIntegration
    private let clock: SessionClock
    private var target: PinchTarget?

    public convenience init(integration: PinchIntegration) {
        self.init(integration: integration, clock: ContinuousSessionClock())
    }

    init(integration: PinchIntegration, clock: SessionClock) {
        self.integration = integration
        self.clock = clock
    }

    public func open() {
        do {
            target = try integration.captureTarget()
            phase = .open
        } catch {
            phase = .failed
        }
    }

    public func choose(_ phrase: String) {
        guard phase == .open, let target else { return }
        selectedPhrase = phrase
        phase = .pinching

        Task {
            await clock.sleep(for: .milliseconds(240))
            do {
                try integration.deliver(phrase, to: target)
                phase = .delivered
                await clock.sleep(for: .milliseconds(500))
                phase = .idle
                selectedPhrase = nil
            } catch {
                phase = .failed
            }
        }
    }

    public func recover() {
        guard phase == .failed else { return }
        phase = target == nil ? .idle : .open
    }
}
