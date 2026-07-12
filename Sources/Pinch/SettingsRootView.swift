import PinchCore
import SwiftUI

struct SettingsRootView: View {
    let library: PhraseLibrary
    @State private var selection = SettingsSection.phrases

    var body: some View {
        TabView(selection: $selection) {
            Tab("Phrases", systemImage: "text.bubble", value: SettingsSection.phrases) {
                PhraseManagementView(library: library)
            }
        }
        .frame(width: 680, height: 500)
    }
}
