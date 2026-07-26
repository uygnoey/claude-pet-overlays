# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

A native macOS Claude Code plugin that shows a fullscreen "Claude Pet" overlay
when Claude Code finishes responding (`stop`) or asks the user a question
(`ask`). The overlay renders a pet animation plus token-usage gauges.

The whole app is a single Swift/AppKit binary compiled on first use. There is
no build system, package manager, or test framework — just shell scripts and
`swiftc`.

## Architecture

Flow: **Claude Code hook → `scripts/notify.sh` → (first run: `scripts/build.sh`) → `bin/claude-pet-overlay` (Swift binary) → fullscreen overlay**

| Path | Role |
| --- | --- |
| `hooks/hooks.json` | Registers two hooks: `Stop` → `notify.sh stop`, and `PreToolUse` matching `AskUserQuestion` → `notify.sh ask`. |
| `scripts/notify.sh` | Hook entrypoint. macOS-only guard, normalizes any non-`ask` event to `stop`, builds the binary if missing, launches it detached with `nohup`. Always exits `0` so a hook failure never blocks Claude Code. |
| `scripts/build.sh` | `swiftc -O -framework Cocoa src/ClaudePetOverlay.swift -o bin/claude-pet-overlay`. |
| `src/ClaudePetOverlay.swift` | The entire app (~1200 lines): arg parsing, i18n, token scanning, gauge + animation rendering, AppKit windows. |
| `frames/<state>/NN.png` | Bundled Claude Pet animation frames (192×208), sourced from `uygnoey/claude-pet`. |
| `bin/` | Local build output. Git-ignored. |

### Key pieces inside `src/ClaudePetOverlay.swift`

- `Arguments` — parses `--root`, `--event`, `--message`, `--timeout`.
- `Language` / `L` — en/ko/es UI strings. Resolution order: `CLAUDE_PET_OVERLAY_LANG` → `CLAUDE_PET_LANG` → `~/.claude_pet.json` `lang` → macOS locale → English.
- `ProcessLock` — `flock` on a temp file so only one overlay shows at a time.
- `TokenScanner.snapshot()` — two-tier usage:
  1. **exact**: OAuth token from `~/.claude/.credentials.json` or macOS Keychain (`/usr/bin/security`) → GET `https://api.anthropic.com/api/oauth/usage`.
  2. **logs fallback**: scans `~/.claude/projects` + `~/.config/claude/projects` `.jsonl`, dedupes by message/request id, weights tokens (output ×5, cache-create ×1.25, cache-read ×0.1).
- `chooseAnimation` — by max gauge %: `failed` ≥85, `waiting` ≥50, `review` (ask), `waving` (stop).
- `AppDelegate` — one borderless screen-saver-level window per display; active panel only on the main display; dismiss on click/key/timeout (default 18s).

## Build & test

```bash
bash scripts/build.sh                 # compile the binary
bash scripts/notify.sh stop           # show the "ready" overlay
bash scripts/notify.sh ask            # show the "question" overlay
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop   # force a language
CLAUDE_PET_OVERLAY_TIMEOUT=0 bash scripts/notify.sh stop # stay open until dismissed
```

Build errors are appended to `${TMPDIR:-/tmp}/claude-pet-overlays.log`.
There is no automated test suite; verify changes by running the overlay.

## Conventions & constraints

- **macOS only.** `notify.sh` exits `0` on non-Darwin; `build.sh` errors out.
- **Never block Claude Code.** Hook-path scripts must fail soft (exit `0`).
- **Read-only on credentials.** The plugin reads OAuth tokens at runtime and
  must never write or log them.
- **Keep the footprint small.** No new dependencies or build tooling — the
  design goal is one Swift file + shell scripts + PNG assets.
- When changing user-facing strings, update all three UI languages (en/ko/es)
  in the `L` enum together.

## Docs are localized

User docs exist in four languages: English, Korean, Spanish, Japanese
(order: en → ko → es → ja). Base file is English; siblings use `.ko` / `.es` /
`.ja` suffixes, cross-linked by a nav line at the top.

- `README.md` (+ `README.ko.md`, `README.es.md`, `README.ja.md`)
- `docs/configuration.*.md` — env vars, `~/.claude_pet.json`, usage sources, animation rules
- `docs/development.*.md` — layout, build/test, hook lifecycle, assets, troubleshooting

When editing documentation content, update every language variant of that
document so they stay in sync. Note the overlay **UI** itself supports only
en/ko/es; Japanese is documentation-only.
