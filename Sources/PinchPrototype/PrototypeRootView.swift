import SwiftUI

struct PrototypeRootView: View {
    @State private var model = PrototypeModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            CodexCanvasView(model: model)

            PrototypeSwitcherView(model: model)
                .padding(.bottom, 16)
        }
        .background {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        }
    }
}
