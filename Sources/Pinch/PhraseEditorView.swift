import SwiftUI

struct PhraseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PhraseEditorDraft
    let save: (PhraseEditorDraft) throws -> Void
    @State private var errorMessage: String?

    init(draft: PhraseEditorDraft, save: @escaping (PhraseEditorDraft) throws -> Void) {
        _draft = State(initialValue: draft)
        self.save = save
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $draft.displayName)
                TextField("Reply", text: $draft.insertionText, axis: .vertical)
                    .lineLimit(3...6)
            } footer: {
                Text("The name stays compact in the picker. The full reply is inserted into ChatGPT.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 280)
        .navigationTitle(draft.id == nil ? "New Phrase" : "Edit Phrase")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveDraft)
                    .disabled(
                        draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || draft.insertionText.isEmpty
                    )
            }
        }
        .alert("Couldn’t Save Phrase", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveDraft() {
        do {
            try save(draft)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
