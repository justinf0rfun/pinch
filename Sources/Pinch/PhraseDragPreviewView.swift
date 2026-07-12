import PinchCore
import SwiftUI

struct PhraseDragPreviewView: View {
    let phrase: Phrase

    var body: some View {
        Label(phrase.displayName, systemImage: "text.bubble")
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}
