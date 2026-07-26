# Claude Pet Overlays

[English](README.md) · **한국어** · [Español](README.es.md) · [日本語](README.ja.md)

Claude Code가 입력을 받을 준비가 되었거나 질문을 던질 때, 화면 전체에 Claude Pet 오버레이를 띄우는 macOS 네이티브 Claude Code 플러그인입니다.

오버레이는 처음 실행할 때 작은 Swift/AppKit 바이너리를 빌드하고, `uygnoey/claude-pet`의 Patch 애니메이션 프레임을 표시하며, Claude Code 사용량 데이터를 바탕으로 토큰 게이지를 함께 보여줍니다.

## 표시 내용

- 모든 디스플레이를 덮는 풀스크린 오버레이(활성 패널은 메인 디스플레이에 표시)
- 현재 토큰 상태에 따라 선택된 Claude Pet 애니메이션
- 사용량 데이터가 있을 때 세션·주간·모델·크레딧 게이지
- 영어, 한국어, 스페인어 UI 텍스트

## 설치

```bash
claude plugin marketplace add https://github.com/uygnoey/claude-pet-overlays.git
claude plugin install claude-pet-overlays
```

설치 후 Claude Code를 재시작하세요.

## 요구 사항

- macOS
- 최초 로컬 빌드를 위한 Xcode Command Line Tools:

```bash
xcode-select --install
```

## 빠른 테스트

```bash
bash scripts/notify.sh stop
bash scripts/notify.sh ask
```

아무 곳이나 클릭하거나 아무 키나 누르면 오버레이가 닫힙니다.

## 기본 설정

```bash
CLAUDE_PET_OVERLAY_LANG=ko bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_LANG=en bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_LANG=es bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_TIMEOUT=0 bash scripts/notify.sh stop
CLAUDE_PET_OVERLAY_MESSAGE="Review needed" bash scripts/notify.sh ask
```

지원하는 모든 환경 변수와 `~/.claude_pet.json` 설정은 [docs/configuration.ko.md](docs/configuration.ko.md)를 참고하세요.

## 토큰 상태 동작 방식

오버레이는 Claude Pet과 동일한 우선순위를 사용합니다.

1. Claude Code OAuth 사용량 엔드포인트로 정확한 서버 퍼센트 조회
2. 로컬 Claude Code JSONL 로그를 폴백 추정치로 사용

OAuth 토큰은 실행 시점에 Claude Code의 로컬 자격 증명 또는 macOS 키체인에서 읽어 오며, 이 플러그인이 토큰을 기록하는 일은 없습니다.

토큰 소스, 한도, 애니메이션 임계값은 [docs/configuration.ko.md](docs/configuration.ko.md)를 참고하세요.

## 프로젝트 문서

- [설정](docs/configuration.ko.md): 언어, 타임아웃, 토큰 한도, 사용량 소스, 애니메이션 규칙
- [개발](docs/development.ko.md): 프로젝트 구조, 빌드/테스트 명령, 훅, 에셋, 문제 해결

## 에셋

Patch 애니메이션 프레임은 [`uygnoey/claude-pet`](https://github.com/uygnoey/claude-pet)에서 가져왔습니다.
