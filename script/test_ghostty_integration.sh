#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_RESOURCES="$ROOT_DIR/dist/Niritty.app/Contents/Resources/ghostty"
RETURN_MARKER="$(mktemp -u /tmp/niritty-return.XXXXXX)"
DELETE_MARKER="$(mktemp -u /tmp/niritty-delete.XXXXXX)"
DELETE_MARKER_WITH_SUFFIX="${DELETE_MARKER}x"
PASTE_MARKER="$(mktemp -u /tmp/niritty-paste.XXXXXX)"
FOCUS_LEFT_DIR="$(mktemp -d /tmp/niritty-focus-left.XXXXXX)"
FOCUS_RIGHT_DIR="$(mktemp -d /tmp/niritty-focus-right.XXXXXX)"
FOCUS_MARKER="niritty-focus-marker"

cd "$ROOT_DIR"
trap 'pkill -x Niritty >/dev/null 2>&1 || true; rm -f "$RETURN_MARKER" "$DELETE_MARKER" "$DELETE_MARKER_WITH_SUFFIX" "$PASTE_MARKER"; rm -rf "$FOCUS_LEFT_DIR" "$FOCUS_RIGHT_DIR"' EXIT

script/test.sh
script/build_and_run.sh --verify

osascript -e 'tell application "System Events" to tell process "Niritty" to click button 1 of group 1 of window 1'
sleep 1

if ! pgrep -x Niritty >/dev/null; then
  echo "Niritty exited after clicking New Terminal Window." >&2
  exit 1
fi

osascript \
  -e 'tell application "System Events"' \
  -e 'tell process "Niritty"' \
  -e "keystroke \"touch $RETURN_MARKER\"" \
  -e 'key code 36' \
  -e 'delay 1' \
  -e "keystroke \"touch ${DELETE_MARKER}x\"" \
  -e 'key code 51' \
  -e 'key code 36' \
  -e 'delay 1' \
  -e 'end tell' \
  -e 'end tell'

if [[ ! -f "$RETURN_MARKER" ]]; then
  echo "Return key did not execute a typed terminal command." >&2
  exit 1
fi

if [[ ! -f "$DELETE_MARKER" ]]; then
  echo "Delete key did not edit the typed terminal command before Return." >&2
  exit 1
fi

if [[ -f "$DELETE_MARKER_WITH_SUFFIX" ]]; then
  echo "Delete key failed; unexpected marker still had its deleted suffix." >&2
  exit 1
fi

printf 'touch %s' "$PASTE_MARKER" | pbcopy
osascript \
  -e 'tell application "System Events"' \
  -e 'tell process "Niritty"' \
  -e 'keystroke "v" using {command down}' \
  -e 'key code 36' \
  -e 'delay 1' \
  -e 'end tell' \
  -e 'end tell'

if [[ ! -f "$PASTE_MARKER" ]]; then
  echo "Clipboard paste did not execute a pasted terminal command." >&2
  exit 1
fi

osascript \
  -e 'tell application "System Events"' \
  -e 'tell process "Niritty"' \
  -e "keystroke \"cd $FOCUS_LEFT_DIR\"" \
  -e 'key code 36' \
  -e 'delay 1' \
  -e 'click button 1 of group 1 of window 1' \
  -e 'delay 1' \
  -e "keystroke \"cd $FOCUS_RIGHT_DIR\"" \
  -e 'key code 36' \
  -e 'delay 1' \
  -e 'key code 123 using {control down, shift down}' \
  -e 'delay 1' \
  -e "keystroke \"touch $FOCUS_MARKER\"" \
  -e 'key code 36' \
  -e 'delay 1' \
  -e 'end tell' \
  -e 'end tell'

if [[ ! -f "$FOCUS_LEFT_DIR/$FOCUS_MARKER" ]]; then
  echo "Terminal focus-left shortcut did not route typing to the left terminal." >&2
  exit 1
fi

if [[ -f "$FOCUS_RIGHT_DIR/$FOCUS_MARKER" ]]; then
  echo "Terminal focus-left shortcut left typing in the right terminal." >&2
  exit 1
fi

if [[ ! -d "$APP_RESOURCES/shell-integration" ]]; then
  echo "Missing packaged Ghostty shell integration resources at $APP_RESOURCES/shell-integration" >&2
  exit 1
fi

if [[ ! -d "$APP_RESOURCES/themes" ]]; then
  echo "Missing packaged Ghostty theme resources at $APP_RESOURCES/themes" >&2
  exit 1
fi

echo "Ghostty integration tests passed."
