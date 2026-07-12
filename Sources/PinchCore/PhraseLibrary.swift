import Foundation

@MainActor
@Observable
public final class PhraseLibrary {
    public enum LibraryError: Error, Equatable {
        case emptyDisplayName
        case emptyInsertionText
        case phraseNotFound
    }

    public private(set) var phrases: [Phrase]
    private let fileURL: URL

    public convenience init() throws {
        let fileURL = URL.applicationSupportDirectory
            .appending(path: "Pinch", directoryHint: .isDirectory)
            .appending(path: "phrases.json")
        try self.init(fileURL: fileURL, localeIdentifier: Locale.current.identifier)
    }

    public init(fileURL: URL, localeIdentifier: String) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            if let library = try? JSONDecoder().decode(PersistedLibrary.self, from: data) {
                phrases = Self.normalized(library.phrases)
            } else {
                let legacy = try JSONDecoder().decode(LegacyLibrary.self, from: data)
                phrases = legacy.phrases.enumerated().map { index, phrase in
                    Phrase(displayName: phrase.displayName, insertionText: phrase.insertionText, order: index)
                }
                try persist()
            }
        } else {
            phrases = Self.defaults(localeIdentifier: localeIdentifier)
            try persist()
        }
    }

    @discardableResult
    public func create(displayName: String, insertionText: String) throws -> Phrase {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LibraryError.emptyDisplayName }
        guard !insertionText.isEmpty else { throw LibraryError.emptyInsertionText }
        let phrase = Phrase(displayName: name, insertionText: insertionText, order: phrases.count)
        try mutate { phrases.append(phrase) }
        return phrase
    }

    public func update(_ id: UUID, displayName: String, insertionText: String) throws {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw LibraryError.emptyDisplayName }
        guard !insertionText.isEmpty else { throw LibraryError.emptyInsertionText }
        guard let index = phrases.firstIndex(where: { $0.id == id }) else { throw LibraryError.phraseNotFound }
        try mutate {
            phrases[index].displayName = name
            phrases[index].insertionText = insertionText
        }
    }

    public func delete(_ id: UUID) throws {
        guard let index = phrases.firstIndex(where: { $0.id == id }) else { throw LibraryError.phraseNotFound }
        try mutate {
            phrases.remove(at: index)
            normalizeOrder()
        }
    }

    public func move(fromOffsets: IndexSet, toOffset: Int) throws {
        try mutate {
            let moved = fromOffsets.map { phrases[$0] }
            for index in fromOffsets.reversed() { phrases.remove(at: index) }
            let destination = toOffset - fromOffsets.count(where: { $0 < toOffset })
            phrases.insert(contentsOf: moved, at: destination)
            normalizeOrder()
        }
    }

    public func restoreDefaults(localeIdentifier: String = Locale.current.identifier) throws {
        try mutate {
            let custom = phrases.filter { !$0.isBuiltIn }
            phrases = Self.defaults(localeIdentifier: localeIdentifier) + custom
            normalizeOrder()
        }
    }

    private func mutate(_ mutation: () -> Void) throws {
        let previous = phrases
        mutation()
        do {
            try persist()
        } catch {
            phrases = previous
            throw error
        }
    }

    private func normalizeOrder() {
        for index in phrases.indices { phrases[index].order = index }
    }

    private func persist() throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(PersistedLibrary(schemaVersion: 1, phrases: phrases))
        try data.write(to: fileURL, options: .atomic)
    }

    private static func normalized(_ phrases: [Phrase]) -> [Phrase] {
        phrases.sorted { $0.order < $1.order }.enumerated().map { index, phrase in
            var phrase = phrase
            phrase.order = index
            return phrase
        }
    }

    private static func defaults(localeIdentifier: String) -> [Phrase] {
        let simplifiedChinese = localeIdentifier.lowercased().hasPrefix("zh")
        let values = simplifiedChinese ? chineseDefaults : englishDefaults
        return values.enumerated().map { index, value in
            Phrase(
                id: value.id,
                displayName: value.displayName,
                insertionText: value.insertionText,
                order: index,
                isBuiltIn: true
            )
        }
    }

    private static let englishDefaults = [
        DefaultPhrase("00000000-0000-0000-0001-000000000001", "Confirm", "Confirm and continue."),
        DefaultPhrase("00000000-0000-0000-0001-000000000002", "Allow once", "Allow this operation once."),
        DefaultPhrase("00000000-0000-0000-0001-000000000003", "Recommended", "Use the recommended option."),
        DefaultPhrase("00000000-0000-0000-0001-000000000004", "Best judgment", "Continue using your best judgment."),
        DefaultPhrase("00000000-0000-0000-0001-000000000005", "Explain risk", "Do not proceed yet; explain the risks first."),
        DefaultPhrase("00000000-0000-0000-0001-000000000006", "Cancel", "Cancel.")
    ]

    private static let chineseDefaults = [
        DefaultPhrase("00000000-0000-0000-0002-000000000001", "确认", "确认，继续"),
        DefaultPhrase("00000000-0000-0000-0002-000000000002", "允许一次", "允许本次操作"),
        DefaultPhrase("00000000-0000-0000-0002-000000000003", "推荐选项", "使用推荐选项"),
        DefaultPhrase("00000000-0000-0000-0002-000000000004", "最佳判断", "按你的最佳判断继续"),
        DefaultPhrase("00000000-0000-0000-0002-000000000005", "解释风险", "暂不执行，请先解释风险"),
        DefaultPhrase("00000000-0000-0000-0002-000000000006", "取消", "取消")
    ]
}

private struct PersistedLibrary: Codable {
    let schemaVersion: Int
    let phrases: [Phrase]
}

private struct LegacyLibrary: Decodable {
    struct LegacyPhrase: Decodable {
        let displayName: String
        let insertionText: String
    }

    let phrases: [LegacyPhrase]
}

private struct DefaultPhrase {
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
