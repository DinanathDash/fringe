# Fringe

Control system volume, display brightness, keyboard backlight, and track playback by sliding the edges or double-tapping the corners of your trackpad.

## The idea

Fringe turns the idle outer margins of your MacBook trackpad or Magic Trackpad into sliders and quick triggers. Rather than reaching for function keys or opening Control Center, you slide along an edge, or double-tap a corner to mute, capture a screenshot, or toggle playback.

## Why it matters

It is a fluid, tactile way to control volume, brightness, and media without breaking your focus or moving your hands. Fringe sends the same hardware keys your keyboard does, so macOS changes the level and Droppy's notch HUD shows it.

## How it works

1. **Start in a corner, slide along the edge**: the left and right edges start in their bottom third (slide up) or top third (slide down). The top edge starts in its left third (slide right) or a designated stretch from 55% to 85% across (slide left), leaving the top right corner to Notification Center. The bottom edge starts in its left third (slide right) or right third (slide left). In a corner two edges share, such as the top left or bottom corners, the first couple of millimetres you slide pick the edge: up or down for the side edge, sideways for the top or bottom one. A touch that lands anywhere else never starts a drag.
2. **Double-tap corners**: double-tap any trackpad corner to trigger quick actions:
   - **Corner mute**: double-tap a corner (default top-right) to mute/unmute your Mac.
   - **Screenshots**: double-tap a corner (default top-left) to capture a full screenshot directly saved to your Desktop folder (`Screenshot YYYY-MM-DD at h.mm.ss a.png`).
   - **Play or pause**: double-tap a corner to toggle media playback.
   - Each of the four corners can be configured to any of these actions or Off.
3. **Track edge controls**:
   - **Skip tracks**: slide once along an edge set to Skip tracks to skip forward (slide right/up) or backward (slide left/down) by a single track per swipe. Edges are strictly reserved for sliding gestures so they never conflict with taps or corner actions.
4. **One finger only**: a resting palm or a second finger stops a drag and can never start one, and a drag that wanders into the middle of the trackpad stops. One-finger drags never scroll the page under the pointer.
5. **An optional key**: ask for Fn (Globe), Option, Control or Command to be held while you drag.
6. **Media keys**: each step posts the hardware volume, brightness, media or keyboard backlight key (`NX_KEYTYPE` system events, `NSEvent.otherEvent`), public API only.
7. **Listen-only**: Fringe's CoreGraphics event tap watches trackpad gesture events in `.listenOnly` mode, and only while gestures are on. It never sees a key and never swallows, delays or alters an event.
8. **One action per edge**: Volume, Display brightness, Keyboard backlight, and Skip tracks each live on at most one edge; an edge can also be off.
9. **Haptics**: a click from the Force Touch trackpad at every step or trigger, which you can turn off.
10. **A shortcut**: pause or resume Fringe from a shortcut you set on Droppy's Shortcuts page.
11. **Logs**: a rotating log in `~/Library/Logs/Fringe/`, exported as a zip or shown in Finder from Settings.

## Surfaces

- **Shelf widget**: what each corner and edge does in a clean two-row layout (first row corners, second row edges), and an Active switch that pauses every gesture. In a row with other widgets it shows the actions as symbols.
- **Settings pane**: permissions status, gestures switch, corner actions, each edge's action, key to hold, edge width, start zone, travel per step, haptics, and logs.

## Permissions

- **Accessibility**: Droppy's trust, which the listen-only event tap and the posted media keys need.
- **Global shortcuts**: the pause shortcut on Droppy's Shortcuts page.

Fringe makes no network connection.
