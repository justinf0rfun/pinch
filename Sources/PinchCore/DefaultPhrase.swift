import Foundation

struct DefaultPhrase {
    let id: UUID
    let displayName: String
    let insertionText: String

    init(_ id: String, _ displayName: String, _ insertionText: String) {
        guard let id = UUID(uuidString: id) else { fatalError("Invalid built-in phrase ID") }
        self.id = id
        self.displayName = displayName
        self.insertionText = insertionText
    }
}
