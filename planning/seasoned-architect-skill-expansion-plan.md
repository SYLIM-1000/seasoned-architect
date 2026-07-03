# Seasoned Architect Skill Expansion Plan

> 이 문서는 플러그인 build를 위한 기록 문서다. 플러그인 사용자에게 배포되는 기능 문서가 아니며, `seasoned-architect/` 플러그인 소스 안에 넣지 않는다.

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-07-02 |
| 상태 | `doc-breakdown` / `doc-slice` 세부 실행 방식 확정 |
| 대상 플러그인 | `seasoned-architect` |
| 목적 | 외부 기획 결과 → 구현 흐름을 Seasoned Architect 문서 구조로 연결 |

---

## 1. 확정된 스킬 구성

`doc-foundation`은 만들지 않는다.

이유:

- 아이데이션과 기획 구체화는 사용자가 이미 `brainstorming`, `grill-me` 등 외부 스킬로 진행한다.
- 시각화는 별도 도구를 사용한다.
- Seasoned Architect는 생각을 만들어내는 도구보다, 확정된 기획을 구현 가능한 문서 구조로 정리하는 도구에 집중한다.

기존에 검토한 `doc-split`도 새로 만들지 않는다. 기존 `doc-slice`와 역할이 겹치므로, `doc-slice`를 확장한다.

| 스킬 | 담당 단계 | 역할 |
|---|---:|---|
| 외부 기획 스킬/도구 | 1~3 | `brainstorming`, `grill-me`, 시각화 도구로 서비스 기획, 화면 구성, 아키텍처 방향 구체화 |
| `/seasoned-architect:doc-breakdown` | 4~6 + 문서 구조화 | 외부 기획 결과를 Seasoned Architect 문서 구조로 정리하고 MVP → 파트 → 구현 스펙으로 분해 |
| `/seasoned-architect:doc-slice` | 7~8 | 구현 스펙을 slice로 만들고 `plan.md` / `guide.md` 생성 |

전체 흐름:

```txt
brainstorming / grill-me / 시각화 도구
→ /seasoned-architect:doc-breakdown
→ sub agent 필수 검토
→ /seasoned-architect:doc-slice
→ sub agent plan 리뷰
→ build-loop-codex
```

---

## 2. 사용자 구현 방식과 스킬 매핑

| 사용자 단계 | 내용 | 담당 스킬 |
|---:|---|---|
| 1 | 서비스 기획을 철저히 진행 | 외부 `brainstorming`, `grill-me` |
| 2 | 프론트엔드 페이지, 버튼, 컴포넌트 기획 | 외부 기획/시각화 도구 |
| 3 | 프로젝트/프론트엔드 기획안을 토대로 아키텍처 선택 | 외부 기획 결과 + `doc-breakdown`에서 문서화 |
| 4 | MVP 분할 | `doc-breakdown` |
| 5 | MVP별 큰 파트 분할 | `doc-breakdown` |
| 6 | 파트별 구현 필요 스펙 정의 | `doc-breakdown` |
| 7 | 구현 스펙 slice화 | `doc-slice` |
| 8 | slice별 세부 개발 가이드 작성 | `doc-slice` |
| 9 | build-loop-codex로 slice 구현 | 외부 skill 연동 |

---

## 3. 스킬별 최종 정의

### 3.1 `doc-breakdown`

역할:

- 외부 기획 결과를 Seasoned Architect 문서 구조에 맞게 정리한다.
- 기획을 새로 보완하지 않는다. 입력 기획이 부족하면 부족 항목을 알려주고 `brainstorming` / `grill-me` 사용을 안내한다.
- 제품 목표, 핵심 사용자 흐름, 기본 아키텍처, 프론트엔드 구성을 문서에 반영한다.
- 정리된 기획을 바탕으로 MVP를 나눈다.
- MVP별 큰 파트를 나눈다.
- 파트별 구현 필요 스펙을 정의한다.
- Implementation Spec 초안 작성 직후 sub agent 검토를 반드시 실행한다.
- 검토 결과를 반영한 뒤 사용자 최종 확인을 받는다.
- `WORK_BREAKDOWN.md`를 중심 문서로 관리한다.

주요 출력:

- `docs/agent/structure.md`
- `docs/agent/frontend-components.md`
- `docs/agent/WORK_BREAKDOWN.md`

