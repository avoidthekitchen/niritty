#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GHOSTTY_DIR="$ROOT_DIR/Vendor/ghostty"
GHOSTTYKIT_DIR="$GHOSTTY_DIR/macos/GhosttyKit.xcframework"
ZIG_GLOBAL_CACHE_DIR="${ZIG_GLOBAL_CACHE_DIR:-$ROOT_DIR/.build/zig-global-cache}"

if [[ ! -d "$GHOSTTY_DIR/.git" && ! -f "$GHOSTTY_DIR/.git" ]]; then
  echo "Ghostty submodule is missing. Run: git submodule update --init --recursive Vendor/ghostty" >&2
  exit 1
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

if [[ -d "$GHOSTTYKIT_DIR" && "${NIRITTY_GHOSTTYKIT_FORCE_REBUILD:-0}" != "1" ]]; then
  echo "GhosttyKit.xcframework already exists: $GHOSTTYKIT_DIR"
  exit 0
fi

cd "$GHOSTTY_DIR"
mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
export ZIG_GLOBAL_CACHE_DIR

"$ZIG_BIN" build \
  -Dapp-runtime=none \
  -Demit-xcframework=true \
  -Demit-macos-app=false \
  -Dxcframework-target=native \
  -Doptimize=ReleaseFast

if [[ ! -d "$GHOSTTYKIT_DIR" ]]; then
  echo "GhosttyKit build completed but $GHOSTTYKIT_DIR was not produced." >&2
  exit 1
fi

echo "Built GhosttyKit.xcframework from Ghostty $(git rev-parse HEAD)"
