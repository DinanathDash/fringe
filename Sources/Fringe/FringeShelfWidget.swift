//
//  FringeShelfWidget.swift
//  Fringe
//

import AppKit
import DroppyKit
import SwiftUI

/// Laid out like the trackpad in a 3x3 map: corners in the corners,
/// edges on the sides, with the header wrapped around the notch.
public struct FringeWidgetView: View {
    @ObservedObject var engine: FringeEngine
    let context: ShelfWidgetContext
    let toggle: () -> Void

    /// 143pt on a notched Mac, wrapping the header beside the camera.
    nonisolated static let contentHeight: CGFloat = 143
    nonisolated static let headerHeight: CGFloat = 20

    public init(engine: FringeEngine, context: ShelfWidgetContext, toggle: @escaping () -> Void) {
        self.engine = engine
        self.context = context
        self.toggle = toggle
    }

    private var isEnabled: Bool { engine.settings.isEnabled }
    private var isPermissionNeeded: Bool { isEnabled && !engine.isAccessibilityGranted }

    public var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            if let wrap = context.notchWrap {
                ShelfWidgetNotchWrapRow(wrap) {
                    titleView
                } trailing: {
                    pauseButton
                }
            } else {
                HStack(alignment: .center) {
                    titleView
                    Spacer(minLength: 0)
                    pauseButton
                }
                .frame(height: Self.headerHeight)
            }

            Spacer(minLength: 0)

            ViewThatFits(in: .horizontal) {
                wordsMap
                glyphMap
            }
            .opacity(isEnabled ? 1 : 0.45)
        }
        .padding(context.contentInsets)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(!context.isShelfTransitioning)
    }

    // MARK: - Header

    private var titleView: some View {
        HStack(spacing: DroppySpacing.xsm) {
            Image(systemName: "slider.vertical.3")
                .font(.system(size: 12, weight: .medium))
                .accessibilityHidden(true)
            Text("Fringe")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
    }

    private var pauseButton: some View {
        Button(action: {
            if isPermissionNeeded {
                engine.openAccessibilitySettings()
            } else {
                toggle()
            }
        }) {
            Image(systemName: isPermissionNeeded ? "exclamationmark.triangle.fill" : (isEnabled ? "pause.fill" : "play.fill"))
        }
        .buttonStyle(
            DroppyWashCircleButtonStyle(
                diameter: context.washControlSize,
                tone: isPermissionNeeded ? .accent(.orange) : (isEnabled ? .accent(.green) : .neutral),
                usesAdaptiveForegrounds: context.usesAdaptiveForegrounds
            )
        )
        .help(isPermissionNeeded ? "Open Accessibility Settings" : (isEnabled ? "Pause Fringe gestures" : "Resume Fringe gestures"))
        .accessibilityLabel(isPermissionNeeded ? "Fringe needs Accessibility permission" : (isEnabled ? "Pause Fringe gestures" : "Resume Fringe gestures"))
    }

    // MARK: - 3x3 Words Map (Solo / Wide)

    private var wordsMap: some View {
        VStack(spacing: DroppySpacing.md) {
            // Row 1 (Top)
            HStack(alignment: .center) {
                cornerSpot(.topLeft)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                edgeSpot(.top)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                cornerSpot(.topRight)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }

            // Row 2 (Sides + Center)
            HStack(alignment: .center) {
                edgeSpot(.left)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                centerStatus
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                edgeSpot(.right)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }

            // Row 3 (Bottom)
            HStack(alignment: .center) {
                cornerSpot(.bottomLeft)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                edgeSpot(.bottom)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                cornerSpot(.bottomRight)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - 3x3 Glyph Map (Paired / Narrow)

    private var glyphMap: some View {
        VStack(spacing: DroppySpacing.md) {
            // Row 1 (Top)
            HStack(alignment: .center) {
                cornerGlyphSpot(.topLeft)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                edgeGlyphSpot(.top)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                cornerGlyphSpot(.topRight)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }

            // Row 2 (Sides + Center)
            HStack(alignment: .center) {
                edgeGlyphSpot(.left)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                centerStatus
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                edgeGlyphSpot(.right)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }

            // Row 3 (Bottom)
            HStack(alignment: .center) {
                cornerGlyphSpot(.bottomLeft)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                edgeGlyphSpot(.bottom)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                cornerGlyphSpot(.bottomRight)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Center Status

    private var centerStatus: some View {
        Group {
            if isPermissionNeeded {
                Text("Needs permission")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.orange)
                    .lineLimit(1)
            } else if !isEnabled {
                Text("Paused")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                    .lineLimit(1)
            } else {
                Color.clear.frame(height: 1)
            }
        }
    }

    // MARK: - Spots (Words)

    private func cornerSpot(_ corner: FringeCorner) -> some View {
        let action = engine.settings.action(for: corner)
        return Group {
            if action == .none {
                Text("Off")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            } else {
                HStack(spacing: DroppySpacing.xsm) {
                    Image(systemName: action.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                        .accessibilityHidden(true)
                    Text(action.shortLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                        .lineLimit(1)
                }
            }
        }
        .help(cornerHelp(corner))
    }

    private func edgeSpot(_ edge: FringeEdge) -> some View {
        let action = engine.settings.action(for: edge)
        let isActive = engine.state.activeEdge == edge
        return Group {
            if action == .none {
                Text("Off")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            } else {
                HStack(spacing: DroppySpacing.xsm) {
                    Image(systemName: action.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isActive ? Color.accentColor : AdaptiveColors.notchSurfaceSecondaryText)
                        .accessibilityHidden(true)
                    Text(action.shortLabel)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                        .lineLimit(1)
                }
            }
        }
        .help(edgeHelp(edge))
    }

    // MARK: - Spots (Glyphs)

    private func cornerGlyphSpot(_ corner: FringeCorner) -> some View {
        let action = engine.settings.action(for: corner)
        return Group {
            if action == .none {
                Text("Off")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            } else {
                Image(systemName: action.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                    .accessibilityHidden(true)
            }
        }
        .help(cornerHelp(corner))
    }

    private func edgeGlyphSpot(_ edge: FringeEdge) -> some View {
        let action = engine.settings.action(for: edge)
        let isActive = engine.state.activeEdge == edge
        return Group {
            if action == .none {
                Text("Off")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            } else {
                Image(systemName: action.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? Color.accentColor : AdaptiveColors.notchSurfaceSecondaryText)
                    .accessibilityHidden(true)
            }
        }
        .help(edgeHelp(edge))
    }

    // MARK: - Tooltips

    private func cornerHelp(_ corner: FringeCorner) -> String {
        let action = engine.settings.action(for: corner)
        switch action {
        case .none:
            return "\(corner.label): Off"
        case .mute:
            return "\(corner.label): double-tap to mute"
        case .screenshot:
            return "\(corner.label): double-tap for screenshots"
        case .playPause:
            return "\(corner.label): double-tap for play/pause"
        case .lockScreen:
            return "\(corner.label): double-tap to lock screen"
        }
    }

    private func edgeHelp(_ edge: FringeEdge) -> String {
        let action = engine.settings.action(for: edge)
        switch action {
        case .none:
            return "\(edge.label): Off"
        case .volume:
            return "\(edge.label): slide \(edge.directionLabel.lowercased()) for volume"
        case .brightness:
            return "\(edge.label): slide \(edge.directionLabel.lowercased()) for display brightness"
        case .keyboardBrightness:
            return "\(edge.label): slide \(edge.directionLabel.lowercased()) for keyboard backlight"
        case .media:
            return "\(edge.label): slide \(edge.directionLabel.lowercased()) to skip tracks"
        }
    }
}
