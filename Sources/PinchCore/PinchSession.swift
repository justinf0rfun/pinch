import Foundation
import CoreGraphics

public struct PinchTarget: Equatable, Sendable {
    public let identifier: String
    public let editableFrame: CGRect
    public let attachmentFrame: CGRect
    public let supportsMarker: Bool

    public init(
        identifier: String,
        editableFrame: CGRect = .zero,
        attachmentFrame: CGRect? = nil,
        supportsMarker: Bool = false
    ) {
        self.identifier = identifier
        self.editableFrame = editableFrame
        self.attachmentFrame = attachmentFrame ?? editableFrame
        self.supportsMarker = supportsMarker
    }
}

public enum PinchKey: Equatable, Sendable {
    case number(Int), up, down, `return`, escape
}

@MainActor
public protocol PinchIntegration: AnyObject {
    func captureTarget() throws -> PinchTarget
    func prepareDelivery(to target: PinchTarget) throws
    func deliver(_ phrase: String, to target: PinchTarget) throws
    func startKeyboardMonitor(_ handler: @escaping @MainActor (PinchKey) -> Void)
    func stopKeyboardMonitor()
    func startOutsideClickMonitor(_ handler: @escaping @MainActor () -> Void)
    func stopOutsideClickMonitor()
}

public extension PinchIntegration {
    func prepareDelivery(to target: PinchTarget) throws {}
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
        case idle, hovering, open, pinching, delivered, failed
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
    public var attachmentFrame: CGRect { target?.attachmentFrame ?? .zero }
    public var markerFrame: CGRect? { markerTarget?.attachmentFrame }
    private let integration: PinchIntegration
    private let clock: SessionClock
    private var target: PinchTarget?
    private var markerTarget: PinchTarget?
    private var markerTask: Task<Void, Never>?

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
            let capturedTarget = try integration.captureTarget()
            try integration.prepareDelivery(to: capturedTarget)
            target = capturedTarget
            finishOpening()
        } catch {
            target = nil
            phase = .idle
        }
    }

    public func refreshMarker() {
        guard phase == .idle else { return }
        markerTarget = try? integration.captureTarget()
        if markerTarget?.supportsMarker != true { markerTarget = nil }
    }

    public func beginMarkerHover() {
        beginMarkerActivation(after: .milliseconds(300))
    }

    public func activateMarker() {
        beginMarkerActivation(after: .milliseconds(120))
    }

    public func endMarkerHover() {
        guard phase == .hovering else { return }
        markerTask?.cancel()
        markerTask = nil
        target = nil
        phase = .idle
    }

    public func choose(_ phrase: String) {
        guard phase == .open, let target else { return }
        integration.stopKeyboardMonitor()
        integration.stopOutsideClickMonitor()
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
                integration.startOutsideClickMonitor { [weak self] in
                    self?.cancel()
                }
            }
        }
    }

    public func cancel() {
        guard phase == .hovering || phase == .open || phase == .failed else { return }
        markerTask?.cancel()
        markerTask = nil
        integration.stopKeyboardMonitor()
        integration.stopOutsideClickMonitor()
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
        guard let target else {
            phase = .idle
            return
        }
        do {
            try integration.prepareDelivery(to: target)
            phase = .open
        } catch {
            cancel()
        }
    }

    private func beginMarkerActivation(after delay: Duration) {
        guard (phase == .idle || phase == .hovering), let markerTarget else { return }
        do {
            try integration.prepareDelivery(to: markerTarget)
        } catch {
            target = nil
            phase = .failed
            return
        }
        markerTask?.cancel()
        target = markerTarget
        phase = .hovering
        markerTask = Task { [weak self, clock] in
            await clock.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.finishOpening()
        }
    }

    private func finishOpening() {
        markerTask = nil
        highlightedPhrase = Self.builtInPhrases.first
        phase = .open
        integration.startKeyboardMonitor { [weak self] key in
            self?.handle(key)
        }
        integration.startOutsideClickMonitor { [weak self] in
            self?.cancel()
        }
    }
}
