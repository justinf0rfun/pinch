import SwiftUI

struct OrbitVariantView: View {
    @Bindable var model: PrototypeModel
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion

    private var reducedMotion: Bool { model.forceReducedMotion || systemReducedMotion }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if model.phase == .open || model.phase == .pinching || model.phase == .failed {
                ForEach(Array(model.filteredPhrases.enumerated()), id: \.offset) { index, phrase in
                    let row = index / 2
                    let column = index % 2

                    Button(phrase) {
                        model.selectedIndex = index
                        model.choose(phrase, systemReducedMotion: systemReducedMotion)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .offset(x: CGFloat(column) * -150 - 38, y: CGFloat(row) * -44 - 52)
                    .scaleEffect(
                        x: model.phase == .pinching && index == model.selectedIndex && !reducedMotion ? 0.72 : 1,
                        y: model.phase == .pinching && index == model.selectedIndex && !reducedMotion ? 0.92 : 1
                    )
                    .opacity(model.phase == .pinching && index != model.selectedIndex ? 0.18 : 1)
                }

                if model.phase == .failed {
                    Label("返回", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .offset(x: -56, y: -184)
                }
            }

            PinchMarkerButton(model: model)
        }
        .offset(x: -10, y: -10)
        .animation(reducedMotion ? .easeOut(duration: 0.08) : .bouncy(duration: 0.26, extraBounce: 0.08), value: model.phase)
    }
}
