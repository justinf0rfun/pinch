import PinchCore
import SwiftUI

struct PhraseManagementView: View {
    @Bindable var library: PhraseLibrary
    @State private var editor: PhraseEditorDraft?
    @State private var errorMessage: String?
    @State private var isConfirmingRestore = false
    @State private var dropTargetID: Phrase.ID?

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
                    PhraseRowView(
                        phrase: phrase,
                        shortcutNumber: index < 9 ? index + 1 : nil,
                        isDropTarget: dropTargetID == phrase.id,
                        edit: { edit(phrase) }
                    )
                    .dropDestination(for: String.self) { identifiers, location in
                        reorder(
                            identifiers.first,
                            relativeTo: phrase,
                            placeAfter: location.y > 28
                        )
                    } isTargeted: { isTargeted in
                        dropTargetID = isTargeted ? phrase.id : nil
                    }
                    .contextMenu {
                        Button("Edit", systemImage: "pencil") {
                            edit(phrase)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(phrase)
                        }
                    }
                    .accessibilityAction(named: "Move Up") {
                        moveUp(phrase, from: index)
                    }
                    .accessibilityAction(named: "Move Down") {
                        moveDown(phrase, from: index)
                    }
                    .listRowBackground(Color.clear)
                }
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

    private func restoreDefaults() {
        perform { try library.restoreDefaults() }
    }

    private func confirmRestore() {
        isConfirmingRestore = true
    }

    private func reorder(
        _ identifier: String?,
        relativeTo target: Phrase,
        placeAfter: Bool
    ) -> Bool {
        guard let identifier, let id = UUID(uuidString: identifier) else { return false }
        do {
            try library.move(id, relativeTo: target.id, placeAfter: placeAfter)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func moveUp(_ phrase: Phrase, from index: Int) {
        guard index > 0 else { return }
        _ = reorder(
            phrase.id.uuidString,
            relativeTo: library.phrases[index - 1],
            placeAfter: false
        )
    }

    private func moveDown(_ phrase: Phrase, from index: Int) {
        guard index + 1 < library.phrases.count else { return }
        _ = reorder(
            phrase.id.uuidString,
            relativeTo: library.phrases[index + 1],
            placeAfter: true
        )
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
