# gsCastBarTweaks

gsCastBarTweaks is a Retail World of Warcraft addon for independently placing and sizing the Blizzard target and focus cast bars. It keeps Blizzard's native cast bars and cast events intact; the addon only applies saved visual placement, width, and scale.

## Features

- Independent target and focus cast-bar position, width, and scale controls.
- A draggable minimap button that opens the addon settings.
- Visible, draggable placement previews so bars never need to be positioned blind.
- A one-click action to match the current Blizzard player cast bar's position, effective scale, and width.
- Automatic separation of untouched target and focus defaults when they overlap.
- Saved settings that persist across sessions.

## Installation

1. Install the `gsCastBarTweaks` folder directly in your Retail `Interface/AddOns` directory.
2. Ensure the folder contains `gsCastBarTweaks.toc` at its root.
3. Enable **gsCastBarTweaks** from the character-selection AddOns menu.
4. Log in or run `/reload`.

The addon announces a successful load in chat. Its colored title and icon appear in the AddOns list.

## Configuration

Open the options with the minimap button or through:

`Esc` → `Options` → `AddOns` → `gsCastBarTweaks`

The main page contains all controls:

- Target cast-bar scale, width, horizontal position, and vertical position.
- Focus cast-bar scale, width, horizontal position, and vertical position.
- **Match Player Cast Bar**, which copies the active Blizzard player cast bar's placement, effective scale, and width to both bars.
- **Show positioning previews**, which displays movable target and focus previews.

## Positioning previews

Enable **Show positioning previews** before arranging the bars. Each preview has a cast-bar style, spell icon, label, and progress fill.

- Drag a preview out of combat to save its exact position.
- Use the sliders for precise adjustments or recovery if a bar is intentionally placed off-screen.
- Disable previews after positioning; they are only a configuration aid.

The two previews begin separated so they can be selected individually. If they are intentionally placed together later, gsCastBarTweaks preserves that layout.

## Edit Mode and combat behavior

The addon includes an Edit Mode compatibility layer for its target and focus movers, but the standard Settings page and previews are the recommended configuration path.

Blizzard does not provide a supported API for third-party addons to register independent target and focus cast bars as native Edit Mode systems. gsCastBarTweaks therefore leaves the native cast bars in place and applies its visual adjustments through supported frame APIs.

Position-changing operations are intended for use out of combat. The player-bar matching action and preview dragging are blocked during combat to avoid protected-frame and taint issues.

## Saved settings

The current SavedVariables are:

- `gsCastBarTweaksDB` for target-bar settings and shared preview/minimap settings.
- `gsCastBarTweaksFocusDB` for focus-bar settings.

## Included libraries

The package includes LibStub, CallbackHandler-1.0, and LibEditMode. No separate library installation is required.

## Compatibility

- World of Warcraft Retail interface version `120100`.
- Designed for current Retail target and focus cast-bar frames.
- Does not replace the Blizzard player cast bar or alter cast spell logic.