입력으로 받을 수 있는 것:

- `brainstorming` 결과
- `grill-me` 결과
- 별도 시각화/기획 문서
- 사용자가 직접 설명한 서비스 기획
- 기존 `structure.md`, `frontend-components.md`

시작 가능 조건:

- 화면/페이지 구성이 어느 정도 정리되어 있어야 한다.
- 주요 컴포넌트가 어느 정도 정리되어 있어야 한다.
- 데이터 구조가 어느 정도 정리되어 있어야 한다.
- 권한/사용자 역할이 어느 정도 정리되어 있어야 한다.
- 예외 케이스가 어느 정도 정리되어 있어야 한다.
- 아키텍처 방향이 어느 정도 정리되어 있어야 한다.

고정 workflow:

```txt
외부 기획 결과 입력
→ 시작 가능 조건 점검
→ Seasoned Architect 문서 구조로 정리
→ MVP 후보 제안
→ 사용자와 MVP 확정
→ MVP별 Part 후보 제안
→ 사용자와 Part 확정
→ Part별 Implementation Spec 작성
→ sub agent 필수 검토
→ 검토 결과 반영
→ 사용자 최종 확인
→ doc-slice로 이동
```

사용자 확인 지점:

1. MVP 후보 확정
2. MVP별 Part 후보 확정
3. Implementation Spec 최종 확인

Implementation Spec 상세도:

- slice 직전 수준으로 작성한다.
- 구현 파일 후보, 구현 순서, 테스트 명령까지는 쓰지 않는다.
- 각 Spec에는 화면, 데이터, 상태, 권한, 예외 케이스, 완료 기준을 포함한다.

sub agent 필수 검토 규칙:

- Implementation Spec 초안 작성 직후 반드시 실행한다.
- 모델은 사용 가능한 최고 모델을 사용한다. Codex 환경에서는 `gpt-5.5`를 우선한다.
- reasoning/effort는 사용 가능한 최고 수준을 사용한다. Codex 환경에서는 `xhigh`를 우선한다.
- 검토 대상은 `WORK_BREAKDOWN.md`의 MVP, Part, Implementation Spec이다.
- 검토 목적은 MVP 범위, Part 크기, Spec 구체성, 누락된 화면/데이터/예외/권한/검증 기준, slice화 가능성을 확인하는 것이다.
- 정확한 모델/effort 지정이 불가능하면 사용 가능한 최상위 대안으로 실행하고, 완료 보고에 fallback을 명시한다.

sub agent 검토 결과 반영 규칙:

- 명백한 누락/모순은 문서에 반영한다.
- 사용자 의도 판단이 필요한 항목은 사용자에게 확인한다.
- 반영하지 않은 항목은 이유를 짧게 보고한다.

기존 문서 수정 규칙:

- 기존 `structure.md`, `frontend-components.md`, `WORK_BREAKDOWN.md`는 보존 기반으로 업데이트한다.
- 비어 있거나 오래된 부분만 업데이트한다.
- 새 기획과 기존 문서가 충돌하면 사용자에게 확인한다.
- 전체 재작성은 사용자가 명시적으로 요청한 경우에만 한다.

MVP 이름 규칙:

- 기본값은 `Alpha`, `Beta`, `Post-Beta`다.
- 프로젝트 성격에 따라 `MVP 1`, `Internal Alpha`, `Public Beta` 등으로 바꿀 수 있다.

하지 않을 것:

- 서비스 목표를 새로 바꾸지 않는다.
- 근거 없는 아키텍처 결정을 새로 하지 않는다.
- 프론트엔드 컴포넌트를 새로 발명하지 않는다.
- 부족한 기획을 스킬 안에서 길게 brainstorming하지 않는다.
- slice 파일을 만들지 않는다.
- build-loop용 가이드를 만들지 않는다.

완료 기준:

- 외부 기획 결과가 `structure.md`, `frontend-components.md`, `WORK_BREAKDOWN.md`에 정리되어 있다.
- MVP별로 큰 파트가 정리되어 있다.
- 각 파트 아래 구현 스펙이 정리되어 있다.
- sub agent 검토 결과가 반영되어 있다.
- 사용자가 최종 확인했다.
- 다음 단계에서 `doc-slice`가 읽고 slice로 나눌 수 있다.

