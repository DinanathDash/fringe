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

private final class TapOwnerBox<T: AnyObject> {
    weak var value: T?
    init(_ value: T) { self.value = value }
}

@MainActor
public final class FringeEngine: ObservableObject {
    private static let userDefaultsKey = "com.droppy.fringe.settings.v1"

    @Published public var settings: FringeSettings = FringeSettings() {
        didSet {
            saveSettings()
            objectWillChange.send()
        }
    }

    @Published public var state: FringeLiveState = FringeLiveState()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapOwnerBox: Unmanaged<TapOwnerBox<FringeEngine>>?
    public private(set) var host: DropletHost?

    public var shortcutLabel: String {
        if let shortcut = host?.shortcuts.currentShortcut(id: "fringe.toggle") {
            return shortcut.displayString
        }
        return "Set up"
    }

    // Touch tracking state (Extreme edge with single-finger drag)
    private var seenTouches: Set<Int> = []
    private var disqualifiedTouches: Set<Int> = []
    private var trackedTouchKey: Int?
    private var trackedEdge: FringeEdge?
    private var trackedAction: FringeAction = .none
    private var lastPos: CGFloat = 0
    private var accumulatedDelta: CGFloat = 0

    public init() {
        loadSettings()
    }

    public func start(with host: DropletHost?) {
        self.host = host
        FringeLog.info("FringeEngine starting")
        host?.log.info("FringeEngine starting")
        setupEventTap()
    }

    public func stop() {
        FringeLog.info("FringeEngine stopping")
        host?.log.info("FringeEngine stopping")
        tearDownEventTap()
        endGesture()
        host = nil
    }

