import PinchCore
import SwiftUI

struct SettingsRootView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    let library: PhraseLibrary
    @Bindable var settings: AppSettings
    @State private var selection = SettingsSection.general
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 14) {
                Button("Back to app", systemImage: "arrow.left") {
                    dismissWindow(id: "settings")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                TextField("Search settings…", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Text("Pinch")
                    .font(.callout)
                    .foregroundStyle(.tertiary)

                List(selection: $selection) {
                    if matches("general permission shortcut") {
                        Label("General", systemImage: "gearshape")
                            .tag(SettingsSection.general)
                    }
                    if matches("phrases library replies") {
                        Label("Phrases", systemImage: "text.bubble")
                            .tag(SettingsSection.phrases)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .background(.regularMaterial)
            .navigationSplitViewColumnWidth(min: 210, ideal: 220, max: 240)
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
        .frame(minWidth: 760, minHeight: 520)
    }

    private func matches(_ terms: String) -> Bool {
        searchText.isEmpty || terms.localizedStandardContains(searchText)
    }
}
