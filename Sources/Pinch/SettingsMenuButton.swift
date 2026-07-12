import AppKit
import SwiftUI

struct SettingsMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings…", systemImage: "gearshape", action: showSettings)
    }

    private func showSettings() {
        NSApp.activate()
        openWindow(id: "settings")
    }
}
