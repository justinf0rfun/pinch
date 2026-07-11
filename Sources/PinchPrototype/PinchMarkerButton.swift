import SwiftUI

struct PinchMarkerButton: View {
    @Bindable var model: PrototypeModel
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion
    @State private var clickPinching = false

    private var reducedMotion: Bool {
        model.forceReducedMotion || systemReducedMotion
    }

    private var isPinching: Bool {
        model.phase == .hovering || model.phase == .pinching || clickPinching
    }

    var body: some View {
        Button(action: activate) {
            Image(systemName: "hand.pinch")
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(
                    x: isPinching && !reducedMotion ? 0.78 : 1,
                    y: isPinching && !reducedMotion ? 0.92 : 1
                )
                .rotationEffect(.degrees(isPinching && !reducedMotion ? -7 : 0))
                .offset(y: isPinching && !reducedMotion ? 1.5 : 0)
                .animation(
                    .timingCurve(0.22, 1, 0.36, 1, duration: 0.18),
                    value: isPinching
                )
        }
            .accessibilityLabel("打开 Pinch")
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
            .help("停留 300ms 打开 Pinch")
            .accessibilityHint("停留或按下以显示快捷短语")
            .onHover { hovering in
                hovering ? model.beginHover() : model.endHover()
            }
    }

    private func activate() {
        guard !reducedMotion else {
            model.open()
            return
        }

        clickPinching = true
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            model.open()
            clickPinching = false
        }
    }
}
