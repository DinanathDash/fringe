# Changelog

## [1.0.5] - 2026-11-05

- Updated shelf widget with a two-row layout: corners in the first row (Top-left, Top-right, Bottom-left, Bottom-right) and edges in the second row (Left, Top, Right, Bottom) separated into distinct rounded dashed border containers, with content height increased to 186 pt.
- Added Corner double-tap gestures with configurable actions for all four corners:
  - Corner mute: double-tap a corner (default top-right) to mute/unmute your Mac.
  - Screenshots: double-tap a corner (default top-left) to capture a full screenshot directly saved to your Desktop folder (`Screenshot YYYY-MM-DD at h.mm.ss a.png`).
  - Play or pause: double-tap a corner to toggle media playback.
  - Also configurable to Off for any corner in Settings.
- Added "Skip tracks" sliding action on trackpad edges with dedicated icon (`forward.end.fill`):
  - Slide along the edge to skip by exactly one track per swipe (forward/up or backward/down).
  - Edges are dedicated to sliding gestures to eliminate gesture conflicts with corner double-taps.
- Added explanatory captions to the "Accuracy", "Corners", and "Edges" section headers in Settings to explain edge width, start zone, and travel per step without custom slider rows.
- Increased Accessibility status ("Granted" / "Required") font size in Settings for better legibility.
- Improved edge drag palm rejection so active single-finger gestures are not cancelled prematurely by trackpad perimeter resting flags.
- Fixed bottom edge swipe from right to left (decrement action): added generous start margin tolerance, prioritized horizontal motion in shared corner disambiguation, and expanded horizontal inward displacement so natural wrist rotation arcs don't cancel gestures.
- Added configurable "Start zone" slider in Settings (15% to 50%, default 33%) allowing users to customize how far from each corner a drag can start.
- Added Accessibility permission status row in Settings with an "Open Settings" button and automatic listener retry as soon as Accessibility is granted.
- Added "Needs permission" status indicator in the shelf widget header when Accessibility is missing.
- Added `.bottom` edge column to the shelf widget display.
- Added bottom edge configuration with bi-directional adjustment (slide right from the left third to increase, slide left from the right third to decrease).

## [1.0.4] - 2026-11-05

- Fixed sliding down the left edge from the top left corner, which always went to the top edge: in a corner two edges share, the way you slide now picks the edge.

## [1.0.3] - 2026-11-05

- Fixed a crash in Droppy while you touched the trackpad: Fringe now reads trackpad gestures on the main thread again, as AppKit requires.

## [1.0.2] - 2026-11-04

- First release in the Droplet Store: slide along your trackpad's edges to change the volume, display brightness and keyboard backlight.
- Runs on Droppy 15.3 and later, where it needed a Droppy that had not shipped yet.
- Fringe listens to the trackpad on a thread of its own, only while gestures are on.
- Settings are kept with Fringe's own preferences in Droppy.
- The settings page uses Droppy's native pop-ups and sliders, and the edge width slider covers exactly the range Fringe uses.
- The shelf widget sits on Droppy's padding, and its Active switch and the settings page always agree.
- Logs are exported without starting a process inside Droppy.

## [1.0.1] - 2026-11-04

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
