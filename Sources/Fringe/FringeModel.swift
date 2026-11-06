//
//  FringeModel.swift
//  Fringe
//

import AppKit
import Foundation
import SwiftUI

public enum FringeEdge: String, CaseIterable, Identifiable, Codable, Sendable {
    case left = "Left"
    case right = "Right"
    case top = "Top"
    case bottom = "Bottom"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .left: return "Left edge"
        case .right: return "Right edge"
        case .top: return "Top edge"
        case .bottom: return "Bottom edge"
        }
    }

    public var systemImage: String {
        switch self {
        case .left: return "arrow.left.to.line"
        case .right: return "arrow.right.to.line"
        case .top: return "arrow.up.to.line"
        case .bottom: return "arrow.down.to.line"
        }
    }

    /// How a drag along this edge moves, for the shelf widget.
    public var directionLabel: String {
        switch self {
        case .left, .right: return "Up or down"
        case .top, .bottom: return "Left or right"
        }
    }
}

public enum FringeCorner: String, CaseIterable, Identifiable, Codable, Sendable {
    case topLeft = "Top-Left"
    case topRight = "Top-Right"
    case bottomLeft = "Bottom-Left"
    case bottomRight = "Bottom-Right"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .topLeft: return "Top-left corner"
        case .topRight: return "Top-right corner"
        case .bottomLeft: return "Bottom-left corner"
        case .bottomRight: return "Bottom-right corner"
        }
    }

    public var shortLabel: String {
        switch self {
        case .topLeft: return "Top-left"
        case .topRight: return "Top-right"
        case .bottomLeft: return "Bottom-left"
        case .bottomRight: return "Bottom-right"
        }
    }

    public var systemImage: String {
        switch self {
        case .topLeft: return "arrow.up.left.square"
        case .topRight: return "arrow.up.right.square"
        case .bottomLeft: return "arrow.down.left.square"
        case .bottomRight: return "arrow.down.right.square"
        }
    }
}

public enum FringeCornerAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "Disabled"
    case mute = "Mute"
    case screenshot = "Screenshots"
    case playPause = "Play / Pause"
    case lockScreen = "Lock Screen"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: return "Off"
        case .mute: return "Mute volume"
        case .screenshot: return "Screenshots"
        case .playPause: return "Play / Pause"
        case .lockScreen: return "Lock Screen"
        }
    }

    public var shortLabel: String {
        switch self {
        case .none: return "Off"
        case .mute: return "Mute"
        case .screenshot: return "Screenshots"
        case .playPause: return "Play / Pause"
        case .lockScreen: return "Lock"
        }
    }

    public var systemImage: String {
        switch self {
        case .none: return "slash.circle"
        case .mute: return "speaker.slash.fill"
        case .screenshot: return "camera.viewfinder"
        case .playPause: return "playpause.fill"
        case .lockScreen: return "lock.fill"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw.lowercased() {
        case "mute", "mute volume", "mute mac":
            self = .mute
        case "screenshots", "screenshot", "screenshot toolbar", "screenshot toolbar (⌘⇧5)":
            self = .screenshot
        case "play / pause", "playpause", "play/pause", "media":
            self = .playPause
        case "lock screen", "lock", "lock mac", "screen lock":
            self = .lockScreen
        case "disabled", "none", "off":
            self = .none
        default:
            self = FringeCornerAction(rawValue: raw) ?? .none
        }
    }
}

public enum FringeAction: String, CaseIterable, Identifiable, Codable, Sendable {
    case volume = "Volume"
    case brightness = "Display brightness"
    case keyboardBrightness = "Keyboard backlight"
    case media = "Skip tracks"
    case none = "Disabled"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Display brightness"
        case .keyboardBrightness: return "Keyboard backlight"
        case .media: return "Skip tracks"
        case .none: return "Off"
        }
    }

    public var systemImage: String {
        switch self {
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.max.fill"
        case .keyboardBrightness: return "light.max"
        case .media: return "forward.end.fill"
        case .none: return "slash.circle"
        }
    }

    public var shortLabel: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .keyboardBrightness: return "Keyboard"
        case .media: return "Skip"
        case .none: return "Off"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw.lowercased() {
        case "volume":
            self = .volume
        case "display brightness", "brightness":
            self = .brightness
        case "keyboard backlight", "keyboard light", "keyboard":
            self = .keyboardBrightness
        case "skip tracks", "skip", "tracks", "media", "music", "play/pause":
            self = .media
        case "disabled", "none", "off":
            self = .none
        default:
            self = FringeAction(rawValue: raw) ?? .none
        }
    }
}

public enum ModifierGuard: String, CaseIterable, Identifiable, Codable, Sendable {
    case none = "Direct drag"
    case fn = "Fn (Globe) key"
    case option = "Option (⌥) key"
    case control = "Control (⌃) key"
    case command = "Command (⌘) key"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .none: return "hand.draw"
        case .fn: return "globe"
        case .option: return "option"
        case .control: return "control"
        case .command: return "command"
        }
    }

    public var label: String {
        switch self {
        case .none: return "No key"
        case .fn: return "Fn (Globe)"
        case .option: return "Option (⌥)"
        case .control: return "Control (⌃)"
        case .command: return "Command (⌘)"
        }
    }

    public func matches(flags: NSEvent.ModifierFlags) -> Bool {
        switch self {
        case .none:
            return true
        case .fn:
            return flags.contains(.function)
        case .option:
            return flags.contains(.option)
        case .control:
            return flags.contains(.control)
        case .command:
            return flags.contains(.command)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw.lowercased() {
        case "none (direct edge drag)", "direct", "direct drag", "no key":
            self = .none
        case "fn (globe) key", "fn (globe)", "fn key", "fn":
            self = .fn
        case "option (⌥) key", "option (⌥)", "option key", "option":
            self = .option
        case "control (⌃) key", "control (⌃)", "control key", "control":
            self = .control
        case "command (⌘) key", "command (⌘)", "command key", "command":
            self = .command
        default:
            self = ModifierGuard(rawValue: raw) ?? .none
        }
    }
}

