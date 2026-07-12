import PinchCore
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var explainsPermission = false

    var body: some View {
        Form {
            Section("Accessibility") {
                LabeledContent {
                    HStack {
                        Label(permissionLabel, systemImage: permissionIcon)
                            .foregroundStyle(
                                settings.permissionStatus == .granted ? .green : .secondary
                            )
                        Button(
                            settings.permissionStatus == .granted ? "Open Settings" : "Grant Access",
                            action: permissionAction
                        )
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Accessibility Access")
                        Text(permissionDetail)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Keyboard Shortcut") {
                LabeledContent {
                    HStack {
                        if settings.recorder.isRecording {
                            Button("Cancel", action: settings.cancelRecording)
                        }
                        Menu("Shortcut options", systemImage: "ellipsis") {
                            Button("Restore Option–Space", action: settings.restoreDefault)
                        }
                        .labelStyle(.iconOnly)
                        Button(shortcutButtonLabel, action: settings.beginRecording)
                            .monospaced()
                            .accessibilityLabel("Record global shortcut")
                            .accessibilityValue(shortcutButtonLabel)
                        if canSave {
                            Button("Save", action: settings.saveShortcut)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } label: {
                    VStack(alignment: .leading) {
                        Text("Open Pinch")
                        Text(shortcutDetail)
                            .foregroundStyle(shortcutMessage == nil ? Color.secondary : Color.red)
                    }
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
            Text(AppSettings.accessibilityExplanation)
        }
        .task {
            while !Task.isCancelled {
                settings.refreshPermission()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var canSave: Bool {
        guard let draft = settings.recorder.draft else { return false }
        return !settings.recorder.isRecording
            && draft != settings.shortcut.active
            && draft.validation == .valid
    }

    private var shortcutButtonLabel: String {
        if settings.recorder.isRecording { return "Type shortcut…" }
        return settings.recorder.draft?.displayName ?? settings.shortcut.active.displayName
    }

    private var shortcutDetail: String {
        if settings.recorder.isRecording { return "Press a new combination, or Escape to cancel." }
        return shortcutMessage ?? "Opens Pinch from anywhere."
    }

    private var permissionLabel: String {
        settings.permissionStatus == .granted ? "Granted" : "Not Granted"
    }

    private var permissionIcon: String {
        settings.permissionStatus == .granted ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var permissionDetail: String {
        switch settings.permissionStatus {
        case .granted: "Ready to insert phrases into ChatGPT."
        case .revoked: "Access was removed. Grant it again to use Pinch."
        case .notGrantedAfterSettings: "Enable Pinch in System Settings to continue."
        case .notGranted: "Required to insert phrases into the ChatGPT composer."
        }
    }

    private var shortcutMessage: String? {
        if settings.recorder.draft?.validation == .reserved {
            return "Include Command, Control, or Option."
        }
        switch settings.shortcut.error {
        case .duplicate: return "That shortcut is already active."
        case .reserved: return "That shortcut is reserved."
        case .registrationConflict: return "Unavailable. The previous shortcut is still active."
        case nil: return nil
        }
    }

    private func permissionAction() {
        if settings.permissionStatus == .granted {
            settings.openAccessibilitySettings()
        } else {
            explainsPermission = true
        }
    }
}
