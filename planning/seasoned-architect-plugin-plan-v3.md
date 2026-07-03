# Seasoned Architect Plugin — 기획 문서 (v3 draft)

> **한 줄 요약**: AI 에이전트가 장기 프로젝트에서 길을 잃지 않도록, 작업 문서를 구조화하고 커밋 기반 기록을 남기게 하는 Claude Code 플러그인. 이후 Codex에도 이식한다.

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-02 |
| 상태 | **v3 draft** — v2 기반 + 기술 검증 반영, 구현 직전 단계 |
| 대상 사용자 | 임승용 본인 1인 |
| 1차 대상 | Claude Code |
| 이후 대상 | Codex 이식 |
| 플러그인 이름 | `seasoned-architect` |

> **읽는 법**: v2 원문을 보존하고, v3에서 바뀌거나 추가된 부분만 **`[v3]`** 로 표시했다. 판단이 필요한 항목은 강요하지 않고 §10 "열린 결정"에 남겼다.

---

## 0. 변경 이력 & 기술 검증 `[v3]`

### 0.1 기술 검증 결과 (공식 문서 대조, 2026-07)

v2가 전제한 Claude Code 기능을 공식 문서로 확인했다.

| 확인 항목 | 결과 | 근거 / 비고 |
|---|---|---|
| `SubagentStart` 훅 | ✅ **존재** | `agent_type` 매처 지원, `additionalContext`로 주입 가능. **v2 설계 유효** |
| `SessionStart` 컨텍스트 주입 | ✅ **가능** | `hookSpecificOutput.additionalContext` (최대 10,000자) 또는 stdout |
| skill을 `/plugin:name`으로 호출 | ✅ **가능** | "커스텀 커맨드가 skill로 통합됨". skill/command 동일 작동, **skill 권장** |
| `plugin.json`에 컴포넌트 경로 명시 | ⚠️ **불필요** | `skills/`, `hooks/hooks.json` 등 관례 디렉토리 **자동 발견**. 매니페스트 자체도 선택 |
| 플러그인의 git 훅 설치 | ⚠️ **네이티브 아님** | Claude Code 훅과 git 훅은 별개. 설치는 **스크립트**로. `core.hooksPath` 상호작용은 미문서화(주의) |
| PostToolUse로 `git commit` 포착 | ✅ **가능** | `if: "Bash(git commit *)"` + `tool_input.command` 검사. 단 **Claude가 낸 커밋만**(수동/Codex 커밋은 못 잡음) |

