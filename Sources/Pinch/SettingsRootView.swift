import PinchCore
import SwiftUI

struct SettingsRootView: View {
    let library: PhraseLibrary
    @Bindable var settings: AppSettings
    @State private var selection = SettingsSection.general

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 4) {
                Button {
                    selection = .general
                } label: {
                    Label("General", systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    selection == .general ? Color.primary.opacity(0.08) : Color.clear,
                    in: .rect(cornerRadius: 9)
                )
                .accessibilityAddTraits(selection == .general ? .isSelected : [])

                Button {
                    selection = .phrases
                } label: {
                    Label("Phrases", systemImage: "text.bubble")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(
                    selection == .phrases ? Color.primary.opacity(0.08) : Color.clear,
                    in: .rect(cornerRadius: 9)
                )
                .accessibilityAddTraits(selection == .phrases ? .isSelected : [])

                Spacer()
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.top, 42)
            .background {
                ZStack {
                    Color(nsColor: .windowBackgroundColor)
                    Rectangle().fill(.thinMaterial)
                }
            }
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
