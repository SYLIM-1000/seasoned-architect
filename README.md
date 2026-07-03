# Seasoned Architect

Seasoned Architect는 긴 AI 보조 개발 작업에서 기획 문서, MVP 분해, 구현 slice, sub agent 전달 문서, 커밋 기반 작업 기록을 한 흐름으로 관리하기 위한 Codex / Claude Code 겸용 플러그인입니다.

버전은 `.claude-plugin/plugin.json`에서 관리됩니다.

## 핵심 목적

이 플러그인은 아이디어를 대신 내는 도구가 아니라, 이미 정리된 기획과 아키텍처를 구현 가능한 문서 구조로 정리하고 유지하는 도구입니다.

권장 흐름은 다음과 같습니다.

1. `brainstorming`, `grill-me` 같은 별도 스킬로 서비스 기획을 충분히 구체화합니다.
2. `/seasoned-architect:doc-init`으로 프로젝트 문서 구조를 만듭니다.
3. `/seasoned-architect:doc-breakdown`으로 확정된 기획을 MVP, Part, Implementation Spec으로 정리합니다.
4. `/seasoned-architect:doc-slice`로 구현 가능한 slice별 `plan.md`와 `guide.md`를 만듭니다.
5. `build-loop` 같은 구현 루프 스킬로 slice를 구현합니다.
6. 커밋 후 `/seasoned-architect:doc-sync`로 작업 기록을 journal 문서에 반영합니다.

## 지원 환경

- Codex plugin
- Claude Code plugin

두 환경에서 같은 스킬 이름을 사용합니다.

```txt
/seasoned-architect:doc-init
/seasoned-architect:doc-breakdown
/seasoned-architect:doc-slice
/seasoned-architect:doc-sync
```

## 설치

### 1. 저장소 clone

```bash
git clone https://github.com/SYLIM-1000/seasoned-architect.git
cd seasoned-architect
```

### 2. Codex에 설치

```bash
codex plugin marketplace add "/path/to/seasoned-architect"
codex plugin add seasoned-architect@seasoned-architect
codex plugin list
```

설치 후 새 Codex thread/session을 열어야 스킬 목록에 반영됩니다.

### 3. Claude Code에 설치

```bash
claude plugin marketplace add "/path/to/seasoned-architect" --scope user
claude plugin install seasoned-architect@seasoned-architect --scope user
claude plugin list
```

설치 후 새 Claude Code session을 열어야 스킬과 lifecycle hook이 반영됩니다.

## 스킬 설명

### `/seasoned-architect:doc-init`

현재 Git 프로젝트에 Seasoned Architect 문서 구조를 초기화합니다.

생성 또는 갱신 대상:

```txt
docs/agent/DOCS_MAP.md
docs/agent/WORK_BREAKDOWN.md
docs/agent/structure.md
docs/agent/frontend-components.md
docs/agent/journal/.gitkeep
```

역할:

- 현재 프로젝트가 Git 저장소인지 확인합니다.
- `docs/agent` 문서 구조를 생성합니다.
- 기존 문서가 있으면 덮어쓰기 전에 확인합니다.
- 사용자 승인 후 Git `post-commit` hook을 설치합니다.
- 사용자 승인 후 `AGENTS.md`에 Seasoned Architect 섹션을 추가합니다. Codex에는 플러그인 lifecycle hook이 없으므로 이 섹션이 세션 시작 컨텍스트를 대신합니다.

주의:

- Git hook은 플러그인 설치만으로 프로젝트에 자동 설치되지 않습니다.
- 각 프로젝트에서 `/seasoned-architect:doc-init`을 실행하고 hook 설치를 승인해야 합니다.
- 기존 `post-commit` hook이 심링크이거나 git이 추적하는 파일(husky 등 공유 hook 매니저)이면 자동 설치를 거부하고 수동 추가 방법을 안내합니다.

### `/seasoned-architect:doc-breakdown`

외부에서 정리된 기획, 화면 기획, 아키텍처 메모를 Seasoned Architect 문서 구조로 정리합니다.

