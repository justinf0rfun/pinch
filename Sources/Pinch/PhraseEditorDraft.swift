import PinchCore

struct PhraseEditorDraft: Identifiable {
    let id: Phrase.ID?
    var displayName: String
    var insertionText: String

    init(phrase: Phrase? = nil) {
        id = phrase?.id
        displayName = phrase?.displayName ?? ""
        insertionText = phrase?.insertionText ?? ""
    }
}
