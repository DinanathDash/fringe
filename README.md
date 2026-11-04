# Fringe

Control system volume, display brightness, and keyboard backlight by dragging along the edges of your trackpad.

## The idea

Fringe transforms the idle outer margins of your MacBook trackpad or Magic Trackpad into tactile physical sliders. Rather than reaching for function keys or opening Control Center, dragging along the left, right, or top edge of your trackpad glides smoothly through system controls.

## Why it matters

It provides a fluid, tactile way to scrub volume and display brightness without breaking your focus or repositioning your hands. Because it uses native macOS media key events, changes seamlessly trigger Droppy's built-in notch HUD for immediate visual feedback.

## How it works

1. **Extreme edge dragging**: Dragging a finger along the outer margin of your trackpad adjusts controls smoothly. Because edge drags operate with a single finger, macOS never synthesizes scroll wheel events, preventing underlying scrollable web pages or documents from moving.
2. **Direct drag & modifier guards**: Works via direct drag with zero keys required, or with an optional modifier key guard (`Fn` / Globe, `⌥ Option`, `⌃ Control`, or `⌘ Command`) for intentional activation.
3. **Extreme origin boundaries**: Gestures must originate from within the outer boundary zone (defaulting to 5% of trackpad width). Touches that begin in the center of the trackpad are automatically disqualified.
4. **Native media key dispatch**: Fringe posts standard `NX_KEYTYPE` system events using 100% public APIs (`NSEvent.otherEvent`), matching macOS hardware key presses so that macOS and Droppy's native notch HUD handle volume and brightness adjustments natively.
5. **Listen-only input tap**: Fringe's CoreGraphics event tap operates exclusively in `.listenOnly` mode, ensuring it never swallows, delays, or alters system events.
6. **Unique action enforcement**: Each active action (Volume, Display brightness, Keyboard backlight) is guaranteed unique across edges, preventing conflicting bindings.
7. **Haptic feedback**: Subtle alignment clicks accompany each adjustment step on supported trackpads.
8. **Global shortcuts**: Configurable global shortcut registered through `DropletShortcutsService` to toggle or pause gestures at any time from Droppy's Shortcuts page.
9. **Diagnostics & rotating logs**: Built-in rotating file logger in `~/Library/Logs/Fringe/fringe.log` with a one-click zip export and Finder reveal button in Settings.

## Surfaces

- **Shelf widget**: Sits directly beside the notch with `ShelfWidgetNotchWrapRow` so there is no empty band above it. Shows current edge assignments, active gesture indicators, and a quick toggle to pause/resume edge monitoring. Supports both standalone and compact shelf layouts.
- **Settings pane**: Full configuration including a "Pause gestures" switch, keyboard shortcut link to Droppy's Shortcuts page, edge action pickers with SF symbols, edge margin fraction slider, sensitivity step slider, modifier key guard selection, haptic feedback toggles, and diagnostic log export.

## Permissions

Fringe declares the following capabilities:

- **Accessibility**: Required to listen to indirect trackpad gesture events via a listen-only CoreGraphics event tap.
- **Global shortcuts**: Allows registering the global toggle shortcut on Droppy's Shortcuts page.
