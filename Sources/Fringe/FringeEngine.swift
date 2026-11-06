//
//  FringeEngine.swift
//  Fringe
//

import AppKit
import Combine
import CoreGraphics
import DroppyKit
import Foundation
import SwiftUI

/// Settings, live state and the edge listener's lifetime. The listener runs
/// only while gestures are on (`FringeEdgeTap`).
@MainActor
public final class FringeEngine: ObservableObject {
    private static let preferencesKey = "settings"

    @Published public var settings: FringeSettings = FringeSettings() {
        didSet {
            guard settings != oldValue else { return }
            saveSettings()
            applySettings()
        }
    }

    @Published public private(set) var state: FringeLiveState = FringeLiveState()
    @Published public private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    @Published public private(set) var isListening: Bool = false

    public private(set) var host: DropletHost?
    private var tap: FringeEdgeTap?
    private var isLoadingSettings = false
    private var retryTimer: Timer?

    public var shortcutLabel: String {
        if let shortcut = host?.shortcuts.currentShortcut(id: FringeDroplet.toggleShortcutID) {
            return shortcut.displayString
        }
        return "Set up"
    }

    public init() {}

    public func start(with host: DropletHost?) {
        self.host = host
        FringeLog.info("FringeEngine starting")
        host?.log.info("FringeEngine starting")
        loadSettings()
        refreshAccessibilityStatus()
        applySettings()
    }

    public func stop() {
        FringeLog.info("FringeEngine stopping")
        host?.log.info("FringeEngine stopping")
        stopRetryTimer()
        stopListening()
        host = nil
    }

    // MARK: - Persistence

    /// Fringe's own keys in Droppy's preferences (`host.preferences`), never
    /// `UserDefaults.standard`, which inside Droppy is Droppy's own settings.
    private func loadSettings() {
        guard let preferences = host?.preferences,
              let stored = preferences.value(forKey: Self.preferencesKey, as: FringeSettings.self) else { return }
        isLoadingSettings = true
        settings = stored
        isLoadingSettings = false
    }

    private func saveSettings() {
        guard !isLoadingSettings, let preferences = host?.preferences else { return }
        preferences.setValue(settings, forKey: Self.preferencesKey)
    }

    // MARK: - Listener

    private func applySettings() {
        guard host != nil else { return }
        guard settings.isEnabled else {
            stopListening()
            stopRetryTimer()
            return
        }

        let granted = AXIsProcessTrusted()
        isAccessibilityGranted = granted
        if !granted {
            stopListening()
            startRetryTimer()
            return
        }

        stopRetryTimer()

        let config = FringeGestureConfig(settings: settings)
        if let tap {
            tap.update(config)
            isListening = tap.isRunning
            return
        }

        let tap = FringeEdgeTap(config: config) { [weak self] effect in
            self?.apply(effect)
        }
        self.tap = tap
        tap.start()
        isListening = tap.isRunning

        if !isListening {
            startRetryTimer()
        }
    }

    private func stopListening() {
        tap?.stop()
        tap = nil
        isListening = false
        if state != FringeLiveState() {
            state = FringeLiveState()
        }
    }

    // MARK: - Accessibility Retry

    private func startRetryTimer() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkAccessibilityAndRetry()
            }
        }
    }

    private func stopRetryTimer() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    private func checkAccessibilityAndRetry() {
        guard settings.isEnabled else {
            stopRetryTimer()
            return
        }
        let granted = AXIsProcessTrusted()
        if granted != isAccessibilityGranted {
            isAccessibilityGranted = granted
            if granted {
                FringeLog.info("Fringe: Accessibility granted, starting listener")
                host?.log.info("Fringe: Accessibility granted, starting listener")
                applySettings()
            }
        } else if granted && !isListening {
            applySettings()
        }
    }

    public func refreshAccessibilityStatus() {
        isAccessibilityGranted = AXIsProcessTrusted()
        if isAccessibilityGranted && settings.isEnabled && !isListening {
            applySettings()
        }
    }

    public func openAccessibilitySettings() {
        let script = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: script) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Gestures

    private func apply(_ effect: FringeGestureEffect) {
        switch effect {
        case let .engaged(edge, action):
            state.isEngaged = true
            state.activeEdge = edge
            state.activeAction = action
        case .disengaged:
            state.isEngaged = false
            state.activeEdge = nil
            state.activeAction = .none
        case .stepped, .cornerTriggered:
            guard settings.hapticFeedbackEnabled else { return }
            // .levelChange is the firm click macOS uses between pressure levels.
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
    }
}

