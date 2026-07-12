public enum PhraseLibraryError: Error, Equatable {
    case emptyDisplayName
    case emptyInsertionText
    case phraseNotFound
    case invalidOrder
}