### 3.2 `doc-slice`

최종 역할:

- `WORK_BREAKDOWN.md`의 확정된 Implementation Spec을 읽는다.
- 하나의 Implementation Spec을 하나 이상 구현 가능한 slice로 나눈다.
- slice 후보를 자동으로 만들고, 각 slice의 `plan.md`를 먼저 생성한다.
- 생성된 전체 slice `plan.md` 묶음을 sub agent에게 1회 리뷰 요청한다.
- finding이 실제 문제인지 확인한 뒤 필요한 내용만 `plan.md`에 반영한다.
- 그 다음 각 slice의 `guide.md`를 slice별로 별도 생성한다.
- `DOCS_MAP.md`와 `WORK_BREAKDOWN.md`에 slice 연결을 추가한다.
- `guide.md`에 build-loop-codex handoff 정보를 포함한다.

고정 workflow:

```txt
WORK_BREAKDOWN.md의 Implementation Spec 확인
→ slice별 plan.md 생성
→ 전체 plan.md 묶음 sub agent 리뷰
→ 실제 finding 반영
→ slice별 guide.md 생성
→ DOCS_MAP.md 연결
→ WORK_BREAKDOWN.md에 slice 링크 추가
→ build-loop-codex에 넘길 준비 완료
```

slice 크기 기준:

- build-loop-codex가 한 번에 구현하고 검증할 수 있는 업무 단위로 나눈다.
- 보통 화면 1개 또는 긴밀하게 묶인 기능 1개를 기준으로 한다.
- acceptance check가 명확해야 한다.
- 너무 크면 여러 slice로 분리한다.

주요 출력:

- `docs/agent/slices/<slice-name>/plan.md`
- `docs/agent/slices/<slice-name>/guide.md`
- `docs/agent/DOCS_MAP.md`
- `docs/agent/WORK_BREAKDOWN.md`의 slice 링크

`plan.md`와 `guide.md`의 차이:

| 파일 | 역할 | 핵심 질문 |
|---|---|---|
| `plan.md` | 이 slice가 무엇인지 설명하는 기획/범위 문서 | 무엇을, 왜, 어디까지 만들 것인가 |
| `guide.md` | 이 slice를 어떻게 구현할지 알려주는 실행 지시서 | 어떤 파일을 어떤 순서로 수정하고, 어떻게 검증할 것인가 |

`plan.md`에 들어갈 내용:

- slice 목적
- 연결된 MVP / Part / Implementation Spec
- 사용자 시나리오
- 포함 범위
- 제외 범위
- 필요한 화면, 데이터, 상태
- 성공 기준

`guide.md`에 들어갈 내용:

- 구현 순서
- 먼저 읽어야 할 문서
- 수정 가능한 파일
- 수정하면 안 되는 파일
- acceptance checks
- verification commands
- build-loop-codex handoff 블록

sub agent 리뷰 규칙:

- `plan.md`는 생성된 전체 slice 묶음을 대상으로 1회 리뷰한다.
- 리뷰 목적은 slice 간 중복, 누락, 순서 문제, 범위 과대/과소 여부 확인이다.
- `guide.md`는 기본적으로 별도 리뷰하지 않는다.
- 단, 권한/인증, 결제, 데이터 삭제, 개인정보/보안, 대량 데이터 변경, 외부 API 연동, 아키텍처 핵심 변경 slice는 `guide.md`도 sub agent 리뷰를 받는다.

verification commands 작성 규칙:

- `package.json`, `README.md`, `Makefile`, `pyproject.toml`, 기존 문서를 보고 테스트/빌드/린트 명령어를 추론한다.
- 명확하지 않으면 사용자에게 질문한다.
- 실제 프로젝트에 없는 일반 명령을 임의로 넣지 않는다.

하지 않을 것:

- 제품 목표를 새로 정하지 않는다.
- MVP/Part/Implementation Spec 구조를 임의로 바꾸지 않는다.
- 아키텍처 결정을 새로 하지 않는다.
- 코드를 구현하지 않는다.

완료 기준:

