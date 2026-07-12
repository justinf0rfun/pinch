import PinchCore
import SwiftUI

struct PhraseRowView: View {
    let phrase: Phrase
    let shortcutNumber: Int?
    let isDropTarget: Bool
    let edit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 12) {
                    Text(shortcutNumber.map(String.init) ?? "–")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(shortcutNumber == nil ? .tertiary : .secondary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary, in: .rect(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(phrase.displayName)
                            .font(.body)
                            .lineLimit(1)
                        Text(phrase.insertionText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .frame(width: 32, height: 32)
                .contentShape(.rect)
                .accessibilityHidden(true)
                .draggable(phrase.id.uuidString)
        }
        .contentShape(.rect)
        .padding(.vertical, 8)
        .background(
            isDropTarget ? Color.accentColor.opacity(0.12) : Color.clear,
            in: .rect(cornerRadius: 8)
        )
    }
}
