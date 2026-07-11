import SwiftUI

struct CodexCanvasView: View {
    @Bindable var model: PrototypeModel
    @Environment(\.accessibilityReduceMotion) private var systemReducedMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Codex", systemImage: "terminal")
                    .bold()
                Spacer()
                Text("PINCH INTERACTION LAB")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("我会修改 3 个文件并运行测试。是否允许继续？")
                        .padding(14)
                        .background(.quaternary, in: .rect(cornerRadius: 14))

                    Text("把指针移到输入框右侧的 Pinch 标记，或点击标记开始。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
            }

            Spacer(minLength: 80)

            ZStack(alignment: .bottomTrailing) {
                TextField("回复 Codex…", text: $model.composerText, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .padding(.trailing, 44)
                    .glassEffect(.regular, in: .rect(cornerRadius: 22))

                picker
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 82)
        }
        .onKeyPress(.downArrow) {
            guard model.phase == .open else { return .ignored }
            model.moveSelection(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            guard model.phase == .open else { return .ignored }
            model.moveSelection(-1)
            return .handled
        }
        .onKeyPress(.return) {
            guard model.phase == .open, let phrase = model.filteredPhrases[safe: model.selectedIndex] else { return .ignored }
            model.choose(phrase, systemReducedMotion: systemReducedMotion)
            return .handled
        }
        .onKeyPress(.escape) {
            guard model.phase != .idle else { return .ignored }
            model.dismiss()
            return .handled
        }
    }

    @ViewBuilder
    private var picker: some View {
        switch model.variant {
        case .edge:
            EdgeListVariantView(model: model)
        case .inline:
            InlineTrayVariantView(model: model)
        case .orbit:
            OrbitVariantView(model: model)
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
