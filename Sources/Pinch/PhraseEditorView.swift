import SwiftUI

struct PhraseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: PhraseEditorDraft
    let save: (PhraseEditorDraft) throws -> Void
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("Display name", text: $draft.displayName)
            TextField("Insertion text", text: $draft.insertionText, axis: .vertical)
                .lineLimit(3...8)
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 240)
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
