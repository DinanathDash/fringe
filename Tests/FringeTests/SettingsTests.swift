import Foundation
import Testing
@testable import Fringe

@Suite("Saved settings")
struct SettingsTests {
    private func decode(_ json: String) throws -> FringeSettings {
        try JSONDecoder().decode(FringeSettings.self, from: Data(json.utf8))
    }

    @Test("Settings saved by 1.0.4 load in 1.0.5, with the new options at their defaults")
    func loads104Settings() throws {
        let s = try decode("""
        {"isEnabled": false, "leftAction": "Keyboard backlight", "rightAction": "Volume",
         "topAction": "Disabled", "bottomAction": "Disabled", "edgeMarginFraction": 0.06,
         "stepDistance": 0.03, "modifierGuard": "Option (⌥) key", "hapticFeedbackEnabled": false}
        """)

        #expect(s.isEnabled == false)
        #expect(s.leftAction == .keyboardBrightness)
        #expect(s.rightAction == .volume)
        #expect(s.topAction == .none)
        #expect(s.edgeMarginFraction == 0.06)
        #expect(s.stepDistance == 0.03)
        #expect(s.modifierGuard == .option)
        #expect(s.hapticFeedbackEnabled == false)
        #expect(s.startZoneFraction == 0.33)
        #expect(s.topLeftCornerAction == .screenshot)
        #expect(s.topRightCornerAction == .mute)
        #expect(s.bottomLeftCornerAction == .none)
    }

    @Test("Empty saved settings give the defaults")
    func emptyGivesDefaults() throws {
        #expect(try decode("{}") == FringeSettings())
    }

    @Test("Older spellings of actions and keys still load", arguments: [
        ("brightness", FringeAction.brightness),
        ("keyboard", .keyboardBrightness),
        ("KEYBOARD LIGHT", .keyboardBrightness),
        ("off", .none),
        ("Skip tracks", .media),
    ])
    func legacyActionNames(raw: String, expected: FringeAction) throws {
        #expect(try decode(#"{"leftAction": "\#(raw)"}"#).leftAction == expected)
    }

    @Test("Older spellings of the key to hold still load", arguments: [
        ("None (direct edge drag)", ModifierGuard.none),
        ("fn", .fn),
        ("Command key", .command),
        ("control (⌃)", .control),
    ])
    func legacyModifierNames(raw: String, expected: ModifierGuard) throws {
        #expect(try decode(#"{"modifierGuard": "\#(raw)"}"#).modifierGuard == expected)
    }

    @Test("Older spellings of corner actions still load", arguments: [
        ("Screenshot toolbar (⌘⇧5)", FringeCornerAction.screenshot),
        ("mute mac", .mute),
        ("media", .playPause),
    ])
    func legacyCornerNames(raw: String, expected: FringeCornerAction) throws {
        #expect(try decode(#"{"topLeftCornerAction": "\#(raw)"}"#).topLeftCornerAction == expected)
    }

    @Test("An action this version doesn't know turns that edge off instead of failing to load")
    func unknownActionIsOff() throws {
        let s = try decode(#"{"leftAction": "Scroll speed", "rightAction": "Volume"}"#)
        #expect(s.leftAction == .none)
        #expect(s.rightAction == .volume)
    }

    @Test("Settings survive a save and load")
    func roundTrip() throws {
        var s = FringeSettings()
        s.setAction(.media, for: .bottom)
        s.setAction(.playPause, for: .bottomRight)
        s.startZoneFraction = 0.45
        s.modifierGuard = .fn
        let data = try JSONEncoder().encode(s)

        #expect(try JSONDecoder().decode(FringeSettings.self, from: data) == s)
    }
}

@Suite("One action per edge")
struct ActionAssignmentTests {
    @Test("Giving an action to a second edge takes it off the first")
    func actionMovesBetweenEdges() {
        var s = FringeSettings()  // left: volume
        s.setAction(.volume, for: .bottom)

        #expect(s.bottomAction == .volume)
        #expect(s.leftAction == .none)
        #expect(s.rightAction == .brightness)
    }

    @Test("Any number of edges can be Off")
    func manyEdgesOff() {
        var s = FringeSettings()
        s.setAction(.none, for: .left)
        s.setAction(.none, for: .right)

        #expect(s.leftAction == .none)
        #expect(s.rightAction == .none)
        #expect(s.topAction == .keyboardBrightness)
    }
}

@Suite("Gesture config")
struct GestureConfigTests {
    @Test("Out-of-range saved values are pulled back into range")
    func clampsToRanges() {
        var s = FringeSettings()
        s.edgeMarginFraction = 0.5
        s.startZoneFraction = 0.01
        s.stepDistance = 0

        let c = FringeGestureConfig(settings: s)
        #expect(c.margin == 0.08)
        #expect(c.startZoneFraction == 0.15)
        #expect(c.stepDistance == 0.02)
    }

    @Test("In-range values pass through unchanged")
    func keepsInRangeValues() {
        var s = FringeSettings()
        s.edgeMarginFraction = 0.05
        s.startZoneFraction = 0.4
        s.stepDistance = 0.06

        let c = FringeGestureConfig(settings: s)
        #expect(c.margin == 0.05)
        #expect(c.startZoneFraction == 0.4)
        #expect(c.stepDistance == 0.06)
    }

    @Test("A zero step distance in saved settings can't make a drag step forever")
    func zeroStepDistanceIsSafe() {
        var s = FringeSettings()
        s.stepDistance = 0
        var pad = TrackpadScript(s)
        pad.drag(from: pt(0.02, 0.10), to: pt(0.02, 0.15), moves: 1)

        #expect(pad.steps.count == 2)  // 5% at the 2% minimum
    }
}
