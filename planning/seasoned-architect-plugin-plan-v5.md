# Seasoned Architect Plugin — 기획 문서 (v5)

> **한 줄 요약**: AI 에이전트가 장기 프로덕트 개발에서 길을 잃지 않도록, 기획→MVP→파트→스펙→slice→구현가이드→커밋일지 흐름을 문서화하고, 필요한 때만 문서를 읽게 하는 Claude Code 플러그인. 이후 Codex에도 이식한다.

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-02 |
| 상태 | **v5 — 구현 전 최종 기획안** |
| 대상 사용자 | 임승용 본인 1인 |
| 1차 대상 | Claude Code |
| 이후 대상 | Codex 이식 |
| 플러그인 이름 | `seasoned-architect` |

---

## 0. v5 변경 요약

v4에서 마지막 리뷰와 사용자의 실제 프로덕트 개발 프로세스를 반영해 다음을 보강했다.

| 항목 | v5 결정 |
|---|---|
| raw log 위치 | `git rev-parse --git-common-dir` 기준으로 변경. worktree/subagent 커밋 기록이 흩어지지 않게 함 |
| hook script 안정성 | 설치 시 capture script를 Git common dir 내부 안정 경로에 복사 |
| build-loop 연결 | 각 slice `guide.md`에 **Build-loop handoff** 블록 필수 추가 |
| `doc-slice` 책임 | slice 파일만 만들지 않고 `DOCS_MAP.md`, `WORK_BREAKDOWN.md`까지 반드시 갱신 |
| 작업 분해 문서 | `WORK_BREAKDOWN.md` 추가. MVP→파트→스펙→slice 추적 |
| 프론트엔드 문서 | `frontend-components.md` 추가. 화면/컴포넌트 기획과 구현 연결 |
| journal 검증 기록 | journal entry에 `Verification`, `Evidence source` 필드 추가 |
| `doc-sync` 추론 규칙 | `plan.md → guide.md → commit message → diff → 확인 필요` 우선순위 적용 |
| 컨텍스트 정책 | 문서 본문 자동 주입 금지. 필요할 때만 lazy read |
| 중복 읽기 방지 | 같은 세션에서 이미 읽은 문서는 파일 변경/refresh 요청 없으면 다시 읽지 않음 |
| build-loop 컨텍스트 제한 | PM agent는 전체 Seasoned Architect를 붙여넣지 않고 handoff 블록과 경로만 전달 |
| 후순위 기능 | `doc-status`, `WIP.md`, slice별 journal index는 v0.1 제외 |

---

## 1. 목적

장기적이고 복잡한 프로덕트 개발에서 AI 에이전트가 반복적으로 겪는 문제를 줄인다.

1. **기록 부재 / 추적 불가**  
   무엇을 왜 했는지 남지 않아 되짚거나 이어가기 어렵다.

2. **세션 단절 / 망각**  
   새 세션마다 이전 맥락을 다시 설명해야 한다.

3. **큰 그림 상실(drift)**  
   눈앞 구현에 매몰되어 제품 목표, MVP 범위, 아키텍처, 기획 의도에서 벗어난다.

4. **slice와 원래 기획의 연결 단절**  
   구현 slice가 어느 MVP/파트/스펙에서 나온 것인지 시간이 지나면 추적하기 어렵다.

이 플러그인의 핵심 목적은 다음이다.

> 작업 기록을 남기고, 필요한 문서만 읽게 하며, 기획에서 구현까지의 연결을 유지하고, 다음 세션/서브에이전트가 이어받을 수 있는 상태를 만든다.

---

## 2. 사용자의 기본 프로덕트 개발 흐름

이 플러그인은 아래 흐름을 방해하지 않고 보조한다.

```txt
1. 서비스/제품 기획 구체화
2. 프론트엔드 페이지·컴포넌트 기획
3. 아키텍처 선택 및 정의
4. MVP 분할
5. MVP별 큰 파트 분할
6. 파트별 구현 스펙 정의
7. 파트별 구현 스펙을 slice로 분할
8. slice별 세부 개발 가이드 작성
9. build-loop-codex로 slice 구현
10. 커밋
11. doc-sync로 journal 반영
```

Seasoned Architect가 담당하는 연결:

| 개발 단계 | Seasoned Architect 문서 |
|---|---|
| 전체 제품/아키텍처 | `structure.md` |
| MVP→파트→스펙→slice 추적 | `WORK_BREAKDOWN.md` |
| 프론트엔드 컴포넌트 기획 | `frontend-components.md` |
| 작업별 문서 라우팅 | `DOCS_MAP.md` |
| slice 기획 | `slices/<slice>/plan.md` |
| slice 구현 가이드 | `slices/<slice>/guide.md` |
| 커밋 기반 작업 기록 | `journal/YYYY-MM.md` |

---

## 3. 설계 원칙

### 3.1 내용층과 실행층 분리

| 층 | 역할 | 예시 | 이식성 |
|---|---|---|---|
| **내용층** | 프로젝트 문서와 규약 | `docs/agent/**` | Claude Code와 Codex에서 그대로 사용 |
| **실행층** | 문서를 읽고 쓰게 만드는 장치 | Claude Code hooks, skills, git hooks | 도구별 재매핑 필요 |

원칙:

- 문서와 규약은 마크다운 중심으로 둔다.
- Claude Code 전용 기능은 얇게 둔다.
- Codex 이식 시 `docs/agent/**`는 그대로 쓰고, 실행층만 바꾼다.

### 3.2 커밋 기반 기록

일지의 기준 이벤트는 **git commit**이다.

이유:

- AI가 한 작업뿐 아니라 사람이 직접 한 작업도 잡을 수 있다.
- Claude Code, Codex, 터미널 수동 작업 모두 같은 기준으로 연결된다.
- 커밋 해시가 있어 추적성이 좋다.

