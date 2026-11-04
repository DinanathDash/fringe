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
    public static let widgetID: ShelfWidgetID = "fringe.main"

    public let engine = FringeEngine()
    public private(set) var host: DropletHost?

    @Published public var isEnabled: Bool = true {
        didSet {
            engine.settings.isEnabled = isEnabled
        }
    }

    public override init() {
        super.init()
    }

    public func activate(host: DropletHost) throws {
        self.host = host
        self.isEnabled = engine.settings.isEnabled
        FringeRotatingFileLogSink.setup()
        FringeLog.info("Fringe activated")
        host.log.info("Fringe activated")

        host.shortcuts.register(
            id: "fringe.toggle",
            title: "Toggle Fringe gestures",
            defaultShortcut: nil
        ) { [weak self] in
            self?.toggleEnabled()
        }

        engine.start(with: host)
    }

    public func deactivate() {
        FringeLog.info("Fringe deactivating")
        host?.shortcuts.unregister(id: "fringe.toggle")
        engine.stop()
        FringeRotatingFileLogSink.shared.flush()
        host = nil
    }

    public func toggleEnabled() {
        isEnabled.toggle()
        FringeLog.info("Fringe isEnabled toggled to \(self.isEnabled)")
        host?.log.info("Fringe isEnabled toggled to \(self.isEnabled)")
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
                    preferredSoloWidth: 420,
                    preferredPairedWidth: 210,
                    contentHeight: .fixed(100),
                    notchWrap: ShelfWidgetNotchWrapTraits(headerHeight: 34, minimumBandWidth: 64)
                )
            )
        ]
    }

    public func makeWidgetView(_ id: ShelfWidgetID, context: ShelfWidgetContext) -> AnyView {
        AnyView(FringeWidgetView(droplet: self, context: context))
    }

    public func makeWidgetSettingsPopover(_ id: ShelfWidgetID) -> AnyView? { nil }
}

// MARK: - Settings pane

extension FringeDroplet: SettingsPaneProviding {
    public func makeSettingsPane(context: SettingsPaneContext) -> AnyView {
        AnyView(FringeSettingsPane(engine: engine))
    }
}
