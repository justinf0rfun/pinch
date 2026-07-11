import SwiftUI

@MainActor
@Observable
final class PrototypeModel {
    enum Variant: String, CaseIterable {
        case edge = "A — Edge list"
        case inline = "B — Inline tray"
        case orbit = "C — Pinch orbit"
    }

    enum Phase: String {
        case idle, hovering, open, pinching, delivered, failed
    }

    let phrases = [
        "确认，继续",
        "允许本次操作",
        "使用推荐选项",
        "按你的最佳判断继续",
        "暂不执行，请先解释风险",
        "取消"
    ]

    var variant = Variant.edge
    var phase = Phase.idle
    var selectedIndex = 0
    var composerText = ""
    var simulateFailure = false
    var forceReducedMotion = false
    var searchText = ""
    private var hoverTask: Task<Void, Never>?

    var filteredPhrases: [String] {
        searchText.isEmpty ? phrases : phrases.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    func beginHover() {
        hoverTask?.cancel()
        phase = .hovering
        hoverTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            phase = .open
        }
    }

    func endHover() {
        hoverTask?.cancel()
        if phase == .hovering { phase = .idle }
    }

    func open() {
        hoverTask?.cancel()
        phase = .open
    }

    func dismiss() {
        hoverTask?.cancel()
        phase = .idle
        searchText = ""
    }

    func moveSelection(_ delta: Int) {
        guard !filteredPhrases.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + filteredPhrases.count) % filteredPhrases.count
    }

    func choose(_ phrase: String, systemReducedMotion: Bool) {
        guard phase == .open else { return }
        phase = .pinching
        let reducedMotion = forceReducedMotion || systemReducedMotion

        Task {
            try? await Task.sleep(for: .milliseconds(reducedMotion ? 90 : 240))
            if simulateFailure {
                phase = .failed
            } else {
                composerText = phrase
                phase = .delivered
                try? await Task.sleep(for: .milliseconds(500))
                phase = .idle
            }
        }
    }

    func resetForVariant(_ newVariant: Variant) {
        variant = newVariant
        selectedIndex = 0
        composerText = ""
        dismiss()
    }
}