// MARK: - The listener

/// What the listener reads: a copy of the settings it needs.
struct FringeGestureConfig: Sendable, Equatable {
    var leftAction: FringeAction
    var rightAction: FringeAction
    var topAction: FringeAction
    var bottomAction: FringeAction
    var topLeftCornerAction: FringeCornerAction
    var topRightCornerAction: FringeCornerAction
    var bottomLeftCornerAction: FringeCornerAction
    var bottomRightCornerAction: FringeCornerAction
    var margin: CGFloat
    var startZoneFraction: CGFloat
    var stepDistance: CGFloat
    var modifierGuard: ModifierGuard

    init(settings: FringeSettings) {
        leftAction = settings.leftAction
        rightAction = settings.rightAction
        topAction = settings.topAction
        bottomAction = settings.bottomAction
        topLeftCornerAction = settings.topLeftCornerAction
        topRightCornerAction = settings.topRightCornerAction
        bottomLeftCornerAction = settings.bottomLeftCornerAction
        bottomRightCornerAction = settings.bottomRightCornerAction
        margin = CGFloat(min(max(settings.edgeMarginFraction, FringeSettings.edgeMarginRange.lowerBound),
                             FringeSettings.edgeMarginRange.upperBound))
        startZoneFraction = CGFloat(min(max(settings.startZoneFraction, FringeSettings.startZoneRange.lowerBound),
                                        FringeSettings.startZoneRange.upperBound))
        stepDistance = CGFloat(min(max(settings.stepDistance, FringeSettings.stepDistanceRange.lowerBound),
                                   FringeSettings.stepDistanceRange.upperBound))
        modifierGuard = settings.modifierGuard
    }

    func action(for edge: FringeEdge) -> FringeAction {
        switch edge {
        case .left: return leftAction
        case .right: return rightAction
        case .top: return topAction
        case .bottom: return bottomAction
        }
    }

    func action(for corner: FringeCorner) -> FringeCornerAction {
        switch corner {
        case .topLeft: return topLeftCornerAction
        case .topRight: return topRightCornerAction
        case .bottomLeft: return bottomLeftCornerAction
        case .bottomRight: return bottomRightCornerAction
        }
    }
}

enum FringeGestureEffect: Sendable {
    case engaged(FringeEdge, FringeAction)
    case disengaged
    case stepped(FringeAction, increase: Bool)
    case cornerTriggered(FringeCorner, FringeCornerAction)
}

/// A listen-only tap on trackpad gesture events, on the main run loop, as
/// Fringe 1.0.1 had it. AppKit has to see these events on the main thread:
/// `NSEvent(cgEvent:)` asks the Text Services Manager for the input source,
/// which asserts the main queue, and on a thread of its own (1.0.2) that
/// assertion crashed Droppy. A listen-only tap never holds an event back, so
/// the main thread being busy delays only Fringe, not the user's input. The
/// callback does as little as it can: read the touches, step the tracker,
/// post a key when a step lands. Every member is used on the main thread
/// only.
@MainActor
final class FringeEdgeTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var config: FringeGestureConfig
    private var tracker = FringeGestureTracker()
    private let onEffect: (FringeGestureEffect) -> Void

    var isRunning: Bool { tap != nil }

    init(config: FringeGestureConfig, onEffect: @escaping (FringeGestureEffect) -> Void) {
        self.config = config
        self.onEffect = onEffect
    }

    func update(_ config: FringeGestureConfig) {
        self.config = config
    }

    func start() {
        guard tap == nil else { return }
        // droppykit-lint: allow event-tap: Fringe's one input, a listen-only tap on trackpad gesture events (never keys); it never alters or drops an event, and it runs only while gestures are on
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: NSEvent.EventTypeMask.gesture.rawValue,
            callback: { _, type, event, info in
                // The source is on the main run loop, so this is the main thread.
                guard let info else { return Unmanaged.passUnretained(event) }
                MainActor.assumeIsolated {
                    Unmanaged<FringeEdgeTap>.fromOpaque(info).takeUnretainedValue().handle(type, event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            FringeLog.warning("Fringe: the trackpad listener could not start; Droppy needs Accessibility")
            return
        }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            CFRunLoopSourceInvalidate(source)
        }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
        tracker = FringeGestureTracker()
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard tap != nil,
              type.rawValue == NSEvent.EventType.gesture.rawValue,
              let nsEvent = NSEvent(cgEvent: event) else { return }

        let touches = nsEvent.allTouches()
            .filter { $0.type == .indirect }
            .map {
                FringeTouch(
                    key: $0.identity.hash,
                    phase: $0.phase,
                    isResting: $0.isResting,
                    position: $0.normalizedPosition,
                    deviceSize: $0.deviceSize
                )
            }
        guard !touches.isEmpty else { return }

        let flags = NSEvent.ModifierFlags(rawValue: UInt(CGEventSource.flagsState(.combinedSessionState).rawValue))
        for effect in tracker.handle(touches, flags: flags, config: config) {
            switch effect {
            case let .stepped(action, increase):
                FringeMediaKeys.step(action, increase: increase)
            case let .cornerTriggered(_, cornerAction):
                FringeMediaKeys.performCornerAction(cornerAction)
            default:
                break
            }
            onEffect(effect)
        }
    }

    // The tap holds this object unretained; the engine owns it and stops it
    // before letting it go.
}

