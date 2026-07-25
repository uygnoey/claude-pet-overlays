#!/usr/bin/env bash
set -euo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
EVENT="${1:-stop}"
TIMEOUT="${CLAUDE_PET_OVERLAY_TIMEOUT:-18}"
BIN="$ROOT/bin/claude-pet-overlay"
LOG="${TMPDIR:-/tmp}/claude-pet-overlays.log"

if [[ "$(uname -s)" != "Darwin" ]]; then
  exit 0
fi

case "$EVENT" in
  ask)
    MESSAGE="${CLAUDE_PET_OVERLAY_MESSAGE:-Claude is waiting for your answer}"
    ;;
  *)
    EVENT="stop"
    MESSAGE="${CLAUDE_PET_OVERLAY_MESSAGE:-Claude is ready for input}"
    ;;
esac

if [[ ! -x "$BIN" ]]; then
  if ! bash "$ROOT/scripts/build.sh" >/dev/null 2>>"$LOG"; then
    exit 0
  fi
fi

nohup "$BIN" \
  --root "$ROOT" \
  --event "$EVENT" \
  --message "$MESSAGE" \
  --timeout "$TIMEOUT" \
  >>"$LOG" 2>&1 &

exit 0

