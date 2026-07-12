import PinchCore
import SwiftUI

struct SettingsRootView: View {
    let library: PhraseLibrary
    @State private var selection = SettingsSection.phrases

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Phrases", systemImage: "text.badge.plus")
                    .tag(SettingsSection.phrases)
            }
            .navigationTitle("Settings")
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            PhraseManagementView(library: library)
        }
        .frame(minWidth: 760, minHeight: 500)
    }
}