### 3.3 자동 주입은 최소화, 실제 문서 읽기는 lazy read

세션 시작과 서브에이전트 시작 시 문서 본문을 자동으로 넣지 않는다.

대신 짧은 규칙만 주입한다.

```md
Seasoned Architect active.
- 맥락이 중요한 작업(이어가기·구현·수정·리팩터·디버깅)에서는 먼저 docs/agent/DOCS_MAP.md를 확인한다.
- 무엇을 읽을지는 DOCS_MAP이 안내한다.
- 단순 질문·일회성 작업·사용자가 생략 요청한 경우 읽지 않는다.
```

구체적인 라우팅 규칙은 `DOCS_MAP.md` 한 곳에만 둔다.  
같은 규칙을 hook 문구와 `DOCS_MAP.md`에 중복 작성하지 않는다.

### 3.4 Context Budget Policy

컨텍스트와 토큰 낭비를 막기 위한 정책이다.

```md
Seasoned Architect는 세션 시작 시 문서 본문을 자동 주입하지 않는다.

기본 원칙:
- SessionStart/SubagentStart는 짧은 규칙과 상태 넛지만 주입한다.
- 문서 본문은 작업상 필요할 때만 lazy read한다.
- 같은 세션에서 이미 읽은 문서는 파일이 바뀌었거나 사용자가 refresh를 요청하지 않는 한 다시 읽지 않는다.
- subagent는 부모 agent의 컨텍스트를 공유하지 않는 fresh context이므로, 자기 작업에 필요한 최소 문서만 읽는다.
- build-loop 실행 시 PM agent는 전체 문서를 붙여넣지 않고, slice guide 경로와 handoff 블록만 전달한다.
```

### 3.5 1인용 우선

v0.1은 임승용 개인 워크플로우에서 실제로 작동하는 최소 제품을 목표로 한다.

v0.1에서 하지 않을 것:

- 팀용 권한 관리
- 복잡한 설정 UI
- 여러 사용자 충돌 해결
- 원격 동기화
- build-loop 내장
- 자동으로 모든 문서 읽기

---

## 4. 확정 결정

| # | 결정 | 이유 |
|---|---|---|
| D1 | 대상은 임승용 1인 | 범용화보다 실제 사용성 우선 |
| D2 | Claude Code 플러그인으로 먼저 구현 | 현재 사용 환경에 먼저 맞춤 |
| D3 | Codex 이식성을 설계에 포함 | 내용층을 도구 무관 마크다운으로 유지 |
| D4 | 문서 루트는 `docs/agent/` | 프로젝트 문서와 분리되고 의미가 명확함 |
| D5 | 일지 기준 이벤트는 `git commit` | 도구 무관, 수동 작업까지 포착 가능 |
| D6 | `post-commit`은 markdown journal을 직접 수정하지 않음 | 커밋 직후 working tree가 dirty 되는 문제 방지 |
| D7 | `post-commit`은 raw 사실만 저장 | AI 없이도 모든 커밋을 놓치지 않음 |
| D8 | raw log는 Git common dir 내부에 저장 | worktree/subagent 커밋 기록이 흩어지지 않음 |
| D9 | raw log 실제 경로는 `git rev-parse --git-common-dir`로 계산 | 모든 worktree에서 공유되는 위치 사용 |
| D10 | hook 위치 계산에는 `git rev-parse --git-path hooks/post-commit` 사용 | core Git hook 위치 계산에는 적합 |
| D11 | capture script는 Git common dir 내부 안정 경로에 복사 | 플러그인 업데이트/이동으로 hook이 깨지는 문제 방지 |
| D12 | markdown journal은 `/seasoned-architect:doc-sync`가 생성/보강 | 사실 포착과 AI 서술 분리 |
| D13 | sync 여부는 journal에 commit hash 존재 여부로 판단 | 별도 상태 파일 없이 단순 |
| D14 | journal 파일 단위는 월별 | 시간순 흐름 파악이 쉽고 구현이 단순 |
| D15 | SessionStart/SubagentStart는 짧은 사용 규칙만 주입 | 컨텍스트 낭비 방지 |
| D16 | SessionStart에 미동기화 커밋 넛지 포함 | 쓰기 루프를 닫음 |
| D17 | `WORK_BREAKDOWN.md` 추가 | MVP→파트→스펙→slice 연결 유지 |
| D18 | `frontend-components.md` 추가 | 프론트엔드 기획과 구현 일관성 유지 |
| D19 | slice `guide.md`에 Build-loop handoff 블록 필수 | build-loop subagent가 올바른 문서를 읽게 함 |
| D20 | `doc-slice`는 `DOCS_MAP.md`, `WORK_BREAKDOWN.md`까지 반드시 갱신 | 라우팅과 추적 문서 누락 방지 |
| D21 | journal entry에 `Verification`, `Evidence source` 포함 | build-loop 검증 결과와 근거를 구조화 |
| D22 | `doc-sync`의 Why 추론은 근거 우선순위를 따른다 | AI가 없는 의도를 지어내는 위험 방지 |
| D23 | PostToolUse 커밋 직후 넛지는 v0.2/옵션 | v0.1 노이즈와 복잡도 절감 |
| D24 | 신규 플러그인은 `skills/` 중심 구조 사용 | Claude Code에서 권장되는 구조 |
| D25 | build-loop은 내장하지 않고 통합만 고려 | 결합도와 중복 방지 |
| D26 | 다중 에이전트 조율은 핵심 범위 밖 | slice guide와 기존 build-loop 흐름으로 대응 |

---

## 5. 문서 구조

대상 프로젝트에 다음 구조를 만든다.

```txt
<target-repo>/docs/agent/
├── DOCS_MAP.md
├── WORK_BREAKDOWN.md
├── structure.md
├── frontend-components.md
├── slices/
│   └── <slice>/
│       ├── plan.md
│       └── guide.md
└── journal/
    └── YYYY-MM.md
```

