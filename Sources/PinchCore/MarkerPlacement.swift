import Foundation

public enum MarkerPlacement {
    public static func origin(for composerFrame: CGRect, markerSize: CGSize) -> CGPoint {
        CGPoint(
            x: composerFrame.maxX - markerSize.width - 16,
            y: composerFrame.maxY - markerSize.height - 16
        )
    }
}

public enum PickerPlacement {
    public static func origin(
        near target: CGRect,
        panelSize: CGSize,
        visibleFrame: CGRect,
        anchor: PinchTargetAnchor
    ) -> CGPoint {
        let x: CGFloat
        let y: CGFloat
        if anchor != .composer {
            x = anchor == .caret ? target.maxX + 10 : target.minX
            let above = target.maxY + 10
            y = above + panelSize.height <= visibleFrame.maxY
                ? above
                : target.minY - panelSize.height - 10
        } else {
            let right = target.maxX + 10
            x = right + panelSize.width <= visibleFrame.maxX
                ? right
                : target.minX - panelSize.width - 12
            y = target.minY
        }
        return CGPoint(
            x: min(max(x, visibleFrame.minX), visibleFrame.maxX - panelSize.width),
            y: min(max(y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
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
