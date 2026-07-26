# Claude Pet Overlays

[English](README.md) · [한국어](README.ko.md) · **Español** · [日本語](README.ja.md)

Complemento nativo de Claude Code para macOS que muestra una superposición de Claude Pet a pantalla completa cuando Claude Code está listo para recibir texto o hace una pregunta.

La superposición compila un pequeño binario en Swift/AppKit la primera vez que se usa, muestra los fotogramas de animación de Patch de `uygnoey/claude-pet` y añade medidores de tokens a partir de los datos de uso de Claude Code.

## Demostración

![Demostración de la superposición de Claude Pet](screenshots/overlay-demo.gif)

Cuando Claude Code termina un turno, la mascota da un **salto** de alegría; cuando hace una pregunta, reproduce la animación de **revisión** (`review`).

## Qué muestra

- Una superposición a pantalla completa en cada monitor, con el panel activo en el monitor principal
- Una animación de Claude Pet elegida según el estado actual de tokens
- Medidores de uso de sesión, semanal, modelo o crédito cuando hay datos de uso disponibles
- Texto de interfaz en inglés, coreano y español

## Instalación

```bash
claude plugin marketplace add https://github.com/uygnoey/claude-pet-overlays.git
claude plugin install claude-pet-overlays
```

Reinicia Claude Code después de instalar.

## Requisitos

- macOS
- Xcode Command Line Tools para la primera compilación local:

```bash
xcode-select --install
```

## Prueba rápida

```bash
bash scripts/notify.sh stop
bash scripts/notify.sh ask
```

Haz clic en cualquier lugar o pulsa cualquier tecla para cerrar la superposición.

## Configuración básica

```bash
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_LANG=en bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_LANG=es bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_TIMEOUT=0 bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_MESSAGE="Review needed" bash scripts/notify.sh ask
```

Consulta [docs/configuration.es.md](docs/configuration.es.md) para conocer todas las variables de entorno y ajustes de `~/.claude_pet.json` admitidos.

## Cómo funciona el estado de tokens

La superposición usa la misma prioridad que Claude Pet:

1. El endpoint de uso OAuth de Claude Code para obtener porcentajes exactos del servidor
2. Los registros JSONL locales de Claude Code como estimación de reserva

Los tokens OAuth se leen de las credenciales locales de Claude Code o del Llavero de macOS en tiempo de ejecución, y este complemento nunca los escribe.

Consulta [docs/configuration.es.md](docs/configuration.es.md) para conocer las fuentes de tokens, los límites y los umbrales de animación.

## Documentación del proyecto

- [Configuración](docs/configuration.es.md): idioma, tiempo de espera, límites de tokens, fuentes de uso y reglas de animación
- [Desarrollo](docs/development.es.md): estructura del proyecto, comandos de compilación/prueba, hooks, recursos y solución de problemas

## Recursos

Los fotogramas de animación de Patch provienen de [`uygnoey/claude-pet`](https://github.com/uygnoey/claude-pet).
