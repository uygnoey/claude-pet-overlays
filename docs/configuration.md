# Configuration

**English** · [한국어](configuration.ko.md) · [Español](configuration.es.md) · [日本語](configuration.ja.md)

Claude Pet Overlays is configured through environment variables, Claude Pet's existing `~/.claude_pet.json` file, and Claude Code hook events.

## Hook Events

The plugin handles two Claude Code hook paths:

| Hook | Event | Behavior |
| --- | --- | --- |
| `Stop` | `stop` | Shows the overlay when Claude Code finishes responding. |
| `PreToolUse` with `AskUserQuestion` | `ask` | Shows the overlay when Claude Code is waiting for user input. |

Any event other than `ask` is normalized to `stop` by `scripts/notify.sh`.

## Overlay Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `CLAUDE_PLUGIN_ROOT` | Repository root inferred from `scripts/notify.sh` | Plugin root. Claude Code normally sets this for installed plugins. |
| `CLAUDE_PET_OVERLAY_LANG` | Auto-detected | Forces overlay language. Supported values include `en`, `ko`, and `es`. |
| `CLAUDE_PET_LANG` | Auto-detected | Fallback language override shared with Claude Pet. |
| `CLAUDE_PET_OVERLAY_TIMEOUT` | `18` | Seconds before the overlay dismisses itself. Set `0` to keep it open until click or key press. |
| `CLAUDE_PET_OVERLAY_MESSAGE` | Event-specific default | Replaces the default overlay message. |

Language detection order:

1. `CLAUDE_PET_OVERLAY_LANG`
2. `CLAUDE_PET_LANG`
3. `~/.claude_pet.json` `lang`
4. macOS preferred languages
5. English

## Token Limit Environment Variables

These values are used only when the overlay falls back to local Claude Code logs.

| Variable | Default | Description |
| --- | --- | --- |
| `CLAUDE_PET_SESSION_LIMIT` | `8000000` | Estimated five-hour session token limit. |
| `CLAUDE_PET_WEEKLY_LIMIT` | `60000000` | Estimated weekly token limit. |
| `CLAUDE_PET_OPUS_LIMIT` | `15000000` | Estimated model-family weekly token limit. |
| `CLAUDE_PET_MODEL` | `auto` | Model keyword for the third gauge. `auto` picks a premium family seen in recent logs, then falls back to `opus`. |

## `~/.claude_pet.json`

When present, the overlay reads existing Claude Pet calibration values:

```json
{
  "lang": "ko",
  "session_limit": 8000000,
  "weekly_limit": 60000000,
  "opus_limit": 15000000,
  "model_keyword": "opus",
  "weekly_reset_day": 0,
  "weekly_reset_hour": 20
}
```

Supported keys:

| Key | Description |
| --- | --- |
| `lang` | UI language. Supports English, Korean, and Spanish aliases. |
| `session_limit` | Estimated five-hour session limit for local-log mode. |
| `weekly_limit` | Estimated weekly limit for local-log mode. |
| `opus_limit` | Estimated model-family limit for local-log mode. |
| `model_keyword` | Model name substring used for the third local-log gauge. |
| `weekly_reset_day` | Weekly reset weekday index used by Claude Pet compatibility logic. Monday is `0`; Sunday is `6`. |
| `weekly_reset_hour` | Weekly reset hour in local time. Defaults to `20`. |

Environment token-limit variables are read first, then values from `~/.claude_pet.json` override them when present.

## Usage Sources

The overlay attempts exact usage first:

1. Read the OAuth access token from `~/.claude/.credentials.json`
2. If unavailable, read `Claude Code-credentials` from macOS Keychain with `/usr/bin/security`
3. Fetch usage percentages from `https://api.anthropic.com/api/oauth/usage`

If exact usage is unavailable, it estimates usage from local Claude Code JSONL logs:

- `~/.claude/projects`
- `~/.config/claude/projects`

Local-log mode scans recent `.jsonl` files, deduplicates request/message IDs, and weights usage as:

| Usage field | Weight |
| --- | --- |
| `input_tokens` | `1.0` |
| `output_tokens` | `5.0` |
| `cache_creation_input_tokens` | `1.25` |
| `cache_read_input_tokens` | `0.1` |

## Animation Rules

Animation selection is based on the highest visible gauge percentage:

| Condition | Animation |
| --- | --- |
| `85%` or higher | `failed` |
| `50%` to `84%` | `waiting` |
| `ask` event below `50%` | `review` |
| `stop` event below `50%` | `waving` |

Frame timing is slightly faster for urgent states:

| Animation | Interval |
| --- | --- |
| `failed` | `0.16s` |
| `waiting` | `0.20s` |
| `review` | `0.24s` |
| `waving` | `0.26s` |
| Other fallback states | `0.28s` |
