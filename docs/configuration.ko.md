# 설정

[English](configuration.md) · **한국어** · [Español](configuration.es.md) · [日本語](configuration.ja.md)

Claude Pet Overlays는 환경 변수, 기존 Claude Pet의 `~/.claude_pet.json` 파일, 그리고 Claude Code 훅 이벤트를 통해 설정합니다.

## 훅 이벤트

이 플러그인은 두 가지 Claude Code 훅 경로를 처리합니다.

| 훅 | 이벤트 | 동작 |
| --- | --- | --- |
| `Stop` | `stop` | Claude Code가 응답을 마치면 오버레이를 표시합니다. |
| `AskUserQuestion`이 포함된 `PreToolUse` | `ask` | Claude Code가 사용자 입력을 기다릴 때 오버레이를 표시합니다. |

`ask` 이외의 이벤트는 `scripts/notify.sh`에서 모두 `stop`으로 정규화됩니다.

## 오버레이 환경 변수

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `CLAUDE_PLUGIN_ROOT` | `scripts/notify.sh`가 추론한 저장소 루트 | 플러그인 루트. 설치된 플러그인의 경우 보통 Claude Code가 설정합니다. |
| `CLAUDE_PET_OVERLAY_LANG` | 자동 감지 | 오버레이 언어를 강제합니다. `en`, `ko`, `es` 등을 지원합니다. |
| `CLAUDE_PET_LANG` | 자동 감지 | Claude Pet과 공유하는 폴백 언어 재정의값. |
| `CLAUDE_PET_OVERLAY_TIMEOUT` | `18` | 오버레이가 스스로 닫히기까지의 초. `0`으로 설정하면 클릭이나 키 입력 전까지 유지됩니다. |
| `CLAUDE_PET_OVERLAY_MESSAGE` | 이벤트별 기본값 | 기본 오버레이 메시지를 대체합니다. |

언어 감지 순서:

1. `CLAUDE_PET_OVERLAY_LANG`
2. `CLAUDE_PET_LANG`
3. `~/.claude_pet.json`의 `lang`
4. macOS 선호 언어
5. 영어

## 토큰 한도 환경 변수

이 값들은 오버레이가 로컬 Claude Code 로그로 폴백할 때만 사용됩니다.

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `CLAUDE_PET_SESSION_LIMIT` | `8000000` | 추정 5시간 세션 토큰 한도. |
| `CLAUDE_PET_WEEKLY_LIMIT` | `60000000` | 추정 주간 토큰 한도. |
| `CLAUDE_PET_OPUS_LIMIT` | `15000000` | 추정 모델 계열 주간 토큰 한도. |
| `CLAUDE_PET_MODEL` | `auto` | 세 번째 게이지의 모델 키워드. `auto`는 최근 로그에서 보인 프리미엄 계열을 고른 뒤 `opus`로 폴백합니다. |

## `~/.claude_pet.json`

이 파일이 있으면 오버레이는 기존 Claude Pet 보정값을 읽습니다.

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

지원 키:

| 키 | 설명 |
| --- | --- |
| `lang` | UI 언어. 영어, 한국어, 스페인어 별칭을 지원합니다. |
| `session_limit` | 로컬 로그 모드용 추정 5시간 세션 한도. |
| `weekly_limit` | 로컬 로그 모드용 추정 주간 한도. |
| `opus_limit` | 로컬 로그 모드용 추정 모델 계열 한도. |
| `model_keyword` | 세 번째 로컬 로그 게이지에 사용되는 모델명 부분 문자열. |
| `weekly_reset_day` | Claude Pet 호환 로직에서 사용하는 주간 리셋 요일 인덱스. 월요일이 `0`, 일요일이 `6`. |
| `weekly_reset_hour` | 로컬 시간 기준 주간 리셋 시각. 기본값은 `20`. |

환경 변수 토큰 한도가 먼저 읽히고, `~/.claude_pet.json`에 값이 있으면 그것으로 덮어씁니다.

## 사용량 소스

오버레이는 먼저 정확한 사용량을 시도합니다.

1. `~/.claude/.credentials.json`에서 OAuth 액세스 토큰을 읽습니다
2. 없으면 `/usr/bin/security`로 macOS 키체인의 `Claude Code-credentials`를 읽습니다
3. `https://api.anthropic.com/api/oauth/usage`에서 사용량 퍼센트를 가져옵니다

정확한 사용량을 얻을 수 없으면 로컬 Claude Code JSONL 로그로 사용량을 추정합니다.

- `~/.claude/projects`
- `~/.config/claude/projects`

로컬 로그 모드는 최근 `.jsonl` 파일을 스캔하고, 요청/메시지 ID를 중복 제거한 뒤, 다음 가중치로 사용량을 계산합니다.

| 사용량 필드 | 가중치 |
| --- | --- |
| `input_tokens` | `1.0` |
| `output_tokens` | `5.0` |
| `cache_creation_input_tokens` | `1.25` |
| `cache_read_input_tokens` | `0.1` |

## 애니메이션 규칙

애니메이션은 가장 높은 게이지 퍼센트를 기준으로 선택됩니다.

| 조건 | 애니메이션 |
| --- | --- |
| `85%` 이상 | `failed` |
| `50%` ~ `84%` | `waiting` |
| `50%` 미만의 `ask` 이벤트 | `review` |
| `50%` 미만의 `stop` 이벤트 | `waving` |

급한 상태일수록 프레임 간격이 조금 더 빠릅니다.

| 애니메이션 | 간격 |
| --- | --- |
| `failed` | `0.09s` |
| `waiting` | `0.13s` |
| `review` | `0.16s` |
| `waving` | `0.18s` |
| 기타 폴백 상태 | `0.20s` |
