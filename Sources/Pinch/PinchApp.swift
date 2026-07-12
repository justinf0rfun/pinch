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
            SettingsMenuButton()
            Divider()
            Button("Quit Pinch") { NSApp.terminate(nil) }
        }
        Settings {
            SettingsRootView(library: appDelegate.phraseLibrary)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let integration = MacOSPinchIntegration()
    let phraseLibrary: PhraseLibrary
    private lazy var session = PinchSession(integration: integration, phraseLibrary: phraseLibrary)
    private lazy var panel = PinchPanel(session: session)
    private lazy var marker = MarkerPanel(session: session)
    private lazy var delivery = DeliveryPanel(session: session)
    private var shortcut: GlobalShortcut?
    private var markerTimer: Timer?
    private var markerDragMonitor: Any?
    private var markerStabilizer = MarkerFrameStabilizer()

    override init() {
        do {
            phraseLibrary = try PhraseLibrary()
        } catch {
            fatalError("Unable to load the local phrase library: \(error)")
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        integration.requestAccessibilityPermission()
        shortcut = GlobalShortcut { [weak self] in self?.openPinch() }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMarker() }
        }
        RunLoop.main.add(timer, forMode: .common)
        markerTimer = timer
        markerDragMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMarkerDrag(event.type) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        session.cancel()
        panel.close()
        marker.close()
        delivery.close()
        markerTimer?.invalidate()
        markerTimer = nil
        if let markerDragMonitor { NSEvent.removeMonitor(markerDragMonitor) }
        markerDragMonitor = nil
        shortcut?.stop()
        shortcut = nil
    }

    func openPinch() {
        session.open()
        guard session.phase == .open else { return }
        panel.show(near: session.attachmentFrame)
    }

    private func updateMarker() {
        if session.phase == .idle { session.refreshMarker() }
        let stableFrame = markerStabilizer.frame(
            for: session.markerFrame,
            at: ProcessInfo.processInfo.systemUptime,
            leftMouseDown: CGEventSource.buttonState(.combinedSessionState, button: .left)
        )
        guard let markerFrame = stableFrame else {
            marker.close()
            return
        }
        marker.show(near: markerFrame)
        if session.phase == .open || session.phase == .pinching || session.phase == .failed {
            panel.show(near: session.attachmentFrame)
        }
        if session.phase == .pinching || session.phase == .delivered || session.phase == .failed {
            delivery.show(from: panel.frame, to: session.attachmentFrame)
        } else {
            delivery.close()
        }
    }

    private func handleMarkerDrag(_ eventType: NSEvent.EventType) {
        switch eventType {
        case .leftMouseDragged:
            guard session.phase == .idle, session.markerFrame != nil,
                  markerStabilizer.beginPointerDrag() else { return }
            marker.close()
        case .leftMouseUp:
            markerStabilizer.endPointerDrag(at: ProcessInfo.processInfo.systemUptime)
        default:
            break
        }
    }
}

@MainActor
private final class MarkerPanel {
    private static let size = CGSize(width: 36, height: 36)
    private let panel: NSPanel

    init(session: PinchSession) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureFloatingPanel(panel)
        panel.contentViewController = NSHostingController(
            rootView: MarkerView(session: session)
                .frame(width: Self.size.width, height: Self.size.height)
        )
        panel.setContentSize(Self.size)
    }

    func show(near targetFrame: CGRect) {
        let target = appKitFrame(for: targetFrame)
        panel.setFrameOrigin(MarkerPlacement.origin(for: target, markerSize: Self.size))
        guard !panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        panel.orderOut(nil)
        panel.alphaValue = 1
    }
}

@MainActor
private final class PinchPanel {
    private static let size = CGSize(width: 280, height: 234)
    private let panel: NSPanel
    var frame: CGRect { panel.frame }

    init(session: PinchSession) {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureFloatingPanel(panel)
        panel.contentViewController = NSHostingController(
            rootView: QuickSelectionView(session: session) { [weak panel] in
                panel?.orderOut(nil)
            }
            .frame(width: Self.size.width, height: Self.size.height)
        )
        panel.setContentSize(Self.size)
    }

