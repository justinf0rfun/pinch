import PinchCore
import SwiftUI

struct SettingsRootView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(reduceTransparency ? Color(nsColor: .windowBackgroundColor) : Color.clear)
            .navigationSplitViewColumnWidth(min: 180, ideal: 190, max: 210)
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
        .frame(minWidth: 680, minHeight: 440)
        .background {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}