### 5.1 `DOCS_MAP.md`

문서 지도다. 에이전트가 맥락이 필요한 작업에서 가장 먼저 확인해야 하는 파일이다.

역할:

- 작업 유형별로 읽을 문서 안내
- slice와 코드 경로 매핑
- 최근 진행 확인 위치 안내
- 문서 갱신 규칙 안내
- 불필요한 문서 읽기 방지

예시:

```md
# Seasoned Architect Map

## 읽기 우선순위

항상 먼저:
- `docs/agent/DOCS_MAP.md`

slice 구현 시:
- 해당 slice의 `plan.md`
- 해당 slice의 `guide.md`

build-loop 구현 시:
- 해당 slice `guide.md`의 `Build-loop handoff` 블록
- handoff에 명시된 필수 문서만

MVP/part/spec 맥락이 헷갈릴 때만:
- `docs/agent/WORK_BREAKDOWN.md`

UI/컴포넌트 작업일 때만:
- `docs/agent/frontend-components.md`

최근 진행 확인이 필요할 때만:
- 최신 `journal/YYYY-MM.md`의 관련 commit/slice 부분

## 규칙
- 맥락이 중요한 작업에서는 이 파일을 먼저 읽는다.
- 전체 문서를 무작정 다 읽지 않는다.
- 같은 세션에서 이미 읽은 문서는 파일 변경이나 refresh 요청이 없으면 다시 읽지 않는다.
- 매핑 없는 코드 영역을 반복 수정하면 이 파일 갱신을 제안한다.
```

### 5.2 `WORK_BREAKDOWN.md`

사용자의 기획 흐름을 구현 가능한 slice까지 연결하는 추적 문서다.

역할:

- 제품 목표에서 slice까지의 계층을 보존한다.
- 각 slice가 어느 MVP/파트/스펙에서 나온 것인지 추적한다.
- build-loop 실행 전 해당 slice가 구현 가능한 상태인지 확인한다.

포함 내용:

```md
# Work Breakdown

## Product Goal
- ...

## MVPs

### MVP Alpha

#### Part: Onboarding

##### Implementation Spec: Signup Form

- Slice: onboarding-signup-form
- 관련 문서: `docs/agent/slices/onboarding-signup-form/`
- 관련 frontend component: `SignupPage`, `SignupForm`, `PrimaryButton`
- 관련 architecture decision: auth/session strategy
- Dependencies: auth API contract
- Build-loop ready: yes/no
```

읽기 정책:

- 세션 시작 시 자동으로 읽지 않는다.
- MVP/파트/스펙 맥락이 필요한 경우에만 읽는다.
- build-loop handoff에 명시된 경우에만 subagent가 읽는다.

### 5.3 `structure.md`

프로젝트의 큰 그림이다.

포함 내용:

- 프로젝트 목적
- 핵심 도메인 개념
- 주요 아키텍처
- 기술 스택
- 중요한 설계 결정
- 건드리면 위험한 영역

읽기 정책:

- 세션 시작 시 자동으로 읽지 않는다.
- 아키텍처/도메인/큰 구조 판단이 필요한 경우에만 읽는다.

### 5.4 `frontend-components.md`

프론트엔드 화면·컴포넌트 기획 문서다.

역할:

- 페이지와 컴포넌트의 책임을 명확히 한다.
- 버튼, 입력, 상태, 에러 메시지 등 UI 일관성을 유지한다.
- slice별로 같은 컴포넌트를 다르게 구현하는 문제를 줄인다.

포함 내용:

```md
# Frontend Components

## Pages

### SignupPage
- 목적: 신규 사용자 가입
- 주요 상태: idle, submitting, success, error
- 포함 컴포넌트: SignupForm, PrimaryButton, ErrorMessage

## Components

### PrimaryButton
- 용도: 주요 CTA
- variants: primary, secondary, danger
- states: default, hover, disabled, loading
- 사용 금지: 임의 색상 오버라이드
```

읽기 정책:

- UI/프론트엔드/컴포넌트 작업일 때만 읽는다.
- 백엔드/인프라/문서 작업에서는 읽지 않는다.

### 5.5 `slices/<slice>/plan.md`

특정 slice의 기획 문서다.

포함 내용:

- 왜 하는가
- 무엇을 만들거나 바꾸는가
- 어느 MVP/part/spec에 속하는가
- 범위 안 / 범위 밖
- 성공 기준
- 관련 코드 경로
- 관련 frontend component
- 관련 architecture decision

### 5.6 `slices/<slice>/guide.md`

에이전트가 실제 구현할 때 보는 가이드다.

포함 내용:

- 구현 순서
- 수정할 파일
- 수정 금지 파일
- 테스트 방법
- 주의사항
- 하지 말아야 할 것
- acceptance checks
- verification commands
- Build-loop handoff

#### 5.6.1 Build-loop handoff 필수 블록

각 `guide.md`는 build-loop-codex에 넘길 수 있는 handoff 블록을 포함한다.

예시:

```md
## Build-loop handoff

Seasoned Architect slice: onboarding-signup-form

Read first:
- docs/agent/DOCS_MAP.md
- docs/agent/slices/onboarding-signup-form/plan.md
- docs/agent/slices/onboarding-signup-form/guide.md

Read only if needed:
- docs/agent/WORK_BREAKDOWN.md — MVP/part/spec 맥락이 필요할 때
- docs/agent/frontend-components.md — UI 컴포넌트 구현 판단이 필요할 때

Source of truth:
- 이 guide.md의 Scope, Non-goals, Acceptance checks를 우선한다.

Scope:
- SignupForm UI와 validation 연결

Non-goals:
- 인증 API 구현 변경
- 전역 Button 스타일 변경

Allowed files:
- src/features/onboarding/**
- src/components/forms/**

Do not modify:
- src/auth/session.ts
- src/components/button/Button.tsx

Acceptance checks:
- 이메일 형식 오류가 표시된다.
- 제출 중 loading 상태가 표시된다.
- 성공 시 다음 단계로 이동한다.

Verification:
- pnpm test
- pnpm lint
```

