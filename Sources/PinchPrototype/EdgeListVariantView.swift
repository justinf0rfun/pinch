import SwiftUI

struct EdgeListVariantView: View {
    @Bindable var model: PrototypeModel
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion

    private var reducedMotion: Bool { model.forceReducedMotion || systemReducedMotion }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if model.phase == .open || model.phase == .pinching || model.phase == .failed {
                VStack(spacing: 4) {
                    ForEach(Array(model.filteredPhrases.enumerated()), id: \.offset) { index, phrase in
                        Button(action: { model.choose(phrase, systemReducedMotion: systemReducedMotion) }) {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                Text(phrase)
                                Spacer(minLength: 18)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(index == model.selectedIndex ? .white.opacity(0.12) : .clear, in: .rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .scaleEffect(
                            x: model.phase == .pinching && index == model.selectedIndex && !reducedMotion ? 0.72 : 1,
                            y: model.phase == .pinching && index == model.selectedIndex && !reducedMotion ? 0.92 : 1
                        )
                        .offset(y: model.phase == .pinching && index == model.selectedIndex && !reducedMotion ? 44 : 0)
                        .opacity(model.phase == .pinching && index != model.selectedIndex ? 0.2 : 1)
                    }

                    if model.phase == .failed {
                        Label("请先聚焦输入框", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.top, 5)
                    }
                }
                .padding(8)
                .frame(width: 280)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                .transition(.scale(scale: 0.94, anchor: .bottomTrailing).combined(with: .opacity))
            }

            PinchMarkerButton(model: model)
        }
        .offset(x: -10, y: -10)
        .animation(reducedMotion ? .easeOut(duration: 0.08) : .snappy(duration: 0.22), value: model.phase)
    }
}
