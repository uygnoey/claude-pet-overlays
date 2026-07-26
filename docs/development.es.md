# Desarrollo

[English](development.md) · [한국어](development.ko.md) · **Español** · [日本語](development.ja.md)

Este repositorio es intencionadamente pequeño: los hooks de Claude Code llaman a un script de shell, el script compila o lanza un único binario nativo en Swift, y el binario renderiza la superposición con fotogramas PNG incluidos.

## Estructura del proyecto

| Ruta | Propósito |
| --- | --- |
| `.claude-plugin/plugin.json` | Metadatos del complemento de Claude Code. |
| `.claude-plugin/marketplace.json` | Metadatos del marketplace local. |
| `hooks/hooks.json` | Registro de hooks de Claude Code. |
| `scripts/notify.sh` | Punto de entrada del hook. Normaliza eventos, compila en el primer uso y lanza la superposición en segundo plano. |
| `scripts/build.sh` | Compila `src/ClaudePetOverlay.swift` con `swiftc`. |
| `src/ClaudePetOverlay.swift` | Superposición de AppKit, manejo de idioma, escaneo de tokens, renderizado de medidores y selección de animación. |
| `frames/` | Fotogramas de animación de Claude Pet incluidos. |
| `frames/frames-manifest.json` | Fuente e inventario de fotogramas de los recursos incluidos. |
| `bin/` | Salida de compilación local. Ignorada por git. |

## Compilación

```bash
bash scripts/build.sh
```

El script de compilación:

1. Requiere macOS.
2. Requiere `swiftc`.
3. Compila `src/ClaudePetOverlay.swift` con el framework Cocoa.
4. Genera `bin/claude-pet-overlay`.

## Prueba local

```bash
bash scripts/notify.sh stop
bash scripts/notify.sh ask
CLAUDE_PET_OVERLAY_TIMEOUT=0 bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_MESSAGE="Custom message" bash scripts/notify.sh ask
```

`notify.sh` termina con éxito incluso cuando la compilación local falla, porque los fallos de los hooks no deben interrumpir Claude Code. Los errores de compilación se añaden a:

```text
${TMPDIR:-/tmp}/claude-pet-overlays.log
```

## Ciclo de vida del hook

Claude Code ejecuta los comandos de `hooks/hooks.json`:

```json
{
  "Stop": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\" stop",
  "PreToolUse AskUserQuestion": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\" ask"
}
```

`notify.sh` lanza el binario nativo con:

```bash
bin/claude-pet-overlay --root "$ROOT" --event "$EVENT" --timeout "$TIMEOUT"
```

Si `CLAUDE_PET_OVERLAY_MESSAGE` está definido, también pasa:

```bash
--message "$CLAUDE_PET_OVERLAY_MESSAGE"
```

La app nativa usa un bloqueo temporal en:

```text
${TMPDIR:-/tmp}/claude-pet-overlays.lock
```

Si ya se está ejecutando otra superposición, el nuevo proceso termina sin mostrar una segunda.

## Recursos

Los fotogramas de animación se encuentran en `frames/<estado>/NN.png`.

El manifiesto actual espera:

| Estado | Fotogramas |
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

La superposición carga `frames/<estado-seleccionado>` y recurre a `frames/idle` cuando falta el directorio del estado seleccionado.

## Solución de problemas

### No aparece nada

Ejecuta:

```bash
bash scripts/build.sh
bash scripts/notify.sh stop
```

Luego inspecciona:

```bash
tail -n 100 "${TMPDIR:-/tmp}/claude-pet-overlays.log"
```

### Falta `swiftc`

Instala las Xcode Command Line Tools:

```bash
xcode-select --install
```

### Faltan los medidores de tokens

La superposición aparece igualmente sin datos de uso. Los medidores requieren uno de estos:

- Credenciales OAuth de Claude Code disponibles en `~/.claude/.credentials.json`
- Credenciales de Claude Code disponibles en el Llavero de macOS
- Registros JSONL recientes de Claude Code en `~/.claude/projects` o `~/.config/claude/projects`

### El idioma es incorrecto

Fuerza un idioma para una sola ejecución:

```bash
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop
```

Los valores admitidos incluyen `en`, `ko` y `es`.