업데이트 대상:

```txt
docs/agent/structure.md
docs/agent/frontend-components.md
docs/agent/WORK_BREAKDOWN.md
```

역할:

- 확정된 기획을 프로젝트 구조 문서로 정리합니다.
- MVP 후보를 제안하고 사용자와 확정합니다.
- MVP별 Part를 나눕니다.
- Part별 Implementation Spec을 작성합니다.
- 작성한 Implementation Spec을 sub agent에게 리뷰 요청합니다.
- 리뷰 결과 중 명확한 누락, 모순은 반영하고, 제품 의도가 바뀌는 내용은 사용자에게 확인합니다.

이 스킬은 브레인스토밍용이 아닙니다. 화면, 주요 컴포넌트, 데이터 구조, 권한, 예외 상황, 아키텍처 방향이 부족하면 먼저 `brainstorming` 또는 `grill-me`를 사용하는 것이 좋습니다.

### `/seasoned-architect:doc-slice`

확정된 Implementation Spec을 구현 가능한 slice로 나눕니다.

생성 대상:

```txt
docs/agent/slices/<slice-name>/plan.md
docs/agent/slices/<slice-name>/guide.md
```

역할:

- `WORK_BREAKDOWN.md`에서 `Spec review status: reviewed` 상태인 스펙만 slice화합니다.
- 먼저 slice별 `plan.md`를 만듭니다.
- 모든 `plan.md`를 sub agent에게 함께 리뷰 요청합니다.
- 리뷰 결과를 반영한 뒤 slice별 `guide.md`를 만듭니다.
- `DOCS_MAP.md`와 `WORK_BREAKDOWN.md`에 slice 링크를 갱신합니다.

`plan.md`와 `guide.md`의 차이:

- `plan.md`: 이 slice가 무엇을 구현할지 정리한 계획 문서입니다.
- `guide.md`: sub agent나 구현 루프가 실제 구현할 때 읽는 작업 지시서입니다.

고위험 slice는 `guide.md`도 sub agent 리뷰를 요청합니다.

고위험 기준:

- 인증 / 권한
- 결제
- 데이터 삭제
- 개인정보 / 보안
- 대량 데이터 변경
- 외부 API 연동
- 핵심 아키텍처 변경

### `/seasoned-architect:doc-sync`

Git hook이 수집한 커밋 raw log를 사람이 읽을 수 있는 journal 문서로 변환합니다.

입력:

```txt
<git-common-dir>/seasoned-architect/raw-log.jsonl
```

출력:

```txt
docs/agent/journal/YYYY-MM.md
```

역할:

- 아직 journal에 반영되지 않은 커밋을 찾습니다. 동기화 판정은 해시 앞 7자 이상 일치 기준이며, journal 항목에는 40자 전체 해시를 기록합니다.
- 커밋 메시지, 변경 파일, slice 문서, diff를 근거로 작업 기록을 작성합니다.
- 근거가 부족한 의도는 추측하지 않고 `확인 필요`로 남깁니다.
- amend/rebase로 브랜치에서 도달할 수 없게 된 커밋은 journal 항목 대신 `Superseded commits` 목록에 기록합니다.
- raw log에 없는 커밋(merge 커밋, rebase된 커밋, hook 없이 만든 커밋)은 `git log` 대조로 찾아 `Source: git-log`로 기록합니다.

## 생성되는 문서 구조

Seasoned Architect를 적용한 프로젝트에는 보통 다음 구조가 생깁니다.

```txt
docs/
  agent/
    DOCS_MAP.md
    WORK_BREAKDOWN.md
    structure.md
    frontend-components.md
    journal/
      YYYY-MM.md
    slices/
      <slice-name>/
        plan.md
        guide.md
```

각 문서의 역할:

