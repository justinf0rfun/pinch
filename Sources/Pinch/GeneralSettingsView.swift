import PinchCore
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var explainsPermission = false

    var body: some View {
        Form {
            Section("Accessibility") {
                LabeledContent("Status") {
                    Label(permissionLabel, systemImage: permissionIcon)
                        .foregroundStyle(settings.permissionStatus == .granted ? .green : .secondary)
                }
                Text(permissionDetail)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Grant Accessibility Access") { explainsPermission = true }
                        .disabled(settings.permissionStatus == .granted)
                    Button("Open System Settings", action: settings.openAccessibilitySettings)
                }
            }

            Section("Keyboard Shortcut") {
                LabeledContent("Active Shortcut", value: settings.shortcut.active.displayName)
                HStack {
                    Button(
                        settings.recorder.isRecording ? "Press a shortcut…" : "Record Shortcut",
                        action: settings.beginRecording
                    )
                    Button("Cancel", action: settings.cancelRecording)
                        .disabled(!settings.recorder.isRecording)
                    Button("Restore Option–Space", action: settings.restoreDefault)
                    Spacer()
                    Button("Save", action: settings.saveShortcut)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                }
                if let draft = settings.recorder.draft {
                    LabeledContent("New Shortcut", value: draft.displayName)
                }
                if let message = shortcutMessage {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                ShortcutRecorderView(
                    isRecording: settings.recorder.isRecording,
                    record: settings.record,
                    cancel: settings.cancelRecording
                )
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .alert("Allow Accessibility Access?", isPresented: $explainsPermission) {
            Button("Continue", action: settings.requestAccessibilityPermission)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pinch uses Accessibility only to identify and write to the ChatGPT composer. It does not read or store chats, use the clipboard, or send messages.")
        }
    }

    private var canSave: Bool {
        guard let draft = settings.recorder.draft else { return false }
        return !settings.recorder.isRecording
            && draft != settings.shortcut.active
            && draft.validation == .valid
    }

    private var permissionLabel: String {
        settings.permissionStatus == .granted ? "Granted" : "Not Granted"
    }

    private var permissionIcon: String {
        settings.permissionStatus == .granted ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var permissionDetail: String {
        switch settings.permissionStatus {
        case .granted: "Pinch can insert phrases into the ChatGPT composer."
        case .revoked: "Access was removed. Grant it again to use Pinch."
        case .notGrantedAfterSettings: "Access is still off. Enable Pinch in System Settings."
        case .notGranted: "Required only when you use Pinch with ChatGPT."
        }
    }

    private var shortcutMessage: String? {
        if settings.recorder.draft?.validation == .reserved {
            return "Include Command, Control, or Option."
        }
        switch settings.shortcut.error {
        case .duplicate: return "That shortcut is already active."
        case .reserved: return "That shortcut is reserved."
        case .registrationConflict:
            return "That shortcut is unavailable. The previous shortcut remains active."
        case nil: return nil
        }
    }
}
