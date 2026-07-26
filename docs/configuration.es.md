# Configuración

[English](configuration.md) · [한국어](configuration.ko.md) · **Español** · [日本語](configuration.ja.md)

Claude Pet Overlays se configura mediante variables de entorno, el archivo `~/.claude_pet.json` ya existente de Claude Pet y los eventos de hooks de Claude Code.

## Eventos de hooks

El complemento gestiona dos rutas de hooks de Claude Code:

| Hook | Evento | Comportamiento |
| --- | --- | --- |
| `Stop` | `stop` | Muestra la superposición cuando Claude Code termina de responder. |
| `PreToolUse` con `AskUserQuestion` | `ask` | Muestra la superposición cuando Claude Code espera la entrada del usuario. |

Cualquier evento distinto de `ask` se normaliza a `stop` en `scripts/notify.sh`.

## Variables de entorno de la superposición

| Variable | Valor predeterminado | Descripción |
| --- | --- | --- |
| `CLAUDE_PLUGIN_ROOT` | Raíz del repositorio inferida por `scripts/notify.sh` | Raíz del complemento. Claude Code normalmente la define para los complementos instalados. |
| `CLAUDE_PET_OVERLAY_LANG` | Detección automática | Fuerza el idioma de la superposición. Admite `en`, `ko` y `es`, entre otros. |
| `CLAUDE_PET_LANG` | Detección automática | Anulación de idioma de reserva compartida con Claude Pet. |
| `CLAUDE_PET_OVERLAY_TIMEOUT` | `0` | Segundos antes de que la superposición se cierre sola. El valor predeterminado `0` la mantiene abierta hasta un clic o una tecla. Usa un número positivo para cerrarla automáticamente tras esos segundos. |
| `CLAUDE_PET_OVERLAY_MESSAGE` | Predeterminado según el evento | Reemplaza el mensaje predeterminado de la superposición. |

Orden de detección de idioma:

1. `CLAUDE_PET_OVERLAY_LANG`
2. `CLAUDE_PET_LANG`
3. `lang` de `~/.claude_pet.json`
4. Idiomas preferidos de macOS
5. Inglés

## Variables de entorno de límites de tokens

Estos valores solo se usan cuando la superposición recurre a los registros locales de Claude Code.

| Variable | Valor predeterminado | Descripción |
| --- | --- | --- |
| `CLAUDE_PET_SESSION_LIMIT` | `8000000` | Límite estimado de tokens de sesión de cinco horas. |
| `CLAUDE_PET_WEEKLY_LIMIT` | `60000000` | Límite semanal estimado de tokens. |
| `CLAUDE_PET_OPUS_LIMIT` | `15000000` | Límite semanal estimado de tokens de la familia de modelos. |
| `CLAUDE_PET_MODEL` | `auto` | Palabra clave del modelo para el tercer medidor. `auto` elige una familia premium vista en los registros recientes y luego recurre a `opus`. |

## `~/.claude_pet.json`

Cuando está presente, la superposición lee los valores de calibración existentes de Claude Pet:

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

Claves admitidas:

| Clave | Descripción |
| --- | --- |
| `lang` | Idioma de la interfaz. Admite alias en inglés, coreano y español. |
| `session_limit` | Límite estimado de sesión de cinco horas para el modo de registros locales. |
| `weekly_limit` | Límite semanal estimado para el modo de registros locales. |
| `opus_limit` | Límite estimado de la familia de modelos para el modo de registros locales. |
| `model_keyword` | Subcadena del nombre del modelo usada para el tercer medidor de registros locales. |
| `weekly_reset_day` | Índice del día de reinicio semanal usado por la lógica de compatibilidad de Claude Pet. El lunes es `0`; el domingo es `6`. |
| `weekly_reset_hour` | Hora de reinicio semanal en hora local. El valor predeterminado es `20`. |

Primero se leen las variables de entorno de límites de tokens y luego los valores de `~/.claude_pet.json` los sobrescriben cuando existen.

## Fuentes de uso

La superposición intenta primero obtener el uso exacto:

1. Lee el token de acceso OAuth de `~/.claude/.credentials.json`
2. Si no está disponible, lee `Claude Code-credentials` del Llavero de macOS con `/usr/bin/security`
3. Obtiene los porcentajes de uso de `https://api.anthropic.com/api/oauth/usage`

Si el uso exacto no está disponible, estima el uso a partir de los registros JSONL locales de Claude Code:

- `~/.claude/projects`
- `~/.config/claude/projects`

El modo de registros locales analiza los archivos `.jsonl` recientes, elimina duplicados de ID de solicitud/mensaje y pondera el uso así:

| Campo de uso | Peso |
| --- | --- |
| `input_tokens` | `1.0` |
| `output_tokens` | `5.0` |
| `cache_creation_input_tokens` | `1.25` |
| `cache_read_input_tokens` | `0.1` |

## Reglas de animación

La animación se selecciona según el porcentaje del medidor más alto:

| Condición | Animación |
| --- | --- |
| `85%` o más | `failed` |
| `50%` a `84%` | `waiting` |
| Evento `ask` por debajo del `50%` | `review` |
| Evento `stop` por debajo del `50%` | `waving` |

Los tiempos de fotograma son algo más rápidos en los estados urgentes:

| Animación | Intervalo |
| --- | --- |
| `failed` | `0.30s` |
| `waiting` | `0.34s` |
| `review` | `0.38s` |
| `waving` | `0.42s` |
| Otros estados de reserva | `0.46s` |
