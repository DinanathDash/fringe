# Changelog

## [1.0.0] - 2026-11-04

- Initial release of Fringe.
- Control system volume, display brightness, and keyboard backlight by dragging along trackpad edges.
- Single-finger extreme edge dragging with direct drag and optional modifier key guards (Fn, Option, Control, Command).
- Prevent background page scrolling by using single-finger edge tracking instead of two-finger gestures.
- Full compliance with listen-only input tap guidelines (no swallowed or intercepted events).
- Shelf widget now rises beside the camera notch via `ShelfWidgetNotchWrapRow` with zero empty band above it.
- Simplified settings pane with sentence case throughout and a dedicated "Pause gestures" switch.
- Keyboard shortcut button in settings linked directly to Droppy's Shortcuts page via `DropletShortcutsService`.
- Built-in rotating file logger and diagnostic log exporter with zip archiving and Finder reveal.
- Principal bundle loader class `FringePrincipal` conforming to `DropletPrincipal`.
- Native macOS media key dispatch via public APIs, integrating directly with Droppy's notch HUD.
- Enforced unique action assignment across trackpad edges with SF Symbol picker items.
- Configurable edge margin dead zones and sensitivity step distance sliders.
- Tactile haptic feedback on each adjustment step.
