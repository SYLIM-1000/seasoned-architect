# Seasoned Architect Plugin — 기획 문서 (v0 draft)

> **한 줄 요약**: AI 에이전트가 작업하면서 **문서를 계속 기록·참조**하게 만들어, 길고 복잡한 프로젝트에서 에이전트가 길을 잃지 않고 전체 현황을 남기게 하는 Claude Code 플러그인. (완성 후 Codex에도 이식 예정)

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-01 |
| 상태 | **v0 draft** (설계 확정 전, 아이데이션 산출물) |
| 대상 사용자 | 임승용 본인 (1인) — 완성 후 Codex 이식 |
| 작성 | 임승용 × Claude (브레인스토밍 세션) |
| 플러그인 이름 | `seasoned-architect` |

---

## 1. 목적 & 배경

### 왜 만드나
장기적·복잡한 프로젝트에서 AI 에이전트(들)는 쉽게 **길을 잃는다.** 눈앞 작업에 매몰되어 큰 그림을 놓치고, 세션이 바뀌면 이전 맥락을 잊고, 무엇을 왜 했는지 기록이 남지 않는다. 이 플러그인은 **문서를 통해** 이 문제를 해결한다.

### 이번 세션에서 확인한 "실제로 겪는 문제" (우선순위)
1. **🥇 기록 부재 / 추적 불가** — *무엇을 왜 했는지 남는 게 없어 되짚거나 이어가기 어렵다.* → **이 플러그인의 최우선·심장.**
2. 세션 단절 / 망각 — 새 세션마다 컨텍스트를 다시 설명해야 한다.
3. 큰 그림 상실(drift) — 전체 구조·목표에서 벗어난다.

> **제외**: "다중 에이전트 혼선"은 이미 *slice별 구현가이드 선(先)작성 + `/build-loop` 스킬*로 예방 중이므로, 이 플러그인의 핵심 범위에서 뺀다. (연동은 함 — 아래 참고)

---

## 2. 확정된 결정 (Locked Decisions)

이번 세션에서 합의한 것:

| # | 결정 | 이유 |
|---|---|---|
| D1 | **대상 = 나 1인 (+ Codex 이식)** | 범용 예외처리 걷어내고(YAGNI) 내 워크플로우에 최적화. 단 이식성은 설계에 못박음. |
| D2 | **심장 = git 커밋 기반 구현일지** | 커밋은 (a) 빌드루프 밖 수동작업까지 잡고 (b) git은 도구 무관이라 Codex 이식이 공짜. |
| D3 | **다중 조율은 범위 밖** | 이미 build-loop + 선작성 slice 가이드로 해결됨. |
| D4 | **build-loop = "통합만"** (내장 X) | git 커밋이 이음새라 build-loop의 머지 커밋을 일지 훅이 자동 포착. 내장 시 결합도·중복·이식 문제만 늘고 실익 없음. |
| D5 | **항상 켜짐 = 훅(Hook)으로** | 훅은 이벤트에 결정론적으로 자동 발동. Skill/Command는 모델 판단/수동이라 보장 안 됨. |
| D6 | **폴더링 = DOCS_MAP 어댑터** | 코드 구조에 문서를 끼워맞추지 않고, 고정 문서트리 + 프로젝트별 매핑으로 유연성 확보. |

---

## 3. 핵심 설계 원칙

1. **2층 분리 (가장 중요)** — *내용층(문서·규약)은 두껍게, 실행층(훅·커맨드)은 얇게.*
   - 내용층 = 순수 마크다운 → 도구 무관, **Codex 이식 공짜**.
   - 실행층 = Claude Code 훅/커맨드 → Codex에선 `AGENTS.md` + git 훅으로 **재매핑**.
