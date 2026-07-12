import SwiftUI

struct SettingsMaterial: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 16))
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }
}
