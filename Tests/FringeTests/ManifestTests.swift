import Foundation
import Testing
import DroppyKit
@testable import Fringe

@Suite("Manifest")
struct ManifestTests {
    private func manifestJSON() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("droplet.json")
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] ?? [:]
    }

    private func capabilities() throws -> [String] {
        try manifestJSON()["capabilities"] as? [String] ?? []
    }

    @Test("droplet.json asks for screen-capture, which the screenshot corner needs")
    func screenshotNeedsScreenCapture() throws {
        #expect(FringeCornerAction.allCases.contains(.screenshot))
        #expect(try capabilities().contains("screen-capture"))
    }

    @Test("droplet.json still asks for what the edges and the pause shortcut need")
    func keepsExistingCapabilities() throws {
        let caps = try capabilities()
        #expect(caps.contains("accessibility"))
        #expect(caps.contains("global-shortcuts"))
    }

    @Test("droplet.json specifies minAPI 1.22.0 for wash controls and notch wrap")
    func requiresMinAPI122() throws {
        let kit = try manifestJSON()["kit"] as? [String: Any]
        #expect(kit?["minAPI"] as? String == "1.22.0")
    }

    @MainActor
    @Test("FringeDroplet advertises widget with notch-wrap traits")
    func widgetDescriptorTraits() {
        let droplet = FringeDroplet()
        let descriptors = droplet.widgetDescriptors
        #expect(descriptors.count == 1)
        #expect(descriptors.first?.id == FringeDroplet.widgetID)
        #expect(descriptors.first?.layoutTraits.preferredSoloWidth == 415)
        #expect(descriptors.first?.layoutTraits.notchWrap?.headerHeight == 34)
    }
}
