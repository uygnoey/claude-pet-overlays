# 개발

[English](development.md) · **한국어** · [Español](development.es.md) · [日本語](development.ja.md)

이 저장소는 의도적으로 작게 유지됩니다. Claude Code 훅이 셸 스크립트를 호출하고, 스크립트가 하나의 네이티브 Swift 바이너리를 빌드하거나 실행하며, 바이너리가 번들된 PNG 프레임으로 오버레이를 렌더링합니다.

## 프로젝트 구조

| 경로 | 용도 |
| --- | --- |
| `.claude-plugin/plugin.json` | Claude Code 플러그인 메타데이터. |
| `.claude-plugin/marketplace.json` | 로컬 마켓플레이스 메타데이터. |
| `hooks/hooks.json` | Claude Code 훅 등록. |
| `scripts/notify.sh` | 훅 진입점. 이벤트를 정규화하고, 최초 실행 시 빌드하며, 오버레이를 백그라운드로 실행합니다. |
| `scripts/build.sh` | `swiftc`로 `src/ClaudePetOverlay.swift`를 빌드합니다. |
| `src/ClaudePetOverlay.swift` | AppKit 오버레이, 언어 처리, 토큰 스캔, 게이지 렌더링, 애니메이션 선택. |
| `frames/` | 번들된 Claude Pet 애니메이션 프레임. |
| `frames/frames-manifest.json` | 번들 에셋의 소스 및 프레임 목록. |
| `bin/` | 로컬 빌드 결과물. git에서 무시됩니다. |

## 빌드

```bash
bash scripts/build.sh
```

빌드 스크립트는 다음을 수행합니다.

1. macOS를 요구합니다.
2. `swiftc`를 요구합니다.
3. Cocoa 프레임워크로 `src/ClaudePetOverlay.swift`를 컴파일합니다.
4. `bin/claude-pet-overlay`를 생성합니다.

## 로컬 테스트

```bash
bash scripts/notify.sh stop
bash scripts/notify.sh ask
CLAUDE_PET_OVERLAY_TIMEOUT=0 bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_MESSAGE="Custom message" bash scripts/notify.sh ask
```

훅 실패가 Claude Code를 중단시켜서는 안 되므로, `notify.sh`는 로컬 빌드가 실패해도 성공으로 종료합니다. 빌드 오류는 다음 파일에 추가됩니다.

```text
${TMPDIR:-/tmp}/claude-pet-overlays.log
```

## 훅 수명 주기

Claude Code는 `hooks/hooks.json`의 명령을 실행합니다.

```json
{
  "Stop": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\" stop",
  "PreToolUse AskUserQuestion": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh\" ask"
}
```

`notify.sh`는 다음과 같이 네이티브 바이너리를 실행합니다.

```bash
bin/claude-pet-overlay --root "$ROOT" --event "$EVENT" --timeout "$TIMEOUT"
```

`CLAUDE_PET_OVERLAY_MESSAGE`가 설정되어 있으면 다음도 전달합니다.

```bash
--message "$CLAUDE_PET_OVERLAY_MESSAGE"
```

네이티브 앱은 다음 위치에 임시 잠금 파일을 사용합니다.

```text
${TMPDIR:-/tmp}/claude-pet-overlays.lock
```

이미 다른 오버레이가 실행 중이면, 새 프로세스는 두 번째 오버레이를 표시하지 않고 종료합니다.

## 에셋

애니메이션 프레임은 `frames/<state>/NN.png` 아래에 있습니다.

현재 매니페스트가 기대하는 값:

| 상태 | 프레임 수 |
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

오버레이는 `frames/<선택된 상태>`를 로드하며, 해당 상태 디렉터리가 없으면 `frames/idle`로 폴백합니다.

## 문제 해결

### 아무것도 나타나지 않을 때

실행:

```bash
bash scripts/build.sh
bash scripts/notify.sh stop
```

그런 다음 확인:

```bash
tail -n 100 "${TMPDIR:-/tmp}/claude-pet-overlays.log"
```

### `swiftc`가 없을 때

Xcode Command Line Tools 설치:

```bash
xcode-select --install
```

### 토큰 게이지가 보이지 않을 때

사용량 데이터가 없어도 오버레이는 표시됩니다. 게이지에는 다음 중 하나가 필요합니다.

- `~/.claude/.credentials.json`에서 사용 가능한 Claude Code OAuth 자격 증명
- macOS 키체인에서 사용 가능한 Claude Code 자격 증명
- `~/.claude/projects` 또는 `~/.config/claude/projects` 아래의 최근 Claude Code JSONL 로그

### 언어가 잘못 표시될 때

한 번의 실행에 대해 언어를 강제:

```bash
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop
```

지원 값에는 `en`, `ko`, `es`가 포함됩니다.
