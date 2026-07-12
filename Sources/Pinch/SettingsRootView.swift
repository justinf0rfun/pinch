import PinchCore
import SwiftUI

struct SettingsRootView: View {
    let library: PhraseLibrary
    @Bindable var settings: AppSettings
    @State private var selection = SettingsSection.general
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.pinch.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.tint, in: .rect(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pinch")
                            .font(.headline)
                        Text("Settings")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)

                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search settings", text: $searchText)
                        .textFieldStyle(.plain)
                }
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(.quaternary, in: .rect(cornerRadius: 9))
                    .padding(.horizontal, 12)

                List(selection: $selection) {
                    Section("Settings") {
                        if searchText.isEmpty || "general accessibility shortcut".localizedStandardContains(searchText) {
                            Label("General", systemImage: "gearshape")
                                .tag(SettingsSection.general)
                        }
                    }
                    Section("Library") {
                        if searchText.isEmpty || "phrases".localizedStandardContains(searchText) {
                            Label("Phrases", systemImage: "text.bubble")
                                .tag(SettingsSection.phrases)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .padding(.top, 16)
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
        .toolbarVisibility(.hidden, for: .windowToolbar)
        .frame(width: 920, height: 620)
    }
}
