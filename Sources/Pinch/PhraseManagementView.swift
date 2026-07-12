import PinchCore
import SwiftUI

struct PhraseManagementView: View {
    @Bindable var library: PhraseLibrary
    @State private var editor: PhraseEditorDraft?
    @State private var errorMessage: String?
    @State private var isConfirmingRestore = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Phrases")
                        .font(.title2)
                        .bold()
                    Text("Manage the quick replies shown beside the ChatGPT composer.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu("More", systemImage: "ellipsis") {
                    Button("Restore Defaults…", systemImage: "arrow.counterclockwise", action: confirmRestore)
                }
                .buttonStyle(.bordered)
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

                Button("Add Phrase", systemImage: "plus", action: add)
                    .buttonStyle(.borderedProminent)
                    .help("Add a phrase")
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
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: move)
                .onDelete { offsets in
                    for phrase in offsets.map({ library.phrases[$0] }) {
                        delete(phrase)
                    }
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .background(.quaternary, in: .rect(cornerRadius: 14))
            .clipShape(.rect(cornerRadius: 14))

            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                Text("Drag phrases to reorder them. Shortcuts 1–9 follow this order.")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(28)
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
