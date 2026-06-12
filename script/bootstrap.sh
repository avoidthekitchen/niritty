#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GHOSTTY_DIR="$ROOT_DIR/Vendor/ghostty"
GHOSTTYKIT_DIR="$GHOSTTY_DIR/macos/GhosttyKit.xcframework"
GHOSTTY_RESOURCES_DIR="$GHOSTTY_DIR/zig-out/share/ghostty"

if [[ ! -d "$GHOSTTY_DIR/.git" && ! -f "$GHOSTTY_DIR/.git" ]]; then
  echo "Ghostty submodule is missing. Run: git submodule update --init --recursive Vendor/ghostty" >&2
  exit 1
fi

"$ROOT_DIR/script/ensure_ghosttykit.sh"

missing=0
for path in \
  "$GHOSTTYKIT_DIR/Info.plist" \
  "$GHOSTTYKIT_DIR/macos-arm64/Headers/module.modulemap" \
  "$GHOSTTYKIT_DIR/macos-arm64/Headers/ghostty.h" \
  "$GHOSTTYKIT_DIR/macos-arm64/libghostty-internal-fat.a" \
  "$GHOSTTY_RESOURCES_DIR/shell-integration" \
  "$GHOSTTY_RESOURCES_DIR/themes"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing required Ghostty artifact: $path" >&2
    missing=1
  fi
done

if [[ "$missing" != "0" ]]; then
  exit 1
fi

echo "Niritty bootstrap complete."
