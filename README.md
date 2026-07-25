# Claude Pet Overlays

Native macOS Claude Code plugin that shows a fullscreen overlay when Claude is ready for input or waiting on a question.

The overlay centers Patch from `uygnoey/claude-pet` with live token gauges. Patch animates from the current token state:

- under 50%: ready/review animation
- 50-84%: waiting animation
- 85% and above: failed/panic animation

The overlay UI supports English, Korean, and Spanish. It auto-detects `~/.claude_pet.json` language settings and macOS preferred languages. You can force one:

```bash
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_LANG=en bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_LANG=es bash scripts/notify.sh stop
```

## Install

```bash
claude plugin marketplace add https://github.com/uygnoey/claude-pet-overlays.git
claude plugin install claude-pet-overlays
```

Restart Claude Code after installing.

## Requirements

- macOS
- Xcode Command Line Tools for the first local build:

```bash
xcode-select --install
```

The plugin builds a small native Swift/AppKit binary on first use and caches it in `bin/`.

## Test

```bash
bash scripts/notify.sh stop
bash scripts/notify.sh ask
```

Click anywhere, press any key, or wait for the timeout to dismiss the overlay.

Set `CLAUDE_PET_OVERLAY_TIMEOUT=0` to keep it visible until dismissed.

## Token Status

The overlay uses the same priority as Claude Pet:

1. Claude Code OAuth usage endpoint for exact server percentages
2. Local Claude Code logs as a fallback estimate

The overlay reads Claude Code local usage logs from:

- `~/.claude/projects`
- `~/.config/claude/projects`

It also reads existing calibration values from `~/.claude_pet.json` when present, so limits already tuned in Claude Pet carry over.

OAuth tokens are read from Claude Code's local credentials or macOS Keychain at runtime and are never written by this plugin.

## Assets

Patch animation frames are sourced from `uygnoey/claude-pet`.