2. **훅 = 결정론적 강제** — "무조건 작동해야 하는 것"은 반드시 훅으로. (일지 기록, 세션 시작 시 문서 주입)
3. **논리적 슬라이스 > 물리적 미러링** — 문서는 코드 폴더를 1:1 복제하지 않는다. 리팩터로 경로가 바뀌어도 `DOCS_MAP`만 고치면 됨.
4. **문서 안정도로 계층화** — 거의 안 변하는 문서(구조)와 매번 바뀌는 문서(일지)를 섞지 않는다.
5. **YAGNI** — 1인용이므로 남 쓸 범용 설정·예외처리는 만들지 않는다.

---

## 4. 아키텍처 스케치

### 4.1 운영 루프 (핵심 동작)

```mermaid
flowchart LR
    A["세션 시작<br/>(훅이 문서 주입)"] --> B["문맥 파악<br/>MAP·구조·최근 일지"]
    B --> C["구현<br/>슬라이스 가이드"]
    C --> D["git commit"]
    D --> E["일지 기록<br/>(커밋마다 자동) ★심장"]
    E -. "다음 세션에 read → 연속성·drift 방지" .-> A
```

- 일지는 **커밋 때 쓰이고(write) → 다음 세션 시작 때 읽힌다(read).** 이 한 바퀴가 "망각·drift 방지"의 실체.

### 4.2 2층 구조

| 층 | 무엇 | Claude Code | Codex 이식 |
|---|---|---|---|
| **내용층** (두껍게) | 문서·규약 (자산) | `docs/agent/` 마크다운 | **그대로** — 이식 공짜 |
| **실행층** (얇게) | 문서를 읽고·쓰게 강제 | hooks · commands · skill | `AGENTS.md` + git 훅으로 **재매핑** |

### 4.3 내용층 — 5개 문서 (원안 ①~⑤ 매핑)

```
<target-repo>/docs/agent/
├── DOCS_MAP.md          ④ 지도/어댑터 — "무슨 작업이면 어디 읽어라" + slice↔코드경로 매핑
├── structure.md         ① 전체 구조 — 목표·아키텍처·기술스택 (불변층, drift 방지)
├── slices/
│   └── <slice>/
│       ├── plan.md      ② 기획 (왜/무엇)
│       └── guide.md     ② 구현가이드 (어떻게 — 서브에이전트가 이것만 보고 구현)
└── journal/
    └── 2026-07.md       ③ 구현일지 — 커밋마다 append (★ 심장)
```

| # | 문서 | 안정도 | 언제 읽나 | 언제 쓰나 |
|---|---|---|---|---|
| ① | `structure.md` | 불변 | 세션 시작 | `/doc-init`, 구조 변경 시 |
| ② | `slices/<slice>/` | 중간 | 그 슬라이스 작업 시 | 착수 전 선(先)작성 |
| ③ | `journal/` | 휘발 | 세션 시작(최근분) | **커밋마다 자동** |
| ④ | `DOCS_MAP.md` | 중간 | **가장 먼저**(매 세션) | `/doc-init`, slice 추가 시 |
| ⑤ | (강제장치) | — | — | 훅 = 실행층 전체 |

### 4.4 실행층 — 플러그인 컴포넌트 (Claude Code)

```
seasoned-architect/  (플러그인)
├── .claude-plugin/plugin.json      # 매니페스트
├── hooks/hooks.json                # ⑤ SessionStart(문서 주입) + 커밋 감지(일지 트리거)
├── commands/
│   ├── doc-init.md                 # 레포 스캔 → structure + DOCS_MAP + slice 뼈대 제안
│   ├── doc-slice.md                # 슬라이스 하나 scaffold (plan+guide 템플릿)
│   └── doc-log.md                  # 수동 일지 (자동 기록의 백업)
├── skills/journaling/SKILL.md      # "좋은 일지 쓰는 법"(스키마·규칙) — 훅이 이 규칙으로 기록
├── templates/                      # structure / slice-plan / slice-guide / journal-entry
└── scripts/
    └── post-commit-capture.sh      # (옵션) 결정론적 raw 캡처 — Codex 이식 시 재사용
```