struct FringeTouch {
    let key: Int
    let phase: NSTouch.Phase
    let isResting: Bool
    let position: CGPoint
    /// The trackpad's size in points; zero when it does not say.
    let deviceSize: CGSize
}

/// One-finger drags that start on the trackpad's very edge, as well as corner
/// double-taps.
///
/// A corner that two enabled edges share (top left: the left and top edges;
/// bottom left and bottom right: a side edge and the bottom edge) is not
/// decided at touch-down. The finger's first movement decides it: mostly up
/// or down is the side edge, mostly sideways the top or bottom edge, and the
/// first step counts from where the finger landed.
struct FringeGestureTracker {
    /// How far a finger in a shared corner moves before its edge is picked,
    /// as a fraction of the trackpad's height (about 2 mm): past the jitter
    /// of a landing finger, and no more than the shortest step.
    static let cornerDecisionDistance: CGFloat = 0.02

    /// Maximum duration of a tap in seconds.
    static let maxTapDuration: TimeInterval = 0.35
    /// Maximum displacement for a tap (as fraction of trackpad).
    static let maxTapDisplacement: CGFloat = 0.035
    /// Maximum time interval between two taps to register as a double tap.
    static let doubleTapInterval: TimeInterval = 0.45
    /// Corner zone dimension from trackpad edge.
    static let cornerZoneSize: CGFloat = 0.12

    private struct TapCandidate {
        let touchKey: Int
        let startPos: CGPoint
        let startTime: TimeInterval
        let corner: FringeCorner?
        var maxDisplacement: CGFloat = 0
    }

    private struct CornerTapRecord {
        let corner: FringeCorner
        let timestamp: TimeInterval
        let pos: CGPoint
    }

    private var seenTouches: Set<Int> = []
    private var disqualifiedTouches: Set<Int> = []
    private var trackedTouchKey: Int?
    private var trackedEdge: FringeEdge?
    private var trackedAction: FringeAction = .none
    private var lastPos: CGFloat = 0
    private var accumulatedDelta: CGFloat = 0

    private var activeTapCandidate: TapCandidate?
    private var lastCornerTap: CornerTapRecord?
    private var didStepDuringGesture: Bool = false
    private var hasSkippedTrackDuringSwipe: Bool = false

    /// A touch that landed in a shared corner and has not moved far enough
    /// to say which edge it means, the edges it can still start and where it
    /// landed.
    private var pendingTouchKey: Int?
    private var pendingEdges: [FringeEdge] = []
    private var pendingStart: CGPoint = .zero

    private var isEngaged: Bool { trackedTouchKey != nil }

