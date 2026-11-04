//
//  FringeShelfWidget.swift
//  Fringe
//

import AppKit
import DroppyKit
import SwiftUI

public struct FringeWidgetView: View {
    @ObservedObject var droplet: FringeDroplet
    let context: ShelfWidgetContext

    public init(droplet: FringeDroplet, context: ShelfWidgetContext) {
        self.droplet = droplet
        self.context = context
    }

    public var body: some View {
        if context.isCompact {
            compactLayout
        } else {
            standaloneLayout
        }
    }

    // MARK: - Standalone Layout

    private var standaloneLayout: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            // Header row sits beside the notch when notchWrap is available
            if let wrap = context.notchWrap {
                ShelfWidgetNotchWrapRow(wrap) {
                    wrappedTitle
                } trailing: {
                    headerToggleButton
                }
            } else {
                HStack(spacing: DroppySpacing.xsm) {
                    headerTitle
                    Spacer(minLength: 0)
                    headerToggleButton
                }
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
            }

            Spacer(minLength: 0)

            // Edge mappings laid out with justify-between across the full shelf width
            HStack(alignment: .top, spacing: 0) {
                // Left edge
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: droplet.engine.settings.leftAction.systemImage)
                            .font(.system(size: 11, weight: .medium))
                        Text("Left edge")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)

                    Text(droplet.engine.settings.leftAction.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                    Text("Swipe ↑ / ↓")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                }

                Spacer(minLength: DroppySpacing.md)

                // Top edge
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: droplet.engine.settings.topAction.systemImage)
                            .font(.system(size: 11, weight: .medium))
                        Text("Top edge")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)

                    Text(droplet.engine.settings.topAction.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                    Text("Swipe ← / →")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                }

                Spacer(minLength: DroppySpacing.md)

                // Right edge
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: droplet.engine.settings.rightAction.systemImage)
                            .font(.system(size: 11, weight: .medium))
                        Text("Right edge")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)

                    Text(droplet.engine.settings.rightAction.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

                    Text("Swipe ↑ / ↓")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(context.contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(!context.isShelfTransitioning)
    }

    // MARK: - Header Views

    private var headerTitle: some View {
        HStack(spacing: DroppySpacing.xsm) {
            Image(systemName: "slider.vertical.3")
                .font(.system(size: 12, weight: .medium))
            Text("Fringe")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
    }

    private var wrappedTitle: some View {
        ViewThatFits(in: .horizontal) {
            headerTitle
            Image(systemName: "slider.vertical.3")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)
        }
    }

    private var headerToggleButton: some View {
        Button {
            droplet.toggleEnabled()
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(droplet.isEnabled ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)

                Text(droplet.isEnabled ? "Active" : "Paused")
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .buttonStyle(DroppyQuietButtonStyle(size: .small))
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: DroppySpacing.sm) {
            HStack(spacing: DroppySpacing.xsm) {
                Image(systemName: "slider.vertical.3")
                    .font(.system(size: 12, weight: .medium))
                Text("Fringe")
                    .font(.system(size: 12, weight: .semibold))

                Spacer(minLength: 0)

                Button {
                    droplet.toggleEnabled()
                } label: {
                    Circle()
                        .fill(droplet.isEnabled ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                }
                .buttonStyle(DroppyCircleButtonStyle(size: 18))
            }
            .foregroundStyle(AdaptiveColors.notchSurfaceSecondaryText)

            Spacer(minLength: 0)

            Text(droplet.isEnabled ? "Edges active" : "Paused")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AdaptiveColors.notchSurfacePrimaryText)

            Text("L: Vol • R: Bright • T: Kbd")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(AdaptiveColors.notchSurfaceTertiaryText)
        }
        .padding(context.contentInsets)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(!context.isShelfTransitioning)
    }
}
