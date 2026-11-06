//
//  FringeShelfWidget.swift
//  Fringe
//

import AppKit
import DroppyKit
import SwiftUI

/// No card or border: the content sits straight on the shelf, padded once
/// with `context.contentInsets`. The header sits on the top line; the body
/// displays corners in the first row and edges in the second row, each outlined
/// by rounded dashed borders.
public struct FringeWidgetView: View {
    @ObservedObject var engine: FringeEngine
    let context: ShelfWidgetContext
    let toggle: () -> Void

    /// 20 header + spacing + corners box + spacing + edges box,
    /// plus contentInsets (increased to 220pt).
    nonisolated static let contentHeight: CGFloat = 220
    nonisolated static let headerHeight: CGFloat = 20

    /// The corners the widget lists: Top-Left, Top-Right, Bottom-Left, Bottom-Right.
    private static let corners: [FringeCorner] = [.topLeft, .topRight, .bottomLeft, .bottomRight]

    /// The edges the widget lists, in the order they sit on a trackpad.
    private static let edges: [FringeEdge] = [.left, .top, .right, .bottom]

    public init(engine: FringeEngine, context: ShelfWidgetContext, toggle: @escaping () -> Void) {
        self.engine = engine
        self.context = context
        self.toggle = toggle
    }

    private var isEnabled: Bool { engine.settings.isEnabled }
    private var isPermissionNeeded: Bool { isEnabled && !engine.isAccessibilityGranted }

    public var body: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            header
                .frame(height: Self.headerHeight)
            Spacer(minLength: 0)
            if context.isCompact {
                compactBody
            } else {
                soloBody
            }
        }
        .padding(context.contentInsets)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(!context.isShelfTransitioning)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DroppySpacing.xsm) {
            Image(systemName: "slider.vertical.3")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .accessibilityHidden(true)
            Text("Fringe")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if context.isCompact {
                Button(action: toggle) {
                    Image(systemName: isEnabled ? "pause.fill" : "play.fill")
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 20))
                .help(isEnabled ? "Pause gestures" : "Resume gestures")
                .accessibilityLabel(isEnabled ? "Pause Fringe gestures" : "Resume Fringe gestures")
            } else {
                Button(action: {
                    if isPermissionNeeded {
                        engine.openAccessibilitySettings()
                    } else {
                        toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isPermissionNeeded ? Color.orange : (isEnabled ? Color.green : AdaptiveColors.notchSurfaceTertiaryText))
                            .frame(width: 6, height: 6)
                        Text(isPermissionNeeded ? "Needs permission" : (isEnabled ? "Active" : "Paused"))
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .buttonStyle(DroppyQuietButtonStyle(size: .small))
                .help(isPermissionNeeded ? "Open Accessibility Settings" : (isEnabled ? "Pause gestures" : "Resume gestures"))
                .accessibilityLabel(isPermissionNeeded ? "Fringe needs Accessibility permission" : (isEnabled ? "Fringe is active. Pause gestures" : "Fringe is paused. Resume gestures"))
            }
        }
    }

    // MARK: - Solo (2 Rows: Corners first, Edges second)

    private var soloBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            cornerSection
            edgeSection
        }
        .opacity(isEnabled ? 1 : 0.55)
    }

    // MARK: Row 1 - Corners

    private var cornerSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Corners")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            cornerColumns
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText.opacity(0.35))
        )
    }

    private var cornerColumns: some View {
        HStack(alignment: .top, spacing: DroppySpacing.md) {
            ForEach(Self.corners) { corner in
                cornerColumn(corner)
            }
        }
    }

    private func cornerColumn(_ corner: FringeCorner) -> some View {
        let action = engine.settings.action(for: corner)
        return VStack(alignment: .leading, spacing: 2) {
            Text(corner.shortLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .lineLimit(1)
            HStack(spacing: 5) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    actionText(action.label)
                    actionText(action.shortLabel)
                }
            }
            Text(action == .none ? "Not in use" : "Double-tap")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                .lineLimit(1)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .opacity(action == .none ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }

    // MARK: Row 2 - Edges

    private var edgeSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Edges")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
            edgeColumns
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                )
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText.opacity(0.35))
        )
    }

    private var edgeColumns: some View {
        HStack(alignment: .top, spacing: DroppySpacing.md) {
            ForEach(Self.edges) { edge in
                edgeColumn(edge)
            }
        }
    }

    private func edgeColumn(_ edge: FringeEdge) -> some View {
        let action = engine.settings.action(for: edge)
        let isActive = engine.state.activeEdge == edge
        return VStack(alignment: .leading, spacing: 2) {
            Text(edge.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
                .lineLimit(1)
            HStack(spacing: 5) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? Color.accentColor : AdaptiveColors.notchSurfacePrimaryText)
                    .frame(width: 16)
                    .accessibilityHidden(true)
                ViewThatFits(in: .horizontal) {
                    actionText(action.label)
                    actionText(action.shortLabel)
                }
            }
            Text(action == .none ? "Not in use" : edge.directionLabel)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                .lineLimit(1)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .opacity(action == .none ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }

    private func actionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Compact (Paired)

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(isPermissionNeeded ? "Needs permission" : (isEnabled ? "Gestures active" : "Paused"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isPermissionNeeded ? Color.orange : AdaptiveColors.notchSurfacePrimaryText)
                .lineLimit(1)
            ViewThatFits(in: .horizontal) {
                compactMappings(showsLabels: true)
                compactMappings(showsLabels: false)
            }
            .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
        }
        .opacity(isEnabled ? 1 : 0.55)
    }

    private func compactMappings(showsLabels: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // First row: Active corners
            HStack(spacing: DroppySpacing.sm) {
                ForEach(Self.corners) { corner in
                    let action = engine.settings.action(for: corner)
                    if action != .none {
                        HStack(spacing: 3) {
                            Image(systemName: action.systemImage)
                                .font(.system(size: 9, weight: .semibold))
                            if showsLabels {
                                Text(action.shortLabel)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
            }
            // Second row: Active edges
            HStack(spacing: DroppySpacing.sm) {
                ForEach(Self.edges) { edge in
                    let action = engine.settings.action(for: edge)
                    if action != .none {
                        HStack(spacing: 3) {
                            Image(systemName: action.systemImage)
                                .font(.system(size: 9, weight: .semibold))
                            if showsLabels {
                                Text(action.shortLabel)
                                    .font(.system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }
            }
        }
    }
}
