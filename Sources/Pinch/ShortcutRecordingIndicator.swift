import SwiftUI

struct ShortcutRecordingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        Label {
            Text("Recording…")
        } icon: {
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .opacity(isPulsing ? 0.35 : 1)
        }
        .foregroundStyle(.secondary)
        .accessibilityLabel("Recording shortcut. Press a new combination or Escape to cancel.")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