public struct FringeSettings: Codable, Equatable, Sendable {
    /// The edge zone's width the gesture accepts, as a fraction of the trackpad (2 to 8%, default 4%).
    public static let edgeMarginRange: ClosedRange<Double> = 0.02...0.08
    /// The start zone size along the edge from each corner (15 to 50%, default 33%).
    public static let startZoneRange: ClosedRange<Double> = 0.15...0.50
    /// Trackpad travel for one step, as a fraction of the trackpad (2 to 8%, default 4%).
    public static let stepDistanceRange: ClosedRange<Double> = 0.02...0.08

    public var isEnabled: Bool = true
    public var leftAction: FringeAction = .volume
    public var rightAction: FringeAction = .brightness
    public var topAction: FringeAction = .keyboardBrightness
    public var bottomAction: FringeAction = .none

    /// Actions triggered by double-tapping the trackpad corners.
    public var topLeftCornerAction: FringeCornerAction = .screenshot
    public var topRightCornerAction: FringeCornerAction = .mute
    public var bottomLeftCornerAction: FringeCornerAction = .none
    public var bottomRightCornerAction: FringeCornerAction = .none

    /// Edge zone width as a fraction of the trackpad (2 to 8%, default 4%).
    public var edgeMarginFraction: Double = 0.04

    /// The start zone along the edge from each corner (15 to 50%, default 33%).
    public var startZoneFraction: Double = 0.33

    /// Trackpad travel for one step (2 to 8%, default 4%).
    public var stepDistance: Double = 0.04

    /// A key that must be held for a drag to count.
    public var modifierGuard: ModifierGuard = .none

    /// A click from the Force Touch trackpad on every step.
    public var hapticFeedbackEnabled: Bool = true

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FringeSettings()
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? defaults.isEnabled
        leftAction = try container.decodeIfPresent(FringeAction.self, forKey: .leftAction) ?? defaults.leftAction
        rightAction = try container.decodeIfPresent(FringeAction.self, forKey: .rightAction) ?? defaults.rightAction
        topAction = try container.decodeIfPresent(FringeAction.self, forKey: .topAction) ?? defaults.topAction
        bottomAction = try container.decodeIfPresent(FringeAction.self, forKey: .bottomAction) ?? defaults.bottomAction
        topLeftCornerAction = try container.decodeIfPresent(FringeCornerAction.self, forKey: .topLeftCornerAction) ?? defaults.topLeftCornerAction
        topRightCornerAction = try container.decodeIfPresent(FringeCornerAction.self, forKey: .topRightCornerAction) ?? defaults.topRightCornerAction
        bottomLeftCornerAction = try container.decodeIfPresent(FringeCornerAction.self, forKey: .bottomLeftCornerAction) ?? defaults.bottomLeftCornerAction
        bottomRightCornerAction = try container.decodeIfPresent(FringeCornerAction.self, forKey: .bottomRightCornerAction) ?? defaults.bottomRightCornerAction
        edgeMarginFraction = try container.decodeIfPresent(Double.self, forKey: .edgeMarginFraction) ?? defaults.edgeMarginFraction
        startZoneFraction = try container.decodeIfPresent(Double.self, forKey: .startZoneFraction) ?? defaults.startZoneFraction
        stepDistance = try container.decodeIfPresent(Double.self, forKey: .stepDistance) ?? defaults.stepDistance
        modifierGuard = try container.decodeIfPresent(ModifierGuard.self, forKey: .modifierGuard) ?? defaults.modifierGuard
        hapticFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticFeedbackEnabled) ?? defaults.hapticFeedbackEnabled
    }

    /// The action an edge is set to.
    public func action(for edge: FringeEdge) -> FringeAction {
        switch edge {
        case .left: return leftAction
        case .right: return rightAction
        case .top: return topAction
        case .bottom: return bottomAction
        }
    }

    /// Enforces that each active action is unique to at most one edge.
    /// If an edge is assigned an action already assigned elsewhere, the previous edge is set to `.none`.
    public mutating func setAction(_ action: FringeAction, for edge: FringeEdge) {
        if action != .none {
            if edge != .left && leftAction == action {
                leftAction = .none
            }
            if edge != .right && rightAction == action {
                rightAction = .none
            }
            if edge != .top && topAction == action {
                topAction = .none
            }
            if edge != .bottom && bottomAction == action {
                bottomAction = .none
            }
        }

        switch edge {
        case .left: leftAction = action
        case .right: rightAction = action
        case .top: topAction = action
        case .bottom: bottomAction = action
        }
    }

    /// The action a corner is set to.
    public func action(for corner: FringeCorner) -> FringeCornerAction {
        switch corner {
        case .topLeft: return topLeftCornerAction
        case .topRight: return topRightCornerAction
        case .bottomLeft: return bottomLeftCornerAction
        case .bottomRight: return bottomRightCornerAction
        }
    }

    public mutating func setAction(_ action: FringeCornerAction, for corner: FringeCorner) {
        switch corner {
        case .topLeft: topLeftCornerAction = action
        case .topRight: topRightCornerAction = action
        case .bottomLeft: bottomLeftCornerAction = action
        case .bottomRight: bottomRightCornerAction = action
        }
    }
}

public struct FringeLiveState: Equatable, Sendable {
    public var isEngaged: Bool = false
    public var activeEdge: FringeEdge? = nil
    public var activeAction: FringeAction = .none

    public init() {}
}
