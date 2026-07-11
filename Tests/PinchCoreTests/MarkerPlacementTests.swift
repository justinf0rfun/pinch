import Foundation
import Testing
@testable import PinchCore

@Test("marker sits inside the composer's upper-right content area")
func markerPlacement() {
    let composer = CGRect(x: 100, y: 200, width: 400, height: 96)

    #expect(MarkerPlacement.origin(for: composer, markerSize: CGSize(width: 36, height: 36)) == CGPoint(x: 448, y: 244))
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
