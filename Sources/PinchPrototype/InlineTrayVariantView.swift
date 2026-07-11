import SwiftUI

struct InlineTrayVariantView: View {
    @Bindable var model: PrototypeModel
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion

    private var reducedMotion: Bool { model.forceReducedMotion || systemReducedMotion }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if model.phase == .open || model.phase == .pinching || model.phase == .failed {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(Array(model.filteredPhrases.enumerated()), id: \.offset) { index, phrase in
                            Button(phrase) {
                                model.selectedIndex = index
                                model.choose(phrase, systemReducedMotion: systemReducedMotion)
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .scaleEffect(
                                x: model.phase == .pinching && index == model.selectedIndex && !reducedMotion ? 0.72 : 1,
                                y: model.phase == .pinching && index == model.selectedIndex && !reducedMotion ? 0.92 : 1
                            )
                            .opacity(model.phase == .pinching && index != model.selectedIndex ? 0.25 : 1)
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: 620)
                .glassEffect(.clear, in: .capsule)
                .overlay(alignment: .topTrailing) {
                    if model.phase == .failed {
                        Text("未找到输入目标")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .offset(y: -22)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            PinchMarkerButton(model: model)
        }
        .offset(x: -10, y: -10)
        .animation(reducedMotion ? .easeOut(duration: 0.08) : .snappy(duration: 0.22), value: model.phase)
    }
}