    func show(near targetFrame: CGRect) {
        let target = appKitFrame(for: targetFrame)
        let visible = NSScreen.screens.first(where: { $0.frame.intersects(target) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame ?? .zero
        let origin = PickerPlacement.origin(
            near: target,
            panelSize: panel.frame.size,
            visibleFrame: visible
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }
}

@MainActor
private final class DeliveryPanel {
    private let panel: NSPanel
    private let session: PinchSession
    private var isVisible = false

    init(session: PinchSession) {
        self.session = session
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureFloatingPanel(panel)
        panel.ignoresMouseEvents = true
    }

    func show(from pickerFrame: CGRect, to accessibilityTarget: CGRect) {
        guard !isVisible else { return }
        let target = appKitFrame(for: accessibilityTarget)
        let landingX = max(target.minX + 16, target.maxX - 180)
        let left = min(landingX, pickerFrame.minX)
        let right = max(target.maxX, pickerFrame.maxX)
        let width = max(right - left, 1)
        panel.setFrame(
            CGRect(x: left, y: target.midY - 24, width: width, height: 48),
            display: false
        )
        panel.contentViewController = NSHostingController(
            rootView: DeliveryView(
                session: session,
                startX: pickerFrame.midX - left,
                landingX: landingX - left
            )
        )
        panel.orderFrontRegardless()
        isVisible = true
    }

    func close() {
        panel.orderOut(nil)
        isVisible = false
    }
}

private struct MarkerView: View {
    @Bindable var session: PinchSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button("打开 Pinch", systemImage: "hand.pinch") { session.activateMarker() }
            .labelStyle(.iconOnly)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(width: 36, height: 36)
            .contentShape(.circle)
            .scaleEffect(x: isPinching && !reduceMotion ? 0.78 : 1, y: isPinching && !reduceMotion ? 0.92 : 1)
            .rotationEffect(.degrees(isPinching && !reduceMotion ? -7 : 0))
        .buttonStyle(PinchPressStyle())
        .help("停留 300ms 打开 Pinch")
        .accessibilityLabel("打开 Pinch")
        .accessibilityHint("停留或按下以显示快捷短语")
        .onHover { hovering in
            hovering ? session.beginMarkerHover() : session.endMarkerHover()
        }
        .animation(.easeOut(duration: 0.18), value: isPinching)
    }

    private var isPinching: Bool {
        session.phase == .hovering || session.phase == .pinching
    }
}

private struct QuickSelectionView: View {
    @Bindable var session: PinchSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let dismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(session.phrases) { phrase in
                        Button {
                            session.choose(phrase)
                        } label: {
                            PhraseLabel(
                                phrase: phrase,
                                shortcutNumber: session.phrases.firstIndex(of: phrase).map { $0 + 1 },
                                highlighted: session.highlightedPhraseID == phrase.id
                            )
                        }
                        .buttonStyle(PinchPressStyle())
                        .scaleEffect(
                            x: isSelectedForDelivery(phrase.insertionText) && !reduceMotion ? 0.72 : 1,
                            y: isSelectedForDelivery(phrase.insertionText) && !reduceMotion ? 0.92 : 1
                        )
                        .opacity(deliveryOpacity(for: phrase.insertionText))
                    }
                }
            }
            .scrollIndicators(.hidden)

            if session.phase == .failed {
                Button("重试", systemImage: "arrow.uturn.backward") { session.recover() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.bottom, 8)
            }
        }
        .padding(8)
        .frame(width: 280, height: 234)
        .foregroundStyle(.primary)
        .modifier(PickerMaterial())
        .animation(reduceMotion ? .easeOut(duration: 0.08) : .snappy(duration: 0.24), value: session.phase)
        .onChange(of: session.phase) { _, phase in
            if phase == .delivered || phase == .idle { dismiss() }
        }
    }

    private func isSelectedForDelivery(_ phrase: String) -> Bool {
        session.phase == .pinching && session.selectedPhrase?.insertionText == phrase
    }

    private func deliveryOpacity(for phrase: String) -> Double {
        guard let selected = session.selectedPhrase else { return 1 }
        if reduceMotion { return selected.insertionText == phrase ? 0.45 : 0.2 }
        return selected.insertionText == phrase ? 1 : 0.25
    }
}

private struct DeliveryView: View {
    @Bindable var session: PinchSession
    let startX: CGFloat
    let landingX: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasTravelled = false
    @State private var failureFaded = false

    var body: some View {
        GeometryReader { geometry in
            if let phrase = session.selectedPhrase {
                Text(phrase.insertionText)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .modifier(DeliveryMaterial())
                    .fixedSize()
                    .position(
                        x: reduceMotion ? startX : (hasTravelled ? landingX : startX),
                        y: geometry.size.height / 2
                    )
                    .scaleEffect(hasTravelled && !reduceMotion ? 0.72 : 1, anchor: .center)
                    .opacity(failureFaded ? 0 : (reduceMotion && !hasTravelled ? 0.25 : 1))
            }
        }
        .onAppear { beginTravel() }
        .onChange(of: session.phase) { _, phase in
            if phase == .failed {
                withAnimation(.easeOut(duration: 0.18)) { hasTravelled = false }
                Task {
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 160))
                    withAnimation(.easeOut(duration: 0.08)) { failureFaded = true }
                }
            }
        }
    }

    private func beginTravel() {
        hasTravelled = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.24) : .easeInOut(duration: 0.24)) {
            hasTravelled = true
        }
    }
}

private struct PhraseLabel: View {
    let phrase: Phrase
    let shortcutNumber: Int?
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(shortcutLabel)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(phrase.displayName)
                .lineLimit(1)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(highlighted ? Color.primary.opacity(0.08) : Color.clear, in: .rect(cornerRadius: 10))
        .contentShape(.rect)
    }

    private var shortcutLabel: String {
        shortcutNumber.flatMap { $0 <= 9 ? String($0) : nil } ?? ""
    }
}

private struct PinchPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

private struct PickerMaterial: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(nsColor: .windowBackgroundColor), in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.primary.opacity(0.12))
                }
        } else {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
        }
    }
}

private struct DeliveryMaterial: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .windowBackgroundColor), in: .capsule)
        } else {
            content.glassEffect(.regular, in: .capsule)
        }
    }
}

@MainActor
private func configureFloatingPanel(_ panel: NSPanel) {
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
}

@MainActor
private func appKitFrame(for accessibilityFrame: CGRect) -> CGRect {
    guard let primaryHeight = NSScreen.screens.first?.frame.maxY else { return accessibilityFrame }
    return CGRect(
        x: accessibilityFrame.minX,
        y: primaryHeight - accessibilityFrame.maxY,
        width: accessibilityFrame.width,
        height: accessibilityFrame.height
    )
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
