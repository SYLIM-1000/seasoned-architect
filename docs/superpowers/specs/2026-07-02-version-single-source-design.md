# Version Single Source of Truth — 설계

- 날짜: 2026-07-02
- 상태: 승인됨 (구현 진행)
- 범위: Claude Code + Codex 양쪽 매니페스트의 버전 문자열 단일화

## 문제

`version` 문자열이 6곳에 흩어져 있어 버전업 시 동기화 누락(drift) 위험이 있었다.

- `seasoned-architect/.claude-plugin/plugin.json`
- `seasoned-architect/.claude-plugin/marketplace.json` (플러그인 안쪽)
- `.claude-plugin/marketplace.json` (저장소 루트)
- `seasoned-architect/.codex-plugin/plugin.json`
- `seasoned-architect/README.md` (본문)
- `seasoned-architect/tests/run.sh` (하드코딩된 단언)

## 결정

**정본(single source of truth) = `.claude-plugin/plugin.json`의 `version`.**

근거:

- Claude Code의 버전 결정 순서는 ① `plugin.json` → ② marketplace 항목 → ③ git commit SHA → ④ `unknown`.
- 공식 문서가 "`plugin.json`과 marketplace 양쪽에 version을 두지 말라. Claude Code는 경고 없이 항상 `plugin.json` 값을 쓴다"고 명시.
- Codex는 자체 `.codex-plugin/plugin.json`에서 version을 읽으므로, 그 파일만 정본에서 파생시킨다.

## 각 파일의 역할

| 파일 | 처리 |
|---|---|
| `.claude-plugin/plugin.json` | 정본. 유일한 수동 편집 지점 |
| `.claude-plugin/marketplace.json` (안/밖) | `version` 제거 → plugin.json에서 자동 상속 |
| `.codex-plugin/plugin.json` | `version` 유지, `scripts/sync-version.sh`가 정본에서 스탬프 |
| `README.md` | 버전 숫자 하드코딩 제거, 정본 위치를 가리킴 |
| `tests/run.sh` | 정본을 읽어 일치 검증 (하드코딩 제거) + 단일소스 가드 |

## scripts/sync-version.sh

- 기본 실행: 정본 `version`을 읽어 `.codex-plugin/plugin.json`에 기록.
- `--check`: 기록 없이 일치 여부만 검사, 불일치 시 비정상 종료 (CI/수동 점검용).
- 기존 스크립트와 동일하게 `set -euo pipefail` + `python3` 사용.

## 검증 (tests/run.sh)

- `test_codex_plugin_manifest`: codex `version` == 정본 `version` (하드코딩 제거).
- `test_version_single_source` (신규):
  - 정본 `version`이 비어있지 않음
  - codex `version` == 정본
  - 안/밖 marketplace 항목에 `version` 키 없음

## 유지보수 흐름

```bash
# 1) 정본 한 곳만 수정: .claude-plugin/plugin.json 의 "version"
# 2) Codex로 전파
bash scripts/sync-version.sh
# 3) 일관성 확인
bash tests/run.sh
```

## 안전성

marketplace에서 `version`을 제거해도 설치 버전은 `unknown`으로 떨어지지 않는다. 각 marketplace 항목의 `source`가 `plugin.json`(결정 순서 ①)을 가리키기 때문.