    mutating func handle(
        _ rawTouches: [FringeTouch],
        flags: NSEvent.ModifierFlags,
        config: FringeGestureConfig
    ) -> [FringeGestureEffect] {
        var effects: [FringeGestureEffect] = []

        // Touches that lifted or cancelled this event.
        for touch in rawTouches where touch.phase == .ended || touch.phase == .cancelled {
            seenTouches.remove(touch.key)
            disqualifiedTouches.remove(touch.key)

            if touch.phase == .ended, let candidate = activeTapCandidate, candidate.touchKey == touch.key {
                let now = ProcessInfo.processInfo.systemUptime
                let duration = now - candidate.startTime
                let totalDisp = hypot(touch.position.x - candidate.startPos.x, touch.position.y - candidate.startPos.y)
                let maxDisp = max(candidate.maxDisplacement, totalDisp)

                if duration <= Self.maxTapDuration && maxDisp <= Self.maxTapDisplacement && !didStepDuringGesture {
                    // Valid tap in a corner
                    if let corner = candidate.corner, config.action(for: corner) != .none {
                        if let prev = lastCornerTap,
                           prev.corner == corner,
                           (now - prev.timestamp) <= Self.doubleTapInterval,
                           hypot(candidate.startPos.x - prev.pos.x, candidate.startPos.y - prev.pos.y) <= 0.08 {
                            // Double-tap in corner!
                            let action = config.action(for: corner)
                            effects.append(.cornerTriggered(corner, action))
                            lastCornerTap = nil
                        } else {
                            lastCornerTap = CornerTapRecord(corner: corner, timestamp: now, pos: candidate.startPos)
                        }
                    }
                }
                activeTapCandidate = nil
            }

            if touch.key == pendingTouchKey {
                clearPending()
            }
            if touch.key == trackedTouchKey {
                endGesture(&effects)
            }
        }

        // Touches still on the trackpad.
        let surfaceTouches = rawTouches.filter { $0.phase != .ended && $0.phase != .cancelled }

        // Every finger lifted: end cleanly and forget every touch.
        if surfaceTouches.isEmpty {
            endGesture(&effects)
            seenTouches.removeAll()
            disqualifiedTouches.removeAll()
            activeTapCandidate = nil
            return effects
        }

        // A resting palm or a second finger is never an edge drag: stop, and
        // never let any of these touches start one. If already engaged with a single
        // finger, don't prematurely kill it if macOS trackpad firmware flags perimeter
        // resting state on that moving contact.
        if surfaceTouches.count > 1 || (!isEngaged && surfaceTouches.contains(where: { $0.isResting })) {
            endGesture(&effects)
            activeTapCandidate = nil
            for touch in surfaceTouches {
                disqualifiedTouches.insert(touch.key)
            }
            return effects
        }

        // The key the user asked to hold, if any.
        guard config.modifierGuard.matches(flags: flags) else {
            endGesture(&effects)
            activeTapCandidate = nil
            return effects
        }

        let margin = config.margin

        // Tap candidate tracking for a single touch in any corner.
        if let touch = surfaceTouches.first {
            let now = ProcessInfo.processInfo.systemUptime
            if activeTapCandidate == nil && !seenTouches.contains(touch.key) {
                let corner = Self.corner(at: touch.position)
                if corner != nil {
                    activeTapCandidate = TapCandidate(
                        touchKey: touch.key,
                        startPos: touch.position,
                        startTime: now,
                        corner: corner,
                        maxDisplacement: 0
                    )
                }
            } else if var candidate = activeTapCandidate, candidate.touchKey == touch.key {
                let disp = hypot(touch.position.x - candidate.startPos.x, touch.position.y - candidate.startPos.y)
                candidate.maxDisplacement = max(candidate.maxDisplacement, disp)
                if candidate.maxDisplacement > Self.maxTapDisplacement * 1.5 {
                    activeTapCandidate = nil
                } else {
                    activeTapCandidate = candidate
                }
            }
        }

        // Not dragging yet: this touch may start a drag. One picked in a
        // shared corner steps right below, counted from where the finger
        // landed, so no travel is lost to the decision; one that engaged at
        // touch-down has travelled nothing yet and steps nothing.
        if !isEngaged, let touch = surfaceTouches.first {
            beginIfAtStartZone(touch, config: config, effects: &effects)
        }

        if isEngaged {
            guard let touch = surfaceTouches.first,
                  touch.key == trackedTouchKey,
                  let edge = trackedEdge,
                  trackedAction != .none else {
                endGesture(&effects)
                return effects
            }

            let pos = touch.position

            // Wandering into the middle of the trackpad ends the drag.
            // Horizontal edges (top and bottom) allow extra displacement to
            // accommodate the hand's natural wrist arc when sliding horizontally.
            let maxInwardDisplacement = max(margin * 2.5, 0.12)
            let maxInwardHorizontalDisplacement = max(margin * 3.5, 0.18)
            let hasWanderedIntoCenter: Bool
            switch edge {
            case .left:
                hasWanderedIntoCenter = pos.x > maxInwardDisplacement
            case .right:
                hasWanderedIntoCenter = pos.x < (1.0 - maxInwardDisplacement)
            case .top:
                hasWanderedIntoCenter = pos.y < (1.0 - maxInwardHorizontalDisplacement)
            case .bottom:
                hasWanderedIntoCenter = pos.y > maxInwardHorizontalDisplacement
            }
            if hasWanderedIntoCenter {
                endGesture(&effects)
                return effects
            }

            // Up raises on the side edges, right raises on the top and bottom.
            let currentPos: CGFloat
            switch edge {
            case .left, .right: currentPos = pos.y
            case .top, .bottom: currentPos = pos.x
            }

            accumulatedDelta += currentPos - lastPos
            lastPos = currentPos

            let stepDist = config.stepDistance
            if accumulatedDelta >= stepDist {
                let steps = Int(accumulatedDelta / stepDist)
                accumulatedDelta -= CGFloat(steps) * stepDist
                if trackedAction == .media {
                    if !hasSkippedTrackDuringSwipe {
                        effects.append(.stepped(.media, increase: true))
                        hasSkippedTrackDuringSwipe = true
                        didStepDuringGesture = true
                    }
                } else {
                    for _ in 0..<min(4, steps) {
                        effects.append(.stepped(trackedAction, increase: true))
                    }
                    didStepDuringGesture = true
                }
            } else if accumulatedDelta <= -stepDist {
                let steps = Int((-accumulatedDelta) / stepDist)
                accumulatedDelta += CGFloat(steps) * stepDist
                if trackedAction == .media {
                    if !hasSkippedTrackDuringSwipe {
                        effects.append(.stepped(.media, increase: false))
                        hasSkippedTrackDuringSwipe = true
                        didStepDuringGesture = true
                    }
                } else {
                    for _ in 0..<min(4, steps) {
                        effects.append(.stepped(trackedAction, increase: false))
                    }
                    didStepDuringGesture = true
                }
            }
            return effects
        }
        return effects
    }

