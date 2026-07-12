struct PersistedLibrary: Codable {
    let schemaVersion: Int
    let phrases: [Phrase]
}
