import AppKit

@MainActor
public final class WorkspaceTerminationMonitor {
    private let notificationCenter: NotificationCenter
    private var observer: NSObjectProtocol?

    public init(notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.notificationCenter = notificationCenter
    }

    public func start(_ handler: @escaping @MainActor (NSRunningApplication) -> Void) {
        stop()
        observer = notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            MainActor.assumeIsolated { handler(application) }
        }
    }

    public func stop() {
        if let observer { notificationCenter.removeObserver(observer) }
        observer = nil
    }
}
