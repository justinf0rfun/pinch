import Foundation

public enum AccessibilityCoordinateSpace {
    public static func appKitFrame(
        for accessibilityFrame: CGRect,
        primaryScreenFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: accessibilityFrame.minX,
            y: primaryScreenFrame.maxY - accessibilityFrame.maxY,
            width: accessibilityFrame.width,
            height: accessibilityFrame.height
        )
    }
}

public enum MarkerPlacement {
    public static func origin(for composerFrame: CGRect, markerSize: CGSize) -> CGPoint {
        CGPoint(
            x: composerFrame.maxX - markerSize.width - 5,
            y: composerFrame.maxY - markerSize.height - 16
        )
    }
}

public enum PickerPlacement {
    public static func origin(
        near target: CGRect,
        panelSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let right = target.maxX + 10
        let x = right + panelSize.width <= visibleFrame.maxX
            ? right
            : target.minX - panelSize.width - 12
        return CGPoint(
            x: min(max(x, visibleFrame.minX), visibleFrame.maxX - panelSize.width),
            y: min(max(target.minY, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        )
    }
}

public struct MarkerFrameStabilizer {
    private let stabilityInterval: TimeInterval
    private var candidate: CGRect?
    private var stableSince: TimeInterval?
    private var dragActive = false

    public init(stabilityInterval: TimeInterval = 0.18) {
        self.stabilityInterval = stabilityInterval
    }

    @discardableResult
    public mutating func beginPointerDrag() -> Bool {
        guard !dragActive else { return false }
        dragActive = true
        return true
    }

    public mutating func endPointerDrag(at time: TimeInterval) {
        guard dragActive else { return }
        dragActive = false
        stableSince = time
    }

    public mutating func frame(
        for frame: CGRect?,
        at time: TimeInterval,
        leftMouseDown: Bool
    ) -> CGRect? {
        guard let frame else {
            candidate = nil
            stableSince = nil
            dragActive = false
            return nil
        }

        if candidate != frame {
            candidate = frame
            stableSince = time
            dragActive = dragActive || leftMouseDown
            return nil
        }

        if dragActive {
            guard !leftMouseDown else { return nil }
            dragActive = false
            stableSince = time
            return nil
        }

        guard let stableSince, time - stableSince >= stabilityInterval else { return nil }
        return frame
    }
}