build-loop 원칙:

- build-loop-codex로 slice를 구현할 때는 `guide.md`가 source of truth다.
- PM agent는 implementation/review subagent에게 전체 Seasoned Architect를 붙여넣지 않는다.
- PM agent는 slice name, guide path, Build-loop handoff 블록, acceptance checks, verification commands만 전달한다.
- review agent는 guide 미준수를 material finding 이상으로 본다.

### 5.7 `journal/YYYY-MM.md`

AI가 읽기 좋은 구현 일지다.

이 파일은 `post-commit`이 직접 수정하지 않는다.  
`doc-sync`가 raw log를 읽고 생성/갱신한다.

---

## 6. 기록 설계

### 6.1 raw log와 journal 분리

| 단계 | 저장 위치 | 작성 주체 | 역할 |
|---|---|---|---|
| raw log | Git common dir 내부 `seasoned-architect/raw-log.jsonl` | git `post-commit` hook | 커밋 사실 포착 |
| journal | `docs/agent/journal/YYYY-MM.md` | AI sync skill | 사람이 읽기 좋은 설명으로 정리 |

장점:

- 커밋 직후 working tree가 dirty 되지 않는다.
- 사람이 직접 한 커밋도 포착한다.
- AI 서술이 늦어져도 raw 사실은 남는다.
- Codex 이식 시 git hook을 그대로 재사용할 수 있다.
- worktree/subagent 커밋 기록이 한 곳에 모인다.

주의:

- raw log는 Git 내부 경로라 clone/다른 머신으로 따라오지 않는다.
- 영속 기록은 `docs/agent/journal/*.md`다.
- 그래서 SessionStart 넛지로 미동기화 상태를 알려준다.

### 6.2 raw log 위치

문서상 표현:

```txt
.git/seasoned-architect/raw-log.jsonl
```

구현상 실제 계산:

```sh
RAW_LOG="$(git rev-parse --git-common-dir)/seasoned-architect/raw-log.jsonl"
```

주의:

- raw log는 모든 worktree에서 공유되어야 하므로 common git dir에 저장한다.
- `git rev-parse --git-path hooks/post-commit`은 hook 위치 계산에 사용한다.
- raw log 저장에는 `--git-path seasoned-architect/raw-log.jsonl`을 쓰지 않는다.
- linked worktree에서 `--git-path seasoned-architect/raw-log.jsonl`은 worktree별 경로가 될 수 있어, 메인 repo의 `doc-sync`가 기록을 놓칠 수 있다.

### 6.3 raw log 형식

예시:

```jsonl
{"commit":"a1b2c3d","timestamp":"2026-07-02T14:03:00+09:00","author":"임승용","message":"refactor payment retry logic","changed_files":["src/pay/retry.ts","src/pay/retry.test.ts"],"source":"git-hook"}
```

필드:

| 필드 | 설명 |
|---|---|
| `commit` | 커밋 해시 |
| `timestamp` | 커밋 시각 |
| `author` | 커밋 작성자 |
| `message` | 커밋 메시지 |
| `changed_files` | 변경 파일 목록 |
| `source` | `git-hook` |

제외 필드:

| 필드 | 제외 이유 |
|---|---|
| `synced` | raw log를 수정하지 않고, journal에 commit hash가 있는지로 판단하기 때문 |

### 6.4 journal entry 형식

예시:

```md
## 2026-07-02 14:03 · [slice: payment] · commit a1b2c3d

- **무엇(What)**: 결제 재시도 로직을 리팩터링했다.
- **왜(Why)**: 기존 로직이 일부 케이스에서 중복 결제를 유발할 수 있었다.
- **결과(Result)**: 관련 테스트를 추가했고 기존 테스트가 통과했다.
- **다음(Next/Open)**: 환불 케이스는 별도 slice에서 다룬다.
- **변경 파일**: `src/pay/retry.ts`, `src/pay/retry.test.ts`
- **Verification**:
  - `pnpm test` → pass
  - `pnpm lint` → pass
- **Source**: `git-hook` → `ai-enriched`
- **Confidence**: `ai-enriched`
- **Evidence source**: `slice-guide`, `commit-message`, `diff`
```

`Confidence` 값:

| 값 | 의미 |
|---|---|
| `raw` | git hook이 포착한 사실만 있음 |
| `ai-enriched` | AI가 커밋과 diff를 보고 설명을 보강함 |
| `user-confirmed` | 사용자가 내용 확인/수정함 |

`Verification`을 모르면 다음처럼 남긴다.

```md
- **Verification**: not recorded
```

### 6.5 sync 판단 방식

sync 여부는 별도 상태 파일을 두지 않고 다음으로 판단한다.

```txt
raw log의 commit hash가 docs/agent/journal/*.md에 있으면 synced
없으면 unsynced
```

장점:

- raw log를 수정하지 않아도 된다.
- 별도 `synced-commits.txt`가 필요 없다.
- 구현이 단순하다.

감수할 점:

- journal에서 commit hash를 지우면 다시 미동기화로 잡힐 수 있다.
- 1인용 v0.1에서는 감수 가능한 단순성이다.

### 6.6 `doc-sync` 근거 우선순위

`doc-sync`는 “왜 했는지”를 diff만 보고 지어내면 안 된다.

Why/Result/Next 작성 시 근거 우선순위:

1. 해당 slice `plan.md`
2. 해당 slice `guide.md`
3. commit message
4. diff / changed files
5. 근거가 부족하면 `확인 필요`로 기록

규칙:

- 근거 없는 의도를 단정하지 않는다.
- 확신이 낮으면 `Next/Open`에 확인 필요로 남긴다.
- `Evidence source`에 어떤 근거를 사용했는지 적는다.

