import Foundation
import Testing
@testable import Fringe

@Suite("Manifest")
struct ManifestTests {
    private func capabilities() throws -> [String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("droplet.json")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        return json?["capabilities"] as? [String] ?? []
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
}