    /// Corner region check for double-tap gestures.
    static func corner(at pos: CGPoint) -> FringeCorner? {
        let size = cornerZoneSize
        let isLeft = pos.x <= size
        let isRight = pos.x >= (1.0 - size)
        let isBottom = pos.y <= size
        let isTop = pos.y >= (1.0 - size)

        if isTop && isLeft { return .topLeft }
        if isTop && isRight { return .topRight }
        if isBottom && isLeft { return .bottomLeft }
        if isBottom && isRight { return .bottomRight }
        return nil
    }

    /// A drag starts only on an enabled edge's own start zone: the outer start zones
    /// of the side and bottom edges, or the top edge's left start zone and its
    /// middle-right stretch (leaving the top right corner to Notification Center).
    /// A touch that lands anywhere else never starts one. In a corner two enabled
    /// edges share, the touch waits until its first movement says which edge
    /// it means.
    private mutating func beginIfAtStartZone(_ touch: FringeTouch, config: FringeGestureConfig, effects: inout [FringeGestureEffect]) {
        let margin = config.margin
        let startMargin = max(margin, 0.055)
        let startZone = config.startZoneFraction
        let pos = touch.position
        let touchKey = touch.key

        if !seenTouches.contains(touchKey) {
            seenTouches.insert(touchKey)
            let isAtLeftEdgeOrigin = (pos.x <= startMargin) && ((pos.y <= startZone) || (pos.y >= 1.0 - startZone))
            let isAtRightEdgeOrigin = (pos.x >= 1.0 - startMargin) && ((pos.y <= startZone) || (pos.y >= 1.0 - startZone))
            let isAtTopEdgeOrigin = (pos.y >= 1.0 - startMargin) && ((pos.x <= startZone) || (pos.x >= max(0.50, 1.0 - startZone - 0.15) && pos.x <= 0.85))
            let isAtBottomEdgeOrigin = (pos.y <= startMargin) && ((pos.x <= startZone) || (pos.x >= 1.0 - startZone))
            if !isAtLeftEdgeOrigin && !isAtRightEdgeOrigin && !isAtTopEdgeOrigin && !isAtBottomEdgeOrigin {
                disqualifiedTouches.insert(touchKey)
            }
        }
        guard !disqualifiedTouches.contains(touchKey) else { return }

        // Waiting in a shared corner: engage once the finger has moved far
        // enough to pick an edge, counting from where it landed.
        if pendingTouchKey == touchKey {
            let edges = pendingEdges.filter { config.action(for: $0) != .none }
            guard !edges.isEmpty else {
                // Both edges were turned off under the finger: look again.
                clearPending()
                return
            }
            guard let edge = Self.cornerEdge(of: edges, from: pendingStart, to: touch) else { return }
            let start = pendingStart
            clearPending()
            engage(edge, action: config.action(for: edge), touchKey: touchKey, from: start, effects: &effects)
            return
        }
        clearPending()

        let edges = Self.startEdges(at: pos, config: config)
        if edges.count > 1 {
            pendingTouchKey = touchKey
            pendingEdges = edges
            pendingStart = pos
        } else if let edge = edges.first {
            engage(edge, action: config.action(for: edge), touchKey: touchKey, from: pos, effects: &effects)
        }
    }