### 6.7 커밋 포착 경로

| 경로 | 포착 범위 | v0.1 역할 |
|---|---|---|
| git `post-commit` hook | Claude, Codex, 수동 터미널 커밋 전체 | **raw 포착 주력** |
| Claude Code `PostToolUse` | Claude가 실행한 `git commit`만 | v0.2 즉시 넛지 후보 |

v0.1에서는 git hook만 raw 포착에 사용한다.  
PostToolUse는 v0.1 필수 범위에서 제외한다.

### 6.8 동기화 넛지

`doc-sync`를 깜빡하면 raw log가 journal에 반영되지 않는다.  
이를 막기 위해 v0.1에 SessionStart 넛지를 포함한다.

동작:

1. `seasoned-architect-context.sh`가 raw log의 commit hash 목록을 읽는다.
2. `docs/agent/journal/*.md`에 이미 들어간 commit hash를 확인한다.
3. 미반영 commit 수가 1개 이상이면 SessionStart context 끝에 한 줄을 붙인다.

예시:

```md
Seasoned Architect: 미반영 커밋 3개 있음. `/seasoned-architect:doc-sync` 실행 권장.
```

원칙:

- 자동 실행하지 않는다.
- 커밋을 막지 않는다.
- 0개면 아무 말도 하지 않는다.
- v0.1에서는 SessionStart 넛지만 사용한다.
- PostToolUse 커밋 직후 넛지는 v0.2 또는 설정 옵션으로 미룬다.

---

## 7. 플러그인 구조

```txt
seasoned-architect/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   └── hooks.json
├── skills/
│   ├── doc-init/
│   │   └── SKILL.md
│   ├── doc-slice/
│   │   └── SKILL.md
│   ├── doc-sync/
│   │   └── SKILL.md
│   └── journaling/
│       └── SKILL.md
├── templates/
│   ├── DOCS_MAP.md
│   ├── WORK_BREAKDOWN.md
│   ├── structure.md
│   ├── frontend-components.md
│   ├── slice-plan.md
│   ├── slice-guide.md
│   └── journal-entry.md
└── scripts/
    ├── install-git-hook.sh
    ├── post-commit-capture.sh
    └── seasoned-architect-context.sh
```

Claude Code는 기본 위치의 컴포넌트를 자동 발견한다.

| 컴포넌트 | 위치 |
|---|---|
| Manifest | `.claude-plugin/plugin.json` |
| Skills | `skills/` |
| Hooks | `hooks/hooks.json` |
| Commands | `commands/` |
| Agents | `agents/` |
| MCP | `.mcp.json` |

신규 플러그인은 `commands/`보다 `skills/`를 우선 사용한다.

---

## 8. `plugin.json`

### 8.1 원칙

- manifest는 선택이다.
- manifest를 넣는다면 필수 필드는 `name` 하나다.
- `description`은 강력 권장이다.
- `skills`/`hooks` 경로는 넣지 않는다. 기본 위치 자동 발견을 사용한다.

### 8.2 v0.1 개발 중 권장 manifest

```json
{
  "name": "seasoned-architect",
  "description": "Keeps AI agents oriented in long-running product development through planning docs, slice handoffs, commit logs, and lazy context loading.",
  "author": {
    "name": "임승용"
  }
}
```

### 8.3 `version` 정책

개발 중에는 `version`을 생략한다.

이유:

- Claude Code는 `version`이 있으면 그 값을 업데이트 판단에 사용한다.
- 빠르게 고치는 개발 단계에서는 매번 버전을 올리는 게 번거롭다.
- `version`을 생략하면 git commit SHA 기반 업데이트 흐름을 쓸 수 있다.

안정 배포 시점에는 추가한다.

```json
{
  "name": "seasoned-architect",
  "version": "0.1.0",
  "description": "Keeps AI agents oriented in long-running product development through planning docs, slice handoffs, commit logs, and lazy context loading.",
  "author": {
    "name": "임승용"
  }
}
```

---

## 9. Hooks 설계

### 9.1 `hooks/hooks.json` 역할

v0.1에서 포함:

- `SessionStart`: 짧은 Seasoned Architect 규칙 + 미동기화 커밋 넛지
- `SubagentStart`: 짧은 Seasoned Architect 규칙

v0.1에서 제외:

- `PostToolUse` 커밋 직후 넛지
- 자동 `doc-sync`
- 차단형 staleness guard

### 9.2 SessionStart

목적:

- 문서 본문을 넣지 않는다.
- Seasoned Architect 사용 규칙만 짧게 넣는다.
- 미동기화 커밋이 있으면 한 줄 넛지를 붙인다.

예상 추가 context:

```md
Seasoned Architect active.
For context-heavy work, inspect docs/agent/DOCS_MAP.md first.
Let DOCS_MAP decide which docs to read.
Do not load all agent docs by default.
Do not re-read docs already read in this session unless files changed or the user asks to refresh.

Seasoned Architect: 미반영 커밋 3개 있음. `/seasoned-architect:doc-sync` 실행 권장.
```

미반영 커밋이 없으면 마지막 줄은 생략한다.

### 9.3 SubagentStart

목적:

- 서브에이전트가 부모 컨텍스트를 충분히 못 받아도 최소 규칙을 알게 한다.
- 문서 본문은 넣지 않는다.

예상 추가 context:

```md
Seasoned Architect active for this repo.
For context-heavy work, inspect docs/agent/DOCS_MAP.md first.
Read only the docs relevant to your assigned task.
Do not load all agent docs by default.
If a Build-loop handoff block is provided, follow that block and do not expand beyond it unless necessary.
```

### 9.4 hook output 형식

훅은 `hookSpecificOutput.additionalContext`를 반환한다.

