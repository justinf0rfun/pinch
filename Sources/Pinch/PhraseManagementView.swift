import PinchCore
import SwiftUI

struct PhraseManagementView: View {
    @Bindable var library: PhraseLibrary
    @State private var editor: PhraseEditorDraft?
    @State private var errorMessage: String?
    @State private var isConfirmingRestore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Phrase Library")
                    .font(.title2)
                    .bold()
                Text("Choose the short replies that appear beside the ChatGPT composer. Drag to reorder; the first nine use number shortcuts.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            List {
                ForEach(library.phrases.enumerated(), id: \.element.id) { index, phrase in
                    Button {
                        edit(phrase)
                    } label: {
                        PhraseRowView(phrase: phrase, shortcutNumber: index < 9 ? index + 1 : nil)
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
                    for phrase in offsets.map({ library.phrases[$0] }) {
                        delete(phrase)
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .clipShape(.rect(cornerRadius: 10))
        }
        .padding(20)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Phrase", systemImage: "plus", action: add)
                    .help("Add a phrase")
            }
            ToolbarItem {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Restore Defaults…", systemImage: "arrow.counterclockwise", action: confirmRestore)
                }
                .help("More phrase actions")
                .confirmationDialog(
                    "Restore Built-In Phrases?",
                    isPresented: $isConfirmingRestore
                ) {
                    Button("Restore Defaults", action: restoreDefaults)
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Built-in phrases will return to their original text and order. Your custom phrases will not change.")
                }
            }
        }
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

    private func confirmRestore() {
        isConfirmingRestore = true
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
