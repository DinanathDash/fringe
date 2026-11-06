import DroppyKit
import DroppyKitHarness
import Testing
@testable import Fringe

/// Accessibility and the listener are faked, so no real event tap is created.
@MainActor
@Suite("Engine")
struct EngineTests {
    final class FakeListener: FringeListening {
        let world: World
        private(set) var isRunning = false
        init(world: World) { self.world = world }
        func start() { isRunning = world.listenerCanStart; world.starts += 1 }
        func stop() { isRunning = false }
        func update(_ config: FringeGestureConfig) {}
    }

    final class World {
        var trusted = false
        var listenerCanStart = true
        var starts = 0
    }

    let world = World()
    let host = makeHarnessHost()

    func makeEngine() -> FringeEngine {
        let world = world
        return FringeEngine(
            isAccessibilityTrusted: { world.trusted },
            makeListener: { _, _ in FakeListener(world: world) }
        )
    }

    @Test("Without Accessibility the engine doesn't listen and says so")
    func withoutAccessibility() {
        let engine = makeEngine()
        engine.start(with: host)

        #expect(engine.isAccessibilityGranted == false)
        #expect(engine.isListening == false)
        engine.stop()
    }

    @Test("Granting Accessibility later starts the listener")
    func grantingLaterStarts() {
        let engine = makeEngine()
        engine.start(with: host)
        world.trusted = true
        engine.refreshAccessibilityStatus()

        #expect(engine.isAccessibilityGranted)
        #expect(engine.isListening)
        engine.stop()
    }

    @Test("A listener that failed to start is tried again, not kept")
    func failedListenerIsRetried() {
        world.trusted = true
        world.listenerCanStart = false
        let engine = makeEngine()
        engine.start(with: host)
        #expect(engine.isListening == false)

        world.listenerCanStart = true
        engine.refreshAccessibilityStatus()

        #expect(engine.isListening)
        engine.stop()
    }

    @Test("Pausing Fringe stops the listener; resuming starts it again")
    func pauseAndResume() {
        world.trusted = true
        let engine = makeEngine()
        engine.start(with: host)
        #expect(engine.isListening)

        engine.settings.isEnabled = false
        #expect(engine.isListening == false)

        engine.settings.isEnabled = true
        #expect(engine.isListening)
        engine.stop()
    }

    @Test("Stopping the engine stops the listener")
    func stopStops() {
        world.trusted = true
        let engine = makeEngine()
        engine.start(with: host)
        engine.stop()

        #expect(engine.isListening == false)
    }

    @Test("Settings are saved in Droppy's preferences and loaded on the next start")
    func settingsPersist() {
        world.trusted = true
        let first = makeEngine()
        first.start(with: host)
        first.settings.startZoneFraction = 0.45
        first.stop()

        let second = makeEngine()
        second.start(with: host)
        #expect(second.settings.startZoneFraction == 0.45)
        second.stop()
    }
}

/// Built by hand because DropletHarness has no public initializer.
@MainActor
func makeHarnessHost() -> DropletHost {
    let recorder = HarnessRecorder()
    let id = FringeDroplet.id
    return DropletHost(
        grantedCapabilities: [.accessibility, .globalShortcuts],
        preferences: HarnessPreferencesService(dropletID: id, recorder: recorder),
        environment: HarnessEnvironmentService(appVersion: "16.0.1", dropletID: id),
        log: HarnessLogService(recorder: recorder),
        installState: HarnessInstallStateService(),
        hud: HarnessHUDService(recorder: recorder),
        shelf: HarnessShelfService(recorder: recorder),
        liveActivity: HarnessLiveActivityService(recorder: recorder),
        notchSurface: HarnessNotchSurfaceService(recorder: recorder, dropletID: id),
        shortcuts: HarnessShortcutsService(recorder: recorder),
        workspace: HarnessWorkspaceService(recorder: recorder),
        feedback: HarnessFeedbackService(recorder: recorder),
        permissions: HarnessPermissionsService(recorder: recorder)
    )
}