- `DOCS_MAP.md`: agent가 어떤 상황에서 어떤 문서를 먼저 읽어야 하는지 알려주는 지도입니다.
- `WORK_BREAKDOWN.md`: MVP, Part, Implementation Spec, slice 링크를 관리합니다.
- `structure.md`: 프로젝트 구조, 아키텍처, 주요 도메인 흐름을 정리합니다.
- `frontend-components.md`: 페이지, 화면, 컴포넌트, 상태, UX 조건을 정리합니다.
- `journal/YYYY-MM.md`: 커밋 기반 작업 기록입니다.
- `slices/<slice-name>/plan.md`: slice의 범위와 수용 기준입니다.
- `slices/<slice-name>/guide.md`: 구현 agent에게 전달할 상세 작업 가이드입니다.

## Hook 동작

Seasoned Architect에는 두 종류의 hook이 있습니다.

### Lifecycle hook (Claude Code 전용)

Claude Code session 시작 또는 sub agent 시작 시 프로젝트 문맥을 가볍게 안내하고, 미반영 커밋이 있으면 `/seasoned-architect:doc-sync` 실행을 권장합니다.

Codex는 플러그인 manifest의 `hooks` 필드를 검증 단계에서 거부하며 플러그인 lifecycle hook을 지원하지 않습니다. Codex에서는 `/seasoned-architect:doc-init`이 추가하는 `AGENTS.md` 섹션이 세션 시작 컨텍스트를 대신하고, `doc-sync`는 커밋 후 수동으로 실행합니다.

### Git `post-commit` hook

프로젝트에서 커밋이 생성될 때 raw log를 기록합니다.

기록 위치:

```txt
.git/seasoned-architect/raw-log.jsonl
```

이 hook은 플러그인 설치만으로 자동 설치되지 않습니다. 각 프로젝트에서 `/seasoned-architect:doc-init`을 실행한 뒤 hook 설치를 승인해야 합니다.

한계:

- `post-commit`은 `git commit`에서만 실행됩니다. merge 커밋, rebase/cherry-pick으로 만들어진 커밋, hook이 없는 다른 기기의 커밋은 raw log에 남지 않으며, `doc-sync`의 `git log` 대조 단계가 이를 보완합니다.
- 플러그인 업데이트 후에는 각 프로젝트에서 `/seasoned-architect:doc-init`을 다시 실행해야 복사된 capture script가 갱신됩니다.

## 플러그인 내부 구조

```txt
.codex-plugin/
  plugin.json
.claude-plugin/
  plugin.json
  marketplace.json
.agents/
  plugins/
    marketplace.json
hooks/
  hooks.json
planning/
docs/
  superpowers/
scripts/
  install-git-hook.sh
  post-commit-capture.sh
  seasoned-architect-context.sh
skills/
  doc-init/
    SKILL.md
  doc-breakdown/
    SKILL.md
  doc-slice/
    SKILL.md
  doc-sync/
    SKILL.md
  journaling/
    SKILL.md
templates/
  DOCS_MAP.md
  WORK_BREAKDOWN.md
  structure.md
  frontend-components.md
  slice-plan.md
  slice-guide.md
  journal-entry.md
tests/
  run.sh
```

## 개발 / 검증

기본 테스트:

```bash
bash tests/run.sh
```

Codex plugin 검증:

```bash
python3 "$HOME/.codex/skills/.system/plugin-creator/scripts/validate_plugin.py" .
```

Claude Code plugin 검증:

```bash
claude plugin validate .claude-plugin/plugin.json
claude plugin validate .claude-plugin/marketplace.json
```

## 현재 설계 원칙

- 기획 자체는 `brainstorming`, `grill-me` 같은 별도 도구에서 충분히 진행합니다.
- Seasoned Architect는 확정된 기획을 구현 가능한 문서 구조로 정리합니다.
- 큰 계획을 바로 구현하지 않고 MVP, Part, Implementation Spec, Slice 순서로 낮춥니다.
- 중요한 문서는 sub agent 리뷰를 거쳐 누락과 모순을 줄입니다.
- 구현 agent에게는 slice별 `guide.md`를 전달합니다.
- 커밋 후 journal을 갱신해 장기 작업의 맥락 손실을 줄입니다.