출처: [hooks](https://code.claude.com/docs/en/hooks-guide) · [plugins](https://code.claude.com/docs/en/plugins) · [plugins-reference](https://code.claude.com/docs/en/plugins-reference) · [skills](https://code.claude.com/docs/en/skills)

### 0.2 v2 → v3 변경 목록

- **[검증]** `SubagentStart` 실재 확인 → §6.2·D10 그대로 유지(불확실성 제거).
- **[수정]** §6.1 `plugin.json`에서 `skills`/`hooks` 경로 필드 삭제(자동 발견). `name`+`description`만 필수.
- **[보강]** §10.1 git 훅 설치에 `core.hooksPath` 감지·기존 훅 백업·`exit 0` 비차단 요구 추가.
- **[정리]** §5.2 `synced` 필드와 §10.2 옵션 C의 중복 해소(옵션 C 우선, `synced`는 선택).
- **[추가]** §5.4 커밋 포착 경로 비교(git hook vs PostToolUse)와 권장.
- **[추가·제안]** §5.5 + §10.5 `doc-sync` 리마인드(넛지) — 수동 동기화 깜빡 방지.
- **[정리]** §2.3 주입 규칙은 최소화하고 라우팅 진실은 `DOCS_MAP.md` 한 곳으로(DRY).
- **[명시]** §6 각 skill의 호출 주체(사용자 트리거 vs 모델 내부) 프론트매터로 구분.

---

## 1. 목적

장기적이고 복잡한 프로젝트에서 AI 에이전트가 다음 문제를 반복한다.

1. **기록 부재 / 추적 불가**  
   무엇을 왜 했는지 남지 않아, 되짚거나 이어가기 어렵다.
2. **세션 단절 / 망각**  
   새 세션마다 이전 맥락을 다시 설명해야 한다.
3. **큰 그림 상실(drift)**  
   눈앞 작업에 매몰되어 전체 구조와 목표에서 벗어난다.

이 플러그인의 핵심 목적은 **작업 기록을 남기고, 필요할 때 문서를 읽게 하며, 다음 세션이 이어받을 수 있는 상태를 만드는 것**이다.

---

## 2. 설계 원칙

### 2.1 내용층과 실행층 분리

| 층 | 역할 | 예시 | 이식성 |
|---|---|---|---|
| **내용층** | 프로젝트 문서와 규약 | `docs/agent/**` | 도구 무관. Claude Code와 Codex에서 그대로 사용 |
| **실행층** | 문서를 읽고 쓰게 만드는 장치 | Claude Code hooks, skills, git hooks | 도구별 재매핑 필요 |

핵심 원칙:

- 문서와 규약은 **마크다운 중심**으로 둔다.
- Claude Code 전용 기능은 얇게 둔다.
- Codex 이식 시 내용층은 그대로 쓰고, 실행층만 바꾼다.

### 2.2 커밋 기반 기록

일지의 기준 이벤트는 **git commit**이다.

이유:

- AI가 한 작업뿐 아니라 사람이 직접 한 작업도 잡을 수 있다.
- Claude Code, Codex, 터미널 수동 작업 모두 같은 기준으로 연결된다.
- 커밋 해시가 있어 추적성이 좋다.

### 2.3 자동 주입은 최소화, 실제 문서 읽기는 lazy read

세션 시작과 서브에이전트 시작 시 문서 본문을 자동으로 많이 넣지 않는다.

대신 짧은 규칙만 주입한다.

```md
Seasoned Architect active.
- 맥락이 중요한 작업(이어가기·구현·수정·리팩터·디버깅)에서는 먼저 docs/agent/DOCS_MAP.md를 확인한다.
- 무엇을 읽을지는 DOCS_MAP이 안내한다. (라우팅 규칙의 진실은 DOCS_MAP 한 곳)
- 단순 질문·일회성 작업·사용자가 생략 요청한 경우 읽지 않는다.
```

> **`[v3]` DRY 원칙**: 주입 규칙은 위처럼 "DOCS_MAP을 먼저 보라"는 **포인터만** 담고, "어떤 작업이면 어디를 읽어라" 같은 구체 라우팅은 `DOCS_MAP.md`에만 둔다. 두 곳에 같은 규칙을 쓰면 갱신 시 어긋난다.

이유:

- 전체 문서 자동 주입은 컨텍스트 낭비가 크다.
- 완전 수동은 사용자가 깜빡하면 플러그인의 효과가 약해진다.
- 짧은 규칙 자동 주입 + 필요 시 읽기가 가장 균형이 좋다.

### 2.4 1인용 우선

범용 예외처리, 팀 협업 권한, 복잡한 설정 UI는 v1 범위에서 제외한다.

목표는 **내 워크플로우에서 실제로 작동하는 최소 제품**이다.

---

## 3. 확정 결정

| # | 결정 | 이유 |
|---|---|---|
| D1 | 대상은 임승용 1인 | 범용화보다 실제 사용성 우선 |
| D2 | Claude Code 플러그인으로 먼저 구현 | 현재 사용 환경에 먼저 맞춤 |
| D3 | Codex 이식성을 설계에 포함 | 내용층을 도구 무관 마크다운으로 유지 |
| D4 | 문서 루트는 `docs/agent/` | 프로젝트 문서와 분리되고 의미가 명확함 |
| D5 | 일지 기준 이벤트는 `git commit` | 도구 무관, 수동 작업까지 포착 가능 |
| D6 | `post-commit`은 markdown journal을 직접 수정하지 않음 | 커밋 직후 working tree가 dirty 되는 문제 방지 |
| D7 | `post-commit`은 `.git/seasoned-architect/raw-log.jsonl`에 raw 사실만 저장 | git 내부 비추적 영역에 안전하게 저장 |
| D8 | markdown journal은 `/seasoned-architect:doc-sync`가 raw log를 읽어 생성/보강 | 사실 포착과 AI 서술을 분리 |
| D9 | 세션 시작 시 문서 본문은 주입하지 않음 | 컨텍스트 낭비 방지 |
| D10 | SessionStart/SubagentStart는 짧은 사용 규칙만 주입 | 필요한 작업에서만 문서 읽기 유도 · **`[v3]` SubagentStart 실재 확인됨** |
| D11 | 신규 플러그인은 `skills/` 중심 구조 사용 | Claude Code 플러그인 구조에 자연스러움 · **`[v3]` 커맨드가 skill로 통합되어 `/seasoned-architect:*` 호출 유효** |
| D12 | build-loop은 내장하지 않고 통합만 고려 | 결합도와 중복 방지 |
| D13 | 다중 에이전트 조율은 핵심 범위 밖 | 기존 build-loop + slice guide 흐름으로 대응 |

---

## 4. 문서 구조

대상 프로젝트에 다음 구조를 만든다.

```txt
<target-repo>/docs/agent/
├── DOCS_MAP.md
├── structure.md
├── slices/
│   └── <slice>/
│       ├── plan.md
│       └── guide.md
└── journal/
    └── YYYY-MM.md
```

### 4.1 `DOCS_MAP.md`

문서 지도다. 에이전트가 가장 먼저 확인해야 하는 파일이다.

역할:

- 어떤 작업이면 어떤 slice 문서를 읽을지 안내
- slice와 코드 경로 매핑
- 최근 진행 확인 위치 안내

예시:

```md
# Seasoned Architect Map

## 작업별 문서 위치
- 결제 관련 작업 → `docs/agent/slices/payment/`
- 온보딩 관련 작업 → `docs/agent/slices/onboarding/`
- 전체 구조 파악 → `docs/agent/structure.md`
- 최근 진행 현황 → `docs/agent/journal/` 최신 파일

## 규칙
- 맥락이 중요한 작업에서는 이 파일을 먼저 읽는다.
- 관련 slice가 있으면 `plan.md`, `guide.md`, 최신 journal만 읽는다.
- 전체 문서를 무작정 다 읽지 않는다.
```

### 4.2 `structure.md`

프로젝트의 큰 그림이다.

포함 내용:

- 제품/프로젝트 목적
- 핵심 도메인 개념
- 주요 아키텍처
- 기술 스택
- 중요한 설계 결정
- 건드리면 위험한 영역

자주 바뀌지 않는 안정 문서다.

### 4.3 `slices/<slice>/plan.md`

특정 작업 단위의 기획 문서다.

포함 내용:

- 왜 하는가
- 무엇을 만들거나 바꾸는가
- 범위 안 / 범위 밖
- 성공 기준
- 관련 코드 경로

### 4.4 `slices/<slice>/guide.md`

에이전트가 실제 구현할 때 보는 가이드다.

포함 내용:

- 구현 순서
- 수정할 파일
- 테스트 방법
- 주의사항
- 하지 말아야 할 것

서브에이전트는 가능하면 이 파일만 보고도 작업할 수 있어야 한다.

### 4.5 `journal/YYYY-MM.md`

AI가 읽기 좋은 구현 일지다.

단, 이 파일은 `post-commit`이 직접 수정하지 않는다.  
`doc-sync`가 `.git/seasoned-architect/raw-log.jsonl`을 읽고 생성/갱신한다.

---

## 5. 기록 설계

### 5.1 raw log와 journal을 분리한다

기록에는 두 단계가 있다.

| 단계 | 저장 위치 | 작성 주체 | 역할 |
|---|---|---|---|
| raw log | `.git/seasoned-architect/raw-log.jsonl` | git `post-commit` hook | 커밋 사실을 절대 놓치지 않기 |
| journal | `docs/agent/journal/YYYY-MM.md` | AI sync skill | 사람이 읽기 좋은 설명으로 정리 |

이 구조의 장점:

- 커밋 직후 working tree가 dirty 되지 않는다.
- 사람이 직접 한 커밋도 포착한다.
- AI 서술이 늦어져도 raw 사실은 남는다.
- Codex 이식 시에도 git hook을 그대로 재사용할 수 있다.

> **`[v3]` 내구성 주의**: `.git/` 내부라 raw log는 **clone/다른 머신으로 따라오지 않는다.** 즉 raw log는 "휘발성 스크래치", **영속 기록은 오직 `journal/*.md`**다. 머신을 옮기거나 새로 clone하기 전에는 반드시 `doc-sync`로 journal에 반영해야 미동기화 사실이 유실되지 않는다. (→ §5.5 넛지가 이 위험을 줄인다)

### 5.2 raw log 형식

위치:

```txt
.git/seasoned-architect/raw-log.jsonl
```

예시:

```jsonl
{"commit":"a1b2c3d","timestamp":"2026-07-02T14:03:00+09:00","author":"임승용","message":"refactor payment retry logic","changed_files":["src/pay/retry.ts","src/pay/retry.test.ts"],"source":"git-hook"}
```

권장 필드:

| 필드 | 설명 |
|---|---|
| `commit` | 커밋 해시 |
| `timestamp` | 커밋 시각 |
| `author` | 커밋 작성자 |
| `message` | 커밋 메시지 |
| `changed_files` | 변경 파일 목록 |
| `source` | `git-hook` |

> **`[v3]` `synced` 필드 정리**: v2 예시엔 `"synced":false`가 있었으나, sync 추적은 §10.2 **옵션 C(journal에 commit hash가 있는지로 판단)** 를 우선 채택한다. 이 경우 `synced` 필드는 중복이므로 **선택**으로 둔다. (git hook이 raw log의 과거 줄을 되짚어 수정하는 것도 피하는 게 단순하다.)

주의:

- `.git/` 내부 파일이라 git에 커밋되지 않는다.
- 레포를 새로 clone하면 raw log는 따라오지 않는다.
- 장기 보존용 기록은 `docs/agent/journal/*.md`에 반영되어야 한다.

### 5.3 journal entry 형식

예시:

```md
## 2026-07-02 14:03 · [slice: payment] · commit a1b2c3d

- **무엇(What)**: 결제 재시도 로직을 리팩터링했다.
- **왜(Why)**: 기존 로직이 일부 케이스에서 중복 결제를 유발할 수 있었다.
- **결과(Result)**: 관련 테스트를 추가했고 기존 테스트가 통과했다.
- **다음(Next/Open)**: 환불 케이스는 별도 slice에서 다룬다.
- **변경 파일**: `src/pay/retry.ts`, `src/pay/retry.test.ts`
- **Source**: `git-hook` → `ai-enriched`
- **Confidence**: `ai-enriched`
```

`Source`, `Confidence`를 둔다.

| 값 | 의미 |
|---|---|
| `raw` | git hook이 포착한 사실만 있음 |
| `ai-enriched` | AI가 커밋과 diff를 보고 설명을 보강함 |
| `user-confirmed` | 사용자가 내용 확인/수정함 |

### 5.4 커밋 포착 경로 — git hook vs PostToolUse `[v3]`

커밋을 raw log로 잡는 방법은 두 가지가 있다.

| 경로 | 포착 범위 | 설치 | 비고 |
|---|---|---|---|
| **git `post-commit` 훅** (D7, 채택) | **모든 커밋** (Claude·Codex·수동 터미널) | 스크립트로 설치 필요 | 도구 무관·이식성 최고. AI 없어도 작동 |
| PostToolUse `if:"Bash(git commit *)"` | **Claude가 낸 커밋만** | 플러그인 hooks.json에 내장(설치 불필요) | 수동/Codex 커밋은 못 잡음 |

**권장**: **raw 포착의 주력은 git 훅**으로 유지한다(D5의 "수동 작업까지 포착" 목표를 만족하는 유일한 경로). PostToolUse는 raw 포착용이 아니라, **§5.5 넛지의 트리거**(Claude 커밋 직후 즉시 "동기화할래?" 유도)로 쓰면 좋다. 이 경우 두 경로가 역할이 달라 중복 기록 위험도 없다.

### 5.5 일지 동기화 리마인드(넛지) `[v3] 제안`

`doc-sync`가 완전 수동이면, 읽기 쪽에서 없앤 "깜빡" 위험이 쓰기 쪽에 남는다. 이를 값싸게 막는다.

- `scripts/seasoned-architect-context.sh`가 **미동기화 커밋 수**를 계산한다.
  - 방법: raw log의 커밋 해시 중, `journal/*.md`에 아직 없는 것의 개수(§10.2 옵션 C와 동일 로직).
- SessionStart 주입 규칙 끝에 한 줄을 조건부로 덧붙인다.
  - 예: `미반영 커밋 3개 있음 → /seasoned-architect:doc-sync 권장`
  - 0개면 아무 것도 붙이지 않는다(노이즈 최소).
- (선택) PostToolUse `Bash(git commit *)`로 Claude 커밋 직후 같은 넛지를 즉시 띄운다.

효과: 기존 인프라(`seasoned-architect-context.sh`)만으로 "쓰기 루프"가 닫힌다. 강제 차단이 아니라 **권유**라 1인용 원칙과도 맞는다. → 채택 여부는 §10.5.

---

## 6. 플러그인 구조

Claude Code 플러그인 구조는 다음을 권장한다.

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
│   ├── structure.md
│   ├── slice-plan.md
│   ├── slice-guide.md
│   └── journal-entry.md
└── scripts/
    ├── install-git-hook.sh
    ├── post-commit-capture.sh
    └── seasoned-architect-context.sh
```

> **`[v3]` 자동 발견**: `skills/`, `hooks/hooks.json`, `commands/`, `agents/` 등은 **플러그인 설치 시 자동 발견**된다. `plugin.json`에 경로를 명시할 필요가 없다(오히려 불필요). 관례 디렉토리명만 지키면 매니페스트 없이도 로드된다.

> **`[v3]` skill 호출 주체**: 각 `SKILL.md` 프론트매터로 호출 방식을 구분한다.
> - **사용자 트리거**: `doc-init`, `doc-slice`, `doc-sync` — `/seasoned-architect:*`로 사용자가 직접 호출.
> - **모델 내부**: `journaling` — 사용자가 부르는 게 아니라 `doc-sync`가 참조하는 규칙 지식(모델 주도 호출 또는 doc-sync가 읽는 레퍼런스).

### 6.1 `.claude-plugin/plugin.json`

역할:

- 플러그인 이름 / 설명 / 버전 / author

예상 이름 **`[v3]` 간소화**(경로 필드 제거 — 자동 발견):

```json
{
  "name": "seasoned-architect",
  "version": "0.1.0",
  "description": "Keeps AI agents oriented in long-running projects through docs, commit logs, and lazy context loading.",
  "author": {
    "name": "임승용"
  }
}
```

- `name`, `description`만 필수. `version`·`author`는 선택.
- `skills`/`hooks` 경로 필드는 **넣지 않는다**(자동 발견).

### 6.2 `hooks/hooks.json`

역할:

- `SessionStart`: 짧은 Seasoned Architect 사용 규칙만 주입
- `SubagentStart`: 서브에이전트용 짧은 규칙만 주입 **(`[v3]` 이벤트 실재 확인 — `agent_type` 매처 사용 가능)**
- (선택) `PostToolUse` `if:"Bash(git commit *)"`: 커밋 직후 동기화 넛지 (§5.5)

문서 본문은 주입하지 않는다.

주입 방식 **`[v3]`**: 훅 스크립트가 JSON으로 `hookSpecificOutput.additionalContext`를 반환하거나 stdout으로 출력(최대 10,000자, `exit 0`).

예상 동작:

```md
Seasoned Architect active.
For context-heavy work, inspect docs/agent/DOCS_MAP.md first.
Read only the relevant slice docs and latest journal entries.
Do not load all agent docs by default.
```

### 6.3 `doc-init` skill

새 프로젝트에서 1회 실행한다.

역할:

1. 레포 구조 스캔
2. `docs/agent/` 생성 제안
3. `structure.md` 초안 생성
4. `DOCS_MAP.md` 초안 생성
5. 기본 slice 후보 제안
6. git `post-commit` hook 설치 안내 또는 설치 실행 **(`[v3]` §10.1 견고성 규칙 준수)**

주의:

- 자동으로 큰 변경을 하지 않는다.
- 생성 전 사용자 확인을 받는다.

### 6.4 `doc-slice` skill

새 작업 단위를 만들 때 실행한다.

역할:

- `docs/agent/slices/<slice>/plan.md` 생성
- `docs/agent/slices/<slice>/guide.md` 생성
- `DOCS_MAP.md`에 slice 매핑 추가 제안

### 6.5 `doc-sync` skill

raw log를 journal로 변환/보강한다.

역할:

1. `.git/seasoned-architect/raw-log.jsonl` 확인
2. 아직 journal에 반영되지 않은 commit 찾기
3. 필요하면 `git show <commit>`으로 변경 내용 확인
4. 관련 slice 추론
5. `docs/agent/journal/YYYY-MM.md`에 entry 추가
6. sync 상태 기록

> **`[v3]` slice 매칭 규칙**: 4단계에서 커밋이
> - 여러 slice에 걸치면 → 해당 slice를 모두 태그(또는 `cross-cutting`).
> - `DOCS_MAP`에 매핑 없는 영역이면 → `unassigned`로 두고 "DOCS_MAP 갱신 필요"를 `Next/Open`에 남긴다.

주의:

- AI가 추정한 내용은 `Confidence: ai-enriched`로 표시한다.
- 확신이 낮으면 `Next/Open`에 확인 필요 항목으로 남긴다.

### 6.6 `journaling` skill

좋은 일지를 쓰기 위한 내부 규칙이다.

역할:

- journal entry 스키마 정의
- 좋은/나쁜 기록 예시 제공
- AI가 과장하거나 없는 의도를 지어내지 않게 제한

---

## 7. 운영 흐름

### 7.1 초기화

```txt
사용자 → /seasoned-architect:doc-init
AI → 레포 스캔
AI → docs/agent 초안 제안
사용자 → 승인
AI → docs/agent 파일 생성
AI → git hook 설치 안내 또는 설치
```

### 7.2 새 slice 시작

```txt
사용자 → /seasoned-architect:doc-slice onboarding
AI → plan.md / guide.md 템플릿 생성
사용자 → 내용 보완
AI → 구현 시 guide.md 기준으로 작업
```

### 7.3 작업 중

```txt
SessionStart/SubagentStart
→ 짧은 Seasoned Architect 규칙만 주입 (+ [v3] 미동기화 커밋 넛지)
→ 맥락이 중요한 작업이면 DOCS_MAP.md 확인
→ 관련 slice 문서만 읽음
→ 작업 수행
```

### 7.4 커밋 후

```txt
git commit
→ post-commit hook 실행
→ .git/seasoned-architect/raw-log.jsonl에 커밋 사실 저장
→ working tree는 dirty 되지 않음
```

### 7.5 일지 동기화

```txt
사용자 → /seasoned-architect:doc-sync   (또는 [v3] 넛지를 보고 실행)
AI → raw log 확인
AI → git show로 변경 내용 확인
AI → journal/YYYY-MM.md 작성 또는 보강
```

---

## 8. Codex 이식 계획

| 기능 | Claude Code | Codex |
|---|---|---|
| 플러그인 패키징 | Claude Code plugin | Codex plugin/skill 구조로 재구성 |
| 세션 시작 규칙 | `SessionStart` hook | `AGENTS.md` 또는 Codex용 instruction |
| 서브에이전트 시작 규칙 | `SubagentStart` hook | Codex subagent 지시문 또는 작업 템플릿 |
| 커밋 사실 포착 | git `post-commit` hook | 동일하게 사용 |
| raw log 저장 | `.git/seasoned-architect/raw-log.jsonl` | 동일하게 사용 |
| journal 작성 | `/seasoned-architect:doc-sync` skill | Codex skill 또는 명령으로 이식 |
| 문서 본문 | `docs/agent/**` | 그대로 사용 |

핵심:

- `docs/agent/**`는 그대로 유지한다.
- git hook도 거의 그대로 유지한다.
- Claude Code hook만 Codex의 instruction/skill 방식으로 바꾼다.

---

## 9. MVP 범위

v0.1에서 만들 것:

1. `seasoned-architect` 플러그인 기본 구조
2. `doc-init` skill
3. `doc-slice` skill
4. `doc-sync` skill
5. `journaling` skill
6. `SessionStart` 짧은 규칙 주입 hook
7. `SubagentStart` 짧은 규칙 주입 hook
8. `post-commit-capture.sh`
9. `.git/seasoned-architect/raw-log.jsonl` raw 기록
10. 기본 템플릿 5종
11. **`[v3]`** `seasoned-architect-context.sh` + 미동기화 커밋 넛지(§5.5 채택 시)

v0.1에서 제외할 것:

- 팀용 설정 UI
- 복잡한 권한 관리
- 원격 저장소 기반 동기화
- 여러 사람의 journal 충돌 해결
- staleness guard 강제 차단
- 자동으로 모든 문서 읽기
- build-loop 내장

---

## 10. 아직 열려 있는 결정

### 10.1 git hook 설치 방식

선택지:

| 옵션 | 설명 | 장점 | 단점 |
|---|---|---|---|
| A | `doc-init`이 사용자 확인 후 `.git/hooks/post-commit` 직접 설치 | 간단함 | 기존 hook이 있으면 병합 필요 |
| B | `core.hooksPath`를 별도 폴더로 설정 | 관리 쉬움 | 프로젝트 기존 설정과 충돌 가능 |
| C | 설치 스크립트만 제공하고 사용자가 직접 실행 | 안전함 | 자동성이 낮음 |

추천: **A로 시작하되, 기존 hook이 있으면 백업 후 병합 제안**.

> **`[v3]` 설치 견고성 요구(공식 미문서 영역 — 방어적으로)**:
> 1. 설치 전 `git config --get core.hooksPath`를 확인한다. 설정돼 있으면 `.git/hooks/`가 아니라 **그 경로**에 설치해야 한다(안 그러면 훅이 조용히 무시됨 — Husky 등).
> 2. 기존 `post-commit`이 있으면 **백업**(`post-commit.bak`) 후 append 방식으로 병합.
> 3. 훅 스크립트는 **항상 `exit 0`**, 빠르게 끝나고, 실패해도 커밋을 막지 않는다(기록 실패 ≠ 커밋 실패).

### 10.2 raw log sync 상태 저장 방식

선택지:

| 옵션 | 설명 |
|---|---|
| A | raw log 각 줄에 `synced`를 수정 |
| B | `.git/seasoned-architect/synced-commits.txt` 별도 관리 |
| C | journal에서 commit hash 존재 여부로 판단 |

추천: **C 우선**. 가장 단순하다.  
필요해지면 B를 추가한다.  
**`[v3]`** C를 택했으므로 §5.2의 `synced` 필드는 선택항목으로 정리했다.

### 10.3 journal 파일 단위

선택지:

| 옵션 | 설명 |
|---|---|
| 월별 | `journal/2026-07.md` |
| slice별 | `journal/payment.md` |
| 둘 다 | 월별 + slice index |

추천: **월별**.  
slice별 검색은 나중에 인덱스로 보강한다.

### 10.4 staleness guard

나중에 고려할 기능:

- 특정 code path가 바뀌었는데 관련 journal이 없으면 경고
- `DOCS_MAP.md`에 없는 영역을 수정하면 경고
- 오래된 slice guide를 업데이트하라고 제안

v0.1에서는 차단하지 않고 **경고만** 고려한다.

### 10.5 doc-sync 리마인드(넛지) 채택 여부 `[v3]`

§5.5의 넛지를 v0.1에 넣을지.

- **넣기(추천)**: `seasoned-architect-context.sh`로 미동기화 커밋 수를 세어 SessionStart 규칙에 한 줄. 쓰기 루프가 닫힌다. 비용 거의 0.
- **빼기**: 완전 수동 유지. 더 단순하지만 journal이 낡을 위험.

권장: **넣기.** 단, 넛지는 "권유"까지만(자동 실행·차단 아님).

---

## 11. 성공 기준

v0.1이 성공하려면 다음이 가능해야 한다.

1. 새 레포에서 `/seasoned-architect:doc-init`으로 `docs/agent/` 초안을 만들 수 있다.
2. 새 작업 단위를 `/seasoned-architect:doc-slice <name>`으로 만들 수 있다.
3. 커밋하면 `.git/seasoned-architect/raw-log.jsonl`에 기록이 남는다.
4. 커밋 직후 working tree가 dirty 되지 않는다.
5. `/seasoned-architect:doc-sync`를 실행하면 journal markdown이 생긴다.
6. 새 세션/서브에이전트는 문서 본문이 아니라 짧은 사용 규칙만 받는다.
7. 사용자가 “최근 문서 확인하고 이어서 작업해줘”라고 하면 관련 문서만 읽고 작업한다.
8. **`[v3]`** 미동기화 커밋이 있으면 세션 시작 시 그 사실이 넛지로 뜬다(§10.5 채택 시).

---

## 12. 구현 순서 제안

1. 플러그인 뼈대 생성
2. 템플릿 작성
3. `post-commit-capture.sh` 작성 **(+ `[v3]` install-git-hook.sh 견고성 §10.1)**
4. raw log 포맷 검증
5. `doc-sync` skill 작성 **(+ `[v3]` slice 매칭 규칙 §6.5)**
6. `doc-init` skill 작성
7. `doc-slice` skill 작성
8. `SessionStart` / `SubagentStart` hook 작성 **(+ `[v3]` 넛지 §5.5, 채택 시)**
9. 실제 테스트 레포에서 end-to-end 검증
10. v0.1 태그

---

## 13. 참고 링크

- Claude Code Hooks: https://code.claude.com/docs/en/hooks-guide
- Claude Code Plugins: https://code.claude.com/docs/en/plugins
- Claude Code Plugins Reference: https://code.claude.com/docs/en/plugins-reference
- Claude Code Skills: https://code.claude.com/docs/en/skills
- Cline Memory Bank: https://docs.cline.bot/best-practices/memory-bank
- Kiro Steering: https://kiro.dev/docs/steering/
- Agent OS: https://github.com/buildermethods/agent-os
- GitHub Spec Kit: https://github.com/github/spec-kit
- BMAD-METHOD: https://github.com/bmad-code-org/BMAD-METHOD
- Task Master AI: https://github.com/eyaltoledano/claude-task-master
