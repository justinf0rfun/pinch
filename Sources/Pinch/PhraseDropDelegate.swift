import PinchCore
import SwiftUI
import UniformTypeIdentifiers

struct PhraseDropDelegate: DropDelegate {
    let targetID: Phrase.ID
    let entered: (Phrase.ID) -> Void
    let exited: (Phrase.ID) -> Void
    let dropped: () -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [UTType.text])
    }

    func dropEntered(info: DropInfo) {
        entered(targetID)
    }

    func dropExited(info: DropInfo) {
        exited(targetID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dropped()
    }
}
