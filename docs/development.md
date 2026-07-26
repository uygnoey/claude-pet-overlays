# Development

**English** · [한국어](development.ko.md) · [Español](development.es.md) · [日本語](development.ja.md)

This repository is intentionally small: Claude Code hooks call a shell script, the script builds or launches one native Swift binary, and the binary renders the overlay with bundled PNG frames.

## Project Layout

| Path | Purpose |
| --- | --- |
| `.claude-plugin/plugin.json` | Claude Code plugin metadata. |
| `.claude-plugin/marketplace.json` | Local marketplace metadata. |
| `hooks/hooks.json` | Claude Code hook registration. |
| `scripts/notify.sh` | Hook entrypoint. Normalizes events, builds on first use, and launches the overlay in the background. |
| `scripts/build.sh` | Builds `src/ClaudePetOverlay.swift` with `swiftc`. |
| `src/ClaudePetOverlay.swift` | AppKit overlay, language handling, token scanning, gauge rendering, and animation selection. |
| `frames/` | Bundled Claude Pet animation frames. |
| `frames/frames-manifest.json` | Source and frame inventory for bundled assets. |
| `bin/` | Local build output. Ignored by git. |

## Build

```bash
bash scripts/build.sh
```

The build script:

1. Requires macOS.
2. Requires `swiftc`.
3. Compiles `src/ClaudePetOverlay.swift` with the Cocoa framework.
4. Writes `bin/claude-pet-overlay`.

## Local Test

```bash
bash scripts/notify.sh stop
bash scripts/notify.sh ask
CLAUDE_PET_OVERLAY_TIMEOUT=0 bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_MESSAGE="Custom message" bash scripts/notify.sh ask
```

`notify.sh` exits successfully even when the local build fails, because hook failures should not interrupt Claude Code. Build errors are appended to:

```text
${TMPDIR:-/tmp}/claude-pet-overlays.log
```

## Hook Lifecycle

Claude Code runs commands from `hooks/hooks.json`:

```json
{
  "Stop": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\" stop",
  "PreToolUse AskUserQuestion": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\" ask"
}
```

`notify.sh` launches the native binary with:

```bash
bin/claude-pet-overlay --root "$ROOT" --event "$EVENT" --timeout "$TIMEOUT"
```

If `CLAUDE_PET_OVERLAY_MESSAGE` is set, it also passes:

```bash
--message "$CLAUDE_PET_OVERLAY_MESSAGE"
```

The native app uses a temporary lock at:

```text
${TMPDIR:-/tmp}/claude-pet-overlays.lock
```

If another overlay is already running, the new process exits without showing a second overlay.

## Assets

Animation frames live under `frames/<state>/NN.png`.

The current manifest expects:

| State | Frames |
| --- | --- |
| `failed` | `8` |
| `idle` | `6` |
| `jumping` | `5` |
| `review` | `6` |
| `running` | `6` |
| `running-left` | `8` |
| `running-right` | `8` |
| `waiting` | `6` |
| `waving` | `4` |

The overlay loads `frames/<selected-state>` and falls back to `frames/idle` when the selected state directory is missing.

## Troubleshooting

### Nothing appears

Run:

```bash
bash scripts/build.sh
bash scripts/notify.sh stop
```

Then inspect:

```bash
tail -n 100 "${TMPDIR:-/tmp}/claude-pet-overlays.log"
```

### `swiftc` is missing

Install Xcode Command Line Tools:

```bash
xcode-select --install
```

### Token gauges are missing

The overlay still appears without usage data. Gauges require one of:

- Claude Code OAuth credentials available in `~/.claude/.credentials.json`
- Claude Code credentials available in macOS Keychain
- Recent Claude Code JSONL logs under `~/.claude/projects` or `~/.config/claude/projects`

### Language is wrong

Force a language for a single run:

```bash
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop
```

Supported values include `en`, `ko`, and `es`.
