# Niritty

Niritty is a planned native macOS workspace environment for terminal and browser windows arranged with Niri-style scrollable columns.

The project is currently in planning. The sections below describe the intended v1 behavior and the scope that is explicitly deferred.

## Concept

Niritty treats terminal and browser surfaces as first-class **Windows** inside a vertically stacked set of dynamic **Workspaces**.

- A **Workspace Stack** is a vertical stack of workspaces.
- A **Workspace** is a horizontal scrollable strip of columns.
- A **Column** is the horizontal layout unit. In v1, each column contains one visible window.
- A **Window** is either a Terminal Window or Browser Window.

The model is inspired by [Niri](https://niri-wm.github.io/niri/): columns move horizontally inside a workspace, and columns can transfer up or down between workspaces. Window consumption, expulsion, and tabbed columns are planned future concepts, not v1 features.

## Planned V1

Niritty v1 should support:

- one native macOS app window
- dynamic workspaces with one empty workspace at the bottom
- automatic cleanup of extra empty workspaces
- terminal windows backed by `libghostty`
- browser windows backed by `WKWebView`
- one global browser session shared by browser windows
- browser windows opening to `about:blank`
- minimal browser chrome: address field, back, forward, reload or stop
- minimal shared window chrome for identity and close controls
- horizontal focus movement across columns
- vertical focus movement across workspaces
- column movement left and right inside a workspace
- column transfer up and down between workspaces
- semantic column width modes: one-third, half, two-thirds, and full
- width rotation to the next larger mode, wrapping from full to the smallest mode
- new columns defaulting to half width
- new windows inserting to the right of the focused window
- a minimal workspace rail with click-to-focus
- a static shortcut overlay
- persistence for non-empty workspaces
- restoration of browser URLs
- restoration of terminal windows as fresh shells in their last known directory

## Planned Shortcuts

V1 uses fixed workspace shortcuts. Configurable keybindings are deferred, but the command model should be designed so remapping can be added later.

- `Ctrl+Shift+Arrow`: move focus
- `Ctrl+Shift+Command+Arrow`: move or transfer the focused column
- `Ctrl+Shift+/`: show the shortcut overlay

## Deferred Beyond V1

The following are intentionally out of v1 scope:

- Command Palette
- Niri-style Overview
- touchpad and mouse gestures
- Window Consumption and Window Expulsion
- tabbed or stacked multi-window columns
- configurable width options
- arbitrary/manual column widths
- configurable keybindings
- configurable Browser Start Page
- browser extension support
- per-workspace browser sessions or profiles
- automatic Workspace Root editing
- automation, API, or CLI surface
- terminal process resurrection
- multiple native macOS app windows
- notarized distribution, installer, or auto-updater

## Architecture Direction

V1 is planned as a fresh native macOS app shell, not a fork of CMUX or Ghostty.

- App shell: native macOS
- Terminal engine: `libghostty`
- Browser engine: `WKWebView`
- Layout engine: custom Niri-inspired Workspace/Column model

See [docs/prd-v1.md](docs/prd-v1.md) for the v1 product requirements draft.
