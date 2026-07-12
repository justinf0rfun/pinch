import PinchCore
import SwiftUI

struct PhraseManagementView: View {
    @Bindable var library: PhraseLibrary
    @State private var editor: PhraseEditorDraft?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(library.phrases) { phrase in
                    Button {
                        edit(phrase)
                    } label: {
                        LabeledContent {
                            Text(phrase.insertionText)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } label: {
                            Text(phrase.displayName)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") {
                            edit(phrase)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(phrase)
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete { offsets in
                    for phrase in offsets.map({ library.phrases[$0] }) { delete(phrase) }
                }
            }
            .navigationTitle("Phrases")
            .toolbar {
                ToolbarItemGroup {
                    Button("Add Phrase", systemImage: "plus", action: add)
                    Button("Restore Defaults", systemImage: "arrow.counterclockwise", action: restoreDefaults)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 440)
        .sheet(item: $editor) { draft in
            NavigationStack {
                PhraseEditorView(draft: draft, save: save)
            }
        }
        .alert("Phrase Library Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save(_ draft: PhraseEditorDraft) throws {
        if let id = draft.id {
            try library.update(id, displayName: draft.displayName, insertionText: draft.insertionText)
        } else {
            try library.create(displayName: draft.displayName, insertionText: draft.insertionText)
        }
    }

    private func add() {
        editor = PhraseEditorDraft()
    }

    private func edit(_ phrase: Phrase) {
        editor = PhraseEditorDraft(phrase: phrase)
    }

    private func delete(_ phrase: Phrase) {
        perform { try library.delete(phrase.id) }
    }

    private func move(fromOffsets: IndexSet, toOffset: Int) {
        perform { try library.move(fromOffsets: fromOffsets, toOffset: toOffset) }
    }

    private func restoreDefaults() {
        perform { try library.restoreDefaults() }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
