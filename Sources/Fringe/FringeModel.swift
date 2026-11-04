//
//  FringeModel.swift
//  Fringe
//

import AppKit
import Foundation
import SwiftUI

public enum FringeEdge: String, CaseIterable, Identifiable, Codable {
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
}

public enum FringeAction: String, CaseIterable, Identifiable, Codable {
    case volume = "Volume"
    case brightness = "Display brightness"
    case keyboardBrightness = "Keyboard backlight"
    case none = "Disabled"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Display brightness"
        case .keyboardBrightness: return "Keyboard backlight"
        case .none: return "Disabled"
        }
    }

    public var systemImage: String {
        switch self {
        case .volume: return "speaker.wave.2.fill"
        case .brightness: return "sun.max.fill"
        case .keyboardBrightness: return "light.max"
        case .none: return "slash.circle"
        }
    }

    public var shortLabel: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .keyboardBrightness: return "Keyboard"
        case .none: return "Disabled"
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
        case "disabled", "none":
            self = .none
        default:
            self = FringeAction(rawValue: raw) ?? .none
        }
    }
}

public enum ModifierGuard: String, CaseIterable, Identifiable, Codable {
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
        case .none: return "Direct drag"
        case .fn: return "Fn (Globe) key"
        case .option: return "Option (⌥) key"
        case .control: return "Control (⌃) key"
        case .command: return "Command (⌘) key"
        }
    }

    public var displayBadge: String {
        switch self {
        case .none: return "Direct drag"
        case .fn: return "🌐 fn"
        case .option: return "⌥ Option"
        case .control: return "⌃ Control"
        case .command: return "⌘ Command"
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
        case "none (direct edge drag)", "direct", "direct drag":
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

public struct FringeSettings: Codable, Equatable {
    public var isEnabled: Bool = true
    public var leftAction: FringeAction = .volume
    public var rightAction: FringeAction = .brightness
    public var topAction: FringeAction = .keyboardBrightness
    public var bottomAction: FringeAction = .none

    /// Extreme edge boundary width as a fraction (0.02 ... 0.08, default 0.04 / 4%)
    public var edgeMarginFraction: Double = 0.04

    /// Trackpad travel distance required for 1 media notch step (0.02 ... 0.08, default 0.04 / 4%)
    public var stepDistance: Double = 0.04

    /// Key guard required to engage fringe gestures
    public var modifierGuard: ModifierGuard = .none

    /// Haptic click feedback on adjustments
    public var hapticFeedbackEnabled: Bool = true

    public init() {}

    /// Enforces that each active action is unique to at most one edge.
    /// If an edge is assigned an action already assigned elsewhere, the previous edge is swapped or set to `.none`.
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
}

public struct FringeLiveState {
    public var isEngaged: Bool = false
    public var activeEdge: FringeEdge? = nil
    public var activeAction: FringeAction = .none

    public init() {}
}
