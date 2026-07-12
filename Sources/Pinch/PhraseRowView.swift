import PinchCore
import SwiftUI

struct PhraseRowView: View {
    let phrase: Phrase
    let shortcutNumber: Int?

    var body: some View {
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

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .padding(.vertical, 8)
    }
}