- **`hooks/hooks.json`이 심장부.** SessionStart 훅이 "DOCS_MAP 먼저 읽어라 + 최근 일지 N개 + structure"를 매 세션 자동 주입.
- **서브에이전트 대응**: 주입 컨텍스트에 *"작업 전 `docs/agent/DOCS_MAP.md` 먼저 읽어라"* 규칙 + 경로 고정. (build-loop이 띄우는 서브에이전트도 문서를 읽게)

---

## 5. ⚠️ 열린 결정 — "일지 서술을 누가 쓰나"

일지 트리거는 커밋으로 확정. 남은 질문: **커밋 순간 '무엇을/왜/결과'라는 서술을 실제로 쓰는 주체.**

### 개념 (초보용)
- **Claude 훅(`PostToolUse`)**: Claude(AI) 안에서 발동 → AI에게 "지금 일지 써"라고 시킬 수 있음. AI는 방금 뭘 왜 했는지 다 알아 **풍부하게 서술**. 단, 작업자가 Claude일 때만 됨.
- **git 훅(`post-commit`)**: git 프로그램의 셸 스크립트 → AI 없음. **사실만**(해시·파일·메시지·시각) 기록. 누가 하든 무조건 남지만 '왜'는 없음 → 나중에 AI가 채워야 함.

### 일지에는 '두 가지 일'이 있다
- **일① 기록을 절대 놓치지 않기(사실 포착)** → 멍청하지만 확실한 **git 훅**.
- **일② 의미를 서술(무엇/왜)** → **AI**.

### 선택지
| | 방식 | 장점 | 단점 |
|---|---|---|---|
| 옵션1 | Claude 실시간만 | 가장 단순, 서술 풍부 | Codex 가면 일지 안 남음, 손커밋 놓침 |
| 옵션2 | git 훅만 | 어디서나·무조건 남음 | 전부 사후 서술이라 덜 풍부 |
| **옵션3 (추천)** | 결합 | git 훅이 사실을 항상 포착(절대 안 놓침) + AI가 서술(Claude=실시간, Codex=다음 세션에 채움) | 만들 게 조금 더 많음 |

> **옵션3 한 줄**: "멍청한 층(git 훅)은 절대 안 잊고, 똑똑한 층(AI)은 설명한다."

### 판단 기준
- **당분간 Claude Code만** → **옵션1로 시작**, Codex 옮길 때 옵션3로 승격 (YAGNI).
- **곧 Codex도 / 기록 누락을 절대 싫어함** → 처음부터 **옵션3**.

**→ 결정 대기 중** (D2의 세부. 일지 *포맷*은 세 옵션 모두 동일하므로 내용층은 안 갈라짐.)

---

## 6. 사용 워크플로우

1. **`/doc-init`** — 새 프로젝트에서 1회. 레포를 스캔해 `structure.md` + `DOCS_MAP.md` + slice 뼈대 초안 제안 → 내가 승인.
2. **`/doc-slice <이름>`** — 슬라이스 착수 전 기획+구현가이드 scaffold (템플릿). 내가 내용 채움.
3. **작업** — 에이전트가 세션 시작 시 주입받은 DOCS_MAP → 해당 slice guide 읽고 구현. (build-loop 사용 가능)
4. **커밋** — 커밋 순간 일지 자동 기록(위 열린 결정 방식).
5. **다음 세션** — 최근 일지 자동 주입 → 연속성 유지. (1로 순환)

---

## 7. Codex 이식 계획 (실행층 재매핑)

| 기능 | Claude Code | Codex |
|---|---|---|
| 항상 읽히는 지시 | SessionStart 훅이 컨텍스트 주입 | **`AGENTS.md`** (Codex가 자동 로드)에 "작업 전 DOCS_MAP 읽기" 규약 |
| 일지 트리거 | `PostToolUse`(commit 감지) | **git `post-commit` 훅** (도구 무관, 동일 작동) |
| 일지 서술 | AI 실시간 | git 훅 raw 캡처 + 다음 세션에 AI가 서술 |
| 문서·규약·템플릿 | `docs/agent/**` | **동일** (마크다운, 수정 불필요) |

