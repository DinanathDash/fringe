import Testing
@testable import Fringe

/// Default corners: top left screenshot, top right mute, bottom corners off.
@Suite("Corners")
struct CornerTests {
    @Test("Sliding down from the top left corner is the left edge (the 1.0.4 fix)")
    func topLeftDownIsLeftEdge() {
        var pad = TrackpadScript()
        pad.drag(from: pt(0.02, 0.98), to: pt(0.02, 0.89))

        #expect(pad.effects == [
            .engaged(.left, .volume),
            .stepped(.volume, increase: false),
            .stepped(.volume, increase: false),
            .disengaged,
        ])
    }

    @Test("Sliding right from the top left corner is the top edge")
    func topLeftRightIsTopEdge() {
        var pad = TrackpadScript()
        pad.drag(from: pt(0.02, 0.98), to: pt(0.11, 0.98))

        #expect(pad.effects == [
            .engaged(.top, .keyboardBrightness),
            .stepped(.keyboardBrightness, increase: true),
            .stepped(.keyboardBrightness, increase: true),
            .disengaged,
        ])
    }

    @Test("The first step in a shared corner counts from where the finger landed")
    func sharedCornerKeepsTravel() {
        var pad = TrackpadScript()
        let k = pad.newKey()
        pad.event([touch(k, .began, pt(0.02, 0.98))])
        pad.event([touch(k, .moved, pt(0.02, 0.93))])  // 5% in one move: decides and steps

        #expect(pad.effects == [.engaged(.left, .volume), .stepped(.volume, increase: false)])
    }

    @Test("A finger that hasn't moved 2% yet in a shared corner hasn't picked an edge")
    func sharedCornerWaitsForMovement() {
        var pad = TrackpadScript()
        let k = pad.newKey()
        pad.event([touch(k, .began, pt(0.02, 0.98))])
        pad.event([touch(k, .moved, pt(0.025, 0.99))])

        #expect(pad.effects.isEmpty)
    }

    @Test("Sliding left from the bottom right corner is the bottom edge, when one is set")
    func bottomRightLeftIsBottomEdge() {
        var settings = FringeSettings()
        settings.setAction(.media, for: .bottom)
        var pad = TrackpadScript(settings)
        pad.drag(from: pt(0.98, 0.02), to: pt(0.85, 0.02))

        #expect(pad.effects == [
            .engaged(.bottom, .media),
            .stepped(.media, increase: false),
            .disengaged,
        ])
    }

    @Test("Double-tapping the top right corner mutes")
    func doubleTapTopRightMutes() {
        var pad = TrackpadScript()
        pad.tap(at: pt(0.95, 0.95))
        pad.tap(at: pt(0.95, 0.95), after: 0.15)

        #expect(pad.effects.filter(isCornerTrigger) == [.cornerTriggered(.topRight, .mute)])
    }

    @Test("A double-tap counts when the trackpad marks the corner touches as resting")
    func restingDoubleTapCounts() {
        var pad = TrackpadScript()
        for gap in [0.01, 0.15] {
            let k = pad.newKey()
            pad.event([touch(k, .began, pt(0.95, 0.95), resting: true)], after: gap)
            pad.event([touch(k, .ended, pt(0.95, 0.95), resting: true)], after: 0.08)
        }

        #expect(pad.effects.filter(isCornerTrigger) == [.cornerTriggered(.topRight, .mute)])
    }

    @Test("A resting touch in a corner still can't start an edge drag")
    func restingCornerTouchDoesNotDrag() {
        var pad = TrackpadScript()
        let k = pad.newKey()
        pad.event([touch(k, .began, pt(0.02, 0.98), resting: true)])
        pad.event([touch(k, .moved, pt(0.02, 0.80), resting: true)])

        #expect(pad.effects.isEmpty)
    }

    @Test("A single tap does nothing")
    func singleTap() {
        var pad = TrackpadScript()
        pad.tap(at: pt(0.95, 0.95))

        #expect(pad.effects.filter(isCornerTrigger).isEmpty)
    }

    @Test("Two taps further apart than 0.45 s are not a double-tap")
    func slowTapsAreNotDoubleTap() {
        var pad = TrackpadScript()
        pad.tap(at: pt(0.95, 0.95))
        pad.tap(at: pt(0.95, 0.95), after: 0.60)

        #expect(pad.effects.filter(isCornerTrigger).isEmpty)
    }

    @Test("Taps in two different corners are not a double-tap")
    func tapsInDifferentCorners() {
        var pad = TrackpadScript()
        pad.tap(at: pt(0.05, 0.95))
        pad.tap(at: pt(0.95, 0.95), after: 0.15)

        #expect(pad.effects.filter(isCornerTrigger).isEmpty)
    }

    @Test("A double-tap in a corner set to Off does nothing")
    func doubleTapOffCorner() {
        var pad = TrackpadScript()
        pad.tap(at: pt(0.05, 0.05))
        pad.tap(at: pt(0.05, 0.05), after: 0.15)

        #expect(pad.effects.filter(isCornerTrigger).isEmpty)
    }

    @Test("A press held longer than 0.35 s is not a tap")
    func longPressIsNotTap() {
        var pad = TrackpadScript()
        for _ in 0..<2 {
            let k = pad.newKey()
            pad.event([touch(k, .began, pt(0.95, 0.95))], after: 0.1)
            pad.event([touch(k, .ended, pt(0.95, 0.95))], after: 0.5)
        }

        #expect(pad.effects.filter(isCornerTrigger).isEmpty)
    }

    @Test("A drag that started in a corner and stepped is not a tap")
    func dragIsNotTap() {
        var pad = TrackpadScript()
        pad.drag(from: pt(0.02, 0.98), to: pt(0.02, 0.90), moves: 2)
        pad.drag(from: pt(0.02, 0.98), to: pt(0.02, 0.90), moves: 2)

        #expect(pad.effects.filter(isCornerTrigger).isEmpty)
    }
}

private func isCornerTrigger(_ e: FringeGestureEffect) -> Bool {
    if case .cornerTriggered = e { return true }
    return false
}
