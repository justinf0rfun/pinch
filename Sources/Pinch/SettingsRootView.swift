import PinchCore
import SwiftUI

struct SettingsRootView: View {
    let library: PhraseLibrary
    @Bindable var settings: AppSettings
    @State private var selection = SettingsSection.general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("General", systemImage: "gearshape")
                    .tag(SettingsSection.general)
                Label("Phrases", systemImage: "text.bubble")
                    .tag(SettingsSection.phrases)
            }
            .font(.callout)
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .padding(.top, 42)
            .background(Color(nsColor: .underPageBackgroundColor))
            .navigationSplitViewColumnWidth(min: 176, ideal: 184, max: 200)
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
        .frame(minWidth: 640, minHeight: 400)
    }
}