예시:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Seasoned Architect active. For context-heavy work, inspect docs/agent/DOCS_MAP.md first."
  }
}
```

원칙:

- 10,000자 이하로 유지한다.
- 빠르게 끝난다.
- 실패해도 작업을 막지 않는다.

---

## 10. Skills 설계

### 10.1 `doc-init`

새 프로젝트에서 1회 실행한다.

역할:

1. 레포 구조 스캔
2. `docs/agent/` 생성 제안
3. `structure.md` 초안 생성
4. `WORK_BREAKDOWN.md` 초안 생성
5. `frontend-components.md` 초안 생성
6. `DOCS_MAP.md` 초안 생성
7. 기본 slice 후보 제안
8. git `post-commit` hook 설치 안내 또는 설치 실행

frontmatter:

```yaml
---
name: doc-init
description: Initialize Seasoned Architect for a repository by creating docs/agent structure and installing the post-commit capture hook. Use when the user explicitly asks to set up Seasoned Architect in a repo.
argument-hint: "[optional project summary]"
disable-model-invocation: true
---
```

이유:

- 파일 생성과 git hook 설치가 포함된다.
- AI가 자동으로 실행하면 안 된다.
- 사용자가 명시적으로 `/seasoned-architect:doc-init`을 실행해야 한다.

### 10.2 `doc-slice`

새 작업 단위를 만들 때 실행한다.

역할:

- `docs/agent/slices/<slice>/plan.md` 생성
- `docs/agent/slices/<slice>/guide.md` 생성
- `docs/agent/DOCS_MAP.md` 갱신
- `docs/agent/WORK_BREAKDOWN.md` 갱신

중요 규칙:

```md
`doc-slice`는 slice 파일 생성만 하지 않는다.

반드시 함께 갱신해야 하는 파일:
1. `docs/agent/slices/<slice>/plan.md`
2. `docs/agent/slices/<slice>/guide.md`
3. `docs/agent/DOCS_MAP.md`
4. `docs/agent/WORK_BREAKDOWN.md`

