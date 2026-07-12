import Foundation
import CoreGraphics

public struct PinchTarget: Equatable, Sendable {
    public let identifier: String
    public let editableFrame: CGRect
    public let attachmentFrame: CGRect

    public init(
        identifier: String,
        editableFrame: CGRect = .zero,
        attachmentFrame: CGRect? = nil
    ) {
        self.identifier = identifier
        self.editableFrame = editableFrame
        self.attachmentFrame = attachmentFrame ?? editableFrame
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

    public enum Failure: Equatable {
        case targetUnavailable
    }

    public var phrases: [Phrase] { phraseLibrary.phrases }

    public private(set) var phase = Phase.idle
    public private(set) var failure: Failure?
    public private(set) var selectedPhrase: Phrase?
    public private(set) var highlightedPhraseID: Phrase.ID?
    public var attachmentFrame: CGRect { target?.attachmentFrame ?? .zero }
    public var markerFrame: CGRect? { markerTarget?.attachmentFrame }
    private let integration: PinchIntegration
    private let phraseLibrary: PhraseLibrary
    private let clock: SessionClock
    private var target: PinchTarget?
    private var markerTarget: PinchTarget?
    private var markerTask: Task<Void, Never>?
    private var deliveryTask: Task<Void, Never>?

    public convenience init(integration: PinchIntegration) {
        guard let phraseLibrary = try? PhraseLibrary() else {
            fatalError("Unable to load the local phrase library")
        }
        self.init(integration: integration, phraseLibrary: phraseLibrary, clock: ContinuousSessionClock())
    }

    public convenience init(integration: PinchIntegration, phraseLibrary: PhraseLibrary) {
        self.init(integration: integration, phraseLibrary: phraseLibrary, clock: ContinuousSessionClock())
    }

    convenience init(integration: PinchIntegration, clock: SessionClock) {
        let fileURL = URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "phrases.json")
        guard let phraseLibrary = try? PhraseLibrary(fileURL: fileURL, localeIdentifier: "zh-Hans") else {
            fatalError("Unable to create the test phrase library")
        }
        self.init(integration: integration, phraseLibrary: phraseLibrary, clock: clock)
    }

    init(integration: PinchIntegration, phraseLibrary: PhraseLibrary, clock: SessionClock) {
        self.integration = integration
        self.phraseLibrary = phraseLibrary
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

    public func choose(_ phrase: Phrase) {
        guard phase == .open, let target else { return }
        selectedPhrase = phrase
        phase = .pinching

        deliveryTask = Task { [weak self, clock] in
            guard let self else { return }
            await clock.sleep(for: .milliseconds(240))
            guard !Task.isCancelled, phase == .pinching else { return }
            integration.stopKeyboardMonitor()
            integration.stopOutsideClickMonitor()
            do {
                try integration.deliver(phrase.insertionText, to: target)
                phase = .delivered
                failure = nil
                await clock.sleep(for: .milliseconds(150))
                guard !Task.isCancelled, phase == .delivered else { return }
                phase = .idle
                selectedPhrase = nil
                highlightedPhraseID = nil
                self.target = nil
                deliveryTask = nil
            } catch {
                phase = .failed
                failure = .targetUnavailable
                deliveryTask = nil
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
        guard phase == .hovering || phase == .open || phase == .pinching || phase == .failed else { return }
        reset(clearMarker: false)
    }

    public func targetApplicationDidTerminate() {
        reset(clearMarker: true)
    }

    private func reset(clearMarker: Bool) {
        markerTask?.cancel()
        markerTask = nil
        deliveryTask?.cancel()
        deliveryTask = nil
        integration.stopKeyboardMonitor()
        integration.stopOutsideClickMonitor()
        target = nil
        selectedPhrase = nil
        highlightedPhraseID = nil
        failure = nil
        if clearMarker { markerTarget = nil }
        phase = .idle
    }

    private func handle(_ key: PinchKey) {
        if phase == .pinching {
            if key == .escape { cancel() }
            return
        }
        guard phase == .open || phase == .failed else { return }
        switch key {
        case .number(let number):
            guard phrases.prefix(9).indices.contains(number - 1) else { return }
            choose(phrases[number - 1])
        case .up:
            moveHighlight(by: -1)
        case .down:
            moveHighlight(by: 1)
        case .return:
            if let highlightedPhrase = phrases.first(where: { $0.id == highlightedPhraseID }) {
                choose(highlightedPhrase)
            }
        case .escape:
            cancel()
        }
    }

    private func moveHighlight(by offset: Int) {
        guard !phrases.isEmpty else { return }
        let current = highlightedPhraseID.flatMap { id in phrases.firstIndex { $0.id == id } } ?? 0
        let next = min(max(current + offset, 0), phrases.count - 1)
        highlightedPhraseID = phrases[next].id
    }

    public func recover() {
        guard phase == .failed else { return }
        guard let target else {
            cancel()
            return
        }
        do {
            try integration.prepareDelivery(to: target)
            failure = nil
            phase = .open
        } catch {
            cancel()
        }
    }

    private func beginMarkerActivation(after delay: Duration) {
        guard (phase == .idle || phase == .hovering), let markerTarget else { return }
        markerTask?.cancel()
        markerTask = nil
        do {
            try integration.prepareDelivery(to: markerTarget)
        } catch {
            target = nil
            phase = .idle
            return
        }
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
        highlightedPhraseID = phrases.first?.id
        phase = .open
        integration.startKeyboardMonitor { [weak self] key in
            self?.handle(key)
        }
        integration.startOutsideClickMonitor { [weak self] in
            self?.cancel()
        }
    }
}