> 원칙 재확인: **내용층 이식은 공짜, 실행층만 도구별로 다시 붙인다.**

---

## 8. 참고한 유사 도구 (리서치 요약)

| 도구 | 빌려올 점 |
|---|---|
| **Cline Memory Bank** | 문서를 안정도로 계층화(불변/휘발), "매 작업 시작 시 읽고 갱신" 패턴 |
| **Kiro (AWS)** | Spec+Steering(상시참조)+Hooks 조합 — 우리 개념의 "정답지". 단 닫힌 IDE |
| **Agent OS** | Standards/Product/Specs 3계층 + drift 방지 |
| **GitHub Spec Kit** | `/specify /plan /tasks` 슬래시 커맨드 UX, 사람 검토 체크포인트 |
| **BMAD-METHOD** | 큰 문서를 story로 sharding → 자기완결적 slice 문서 |
| **Task Master AI** | 진행 현황을 구조화된 상태로 추적 (일지의 대안적 형태) |

링크:
- Cline Memory Bank — https://docs.cline.bot/best-practices/memory-bank
- Kiro Steering — https://kiro.dev/docs/steering/
- Agent OS — https://github.com/buildermethods/agent-os
- GitHub Spec Kit — https://github.com/github/spec-kit
- BMAD-METHOD — https://github.com/bmad-code-org/BMAD-METHOD
- Task Master AI — https://github.com/eyaltoledano/claude-task-master
- Claude Code Hooks — https://code.claude.com/docs/en/hooks-guide

---

## 9. 미해결 질문 / 다음 단계

### 보류 중인 확인 (사용자 판단 대기)
1. 골격(2층 + 5문서 + 루프) 이대로 확정할지, 가감할지.
2. 열린 결정(§5): 일지 서술 방식 옵션1/2/3.
3. 문서 루트 이름 `docs/agent/` 확정 여부.
4. 플러그인 작명 (가칭 `seasoned-architect`).

### 추후 결정 (나중에)
- **Staleness 가드(⑤ 보강)**: 코드가 바뀌었는데 해당 slice 일지가 안 바뀌면 경고/차단할지.
- **일지 파일 단위**: 월별(`journal/YYYY-MM.md`) vs slice별 vs 둘 다 + 인덱스.
- **일지 ↔ 커밋 연결**: entry에 commit hash를 박아 추적성 강화.

### 다음 단계
1. 위 확인 3~4개 정리 → **정식 spec 문서로 확정·커밋**.
2. spec → **구현 계획(writing-plans)** → 슬라이스 단위 구현(build-loop).

---

## 부록 A. 문서 스키마 초안 (참고용, 미확정)

### 구현일지 entry
```markdown
## 2026-07-01 14:03 · [slice: payment] · commit a1b2c3d
- **무엇(What)**: 결제 재시도 로직 리팩터
- **왜(Why)**: 기존 로직이 이중결제 유발
- **결과(Result)**: 테스트 12/12 통과, 배포 전 검증 완료
- **다음(Next/Open)**: 환불 케이스 미처리 → 별도 slice 필요
- **변경 파일**: `src/pay/retry.ts`, `src/pay/retry.test.ts`
```

### 슬라이스 plan.md (front-matter 초안)
```markdown
---
slice: payment
status: planned | in-progress | done
code_paths: [src/pay/, api/checkout/]
---
## 왜(Why) / 무엇(What)
(기획 서술)
```

### DOCS_MAP.md (초안)
```markdown
# 이 프로젝트 문서 지도
- 결제 관련 작업 → `slices/payment/` 읽기 (코드: src/pay/, api/checkout/)
- 전체 구조 파악 → `structure.md`
- 최근 진행 현황 → `journal/` 최신 파일

## 규칙
- 모든 에이전트는 작업 전 이 파일을 **가장 먼저** 읽는다.
```
