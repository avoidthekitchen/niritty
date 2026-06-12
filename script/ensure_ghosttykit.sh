#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GHOSTTY_DIR="$ROOT_DIR/Vendor/ghostty"
GHOSTTYKIT_DIR="$GHOSTTY_DIR/macos/GhosttyKit.xcframework"
GHOSTTY_RESOURCES_DIR="$GHOSTTY_DIR/zig-out/share/ghostty"
STAMP_DIR="$ROOT_DIR/.build/niritty"
STAMP_FILE="$STAMP_DIR/ghosttykit-head.txt"
ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$ROOT_DIR/.build/zig-global-cache}"

if [[ ! -d "$GHOSTTY_DIR/.git" && ! -f "$GHOSTTY_DIR/.git" ]]; then
  echo "Ghostty submodule is missing. Run: git submodule update --init --recursive Vendor/ghostty" >&2
  exit 1
fi

cd "$GHOSTTY_DIR"
GHOSTTY_HEAD="$(git rev-parse HEAD)"

has_required_outputs() {
  [[ -f "$GHOSTTYKIT_DIR/Info.plist" ]] &&
    [[ -f "$GHOSTTYKIT_DIR/macos-arm64/Headers/module.modulemap" ]] &&
    [[ -f "$GHOSTTYKIT_DIR/macos-arm64/Headers/ghostty.h" ]] &&
    [[ -f "$GHOSTTYKIT_DIR/macos-arm64/libghostty-internal-fat.a" ]] &&
    [[ -d "$GHOSTTY_RESOURCES_DIR/shell-integration" ]] &&
    [[ -d "$GHOSTTY_RESOURCES_DIR/themes" ]]
}

if [[ "${NIRITTY_GHOSTTYKIT_FORCE_REBUILD:-0}" != "1" ]] &&
  has_required_outputs &&
  [[ -f "$STAMP_FILE" ]] &&
  [[ "$(cat "$STAMP_FILE")" == "$GHOSTTY_HEAD" ]]; then
  echo "GhosttyKit artifacts are current for Ghostty $GHOSTTY_HEAD"
  exit 0
fi

if [[ -x /opt/homebrew/opt/zig@0.15/bin/zig ]]; then
  ZIG_BIN="${ZIG_BIN:-/opt/homebrew/opt/zig@0.15/bin/zig}"
else
  ZIG_BIN="${ZIG_BIN:-zig}"
fi

if ! command -v "$ZIG_BIN" >/dev/null 2>&1; then
  echo "zig is required to build GhosttyKit.xcframework." >&2
  echo "Install Zig, then rerun: script/ensure_ghosttykit.sh" >&2
  exit 127
fi

mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
export ZIG_GLOBAL_CACHE_DIR

"$ZIG_BIN" build \
  -Dapp-runtime=none \
  -Demit-xcframework=true \
  -Demit-macos-app=false \
  -Dxcframework-target=native \
  -Doptimize=ReleaseFast

if ! has_required_outputs; then
  echo "Ghostty build completed but required GhosttyKit artifacts were not produced." >&2
  echo "Expected framework: $GHOSTTYKIT_DIR" >&2
  echo "Expected resources: $GHOSTTY_RESOURCES_DIR" >&2
  exit 1
fi

mkdir -p "$STAMP_DIR"
printf '%s\n' "$GHOSTTY_HEAD" >"$STAMP_FILE"

echo "Built GhosttyKit artifacts from Ghostty $GHOSTTY_HEAD"