- 각 slice가 어느 MVP, Part, Implementation Spec에서 나온 것인지 추적 가능하다.
- 각 slice의 `plan.md`와 `guide.md`가 생성되어 있다.
- 생성된 `plan.md` 묶음에 대해 sub agent 리뷰가 실행되어 있고, 필요한 finding이 반영되어 있다.
- `DOCS_MAP.md`와 `WORK_BREAKDOWN.md`에 slice 링크가 반영되어 있다.
- `guide.md`에 허용 파일, 수정 금지 파일, acceptance checks, verification commands가 명시되어 있다.
- build-loop-codex에 넘길 수 있는 상태다.

---

## 4. 문서 소유권

동일 문서를 여러 스킬이 건드리므로, 주 소유권을 명확히 둔다.

| 문서 | 주 담당 스킬 | 보조 수정 |
|---|---|---|
| `structure.md` | `doc-breakdown` | 외부 기획 결과를 근거로만 업데이트 |
| `frontend-components.md` | `doc-breakdown` | 외부 기획/시각화 결과를 근거로만 업데이트 |
| `WORK_BREAKDOWN.md` | `doc-breakdown` | `doc-slice`는 slice 링크만 추가 |
| `DOCS_MAP.md` | `doc-slice` | 기존 `doc-init`은 초기 생성 |
| `slices/<slice>/plan.md` | `doc-slice` | 없음 |
| `slices/<slice>/guide.md` | `doc-slice` | 없음 |

---

## 5. 구현 시 반영할 변경 범위

플러그인 기능 구현 단계에서 반영할 항목:

1. `skills/doc-breakdown/SKILL.md` 추가
2. `doc-breakdown`에 외부 기획 준비도 점검, 사용자 확인 지점, sub agent 필수 검토 규칙 추가
3. `skills/doc-slice/SKILL.md` 확장
4. `doc-slice`에 plan-first 생성, 전체 plan.md 묶음 리뷰, guide.md 생성 순서 반영
5. `tests/run.sh`에 새 스킬 존재와 핵심 문구 검증 추가
6. `templates/WORK_BREAKDOWN.md`를 `doc-breakdown` 중심 구조에 맞게 보강
7. `templates/slice-plan.md`, `templates/slice-guide.md`를 `doc-slice` 확장 흐름에 맞게 보강
8. `doc-init`의 다음 추천 액션을 `/seasoned-architect:doc-breakdown`으로 변경

플러그인 기능에서 제외할 항목:

- 이 기획 문서 자체
- sub agent 리뷰 기록 전문
- 개발 중 의사결정 메모
- `doc-foundation` skill
- build-loop-codex skill 자체 수정

---

## 6. 구현 진행 순서

1. 관리문서를 최종 업데이트한다.
2. 스킬 구현 기획문서를 작성한다.
3. 기획문서 중간 커밋을 만든다.
4. 구현 sub agent에게 구현을 맡기고, 메인 agent는 지시와 관리를 담당한다.
5. 메인 agent가 로컬 검증을 실행한다.
6. 새로운 sub agent에게 전체 플러그인 리뷰를 요청한다.
7. 최종 커밋을 만든다.

---

## 7. 최종 확정 요약

최종적으로 Seasoned Architect의 기획 이후 구현 준비 흐름은 두 스킬로 정의한다.

| 스킬 | 최종 책임 | 다음 단계 |
|---|---|---|
| `/seasoned-architect:doc-breakdown` | 외부 기획 결과를 Seasoned Architect 문서 구조로 정리하고, MVP → Part → Implementation Spec까지 확정한다. Spec 초안 작성 직후 sub agent 검토를 반드시 실행한다. | `/seasoned-architect:doc-slice` |
| `/seasoned-architect:doc-slice` | 확정된 Implementation Spec을 구현 가능한 slice로 자동 분할하고, slice별 `plan.md`를 먼저 만든 뒤 sub agent 리뷰를 반영하고, slice별 `guide.md`를 생성한다. | `build-loop-codex` |

역할 경계:

- `doc-breakdown`은 무엇을 구현할지 정리한다.
- `doc-slice`는 어떤 단위와 순서로 구현할지 자른다.
- `build-loop-codex`는 실제 구현을 실행한다.

최종 흐름:

```txt
brainstorming / grill-me / 시각화 도구
→ /seasoned-architect:doc-breakdown
→ sub agent 필수 검토
→ /seasoned-architect:doc-slice
→ sub agent plan 리뷰
→ build-loop-codex
```
