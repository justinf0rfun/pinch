import PinchCore
import SwiftUI

struct PhraseDragPreviewView: View {
    let phrase: Phrase

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(phrase.displayName)
                .font(.body)
                .lineLimit(1)
            Text(phrase.insertionText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 220, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}
