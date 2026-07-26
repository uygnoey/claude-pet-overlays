#!/usr/bin/env bash
set -euo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EVENT="${1:-stop}"
TIMEOUT="${CLAUDE_PET_OVERLAY_TIMEOUT:-0}"
BIN="$ROOT/bin/claude-pet-overlay"
LOG="${TMPDIR:-/tmp}/claude-pet-overlays.log"

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

case "$EVENT" in
  ask)
    ;;
  *)
    EVENT="stop"
    ;;
esac

if [[ ! -x "$BIN" ]]; then
  if ! bash "$ROOT/scripts/build.sh" >/dev/null 2>>"$LOG"; then
    exit 0
  fi
fi

CMD=("$BIN" --root "$ROOT" --event "$EVENT" --timeout "$TIMEOUT")
if [[ -n "${CLAUDE_PET_OVERLAY_MESSAGE:-}" ]]; then
  CMD+=(--message "$CLAUDE_PET_OVERLAY_MESSAGE")
fi

nohup "${CMD[@]}" >>"$LOG" 2>&1 &

exit 0
