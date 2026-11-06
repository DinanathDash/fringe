import AppKit
@testable import Fringe

/// Positions are normalized like NSTouch.normalizedPosition: (0, 0) is bottom left.
struct TrackpadScript {
    var tracker = FringeGestureTracker()
    var config: FringeGestureConfig
    var flags: NSEvent.ModifierFlags = []
    var now: TimeInterval = 1_000
    private(set) var effects: [FringeGestureEffect] = []
    private var nextKey = 1

    init(_ settings: FringeSettings = FringeSettings()) {
        config = FringeGestureConfig(settings: settings)
    }

    mutating func event(_ touches: [FringeTouch], after seconds: TimeInterval = 0.01) {
        now += seconds
        effects += tracker.handle(touches, flags: flags, config: config, now: now)
    }

    mutating func newKey() -> Int {
        defer { nextKey += 1 }
        return nextKey
    }

    mutating func drag(from start: CGPoint, to end: CGPoint, moves: Int = 10, lift: Bool = true) {
        let key = newKey()
        event([touch(key, .began, start)])
        for i in 1...moves {
            let t = CGFloat(i) / CGFloat(moves)
            event([touch(key, .moved, CGPoint(x: start.x + (end.x - start.x) * t,
                                              y: start.y + (end.y - start.y) * t))])
        }
        if lift { event([touch(key, .ended, end)]) }
    }

    mutating func tap(at point: CGPoint, after seconds: TimeInterval = 0.01) {
        let key = newKey()
        event([touch(key, .began, point)], after: seconds)
        event([touch(key, .ended, point)], after: 0.08)
    }

    var steps: [FringeGestureEffect] {
        effects.filter { if case .stepped = $0 { return true } else { return false } }
    }
}

func touch(_ key: Int, _ phase: NSTouch.Phase, _ position: CGPoint, resting: Bool = false) -> FringeTouch {
    FringeTouch(key: key, phase: phase, isResting: resting, position: position,
                deviceSize: CGSize(width: 160, height: 100))
}

func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
