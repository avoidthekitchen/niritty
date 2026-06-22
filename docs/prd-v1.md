# Niritty V1 PRD

## Summary

Niritty v1 is a native macOS workspace environment that treats terminal and browser windows as first-class objects inside a Niri-inspired scrollable-column layout. The goal is to prove the core workspace model before adding command palettes, overview mode, gestures, extensions, tabs, or configuration-heavy features.

When implementation details are ambiguous, use [Niri](https://github.com/niri-wm/niri) and the [Niri workspace docs](https://niri-wm.github.io/niri/Workspaces.html#addressing-workspaces-by-index) as directional references, as long as they do not conflict with Niritty's explicit design decisions in this PRD.

## Goals

- Provide one native macOS app window containing a dynamic workspace stack.
- Let users create and manage Terminal Windows and Browser Windows as peers.
- Preserve Niri-style spatial behavior: horizontal column strips stacked vertically as workspaces.
- Keep v1 keyboard-first while retaining enough visible UI for discoverability.
- Persist and restore useful layout state without promising full process or browser runtime restoration.
- Keep the model testable outside the native UI.

## Implementation Status and Clarifications

The v1 implementation slices are complete. The native app now provides the Workspace Stack model and UI, WKWebView Browser Windows, libghostty Terminal Windows, fixed workspace shortcuts, Column Movement and Column Transfer, semantic Column Width Modes, the Workspace Rail, the Shortcut Overlay, and persistence and restore.

Delivery established these implementation details without expanding product scope:

- Ghostty is vendored as a pinned `Vendor/ghostty` submodule. Bootstrap builds `GhosttyKit.xcframework` locally instead of committing generated framework artifacts.
- The current Ghostty bootstrap and generated xcframework validation support Apple Silicon. Intel Mac support remains outside the completed v1 implementation.
- Reserved workspace shortcuts are handled at the app and embedded-surface boundaries, so focus, movement, transfer, and overlay commands continue to work while embedded terminal or browser content owns keyboard focus.
- Terminal Restore clears the exited-process flag and starts a fresh shell from persisted directory metadata. It does not resurrect the previous process.
- Browser Restore uses the last committed URL with the shared website data store. It does not restore browser runtime state.

## Non-Goals

- Command Palette.
- Niri-style Overview.
- Touchpad and mouse gestures.
- Window Consumption and Window Expulsion.
- Tabbed or stacked multi-window Columns.
- Configurable width options or arbitrary/manual column widths.
- Configurable keybindings.
- Configurable Browser Start Page.
- Browser extension support.
- Per-workspace browser sessions or profiles.
- Automatic Workspace Root editing.
- Automation, API, or CLI surface.
- Terminal process resurrection.
- Multiple native macOS app windows.
- Notarized distribution, installer, or auto-updater.

## Core Concepts

Niritty uses the canonical language in `CONTEXT.md`.

- **Workspace Stack**: the ordered vertical collection of workspaces.
- **Workspace**: a dynamic work context containing columns and windows.
- **Column**: the horizontal layout unit within a workspace.
- **Window**: a first-class item hosted in a column, either a Terminal Window or Browser Window.

In v1, each Column hosts one visible Window. The data model should remain future-ready for multi-window Columns, but v1 behavior should enforce the simpler invariant.

## Workspace Behavior

The Workspace Stack is dynamic.

- The stack always keeps one Empty Workspace at the bottom.
- Opening a Window on the bottom Empty Workspace creates a new Empty Workspace below it.
- Extra Empty Workspaces are removed when they are no longer focused.
- Empty Workspace means zero Columns; window content such as `about:blank` does not make a Workspace empty.
- V1 persists only non-empty Workspaces, then recreates the bottom Empty Workspace on launch.

Each Workspace remembers:

- focused Window
- horizontal scroll position
- Columns and their order
- Workspace Root

Workspace Roots are passive in v1:

- the first Workspace Root defaults to the user's home directory
- new dynamic Workspaces inherit the Workspace Root from the nearest non-empty Workspace above
- Terminal Windows can use Terminal Current Directory for new-terminal inheritance
- explicit root editing is deferred

## Focus and Movement

Focus is spatial.

- `Ctrl+Shift+Left/Right` moves focus across columns in the current Workspace.
- `Ctrl+Shift+Up/Down` moves focus vertically.
- Vertical focus crossing targets the same column index when available, falling back to nearest horizontal position.
- Crossing into a Workspace updates that Workspace's focused Window and horizontal scroll position.
- Focus movement uses minimal scroll to reveal the focused Window.

Columns are the layout units that move.

- `Ctrl+Shift+Command+Left/Right` reorders the focused Window's Column within the current Workspace.
- `Ctrl+Shift+Command+Up/Down` transfers the focused Window's Column to the adjacent Workspace.
- Focus follows the moved or transferred Column.
- Moving down into the bottom Empty Workspace creates a new Empty Workspace below it.

## Column Width

V1 uses semantic width modes:

- one-third
- half
- two-thirds
- full

New Columns default to half width. Width rotation moves to the next larger mode and wraps from full to the smallest mode.

Configurable width sets and arbitrary/manual column widths are deferred.

## Window Creation

New Windows are inserted to the right of the Focused Window and become focused.

If the current Workspace is empty, the new Window creates the first Column in that Workspace.

V1 Window types:

- Terminal Window
- Browser Window

Both Window types share core lifecycle actions:

- create
- focus
- close
- restore
- participate in Column Movement and Column Transfer
- participate in Column Width Mode rotation through their containing Column

## Terminal Windows

Terminal Windows are backed by `libghostty`.

Use [CMUX](https://github.com/manaflow-ai/cmux) as the main reference for feasibility and integration shape because it is a native macOS app that embeds Ghostty-style terminal surfaces. Niritty should not inherit CMUX's AI-agent or mobile-sync product scope, but its terminal embedding approach is relevant prior art.

New Terminal Window directory precedence:

1. Focused Terminal Window's Terminal Current Directory, when known.
2. Workspace Root.
3. User's home directory.

Terminal Restore:

- restore layout position and Column Width Mode
- start a fresh shell
- use last known Terminal Current Directory when available
- do not restore previous process state

When a terminal process exits:

- keep the Terminal Window open
- show an exited state
- allow the user to close or restart it

## Browser Windows

Browser Windows are backed by `WKWebView`.

V1 behavior:

- new Browser Windows open to `about:blank`
- all Browser Windows share one global Browser Session
- Browser Chrome includes address field, back, forward, and reload or stop
- Browser Restore reopens the last committed URL
- cookies and website data persist through the shared Browser Session

V1 does not promise:

- back/forward history restore
- scroll position restore
- form state restore
- JavaScript runtime restore
- per-workspace profiles
- browser extensions

## Visible UI

V1 should not be keyboard-only.

Required visible surfaces:

- minimal app chrome or toolbar for creating Terminal and Browser Windows
- Window Chrome with identity and close controls
- Browser Chrome for browser navigation
- Workspace Rail showing workspace occupancy and active workspace
- Shortcut Overlay listing fixed workspace shortcuts

Workspace Rail:

- shows active Workspace
- shows empty vs non-empty Workspaces
- supports click-to-focus
- does not show live thumbnails
- does not support drag/drop or overview interactions

Shortcut Overlay:

- opened with `Ctrl+Shift+/`
- lists fixed workspace shortcuts
- does not execute commands
- is distinct from the deferred Command Palette

## Architecture Direction

V1 should be implemented as a fresh native macOS app shell:

- native macOS app shell
- `libghostty` for Terminal Windows
- `WKWebView` for Browser Windows
- custom Workspace/Column layout model

Niri and its workspace documentation are the reference for resolving ambiguity in the spatial model, especially around positional workspace addressing and vertical workspace navigation, unless Niritty has an explicit conflicting decision in this PRD.

CMUX is the reference project for proving that native macOS plus Ghostty-style terminal embedding is viable. It should be used as integration prior art, not as a product-scope template.

Implementation should avoid coupling domain state transitions directly to native views. Workspace, Column, Window, focus, movement, transfer, cleanup, width rotation, and restore behavior should be testable as pure model logic.

## Suggested Milestones

1. Pure model tests for Workspace Stack, Workspace, Column, Window, focus, movement, transfer, cleanup, width rotation, and restore.
2. Native layout prototype with fake Terminal and Browser placeholder views.
3. `WKWebView` Browser Window integration.
4. `libghostty` Terminal Window integration.
5. Persistence and restore pass.
6. README and user-facing documentation pass.

## V1 Success Criteria

V1 is successful when a user can:

- launch one native macOS app window
- use a dynamic Workspace Stack with one Empty Workspace at the bottom
- create Terminal and Browser Windows
- navigate focus with `Ctrl+Shift+Arrow`
- move and transfer Columns with `Ctrl+Shift+Command+Arrow`
- rotate Column Width Mode
- use a minimal Workspace Rail
- use a static Shortcut Overlay
- persist and restore non-empty Workspaces
- reopen Browser Windows to their last committed URLs
- restore Terminal Windows as fresh shells in their last known directories
- understand supported and deferred scope from the README