    /// The enabled edges whose start zone holds this point. There are two
    /// only in a corner a side edge shares with the top or bottom edge.
    private static func startEdges(at pos: CGPoint, config: FringeGestureConfig) -> [FringeEdge] {
        let margin = config.margin
        let startZone = config.startZoneFraction
        var edges: [FringeEdge] = []

        // Top edge: from the left start zone rightward, or from the right zone
        // leftward (leaving the top right corner to Notification Center).
        if config.topAction != .none {
            let isAtTopEdge = pos.y >= (1.0 - margin)
            let isAtLeftOrigin = pos.x <= startZone
            let isAtRightOrigin = pos.x >= max(0.50, 1.0 - startZone - 0.15) && pos.x <= 0.85
            if isAtTopEdge && (isAtLeftOrigin || isAtRightOrigin) {
                edges.append(.top)
            }
        }

        // Left edge: from its bottom start zone up, or its top start zone down.
        if config.leftAction != .none {
            let isAtLeftEdge = pos.x <= margin
            let isAtOrigin = (pos.y <= startZone) || (pos.y >= 1.0 - startZone)
            if isAtLeftEdge && isAtOrigin {
                edges.append(.left)
            }
        }

        // Right edge: the same, on the right.
        if config.rightAction != .none {
            let isAtRightEdge = pos.x >= (1.0 - margin)
            let isAtOrigin = (pos.y <= startZone) || (pos.y >= 1.0 - startZone)
            if isAtRightEdge && isAtOrigin {
                edges.append(.right)
            }
        }

        // Bottom edge, when one is set: from its left start zone rightward, or its
        // right start zone leftward. We allow up to max(margin, 0.055) vertically
        // so real thumb/finger pads touching along the bottom rim start reliably.
        if config.bottomAction != .none {
            let isAtBottomEdge = pos.y <= max(margin, 0.055)
            let isAtOrigin = (pos.x <= startZone) || (pos.x >= 1.0 - startZone)
            if isAtBottomEdge && isAtOrigin {
                edges.append(.bottom)
            }
        }

        return edges
    }

    /// The edge a finger in a shared corner means, once it is
    /// `cornerDecisionDistance` from where it landed: mostly up or down is
    /// the side edge, mostly sideways the top or bottom edge. Movement is measured
    /// in the trackpad's own proportions when it reports its size, so a 45 degree
    /// drag on a wide trackpad reads as the diagonal it is. Nil while the finger is closer.
    private static func cornerEdge(of edges: [FringeEdge], from start: CGPoint, to touch: FringeTouch) -> FringeEdge? {
        let size = touch.deviceSize
        let aspect = size.width > 0 && size.height > 0 ? size.width / size.height : 1
        let dx = (touch.position.x - start.x) * aspect
        let dy = touch.position.y - start.y
        guard hypot(dx, dy) >= cornerDecisionDistance else { return nil }
        let isMostlyVertical = abs(dy) > abs(dx)
        return edges.first { $0.tracksVerticalMovement == isMostlyVertical } ?? edges.first
    }

