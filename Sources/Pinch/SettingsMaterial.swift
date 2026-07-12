import SwiftUI

struct SettingsMaterial: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor), in: .rect(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(.primary.opacity(0.09), lineWidth: 1)
            }
    }
}
