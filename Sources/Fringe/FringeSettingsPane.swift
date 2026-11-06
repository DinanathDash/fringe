//
//  FringeSettingsPane.swift
//  Fringe
//

import AppKit
import DroppyKit
import SwiftUI

public struct FringeSettingsPane: View {
    @ObservedObject var engine: FringeEngine
    @State private var isExporting = false

    public init(engine: FringeEngine) {
        self.engine = engine
    }

    public var body: some View {
        DropletSettingsPane {
            permissionSection
            gesturesSection
            cornersSection
            edgesSection
            accuracySection
            diagnosticsSection
        }
        .onAppear {
            engine.refreshAccessibilityStatus()
        }
    }

    // MARK: Permissions

    private var permissionSection: some View {
        DropletSettingsSection {
            settingsSectionHeader("Permissions")
        } content: {
            DropletSettingsCard {
                DropletControlRow(
                    title: "Accessibility",
                    infoTip: "Fringe requires Accessibility permission to listen for trackpad edge gestures and post media keys. Gestures start automatically once granted."
                ) {
                    HStack(spacing: DroppySpacing.sm) {
                        Text(engine.isAccessibilityGranted ? "Granted" : "Required")
                            .font(.body.weight(.medium))
                            .foregroundStyle(engine.isAccessibilityGranted ? .green : .red)
                        if !engine.isAccessibilityGranted {
                            Button("Open Settings") {
                                engine.openAccessibilitySettings()
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    // MARK: Gestures

    private var gesturesSection: some View {
        DropletSettingsSection {
            settingsSectionHeader("Gestures")
        } content: {
            DropletSettingsCard {
                DropletToggleRow(
                    title: "Edge gestures",
                    icon: "hand.draw",
                    subtitle: "Turn off to pause Fringe without removing it.",
                    isOn: $engine.settings.isEnabled
                )
                DropletControlRow(
                    title: "Pause shortcut",
                    icon: "command",
                    infoTip: "Set it on Droppy's Shortcuts page."
                ) {
                    Button(engine.shortcutLabel) {
                        _ = engine.host?.workspace.openShortcuts()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: Corners

    private var cornersSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Corners")
                Text("Double-tap any corner to trigger an action (Mute, Screenshots, Play / Pause).")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                cornerRow(.topLeft, binding: Binding(
                    get: { engine.settings.topLeftCornerAction },
                    set: { engine.settings.topLeftCornerAction = $0 }
                ))
                cornerRow(.topRight, binding: Binding(
                    get: { engine.settings.topRightCornerAction },
                    set: { engine.settings.topRightCornerAction = $0 }
                ))
                cornerRow(.bottomLeft, binding: Binding(
                    get: { engine.settings.bottomLeftCornerAction },
                    set: { engine.settings.bottomLeftCornerAction = $0 }
                ))
                cornerRow(.bottomRight, binding: Binding(
                    get: { engine.settings.bottomRightCornerAction },
                    set: { engine.settings.bottomRightCornerAction = $0 }
                ))
            }
        }
    }

    private func cornerRow(_ corner: FringeCorner, binding: Binding<FringeCornerAction>) -> some View {
        DropletControlRow(title: corner.label, icon: corner.systemImage, infoTip: "Double-tap this corner to trigger the action.") {
            Picker(corner.label, selection: binding) {
                ForEach(FringeCornerAction.allCases) { action in
                    Label(action.label, systemImage: action.systemImage).tag(action)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    // MARK: Edges

    private var edgesSection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Edges")
                Text("Slide along an edge to adjust volume, brightness, backlight, or skip tracks.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                edgeRow(.left, infoTip: "Start in the bottom left corner and slide up, or the top left corner and slide down.")
                edgeRow(.right, infoTip: "Start in the bottom right corner and slide up, or the top right corner and slide down.")
                edgeRow(.top, infoTip: "Start in the top left corner and slide right, or just left of the top right corner and slide left.")
                edgeRow(.bottom, infoTip: "Start in the bottom left corner and slide right, or the bottom right corner and slide left.")
            }
        }
    }

    private func edgeRow(_ edge: FringeEdge, infoTip: String) -> some View {
        DropletControlRow(title: edge.label, icon: edge.systemImage, infoTip: infoTip) {
            Picker(edge.label, selection: Binding(
                get: { engine.settings.action(for: edge) },
                set: { engine.settings.setAction($0, for: edge) }
            )) {
                ForEach(FringeAction.allCases) { action in
                    Label(action.label, systemImage: action.systemImage).tag(action)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    // MARK: Accuracy

    private var accuracySection: some View {
        DropletSettingsSection {
            VStack(alignment: .leading, spacing: 2) {
                settingsSectionHeader("Accuracy")
                Text("Edge width sets the border margin. Start zone is the corner area that begins a gesture. Travel per step is how far you slide on the trackpad for each step.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        } content: {
            DropletSettingsCard {
                DropletControlRow(
                    title: "Hold a key to drag",
                    infoTip: "Edge drags only count while this key is held."
                ) {
                    Picker("Hold a key to drag", selection: $engine.settings.modifierGuard) {
                        ForEach(ModifierGuard.allCases) { key in
                            Text(key.label).tag(key)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
                DropletSliderRow(
                    title: "Edge width",
                    value: "\(Int((engine.settings.edgeMarginFraction * 100).rounded()))%",
                    binding: $engine.settings.edgeMarginFraction,
                    range: FringeSettings.edgeMarginRange,
                    step: 0.01
                )
                DropletSliderRow(
                    title: "Start zone",
                    value: "\(Int((engine.settings.startZoneFraction * 100).rounded()))%",
                    binding: $engine.settings.startZoneFraction,
                    range: FringeSettings.startZoneRange,
                    step: 0.05
                )
                DropletSliderRow(
                    title: "Travel per step",
                    value: "\(Int((engine.settings.stepDistance * 100).rounded()))%",
                    binding: $engine.settings.stepDistance,
                    range: FringeSettings.stepDistanceRange,
                    step: 0.01
                )
                DropletToggleRow(
                    title: "Haptic feedback",
                    subtitle: "A click from the trackpad at every step.",
                    isOn: $engine.settings.hapticFeedbackEnabled
                )
            }
        }
    }

    // MARK: Diagnostics

    private var diagnosticsSection: some View {
        DropletSettingsSection {
            settingsSectionHeader("Diagnostics")
        } content: {
            DropletSettingsCard {
                DropletControlRow(
                    title: "Logs",
                    infoTip: "Attach these when you report a problem."
                ) {
                    HStack(spacing: DroppySpacing.sm) {
                        Button(isExporting ? "Exporting…" : "Export…") {
                            exportLogs()
                        }
                        .buttonStyle(.bordered)
                        .disabled(isExporting)

                        Button("Show in Finder") {
                            FringeLogExporter.showLogsInFinder()
                        }
                        .buttonStyle(.bordered)
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
                let archiveURL = try await FringeLogExporter.exportLogs()
                defer { try? FileManager.default.removeItem(at: archiveURL) }

                let panel = NSSavePanel()
                panel.title = "Export logs"
                panel.nameFieldStringValue = archiveURL.lastPathComponent
                panel.allowedContentTypes = [.zip]
                panel.canCreateDirectories = true

                NSApp.activate(ignoringOtherApps: true)

                if panel.runModal() == .OK, let destinationURL = panel.url {
                    let fileManager = FileManager.default
                    if fileManager.fileExists(atPath: destinationURL.path) {
                        try fileManager.removeItem(at: destinationURL)
                    }
                    try fileManager.copyItem(at: archiveURL, to: destinationURL)
                }
            } catch {
                FringeLog.error("Export logs failed: \(error.localizedDescription)")
            }
        }
    }
}
