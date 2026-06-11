# Niritty

Niritty is a native macOS workspace environment for terminal and browser windows arranged with Niri-style scrollable columns.

## Language

**Workspace**:
A dynamic work context that contains columns and their windows. A workspace has durable internal identity and can restore its layout, focused window, horizontal scroll position, and workspace root across app launches, but does not need a user-visible name.

**Empty Workspace**:
A workspace with zero columns. Workspace emptiness is structural and does not depend on the content loaded inside a window.

**Workspace Stack**:
The ordered vertical collection of workspaces. Horizontal movement operates within a workspace; vertical movement operates within a column when possible and crosses to adjacent workspaces at column edges. The stack keeps one empty workspace at the bottom, removes extra empty workspaces when they are no longer focused, and persists only non-empty workspaces.

**Workspace Rail**:
A minimal visual indicator of the workspace stack. In v1, the workspace rail shows the active workspace and workspace occupancy, supports click-to-focus, and does not become a full overview.

**Overview**:
A future zoomed-out visual mode for navigating the workspace stack and column strips.

**App Window**:
The native macOS window that contains Niritty's workspace stack. In v1, Niritty has one app window.

**Workspace Root**:
The filesystem directory that anchors a workspace. In v1, it provides a fallback working directory for terminal windows; new dynamic workspaces inherit it from the nearest non-empty workspace above, falling back to the user's home directory. Explicit root editing is deferred.
_Avoid_: Project root, folder, directory

**Column**:
A vertical lane in a workspace's horizontally scrollable layout. A column can host windows and has a current width mode; in v1, each column hosts one visible window.

**Column Width Mode**:
A semantic width assigned to a column relative to the app window. In v1, column width modes are one-third, half, two-thirds, and full; new columns default to half. Width rotation moves to the next larger mode and wraps from full to the smallest mode.
_Avoid_: Pixel width, custom width

**Column Movement**:
The reordering of a column within a workspace's horizontal strip. In v1, moving left or right moves the focused window's column and keeps the focused window focused.

**Column Transfer**:
The movement of a column from one workspace to an adjacent workspace in the workspace stack. In v1, moving up or down transfers the focused window's column and keeps the focused window focused.

**Window Consumption**:
The future action of moving a window into another column so that the column contains multiple windows.

**Window Expulsion**:
The future action of moving a window out of a multi-window column into its own column.

**Window**:
A first-class workspace item hosted inside a column, such as a terminal window or browser window.
_Avoid_: Panel, pane

**Window Chrome**:
The minimal controls and status attached to a window. In v1, every window has visible identity and close controls, with type-specific controls added only where needed.

**Window Insertion**:
The placement of a newly created window. In v1, new windows are inserted in a column to the right of the focused window and become focused.

**Focused Window**:
The window that receives workspace-level actions and normal embedded input. Niritty reserves a small set of workspace shortcuts that take precedence over terminal or browser input.

**Workspace Shortcut**:
A keyboard shortcut reserved for workspace-level commands. In v1, workspace shortcuts use fixed defaults built around `Ctrl+Option`, with configurable keybindings deferred.

**Shortcut Overlay**:
A static help overlay listing the current workspace shortcuts. In v1, it is opened with `Ctrl+Option+Command+/` and does not execute commands.

**Command Palette**:
A future searchable command execution surface.

**Vertical Focus Crossing**:
Movement from one workspace to an adjacent workspace in the workspace stack. Vertical focus crossing targets the same column index when available, falling back to the nearest horizontal position, and updates the target workspace's focused window and horizontal scroll position.

**Terminal Window**:
A window that hosts an interactive terminal session.

**Terminal Current Directory**:
The filesystem directory reported by a terminal window's shell. New terminal windows inherit it from the focused terminal when available; otherwise they use the workspace root.

**Terminal Restore**:
The restoration of a terminal window after app relaunch. In v1, terminal restore starts a fresh shell in the last known terminal current directory rather than restoring the previous process state.

**Exited Terminal Window**:
A terminal window whose shell process has ended. Exited terminal windows remain open until the user closes or restarts them.

**Browser Window**:
A window that hosts an interactive web browsing session.

**Browser Chrome**:
The minimal controls attached to a browser window for navigation. In v1, browser chrome includes an address field, back, forward, and reload or stop.

**Browser Session**:
The shared browsing state used by browser windows, including cookies and website data. In v1, browser windows share one global browser session.

**Browser Start Page**:
The initial page opened by a new browser window. In v1, browser windows open to `about:blank`; configurable workspace start pages are deferred.

**Browser Restore**:
The restoration of a browser window after app relaunch. In v1, browser restore reopens the last committed URL and relies on the shared browser session, without promising full history, scroll, form, or JavaScript runtime restoration.