위 4개 중 하나라도 안전하게 갱신할 수 없으면 작업을 멈추고 사용자에게 확인한다.
```

frontmatter:

```yaml
---
name: doc-slice
description: Create a new Seasoned Architect slice with plan.md and guide.md, then update DOCS_MAP.md and WORK_BREAKDOWN.md. Use only when the user explicitly asks to create or scaffold a slice.
argument-hint: "<slice-name>"
disable-model-invocation: true
---
```

### 10.3 `doc-sync`

raw log를 journal로 변환/보강한다.

역할:

1. raw log 위치 계산
2. raw log의 commit hash 목록 확인
3. journal에 없는 commit 찾기
4. `git show <commit>`으로 변경 내용 확인
5. `DOCS_MAP.md` 기준 관련 slice 추론
6. `plan.md`, `guide.md` 기준 Why/Result 보강
7. `docs/agent/journal/YYYY-MM.md`에 entry 추가
8. 확신 낮은 내용은 `Next/Open`에 확인 필요로 남김

frontmatter:

```yaml
---
name: doc-sync
description: Sync unsynced Seasoned Architect raw commit logs into docs/agent/journal markdown entries. Use when the user asks to sync, update, or write the Seasoned Architect journal.
argument-hint: "[optional commit range]"
disable-model-invocation: true
---
```

slice 매칭 규칙:

| 상황 | 처리 |
|---|---|
| 하나의 slice에 명확히 매칭 | 해당 slice 태그 |
| 여러 slice에 걸침 | 여러 slice 태그 또는 `cross-cutting` |
| 매핑 없음 | `unassigned` 태그 + `DOCS_MAP 갱신 필요`를 `Next/Open`에 기록 |

### 10.4 `journaling`

좋은 일지를 쓰기 위한 내부 규칙이다.

역할:

- journal entry 스키마 정의
- 좋은/나쁜 기록 예시 제공
- AI가 과장하거나 없는 의도를 지어내지 않게 제한
- Why/Result/Verification/Evidence source 작성 규칙 제공

frontmatter:

```yaml
---
name: journaling
description: Internal Seasoned Architect guidance for writing concise, evidence-based journal entries from git commits, slice docs, and diffs.
user-invocable: false
---
```

이유:

- 사용자가 직접 `/seasoned-architect:journaling`으로 부를 skill이 아니다.
- `doc-sync`가 참조하는 내부 규칙 지식이다.

---

## 11. Git hook 설치 방식

### 11.1 확정 방식

**옵션 A 확정:** `doc-init`이 사용자 확인 후 post-commit hook을 설치한다.

이유:

- 1인용이라 가장 단순하다.
- 자동성이 충분하다.
- 기존 hook만 조심하면 된다.

### 11.2 설치 규칙

`install-git-hook.sh`는 다음을 지킨다.

1. git repo인지 확인한다.
2. `git config --get core.hooksPath`를 확인한다.
3. `core.hooksPath`가 있으면 그 경로에 설치한다.
4. 없으면 `git rev-parse --git-path hooks/post-commit` 경로에 설치한다.
5. 기존 `post-commit`이 있으면 덮어쓰지 않는다.
6. 기존 hook은 백업하거나, Seasoned Architect 호출 블록을 append한다.
7. capture script를 `$(git rev-parse --git-common-dir)/seasoned-architect/bin/post-commit-capture.sh`로 복사한다.
8. 실패해도 commit을 막지 않도록 최종 hook은 항상 `exit 0`을 보장한다.
9. hook 내부 작업은 빠르게 끝난다.

### 11.3 기존 hook 병합 원칙

기존 hook이 있으면 다음 블록만 추가한다.

```sh
# seasoned-architect: begin
"$(git rev-parse --git-common-dir)/seasoned-architect/bin/post-commit-capture.sh" || true
# seasoned-architect: end
```

이미 같은 블록이 있으면 중복 추가하지 않는다.

### 11.4 `post-commit-capture.sh` 원칙

- AI를 호출하지 않는다.
- markdown journal을 수정하지 않는다.
- raw log 한 줄만 append한다.
- 실패해도 `exit 0` 한다.
- raw log 경로는 `$(git rev-parse --git-common-dir)/seasoned-architect/raw-log.jsonl`로 계산한다.

---

## 12. 운영 흐름

### 12.1 초기화

```txt
사용자 → /seasoned-architect:doc-init
AI → 레포 스캔
AI → docs/agent 초안 제안
사용자 → 승인
AI → docs/agent 파일 생성
AI → git hook 설치 여부 확인
사용자 → 승인
AI → post-commit hook 설치
```

생성 문서:

```txt
docs/agent/DOCS_MAP.md
docs/agent/WORK_BREAKDOWN.md
docs/agent/structure.md
docs/agent/frontend-components.md
```

### 12.2 기획에서 slice로 분해

```txt
사용자 → 제품/MVP/파트/스펙 기획
AI → WORK_BREAKDOWN.md에 계층 정리
사용자 → slice 분할 결정
사용자 → /seasoned-architect:doc-slice <slice>
AI → plan.md / guide.md 생성
AI → DOCS_MAP.md 갱신
AI → WORK_BREAKDOWN.md 갱신
```

### 12.3 새 slice 시작

```txt
사용자 → /seasoned-architect:doc-slice onboarding-signup-form
AI → plan.md / guide.md 템플릿 생성
AI → Build-loop handoff 블록 포함
AI → DOCS_MAP.md와 WORK_BREAKDOWN.md 갱신
사용자 → 내용 보완
```

### 12.4 작업 중

```txt
SessionStart/SubagentStart
→ 짧은 Seasoned Architect 규칙만 주입
→ SessionStart는 미동기화 커밋 수가 있으면 넛지
→ 맥락이 중요한 작업이면 DOCS_MAP.md 확인
→ 관련 문서만 lazy read
→ 이미 읽은 문서는 파일 변경/refresh 요청 없으면 반복 읽지 않음
```

### 12.5 build-loop로 slice 구현

```txt
사용자 → build-loop-codex로 <slice> 구현 요청
AI/PM → 해당 slice의 guide.md에서 Build-loop handoff 블록 확인
AI/PM → implementation subagent prompt에 guide.md 경로와 handoff 블록 포함
Implementation subagent → guide.md 기준으로 구현
Review subagent → guide.md 준수 여부를 blocking/material 기준으로 리뷰
PM agent → 최종 검증 후 커밋
```

원칙:

- build-loop-codex로 slice를 구현할 때는 `guide.md`가 source of truth다.
- PM agent는 전체 Seasoned Architect를 subagent prompt에 붙여넣지 않는다.
- PM agent는 slice name, guide path, Build-loop handoff 블록, acceptance checks, verification commands만 전달한다.
- implementation subagent는 필요한 경우에만 `DOCS_MAP.md`, `plan.md`, `guide.md`, handoff에 명시된 문서를 읽는다.
- review subagent는 guide 미준수를 material finding 이상으로 본다.

### 12.6 커밋 후

```txt
git commit
→ post-commit hook 실행
→ raw log에 커밋 사실 저장
→ working tree는 dirty 되지 않음
```

### 12.7 일지 동기화

```txt
사용자 → /seasoned-architect:doc-sync
AI → raw log 확인
AI → journal에 없는 commit 확인
AI → git show로 변경 내용 확인
AI → plan.md/guide.md/commit message/diff 순서로 근거 확인
AI → journal/YYYY-MM.md 작성 또는 보강
```

---

## 13. Codex 이식 계획

| 기능 | Claude Code | Codex |
|---|---|---|
| 플러그인 패키징 | Claude Code plugin | Codex plugin/skill 구조로 재구성 |
| 세션 시작 규칙 | `SessionStart` hook | `AGENTS.md` 또는 Codex용 instruction |
| 서브에이전트 시작 규칙 | `SubagentStart` hook | Codex subagent 지시문 또는 작업 템플릿 |
| 커밋 사실 포착 | git `post-commit` hook | 동일하게 사용 |
| raw log 저장 | `git rev-parse --git-common-dir` 기준 | 동일하게 사용 |
| journal 작성 | `/seasoned-architect:doc-sync` skill | Codex skill 또는 명령으로 이식 |
| 문서 본문 | `docs/agent/**` | 그대로 사용 |
| build-loop handoff | `guide.md` 블록 | 동일하게 사용 |

핵심:

- `docs/agent/**`는 그대로 유지한다.
- git hook도 거의 그대로 유지한다.
- Claude Code hook만 Codex instruction/skill 방식으로 바꾼다.

---

## 14. MVP 범위

v0.1에서 만들 것:

1. `seasoned-architect` 플러그인 기본 구조
2. `.claude-plugin/plugin.json`
3. `doc-init` skill
4. `doc-slice` skill
5. `doc-sync` skill
6. `journaling` 내부 skill
7. `SessionStart` 짧은 규칙 주입 hook
8. `SubagentStart` 짧은 규칙 주입 hook
9. `SessionStart` 미동기화 커밋 넛지
10. `install-git-hook.sh`
11. `post-commit-capture.sh`
12. `seasoned-architect-context.sh`
13. raw log 기록
14. 기본 템플릿 7종
    - `DOCS_MAP.md`
    - `WORK_BREAKDOWN.md`
    - `structure.md`
    - `frontend-components.md`
    - `slice-plan.md`
    - `slice-guide.md`
    - `journal-entry.md`
15. Build-loop handoff 블록 템플릿
16. Context Budget Policy

v0.1에서 제외할 것:

- PostToolUse 커밋 직후 넛지
- 자동 `doc-sync`
- `doc-status`
- `WIP.md`
- slice별 journal index
- 팀용 설정 UI
- 복잡한 권한 관리
- 원격 저장소 기반 동기화
- 여러 사람의 journal 충돌 해결
- staleness guard 강제 차단
- 자동으로 모든 문서 읽기
- build-loop 내장

---

## 15. v0.1 이후 후보

### 15.1 `doc-status`

Seasoned Architect 상태를 한 번에 점검하는 명령이다.

예상 출력:

```txt
Seasoned Architect Status

- 미동기화 커밋: 3개
- DOCS_MAP에 등록 안 된 slice: 1개
- guide.md 없는 slice: 0개
- WORK_BREAKDOWN과 연결 안 된 slice: 2개
- journal 최신 업데이트: 2026-07-02
```

왜 나중인가:

- v0.1에서는 SessionStart 넛지가 가장 중요한 위험인 미동기화 커밋을 이미 알려준다.
- `doc-status`는 더 넓은 진단 도구라 v0.2 이후가 적절하다.

### 15.2 `WIP.md`

커밋 전 중단 상태를 기록하는 임시 인계 문서다.

예시:

```txt
docs/agent/WIP.md
```

왜 나중인가:

- 오래된 WIP가 남으면 AI가 잘못 믿을 수 있다.
- 커밋된 내용과 WIP가 충돌할 수 있다.
- 자동화 기준이 애매하다.
- v0.1은 커밋 기준의 확실한 기록 루프를 먼저 만든다.

### 15.3 slice별 journal index

월별 journal을 유지하되, 나중에 slice별 보기만 추가할 수 있다.

예시:

```txt
docs/agent/journal/index-by-slice/payment.md
```

왜 나중인가:

- 월별 journal만으로 v0.1은 충분하다.
- slice별 index는 중복 문서라 동기화 문제가 생긴다.
- 필요성이 확인되면 index를 자동 생성하는 방식으로 추가한다.

### 15.4 PostToolUse 즉시 넛지

Claude가 `git commit`을 실행한 직후 다음을 알려준다.

```md
Seasoned Architect: 방금 커밋이 raw log에 기록됨. 필요하면 `/seasoned-architect:doc-sync` 실행.
```

왜 나중인가:

- SessionStart 넛지만으로 기본 문제는 해결된다.
- 커밋 직후마다 알림이 뜨면 피로할 수 있다.
- 필요성이 확인되면 옵션으로 추가한다.

### 15.5 staleness guard

나중에 고려할 기능:

- 특정 code path가 바뀌었는데 관련 journal이 없으면 경고
- `DOCS_MAP.md`에 없는 영역을 수정하면 경고
- 오래된 slice guide를 업데이트하라고 제안

v0.1에서는 차단하지 않는다.

---

## 16. 성공 기준

v0.1이 성공하려면 다음이 가능해야 한다.

1. 새 레포에서 `/seasoned-architect:doc-init`으로 `docs/agent/` 초안을 만들 수 있다.
2. `WORK_BREAKDOWN.md`로 MVP→part→spec→slice 연결을 기록할 수 있다.
3. `frontend-components.md`로 주요 화면/컴포넌트 기획을 기록할 수 있다.
4. 새 작업 단위를 `/seasoned-architect:doc-slice <name>`으로 만들 수 있다.
5. `doc-slice`는 `plan.md`, `guide.md`, `DOCS_MAP.md`, `WORK_BREAKDOWN.md`를 함께 갱신한다.
6. 각 `guide.md`에는 Build-loop handoff 블록이 포함된다.
7. build-loop 실행 시 PM agent가 전체 문서가 아니라 handoff 블록과 경로만 subagent에게 전달한다.
8. 커밋하면 raw log에 기록이 남는다.
9. worktree/subagent 커밋도 common git dir의 raw log로 모인다.
10. 커밋 직후 working tree가 dirty 되지 않는다.
11. `/seasoned-architect:doc-sync`를 실행하면 `docs/agent/journal/YYYY-MM.md`가 생성/갱신된다.
12. sync 여부는 journal의 commit hash 존재 여부로 판단된다.
13. journal entry에 `Verification`, `Evidence source`가 기록된다.
14. 새 세션/서브에이전트는 문서 본문이 아니라 짧은 사용 규칙만 받는다.
15. 미동기화 커밋이 있으면 세션 시작 시 넛지가 뜬다.
16. `WORK_BREAKDOWN.md`, `frontend-components.md`는 필요할 때만 읽는다.
17. 같은 세션에서 이미 읽은 문서는 파일 변경/refresh 요청 없으면 반복 읽지 않는다.

---

## 17. 구현 순서

1. 플러그인 뼈대 생성
2. `plugin.json` 작성
3. 템플릿 7종 작성
4. `post-commit-capture.sh` 작성
5. `install-git-hook.sh` 작성
6. raw log 포맷 검증
7. `seasoned-architect-context.sh` 작성
8. SessionStart/SubagentStart hook 작성
9. `journaling` skill 작성
10. `doc-sync` skill 작성
11. `doc-init` skill 작성
12. `doc-slice` skill 작성
13. 테스트 레포에서 end-to-end 검증
14. worktree 환경에서 raw log 공유 검증
15. build-loop handoff 흐름 검증
16. v0.1 태그 또는 내부 배포

---

## 18. 참고 링크

- Claude Code Hooks: https://code.claude.com/docs/en/hooks
- Claude Code Plugins: https://code.claude.com/docs/en/plugins
- Claude Code Plugins Reference: https://code.claude.com/docs/en/plugins-reference
- Claude Code Skills: https://code.claude.com/docs/en/skills
- Cline Memory Bank: https://docs.cline.bot/best-practices/memory-bank
- Kiro Steering: https://kiro.dev/docs/steering/
- Agent OS: https://github.com/buildermethods/agent-os
- GitHub Spec Kit: https://github.com/github/spec-kit
- BMAD-METHOD: https://github.com/bmad-code-org/BMAD-METHOD
- Task Master AI: https://github.com/eyaltoledano/claude-task-master
