import AppKit
import Testing
@testable import PinchCore

@MainActor
@Test("stopping the workspace monitor removes its termination observer")
func workspaceTerminationMonitorCleanup() {
    let notificationCenter = NotificationCenter()
    let monitor = WorkspaceTerminationMonitor(notificationCenter: notificationCenter)
    var notifications = 0
    monitor.start { _ in notifications += 1 }

    notificationCenter.post(
        name: NSWorkspace.didTerminateApplicationNotification,
        object: nil,
        userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current]
    )
    #expect(notifications == 1)
    #expect(monitor.isMonitoring)

    monitor.stop()
    notificationCenter.post(
        name: NSWorkspace.didTerminateApplicationNotification,
        object: nil,
        userInfo: [NSWorkspace.applicationUserInfoKey: NSRunningApplication.current]
    )

    #expect(notifications == 1)
    #expect(!monitor.isMonitoring)
}
