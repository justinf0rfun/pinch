import Foundation
import CoreGraphics

public struct PinchTarget: Equatable, Sendable {
    public let identifier: String
    public let frame: CGRect

    public init(identifier: String, frame: CGRect = .zero) {
        self.identifier = identifier
        self.frame = frame
    }
}

public enum PinchKey: Equatable, Sendable {
    case number(Int), up, down, `return`, escape
}

@MainActor
public protocol PinchIntegration: AnyObject {
    func captureTarget() throws -> PinchTarget
    func deliver(_ phrase: String, to target: PinchTarget) throws
    func startKeyboardMonitor(_ handler: @escaping @MainActor (PinchKey) -> Void)
    func stopKeyboardMonitor()
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
    public private(set) var highlightedPhrase: String?
    public var targetFrame: CGRect { target?.frame ?? .zero }
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
        guard phase == .idle else { return }
        do {
            target = try integration.captureTarget()
            highlightedPhrase = Self.builtInPhrases.first
            phase = .open
            integration.startKeyboardMonitor { [weak self] key in
                self?.handle(key)
            }
        } catch {
            target = nil
            phase = .failed
        }
    }

    public func choose(_ phrase: String) {
        guard phase == .open, let target else { return }
        integration.stopKeyboardMonitor()
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
                highlightedPhrase = nil
                self.target = nil
            } catch {
                phase = .failed
                integration.startKeyboardMonitor { [weak self] key in
                    self?.handle(key)
                }
            }
        }
    }

    public func cancel() {
        guard phase == .open || phase == .failed else { return }
        integration.stopKeyboardMonitor()
        target = nil
        selectedPhrase = nil
        highlightedPhrase = nil
        phase = .idle
    }

    private func handle(_ key: PinchKey) {
        guard phase == .open || phase == .failed else { return }
        switch key {
        case .number(let number):
            guard Self.builtInPhrases.indices.contains(number - 1) else { return }
            choose(Self.builtInPhrases[number - 1])
        case .up:
            moveHighlight(by: -1)
        case .down:
            moveHighlight(by: 1)
        case .return:
            if let highlightedPhrase { choose(highlightedPhrase) }
        case .escape:
            cancel()
        }
    }

    private func moveHighlight(by offset: Int) {
        let current = highlightedPhrase.flatMap(Self.builtInPhrases.firstIndex) ?? 0
        let next = min(max(current + offset, 0), Self.builtInPhrases.count - 1)
        highlightedPhrase = Self.builtInPhrases[next]
    }

    public func recover() {
        guard phase == .failed else { return }
        phase = target == nil ? .idle : .open
    }
}
