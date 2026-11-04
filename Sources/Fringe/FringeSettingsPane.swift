//
//  FringeSettingsPane.swift
//  Fringe
//

import AppKit
import DroppyKit
import SwiftUI
import UniformTypeIdentifiers

public struct FringeSettingsPane: View {
    @ObservedObject var engine: FringeEngine
    @State private var isExporting = false

    public init(engine: FringeEngine) {
        self.engine = engine
    }

    public var body: some View {
        DropletSettingsPane {
            // General status & master switch
            DropletSettingsSection {
                settingsSectionHeader("Fringe gestures")
            } content: {
                DropletSettingsCard {
                    DropletToggleRow(
                        title: "Pause gestures",
                        icon: "pause.circle",
                        subtitle: "Temporarily pause edge tracking without disabling the droplet.",
                        isOn: Binding(
                            get: { !engine.settings.isEnabled },
                            set: { engine.settings.isEnabled = !$0 }
                        )
                    )

                    DropletControlRow(
                        title: "Keyboard shortcuts",
                        icon: "command",
                        infoTip: "Set a global shortcut on Droppy's Shortcuts page to pause or resume Fringe gestures."
                    ) {
                        Button {
                            _ = engine.host?.workspace.openShortcuts()
                        } label: {
                            HStack(spacing: 6) {
                                Text(engine.shortcutLabel)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .buttonStyle(.bordered)
                        .help("Set on Droppy's Shortcuts page")
                    }
                }
            }

            // Edge mappings
            DropletSettingsSection {
                settingsSectionHeader("Edge mappings")
            } content: {
                DropletSettingsCard {
                    DropletControlRow(
                        title: "Left edge",
                        icon: "arrow.left.to.line",
                        infoTip: "Drag from bottom to top along the extreme left edge to increase; top to bottom to decrease."
                    ) {
                        HStack {
                            Spacer()
                            Picker("", selection: Binding(
                                get: { engine.settings.leftAction },
                                set: { engine.settings.setAction($0, for: .left) }
                            )) {
                                ForEach(FringeAction.allCases) { action in
                                    Label(action.label, systemImage: action.systemImage).tag(action)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }

                    DropletControlRow(
                        title: "Right edge",
                        icon: "arrow.right.to.line",
                        infoTip: "Drag from bottom to top along the extreme right edge to increase; top to bottom to decrease."
                    ) {
                        HStack {
                            Spacer()
                            Picker("", selection: Binding(
                                get: { engine.settings.rightAction },
                                set: { engine.settings.setAction($0, for: .right) }
                            )) {
                                ForEach(FringeAction.allCases) { action in
                                    Label(action.label, systemImage: action.systemImage).tag(action)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }

                    DropletControlRow(
                        title: "Top edge",
                        icon: "arrow.up.to.line",
                        infoTip: "Drag horizontally along the top margin to increase or decrease."
                    ) {
                        HStack {
                            Spacer()
                            Picker("", selection: Binding(
                                get: { engine.settings.topAction },
                                set: { engine.settings.setAction($0, for: .top) }
                            )) {
                                ForEach(FringeAction.allCases) { action in
                                    Label(action.label, systemImage: action.systemImage).tag(action)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
            }

            // Accidental drag prevention
            DropletSettingsSection {
                settingsSectionHeader("Accidental drag prevention")
            } content: {
                DropletSettingsCard {
                    DropletControlRow(
                        title: "Required modifier key",
                        icon: "keyboard",
                        infoTip: "Optionally require holding a modifier key so edge drags only activate when intentionally desired."
                    ) {
                        HStack {
                            Spacer()
                            Picker("", selection: $engine.settings.modifierGuard) {
                                ForEach(ModifierGuard.allCases) { guardKey in
                                    Label(guardKey.rawValue, systemImage: guardKey.systemImage).tag(guardKey)
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }

                    DropletControlRow(
                        title: "Extreme edge width",
                        icon: "arrow.left.and.right",
                        infoTip: "Width of the active edge zone (5% matches macOS Notification Center's edge sensitivity)."
                    ) {
                        HStack(spacing: 8) {
                            Spacer()
                            Slider(
                                value: $engine.settings.edgeMarginFraction,
                                in: 0.02...0.12,
                                step: 0.01
                            )
                            .frame(width: 140)

                            Text("\(Int(engine.settings.edgeMarginFraction * 100))%")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    DropletControlRow(
                        title: "Step distance",
                        icon: "ruler",
                        infoTip: "Trackpad travel required to trigger one media key notch. Smaller values scrub faster; larger values scrub more gently."
                    ) {
                        HStack(spacing: 8) {
                            Spacer()
                            Slider(
                                value: $engine.settings.stepDistance,
                                in: 0.02...0.08,
                                step: 0.01
                            )
                            .frame(width: 140)

                            Text("\(Int(engine.settings.stepDistance * 100))%")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 36, alignment: .trailing)
                        }
                    }

                    DropletToggleRow(
                        title: "Haptic feedback",
                        icon: "waveform",
                        subtitle: "Tactile click when passing each adjustment step.",
                        isOn: $engine.settings.hapticFeedbackEnabled
                    )
                }
            }

            // Diagnostics
            DropletSettingsSection {
                settingsSectionHeader("Diagnostics")
            } content: {
                DropletSettingsCard {
                    DropletControlRow(
                        title: "Logs",
                        icon: "doc.text",
                        infoTip: "Attach these when reporting a problem."
                    ) {
                        HStack(spacing: 10) {
                            Button(isExporting ? "Exporting…" : "Export…") {
                                exportLogs()
                            }
                            .buttonStyle(.bordered)
                            .disabled(isExporting)

                            Button("Reveal") {
                                FringeLogExporter.showLogsInFinder()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private func exportLogs() {
        isExporting = true
        Task { @MainActor in
            defer { isExporting = false }
            do {
                let tempZipURL = try await FringeLogExporter.exportLogs()
                defer {
                    try? FileManager.default.removeItem(at: tempZipURL)
                }

                let panel = NSSavePanel()
                panel.title = "Export Logs"
                panel.nameFieldStringValue = tempZipURL.lastPathComponent
                panel.allowedContentTypes = [.zip]
                panel.canCreateDirectories = true

                if panel.runModal() == .OK, let destinationURL = panel.url {
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: tempZipURL, to: destinationURL)
                }
            } catch {
                FringeLog.error("Export logs failed: \(error.localizedDescription)")
            }
        }
    }
}
