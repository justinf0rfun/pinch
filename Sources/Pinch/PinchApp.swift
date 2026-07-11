import AppKit
import Carbon.HIToolbox
import PinchCore
import SwiftUI

@main
struct PinchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Pinch", systemImage: "hand.pinch") {
            Button("Open Pinch (⌥Space)") { appDelegate.openPinch() }
            Divider()
            Button("Quit Pinch") { NSApp.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let integration = MacOSPinchIntegration()
    private lazy var session = PinchSession(integration: integration)
    private lazy var panel = PinchPanel(session: session)
    private var shortcut: GlobalShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        integration.requestAccessibilityPermission()
        shortcut = GlobalShortcut { [weak self] in self?.openPinch() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.cancel()
        panel.close()
        shortcut?.stop()
        shortcut = nil
    }

    func openPinch() {
        session.open()
        guard session.phase == .open else { return }
        panel.show(near: session.targetFrame)
    }
}

@MainActor
private final class PinchPanel {
    private let panel: NSPanel

    init(session: PinchSession) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 290),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentViewController = NSHostingController(
            rootView: QuickSelectionView(session: session) { [weak panel] in
                panel?.orderOut(nil)
            }
        )
    }

    func show(near targetFrame: CGRect) {
        let visible = NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: min(max(targetFrame.maxX + 12, visible.minX), visible.maxX - panel.frame.width),
            y: min(max(visible.maxY - targetFrame.maxY, visible.minY), visible.maxY - panel.frame.height)
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }
}

private struct QuickSelectionView: View {
    @Bindable var session: PinchSession
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ForEach(PinchSession.builtInPhrases, id: \.self) { phrase in
                Button {
                    session.choose(phrase)
                } label: {
                    PhraseLabel(phrase: phrase, highlighted: session.highlightedPhrase == phrase)
                }
                .buttonStyle(.plain)
                .scaleEffect(
                    x: session.phase == .pinching && session.selectedPhrase == phrase ? 0.72 : 1,
                    y: session.phase == .pinching && session.selectedPhrase == phrase ? 0.92 : 1
                )
                .opacity(session.selectedPhrase == nil || session.selectedPhrase == phrase ? 1 : 0.25)
            }

            if session.phase == .failed {
                Button("Try again") { session.recover() }
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .animation(.snappy(duration: 0.24), value: session.phase)
        .onChange(of: session.phase) { _, phase in
            if phase == .delivered || phase == .idle { dismiss() }
        }
    }
}

private struct PhraseLabel: View {
    let phrase: String
    let highlighted: Bool

    var body: some View {
        HStack {
            Text(phrase)
            Spacer()
            Text(shortcutNumber).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(highlighted ? Color.primary.opacity(0.1) : Color.clear)
        .contentShape(.rect)
    }

    private var shortcutNumber: String {
        String((PinchSession.builtInPhrases.firstIndex(of: phrase) ?? 0) + 1)
    }
}

@MainActor
private final class GlobalShortcut {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: @MainActor () -> Void

    init(action: @escaping @MainActor () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            globalShortcutCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        let identifier = EventHotKeyID(signature: 0x504E_4348, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil
        eventHandler = nil
    }

    fileprivate func perform() {
        action()
    }
}

private func globalShortcutCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated { shortcut.perform() }
    return noErr
}
