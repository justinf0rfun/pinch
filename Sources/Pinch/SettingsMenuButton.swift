import AppKit
import SwiftUI

struct SettingsMenuButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…", systemImage: "gearshape", action: showSettings)
    }

    private func showSettings() {
        NSApp.activate()
        openSettings()
    }
}
