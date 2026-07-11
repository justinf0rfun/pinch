import AppKit
import PinchCore
import SwiftUI

@main
struct PinchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Pinch", systemImage: "hand.pinch") {
            ComposerMenu(model: model)
        }

        Window("Pinch Test Composer", id: "composer") {
            ComposerView(model: model)
                .frame(minWidth: 560, minHeight: 360)
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@MainActor
@Observable
private final class ComposerIntegration: PinchIntegration {
    var text = ""
    private let target = PinchTarget(identifier: "internal-composer")

    func captureTarget() -> PinchTarget {
        target
    }

    func deliver(_ phrase: String, to target: PinchTarget) {
        guard target == self.target else { return }
        text = phrase
    }
}

@MainActor
@Observable
private final class AppModel {
    let target: ComposerIntegration
    let session: PinchSession

    init() {
        let target = ComposerIntegration()
        self.target = target
        session = PinchSession(integration: target)
    }
}

private struct ComposerMenu: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Test Composer") {
            openWindow(id: "composer")
            NSApp.activate()
        }
        Divider()
        Button("Quit Pinch") { NSApp.terminate(nil) }
    }
}

private struct ComposerView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Internal Test Composer")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 10) {
                TextEditor(text: Binding(
                    get: { model.target.text },
                    set: { model.target.text = $0 }
                ))
                    .font(.body)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 18))

                edgeList
            }

            Text("Pinch inserts text here without submitting it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    @ViewBuilder
    private var edgeList: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if model.session.phase != .idle {
                VStack(spacing: 4) {
                    ForEach(PinchSession.builtInPhrases, id: \.self) { phrase in
                        Button(phrase) { model.session.choose(phrase) }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .scaleEffect(
                                x: model.session.phase == .pinching && model.session.selectedPhrase == phrase ? 0.72 : 1,
                                y: model.session.phase == .pinching && model.session.selectedPhrase == phrase ? 0.92 : 1
                            )
                            .opacity(model.session.selectedPhrase == nil || model.session.selectedPhrase == phrase ? 1 : 0.25)
                    }

                    if model.session.phase == .failed {
                        Button("Try again") { model.session.recover() }
                            .foregroundStyle(.orange)
                    }
                }
                .padding(8)
                .frame(width: 280)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                .animation(.snappy(duration: 0.24), value: model.session.phase)
            }

            Button("Open Pinch", systemImage: "hand.pinch") {
                model.session.open()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)
            .controlSize(.large)
            .accessibilityLabel("Open Pinch phrase list")
        }
    }
}
