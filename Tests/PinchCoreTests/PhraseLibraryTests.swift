import Foundation
import Testing
@testable import PinchCore

@MainActor
@Suite("Phrase library", .serialized)
struct PhraseLibraryTests {
    @Test("CRUD preserves stable identity and explicit order")
    func crud() throws {
        let fixture = try Fixture()
        let library = try fixture.library(localeIdentifier: "en")
        let created = try library.create(displayName: "Ship", insertionText: "Ship the smallest safe change.")

        #expect(library.phrases.last == created)
        #expect(created.order == library.phrases.count - 1)

        try library.update(created.id, displayName: "Ship safely", insertionText: "Ship it safely.")
        #expect(library.phrases.last?.id == created.id)
        #expect(library.phrases.last?.displayName == "Ship safely")
        #expect(library.phrases.last?.insertionText == "Ship it safely.")

        try library.delete(created.id)
        #expect(!library.phrases.contains { $0.id == created.id })
        #expect(library.phrases.map(\.order) == Array(library.phrases.indices))
    }

    @Test("reordering is persisted across restart")
    func reorderAndRestart() throws {
        let fixture = try Fixture()
        let library = try fixture.library(localeIdentifier: "en")
        let custom = try library.create(displayName: "Custom", insertionText: "Custom insertion")
        try library.move(fromOffsets: IndexSet(integer: library.phrases.count - 1), toOffset: 0)

        let restarted = try fixture.library(localeIdentifier: "en")
        #expect(restarted.phrases.first?.id == custom.id)
        #expect(restarted.phrases.map(\.order) == Array(restarted.phrases.indices))
    }

    @Test("restoring current-language defaults does not rewrite custom content")
    func restoreDefaults() throws {
        let fixture = try Fixture()
        let library = try fixture.library(localeIdentifier: "en")
        let custom = try library.create(displayName: "不要翻译", insertionText: "保留我的原文")
        let firstBuiltIn = try #require(library.phrases.first)
        try library.update(firstBuiltIn.id, displayName: "Changed", insertionText: "Changed")
        try library.delete(library.phrases[1].id)

        try library.restoreDefaults(localeIdentifier: "zh-Hans")

        #expect(library.phrases.contains(custom))
        #expect(library.phrases.first { $0.id == custom.id }?.displayName == "不要翻译")
        #expect(library.phrases.contains { $0.displayName == "确认" && $0.insertionText == "确认，继续" })
        #expect(!library.phrases.contains { $0.displayName == "Changed" })
    }

    @Test("Traditional Chinese locales do not receive Simplified Chinese defaults")
    func traditionalChineseFallback() throws {
        let fixture = try Fixture()
        let library = try fixture.library(localeIdentifier: "zh-Hant-TW")

        #expect(library.phrases.first?.displayName == "Confirm")
    }

    @Test("initial unversioned schema migrates with stable IDs and order")
    func initialSchemaMigration() throws {
        let fixture = try Fixture()
        let legacy = """
        {"phrases":[{"displayName":"First","insertionText":"One"},{"displayName":"Second","insertionText":"Two"}]}
        """
        try Data(legacy.utf8).write(to: fixture.url)

        let library = try fixture.library(localeIdentifier: "en")
        let ids = library.phrases.map(\.id)
        #expect(library.phrases.map(\.order) == [0, 1])
        #expect(library.phrases.map(\.displayName) == ["First", "Second"])

        let restarted = try fixture.library(localeIdentifier: "en")
        #expect(restarted.phrases.map(\.id) == ids)
    }
}

private struct Fixture {
    let directory: URL
    let url: URL

    init() throws {
        directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        url = directory.appending(path: "phrases.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    @MainActor
    func library(localeIdentifier: String) throws -> PhraseLibrary {
        try PhraseLibrary(fileURL: url, localeIdentifier: localeIdentifier)
    }
}
