import Foundation
import Testing
@testable import PinchCore

@Test("marker aligns with the composer's send control")
func markerPlacement() {
    let composer = CGRect(x: 100, y: 200, width: 400, height: 96)

    #expect(MarkerPlacement.origin(for: composer, markerSize: CGSize(width: 36, height: 36)) == CGPoint(x: 459, y: 244))
}

@Test("Accessibility frames convert across displays around the primary screen")
func accessibilityFrameConversion() {
    let primary = CGRect(x: 0, y: 0, width: 1_440, height: 900)

    #expect(AccessibilityCoordinateSpace.appKitFrame(
        for: CGRect(x: 100, y: 200, width: 400, height: 96),
        primaryScreenFrame: primary
    ) == CGRect(x: 100, y: 604, width: 400, height: 96))
    #expect(AccessibilityCoordinateSpace.appKitFrame(
        for: CGRect(x: -1_200, y: 100, width: 400, height: 96),
        primaryScreenFrame: primary
    ) == CGRect(x: -1_200, y: 704, width: 400, height: 96))
    #expect(AccessibilityCoordinateSpace.appKitFrame(
        for: CGRect(x: 200, y: -700, width: 400, height: 96),
        primaryScreenFrame: primary
    ) == CGRect(x: 200, y: 1_504, width: 400, height: 96))
    #expect(AccessibilityCoordinateSpace.appKitFrame(
        for: CGRect(x: 200, y: 1_000, width: 400, height: 96),
        primaryScreenFrame: primary
    ) == CGRect(x: 200, y: -196, width: 400, height: 96))
}

@Test("ChatGPT picker shares the composer's bottom edge and grows upward")
func composerPickerPlacement() {
    let visible = CGRect(x: 0, y: 0, width: 1200, height: 900)
    let composer = CGRect(x: 300, y: 200, width: 500, height: 100)

    #expect(PickerPlacement.origin(
        near: composer,
        panelSize: CGSize(width: 280, height: 234),
        visibleFrame: visible
    ) == CGPoint(x: 810, y: 200))
}

@Test("moving frames stay hidden until mouse-up and 180 ms of stability")
func markerFrameStabilization() {
    let initial = CGRect(x: 100, y: 200, width: 400, height: 96)
    let dragged = CGRect(x: 140, y: 220, width: 400, height: 96)
    let final = CGRect(x: 180, y: 240, width: 400, height: 96)
    var stabilizer = MarkerFrameStabilizer(stabilityInterval: 0.18)

    #expect(stabilizer.frame(for: initial, at: 0, leftMouseDown: false) == nil)
    #expect(stabilizer.frame(for: initial, at: 0.181, leftMouseDown: false) == initial)
    #expect(stabilizer.frame(for: dragged, at: 0.20, leftMouseDown: true) == nil)
    #expect(stabilizer.frame(for: final, at: 0.50, leftMouseDown: true) == nil)
    #expect(stabilizer.frame(for: final, at: 0.51, leftMouseDown: false) == nil)
    #expect(stabilizer.frame(for: final, at: 0.689, leftMouseDown: false) == nil)
    #expect(stabilizer.frame(for: final, at: 0.691, leftMouseDown: false) == final)
}

@Test("ordinary frame changes also wait for stability")
func markerFrameChangeStabilization() {
    let first = CGRect(x: 10, y: 20, width: 300, height: 80)
    let second = CGRect(x: 11, y: 20, width: 300, height: 80)
    var stabilizer = MarkerFrameStabilizer(stabilityInterval: 0.18)

    #expect(stabilizer.frame(for: first, at: 1, leftMouseDown: false) == nil)
    #expect(stabilizer.frame(for: first, at: 1.181, leftMouseDown: false) == first)
    #expect(stabilizer.frame(for: second, at: 1.19, leftMouseDown: false) == nil)
    #expect(stabilizer.frame(for: second, at: 1.371, leftMouseDown: false) == second)
}

@Test("pointer drag events hide before the next frame sample")
func markerPointerDragEvents() {
    let frame = CGRect(x: 10, y: 20, width: 300, height: 80)
    var stabilizer = MarkerFrameStabilizer(stabilityInterval: 0.18)

    #expect(stabilizer.frame(for: frame, at: 0, leftMouseDown: false) == nil)
    #expect(stabilizer.frame(for: frame, at: 0.181, leftMouseDown: false) == frame)
    stabilizer.endPointerDrag(at: 0.19)
    #expect(stabilizer.frame(for: frame, at: 0.19, leftMouseDown: true) == frame)

    let beganDrag = stabilizer.beginPointerDrag()
    let repeatedDrag = stabilizer.beginPointerDrag()
    #expect(beganDrag)
    #expect(!repeatedDrag)
    #expect(stabilizer.frame(for: frame, at: 0.20, leftMouseDown: true) == nil)

    stabilizer.endPointerDrag(at: 0.21)
    #expect(stabilizer.frame(for: frame, at: 0.389, leftMouseDown: false) == nil)
    #expect(stabilizer.frame(for: frame, at: 0.391, leftMouseDown: false) == frame)
}