    private mutating func engage(_ edge: FringeEdge, action: FringeAction, touchKey: Int, from start: CGPoint, effects: inout [FringeGestureEffect]) {
        trackedTouchKey = touchKey
        trackedEdge = edge
        trackedAction = action
        switch edge {
        case .left, .right: lastPos = start.y
        case .top, .bottom: lastPos = start.x
        }
        accumulatedDelta = 0
        didStepDuringGesture = false
        hasSkippedTrackDuringSwipe = false
        effects.append(.engaged(edge, action))
    }

    private mutating func clearPending() {
        pendingTouchKey = nil
        pendingEdges = []
    }

    private mutating func endGesture(_ effects: inout [FringeGestureEffect]) {
        if isEngaged {
            effects.append(.disengaged)
        }
        trackedTouchKey = nil
        trackedEdge = nil
        trackedAction = .none
        accumulatedDelta = 0
        didStepDuringGesture = false
        hasSkippedTrackDuringSwipe = false
        clearPending()
    }
}

private extension FringeEdge {
    /// The left and right edges follow the finger up and down.
    var tracksVerticalMovement: Bool {
        switch self {
        case .left, .right: return true
        case .top, .bottom: return false
        }
    }
}

/// The hardware media keys, posted the way a keyboard's volume, media and
/// brightness keys arrive, so macOS changes the level and Droppy shows its
/// own HUD for it.
enum FringeMediaKeys {
    // NX_KEYTYPE_SOUND_UP / _DOWN, NX_KEYTYPE_BRIGHTNESS_UP / _DOWN,
    // NX_KEYTYPE_MUTE, NX_KEYTYPE_PLAY, NX_KEYTYPE_FAST, NX_KEYTYPE_REWIND,
    // NX_KEYTYPE_ILLUMINATION_UP / _DOWN (IOKit's ev_keymap.h).
    private static let soundUp: Int32 = 0
    private static let soundDown: Int32 = 1
    private static let brightnessUp: Int32 = 2
    private static let brightnessDown: Int32 = 3
    private static let muteKey: Int32 = 7
    private static let playKey: Int32 = 16
    private static let fastKey: Int32 = 19
    private static let rewindKey: Int32 = 20
    private static let illuminationUp: Int32 = 21
    private static let illuminationDown: Int32 = 22

    static func step(_ action: FringeAction, increase: Bool) {
        switch action {
        case .volume:
            post(increase ? soundUp : soundDown)
        case .brightness:
            post(increase ? brightnessUp : brightnessDown)
        case .keyboardBrightness:
            post(increase ? illuminationUp : illuminationDown)
        case .media:
            post(increase ? fastKey : rewindKey)
        case .none:
            break
        }
    }

    static func playPause() {
        post(playKey)
    }

    static func mute() {
        post(muteKey)
    }

    static func performCornerAction(_ action: FringeCornerAction) {
        switch action {
        case .none:
            break
        case .mute:
            mute()
        case .screenshot:
            takeDirectScreenshot()
        case .playPause:
            playPause()
        }
    }

    static func takeDirectScreenshot() {
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Desktop")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss\u{202F}a"
        let dateStr = formatter.string(from: Date())
        let filename = "Screenshot \(dateStr).png"
        let destinationURL = desktopURL.appendingPathComponent(filename)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = [destinationURL.path]
        try? task.run()
    }

    /// One key press and its release, as system-defined events (subtype 8).
    private static func post(_ keyCode: Int32) {
        for state in [0xA, 0xB] as [Int32] {
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: Int((keyCode << 16) | (state << 8)),
                data2: -1
            )
            // droppykit-lint: allow synthetic-input: the media, volume, brightness and keyboard backlight keys only (NX_KEYTYPE system events, no character, no pointer), what Fringe is for: there is no public API that sets display brightness or the keyboard backlight
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
