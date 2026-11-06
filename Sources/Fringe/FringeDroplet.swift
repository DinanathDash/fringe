//
//  FringeDroplet.swift
//  Fringe
//

import AppKit
import Combine
import DroppyKit
import Foundation
import SwiftUI

@objc(FringePrincipal)
public final class FringePrincipal: NSObject, DropletPrincipal {
    public override init() { super.init() }

    @MainActor public func makeDroplet() -> AnyObject { FringeDroplet() }
}

@MainActor
public final class FringeDroplet: NSObject, ObservableObject, Droplet {
    public nonisolated static let id: DropletID = "fringe"
    public static let widgetID: ShelfWidgetID = "fringe.widget"
    public static let toggleShortcutID = "fringe.toggle"

    public let engine = FringeEngine()
    public private(set) var host: DropletHost?

    public override init() {
        super.init()
    }

    public func activate(host: DropletHost) throws {
        self.host = host
        FringeRotatingFileLogSink.setup()
        FringeLog.info("Fringe activated")
        host.log.info("Fringe activated")

        host.shortcuts.register(
            id: Self.toggleShortcutID,
            title: "Pause or resume Fringe gestures",
            defaultShortcut: nil
        ) { [weak self] in
            self?.toggleEnabled()
        }

        engine.start(with: host)
    }

    public func deactivate() {
        FringeLog.info("Fringe deactivating")
        host?.shortcuts.unregister(id: Self.toggleShortcutID)
        engine.stop()
        FringeRotatingFileLogSink.shared.flush()
        host = nil
    }

    // MARK: - Actions

    public func toggleEnabled() {
        engine.settings.isEnabled.toggle()
        FringeLog.info("Fringe gestures \(engine.settings.isEnabled ? "on" : "paused")")
        host?.log.info("Fringe gestures \(engine.settings.isEnabled ? "on" : "paused")")
    }
}

// MARK: - Shelf widget

extension FringeDroplet: ShelfWidgetProviding {
    public var widgetDescriptors: [ShelfWidgetDescriptor] {
        [
            ShelfWidgetDescriptor(
                id: Self.widgetID,
                title: "Fringe",
                systemImage: "slider.vertical.3",
                layoutTraits: ShelfWidgetLayoutTraits(
                    preferredSoloWidth: 415,
                    preferredPairedWidth: 200,
                    contentHeight: .fixed(FringeWidgetView.contentHeight),
                    notchWrap: ShelfWidgetNotchWrapTraits(headerHeight: 34, minimumBandWidth: 64)
                )
            )
        ]
    }

    public func makeWidgetView(_ id: ShelfWidgetID, context: ShelfWidgetContext) -> AnyView {
        AnyView(FringeWidgetView(engine: engine, context: context, toggle: { [weak self] in
            self?.toggleEnabled()
        }))
    }

    public func makeWidgetSettingsPopover(_ id: ShelfWidgetID) -> AnyView? { nil }
}

// MARK: - Settings pane

extension FringeDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(FringeSettingsPane(engine: engine))
    }
}
