import PinchCore
import SwiftUI

struct SettingsRootView: View {
    let library: PhraseLibrary
    @Bindable var settings: AppSettings
    @State private var selection = SettingsSection.general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Pinch") {
                    Label("General", systemImage: "gearshape")
                        .tag(SettingsSection.general)
                    Label("Phrases", systemImage: "text.bubble")
                        .tag(SettingsSection.phrases)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            switch selection {
            case .general:
                GeneralSettingsView(settings: settings)
            case .phrases:
                PhraseManagementView(library: library)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 700, minHeight: 480)
    }
}
