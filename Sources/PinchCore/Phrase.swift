import Foundation

public struct Phrase: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var displayName: String
    public var insertionText: String
    public var order: Int
    public var isBuiltIn: Bool

    public init(
        id: UUID = UUID(),
        displayName: String,
        insertionText: String,
        order: Int,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.insertionText = insertionText
        self.order = order
        self.isBuiltIn = isBuiltIn
    }
}
