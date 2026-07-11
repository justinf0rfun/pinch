import SwiftUI

struct PrototypeSwitcherView: View {
    @Bindable var model: PrototypeModel

    var body: some View {
        HStack(spacing: 10) {
            Button("上一个方案", systemImage: "chevron.left", action: previous)
                .labelStyle(.iconOnly)

            VStack(spacing: 1) {
                Text(model.variant.rawValue)
                    .bold()
                Text("state: \(model.phase.rawValue)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 150)

            Button("下一个方案", systemImage: "chevron.right", action: next)
                .labelStyle(.iconOnly)

            Divider().frame(height: 24)

            Toggle("模拟失败", isOn: $model.simulateFailure)
                .toggleStyle(.switch)
                .controlSize(.small)

            Toggle("减少动态", isOn: $model.forceReducedMotion)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.black.opacity(0.82), in: .capsule)
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }

    private func previous() {
        let variants = PrototypeModel.Variant.allCases
        let index = variants.firstIndex(of: model.variant) ?? 0
        model.resetForVariant(variants[(index - 1 + variants.count) % variants.count])
    }

    private func next() {
        let variants = PrototypeModel.Variant.allCases
        let index = variants.firstIndex(of: model.variant) ?? 0
        model.resetForVariant(variants[(index + 1) % variants.count])
    }
}
