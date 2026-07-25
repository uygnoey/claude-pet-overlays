#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$ROOT/bin"
BIN="$BIN_DIR/claude-pet-overlay"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "claude-pet-overlays currently supports macOS only." >&2
  exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "swiftc is required. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

mkdir -p "$BIN_DIR"
swiftc -O -framework Cocoa "$ROOT/src/ClaudePetOverlay.swift" -o "$BIN"
chmod +x "$BIN"
echo "$BIN"

