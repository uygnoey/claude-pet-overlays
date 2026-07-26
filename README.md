# Claude Pet Overlays

**English** · [한국어](README.ko.md) · [Español](README.es.md) · [日本語](README.ja.md)

Native macOS Claude Code plugin that shows a fullscreen Claude Pet overlay when Claude Code is ready for input or asks a question.

The overlay builds a small Swift/AppKit binary on first use, displays Patch animation frames from `uygnoey/claude-pet`, and adds token gauges from Claude Code usage data.

## What It Shows

- A fullscreen overlay on every display, with the active panel on the main display
- A Claude Pet animation selected from the current token state
- Session, weekly, model, or credit usage gauges when usage data is available
- English, Korean, and Spanish UI text

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

## Quick Test

```bash
bash scripts/notify.sh stop
bash scripts/notify.sh ask
```

Click anywhere, press any key, or wait for the timeout to dismiss the overlay.

## Basic Configuration

```bash
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_LANG=en bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_LANG=es bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_TIMEOUT=0 bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_MESSAGE="Review needed" bash scripts/notify.sh ask
```

See [docs/configuration.md](docs/configuration.md) for every supported environment variable and `~/.claude_pet.json` setting.

## How Token Status Works

The overlay uses the same priority as Claude Pet:

1. Claude Code OAuth usage endpoint for exact server percentages
2. Local Claude Code JSONL logs as a fallback estimate

OAuth tokens are read from Claude Code's local credentials or macOS Keychain at runtime and are never written by this plugin.

See [docs/configuration.md](docs/configuration.md) for token sources, limits, and animation thresholds.

## Project Docs

- [Configuration](docs/configuration.md): language, timeout, token limits, usage sources, and animation rules
- [Development](docs/development.md): project layout, build/test commands, hooks, assets, and troubleshooting

## Assets

Patch animation frames are sourced from [`uygnoey/claude-pet`](https://github.com/uygnoey/claude-pet).
