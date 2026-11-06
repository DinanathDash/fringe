import Testing
@testable import Fringe

/// Defaults: left volume, right brightness, top keyboard backlight, 33% start zone, 4% steps.
@Suite("Edge drags")
struct EdgeDragTests {
    @Test("Sliding up the left edge from its bottom corner raises the volume one step per 4%")
    func leftEdgeRaisesVolume() {
        var pad = TrackpadScript()
        // 13%, not 12%: travel that lands exactly on a step boundary rounds down.
        pad.drag(from: pt(0.02, 0.10), to: pt(0.02, 0.23))

        #expect(pad.effects == [
            .engaged(.left, .volume),
            .stepped(.volume, increase: true),
            .stepped(.volume, increase: true),
            .stepped(.volume, increase: true),
            .disengaged,
        ])
    }

    @Test("Sliding down the right edge from its top corner lowers the display brightness")
    func rightEdgeLowersBrightness() {
        var pad = TrackpadScript()
        pad.drag(from: pt(0.98, 0.90), to: pt(0.98, 0.81))

        #expect(pad.effects == [
            .engaged(.right, .brightness),
            .stepped(.brightness, increase: false),
            .stepped(.brightness, increase: false),
            .disengaged,
        ])
    }

    @Test("A drag that lands in the middle third of an edge never starts")
    func middleOfEdgeDoesNotStart() {
        var pad = TrackpadScript()
        pad.drag(from: pt(0.02, 0.45), to: pt(0.02, 0.60))

        #expect(pad.effects.isEmpty)
    }

    @Test("A drag that lands away from every edge never starts, even if it slides onto one")
    func centerTouchSlidingOntoEdgeDoesNotStart() {
        var pad = TrackpadScript()
        pad.drag(from: pt(0.40, 0.10), to: pt(0.02, 0.10))

        #expect(pad.effects.isEmpty)
    }

    @Test("A wider start zone lets a drag begin further along the edge")
    func widerStartZone() {
        var settings = FringeSettings()
        settings.startZoneFraction = 0.50
        var pad = TrackpadScript(settings)
        pad.drag(from: pt(0.02, 0.45), to: pt(0.02, 0.50))

        #expect(pad.effects.first == .engaged(.left, .volume))
    }

    @Test("The top edge's right corner is left alone; its middle-right stretch starts a drag")
    func topRightCornerIsLeftAlone() {
        var corner = TrackpadScript()
        corner.drag(from: pt(0.92, 0.98), to: pt(0.80, 0.98))
        #expect(corner.effects.isEmpty)

        var stretch = TrackpadScript()
        stretch.drag(from: pt(0.80, 0.98), to: pt(0.70, 0.98))
        #expect(stretch.effects == [
            .engaged(.top, .keyboardBrightness),
            .stepped(.keyboardBrightness, increase: false),
            .stepped(.keyboardBrightness, increase: false),
            .disengaged,
        ])
    }

    @Test("An edge set to Off does nothing")
    func disabledEdge() {
        var settings = FringeSettings()
        settings.setAction(.none, for: .left)
        var pad = TrackpadScript(settings)
        pad.drag(from: pt(0.02, 0.10), to: pt(0.02, 0.30))

        #expect(pad.effects.isEmpty)
    }

    @Test("A second finger ends a drag, and those fingers never start a new one")
    func secondFingerEndsDrag() {
        var pad = TrackpadScript()
        let a = pad.newKey(), b = pad.newKey()
        pad.event([touch(a, .began, pt(0.02, 0.10))])
        pad.event([touch(a, .moved, pt(0.02, 0.15))])
        pad.event([touch(a, .moved, pt(0.02, 0.16)), touch(b, .began, pt(0.50, 0.50))])
        pad.event([touch(b, .ended, pt(0.50, 0.50)), touch(a, .moved, pt(0.02, 0.30))])
        pad.event([touch(a, .moved, pt(0.02, 0.40))])

        #expect(pad.effects == [
            .engaged(.left, .volume),
            .stepped(.volume, increase: true),
            .disengaged,
        ])
    }

    @Test("A resting palm can't start a drag")
    func restingTouchDoesNotStart() {
        var pad = TrackpadScript()
        let k = pad.newKey()
        pad.event([touch(k, .began, pt(0.02, 0.10), resting: true)])
        pad.event([touch(k, .moved, pt(0.02, 0.30), resting: true)])

        #expect(pad.effects.isEmpty)
    }

    @Test("A drag already under way survives the trackpad marking that finger as resting")
    func engagedDragSurvivesRestingFlag() {
        var pad = TrackpadScript()
        let k = pad.newKey()
        pad.event([touch(k, .began, pt(0.02, 0.10))])
        pad.event([touch(k, .moved, pt(0.02, 0.15), resting: true)])

        #expect(pad.effects == [.engaged(.left, .volume), .stepped(.volume, increase: true)])
    }

    @Test("Wandering into the middle of the trackpad ends the drag")
    func wanderingEndsDrag() {
        var pad = TrackpadScript()
        pad.drag(from: pt(0.02, 0.10), to: pt(0.30, 0.10), lift: false)

        #expect(pad.effects == [.engaged(.left, .volume), .disengaged])
    }

    @Test("With a key to hold, a drag starts only while it is down")
    func modifierGuard() {
        var settings = FringeSettings()
        settings.modifierGuard = .option

        var without = TrackpadScript(settings)
        without.drag(from: pt(0.02, 0.10), to: pt(0.02, 0.30))
        #expect(without.effects.isEmpty)

        var with = TrackpadScript(settings)
        with.flags = .option
        with.drag(from: pt(0.02, 0.10), to: pt(0.02, 0.15))
        #expect(with.effects.first == .engaged(.left, .volume))
    }

    @Test("One fast event posts at most four steps")
    func stepBurstIsCapped() {
        var pad = TrackpadScript()
        let k = pad.newKey()
        pad.event([touch(k, .began, pt(0.02, 0.05))])
        pad.event([touch(k, .moved, pt(0.02, 0.35))])  // 30%: seven steps' worth

        #expect(pad.steps.count == 4)
    }

    @Test("Skip tracks moves one track per swipe, however far the swipe goes")
    func skipTracksOncePerSwipe() {
        var settings = FringeSettings()
        settings.setAction(.media, for: .left)
        var pad = TrackpadScript(settings)
        pad.drag(from: pt(0.02, 0.05), to: pt(0.02, 0.60))

        #expect(pad.steps == [.stepped(.media, increase: true)])
    }
}