    // MARK: - Persistence

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
           let decoded = try? JSONDecoder().decode(FringeSettings.self, from: data) {
            self.settings = decoded
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    // MARK: - Event Tap Setup

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let box = Unmanaged<TapOwnerBox<FringeEngine>>.fromOpaque(refcon).takeUnretainedValue()
        guard let engine = box.value else { return Unmanaged.passUnretained(event) }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = engine.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type.rawValue == NSEvent.EventType.gesture.rawValue {
            engine.handleGestureEvent(event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func setupEventTap() {
        guard eventTap == nil else { return }

        let box = Unmanaged.passRetained(TapOwnerBox(self))
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: NSEvent.EventTypeMask.gesture.rawValue,
            callback: FringeEngine.eventTapCallback,
            userInfo: box.toOpaque()
        ) else {
            box.release()
            FringeLog.warning("Fringe: Accessibility event tap could not be created directly")
            host?.log.info("Fringe: Accessibility event tap could not be created directly")
            return
        }

        tapOwnerBox = box
        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        if let source = source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func tearDownEventTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        tapOwnerBox?.release()
        tapOwnerBox = nil
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Native Multi-Touch 1-Finger Edge Gesture Handling

    private func handleGestureEvent(_ cgEvent: CGEvent) {
        guard settings.isEnabled else { return }
        guard let nsEvent = NSEvent(cgEvent: cgEvent) else { return }

        let rawTouches = nsEvent.allTouches().filter { $0.type == .indirect }
        guard !rawTouches.isEmpty else { return }

        // Clean up individual touches that ended or were cancelled in this event
        for touch in rawTouches where touch.phase == .ended || touch.phase == .cancelled {
            let key = (touch.identity as AnyObject).hash ?? 0
            seenTouches.remove(key)
            disqualifiedTouches.remove(key)
            if key == trackedTouchKey {
                endGesture()
            }
        }

        // Active physical touches currently contacting the trackpad surface
        let surfaceTouches = Array(rawTouches.filter { $0.phase != .ended && $0.phase != .cancelled })

        // When all fingers leave trackpad, end gesture cleanly and reset all tracking
        if surfaceTouches.isEmpty {
            if state.isEngaged {
                endGesture()
            }
            seenTouches.removeAll()
            disqualifiedTouches.removeAll()
            return
        }

        // --- Palm & Multi-Touch Rejection ---
        // If ANY touch is resting (palm / resting finger), or if there is more than 1 contact point,
        // this is not a deliberate single-finger edge swipe. Immediately abort and disqualify all contacts.
        if surfaceTouches.contains(where: { $0.isResting }) || surfaceTouches.count > 1 {
            if state.isEngaged {
                endGesture()
            }
            for touch in surfaceTouches {
                let key = (touch.identity as AnyObject).hash ?? 0
                disqualifiedTouches.insert(key)
            }
            return
        }

        // Check modifier key guard if configured
        guard settings.modifierGuard.matches(flags: NSEvent.modifierFlags) else {
            if state.isEngaged {
                endGesture()
            }
            return
        }

        // Tight exact edge boundary matching macOS Notification Center physical rim
        let margin = CGFloat(max(0.02, min(0.06, settings.edgeMarginFraction)))

        // If currently engaged in an edge drag gesture, track incremental movement
        if state.isEngaged {
            // Must have exactly 1 active non-resting finger corresponding to the locked edge touch
            guard surfaceTouches.count == 1,
                  let touch = surfaceTouches.first,
                  !touch.isResting,
                  let lockedKey = trackedTouchKey,
                  ((touch.identity as AnyObject).hash ?? 0) == lockedKey,
                  let edge = trackedEdge,
                  trackedAction != .none else {
                endGesture()
                return
            }

            let pos = touch.normalizedPosition

            // Guard against wandering too far into trackpad center while engaged
            let maxInwardDisplacement = max(margin * 2.5, 0.12)
            let hasWanderedIntoCenter: Bool
            switch edge {
            case .left:
                hasWanderedIntoCenter = pos.x > maxInwardDisplacement
            case .right:
                hasWanderedIntoCenter = pos.x < (1.0 - maxInwardDisplacement)
            case .top:
                hasWanderedIntoCenter = pos.y < (1.0 - maxInwardDisplacement)
            case .bottom:
                hasWanderedIntoCenter = pos.y > maxInwardDisplacement
            }

            if hasWanderedIntoCenter {
                endGesture()
                return
            }

            let currentPos: CGFloat
            switch edge {
            case .left, .right:
                // Vertical movement: bottom to top increases
                currentPos = pos.y
            case .top, .bottom:
                // Horizontal movement: left to right increases
                currentPos = pos.x
            }

            let delta = currentPos - lastPos
            lastPos = currentPos
            accumulatedDelta += delta

            let stepDist = CGFloat(max(0.02, min(0.12, settings.stepDistance)))

            if accumulatedDelta >= stepDist {
                let steps = Int(accumulatedDelta / stepDist)
                accumulatedDelta -= CGFloat(steps) * stepDist
                for _ in 0..<min(4, steps) {
                    triggerStep(action: trackedAction, increase: true)
                }
            } else if accumulatedDelta <= -stepDist {
                let steps = Int((-accumulatedDelta) / stepDist)
                accumulatedDelta += CGFloat(steps) * stepDist
                for _ in 0..<min(4, steps) {
                    triggerStep(action: trackedAction, increase: false)
                }
            }
            return
        }

        // --- Gesture Initiation (Strictly 1 Finger Starting from the Exact Edge) ---

        guard let touch = surfaceTouches.first else { return }
        let pos = touch.normalizedPosition
        let touchKey = (touch.identity as AnyObject).hash ?? 0

        // Classify newly appeared touches:
        // Swipes must originate directly at the exact edge rim (matching Notification Center),
        // except for keyboard brightness down which is allowed to start in the designated zone (0.55 ... 0.82)
        // to avoid conflicting with the native Notification Center on the extreme right rim.
        // Touches landing anywhere in the interior or middle of edges are disqualified forever.
        if !seenTouches.contains(touchKey) {
            seenTouches.insert(touchKey)

            let isAtLeftEdgeOrigin = (pos.x <= margin) && ((pos.y <= margin) || (pos.y >= 1.0 - margin))
            let isAtRightEdgeOrigin = (pos.x >= 1.0 - margin) && ((pos.y <= margin) || (pos.y >= 1.0 - margin))
            let isAtTopEdgeOrigin = (pos.y >= 1.0 - margin) && ((pos.x <= margin) || (pos.x >= 0.55 && pos.x <= 0.82))
            let isAtBottomEdgeOrigin = (pos.y <= margin) && ((pos.x <= margin) || (pos.x >= 1.0 - margin))

            if !isAtLeftEdgeOrigin && !isAtRightEdgeOrigin && !isAtTopEdgeOrigin && !isAtBottomEdgeOrigin {
                disqualifiedTouches.insert(touchKey)
            }
        }

        // Abort if this touch originated away from the exact edge starting zones
        guard !disqualifiedTouches.contains(touchKey) else { return }

        var matchedEdge: FringeEdge?
        var matchedAction: FringeAction = .none

        // 1. Top Edge check (Keyboard backlight):
        // Single finger along exact top rim (y >= 1.0 - margin).
        // - Left origin for swiping right (increase): exact left edge (x <= margin)
        // - Right origin for swiping left (decrease): designated zone (0.55 <= x <= 0.82)
        //   leaving rightmost area (x > 0.82) exclusively for macOS Notification Center.
        if settings.topAction != .none {
            let isAtTopEdge = pos.y >= (1.0 - margin)
            let isAtLeftOrigin = pos.x <= margin
            let isAtRightOrigin = pos.x >= 0.55 && pos.x <= 0.82
            if isAtTopEdge && (isAtLeftOrigin || isAtRightOrigin) {
                matchedEdge = .top
                matchedAction = settings.topAction
            }
        }

        // 2. Left Edge check (Volume):
        // Single finger along exact left rim (x <= margin).
        // Must start from exact edge:
        // - Bottom edge for swiping up: y <= margin
        // - Top edge for swiping down: y >= 1.0 - margin
        if matchedEdge == nil && settings.leftAction != .none {
            let isAtLeftEdge = pos.x <= margin
            let isAtExactEdgeOrigin = (pos.y <= margin) || (pos.y >= 1.0 - margin)
            if isAtLeftEdge && isAtExactEdgeOrigin {
                matchedEdge = .left
                matchedAction = settings.leftAction
            }
        }

        // 3. Right Edge check (Display brightness):
        // Single finger along exact right rim (x >= 1.0 - margin).
        // Must start from exact edge:
        // - Bottom edge for swiping up: y <= margin
        // - Top edge for swiping down: y >= 1.0 - margin
        if matchedEdge == nil && settings.rightAction != .none {
            let isAtRightEdge = pos.x >= (1.0 - margin)
            let isAtExactEdgeOrigin = (pos.y <= margin) || (pos.y >= 1.0 - margin)
            if isAtRightEdge && isAtExactEdgeOrigin {
                matchedEdge = .right
                matchedAction = settings.rightAction
            }
        }

        // 4. Bottom Edge check (if configured):
        // Single finger along exact bottom rim (y <= margin).
        // Must start from exact left edge (x <= margin) or exact right edge (x >= 1.0 - margin).
        if matchedEdge == nil && settings.bottomAction != .none {
            let isAtBottomEdge = pos.y <= margin
            let isAtExactEdgeOrigin = (pos.x <= margin) || (pos.x >= 1.0 - margin)
            if isAtBottomEdge && isAtExactEdgeOrigin {
                matchedEdge = .bottom
                matchedAction = settings.bottomAction
            }
        }

        // If a valid extreme edge origin was detected, lock and engage
        if let edge = matchedEdge, matchedAction != .none {
            trackedTouchKey = touchKey
            trackedEdge = edge
            trackedAction = matchedAction

            switch edge {
            case .left, .right:
                lastPos = pos.y
            case .top, .bottom:
                lastPos = pos.x
            }

            accumulatedDelta = 0
            state.isEngaged = true
            state.activeEdge = edge
            state.activeAction = matchedAction
            FringeLog.debug("Edge engaged: \(edge.label) for action \(matchedAction.label)")
        }
    }

    public func endGesture() {
        if state.isEngaged {
            FringeLog.debug("Edge disengaged")
        }
        state.isEngaged = false
        state.activeEdge = nil
        state.activeAction = .none
        trackedTouchKey = nil
        trackedEdge = nil
        trackedAction = .none
        accumulatedDelta = 0
    }

    // MARK: - Native Keyboard Media Key Dispatch (Matches Thump Action Runner)

    private func triggerStep(action: FringeAction, increase: Bool) {
        FringeLog.debug("Trigger step: \(action.label), increase=\(increase)")
        switch action {
        case .volume:
            // 0: NX_KEYTYPE_SOUND_UP, 1: NX_KEYTYPE_SOUND_DOWN
            simulateMediaKey(keyCode: increase ? 0 : 1)
        case .brightness:
            // 2: NX_KEYTYPE_BRIGHTNESS_UP, 3: NX_KEYTYPE_BRIGHTNESS_DOWN
            simulateMediaKey(keyCode: increase ? 2 : 3)
        case .keyboardBrightness:
            // 21: NX_KEYTYPE_ILLUMINATION_UP, 22: NX_KEYTYPE_ILLUMINATION_DOWN
            simulateMediaKey(keyCode: increase ? 21 : 22)
        case .none:
            break
        }

        triggerHaptic()
    }

    /// Exact media key dispatch from ThumpActionRunner on the thump branch:
    /// Posts NX_KEYTYPE system events which natively trigger macOS volume/brightness changes
    /// and Droppy's built-in notch HUD without needing any custom droplet HUD.
    private func simulateMediaKey(keyCode: Int32) {
        let data1 = Int((keyCode << 16) | (0xa << 8))
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        event?.cgEvent?.post(tap: .cghidEventTap)

        let data1Up = Int((keyCode << 16) | (0xb << 8))
        let eventUp = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1Up,
            data2: -1
        )
        eventUp?.cgEvent?.post(tap: .cghidEventTap)
    }

    private func triggerHaptic() {
        guard settings.hapticFeedbackEnabled else { return }
        // .levelChange produces the heaviest, sharpest physical click on Apple Force Touch trackpads
        // (the pattern macOS uses for discrete multi-level pressure button clicks)
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
