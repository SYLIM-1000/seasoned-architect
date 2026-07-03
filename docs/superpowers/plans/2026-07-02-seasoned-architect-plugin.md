# Seasoned Architect Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build v0.1 of the `seasoned-architect` Claude Code plugin from `<project-root>/planning/seasoned-architect-plugin-plan-v5.md`.

**Architecture:** The plugin is a self-contained Claude Code plugin under `seasoned-architect/`. It ships manual skills, lightweight hooks, markdown templates, and deterministic shell scripts. Git commit facts are captured by a repository-installed `post-commit` hook into Git common-dir raw logs; AI-written markdown journals are produced only by `/seasoned-architect:doc-sync`.

**Tech Stack:** Claude Code plugin structure, Markdown skills/templates, Bash, Python 3 for JSON escaping/parsing inside scripts, Git hooks, shell-based integration tests.

---

## Source References

- Spec: `<project-root>/planning/seasoned-architect-plugin-plan-v5.md`
- Claude Code plugin docs: https://code.claude.com/docs/en/plugins
- Claude Code hooks docs: https://code.claude.com/docs/en/hooks
- Claude Code skills docs: https://code.claude.com/docs/en/skills

## Scope

Implement v0.1 only.

Included:
- Plugin skeleton
- `plugin.json`
- 4 skills: `doc-init`, `doc-slice`, `doc-sync`, `journaling`
- `hooks/hooks.json`
- `install-git-hook.sh`
- `post-commit-capture.sh`
- `seasoned-architect-context.sh`
- 7 templates
- Shell integration tests

Excluded:
- PostToolUse immediate sync nudge
- automatic `doc-sync`
- `doc-status`
- `WIP.md`
- slice journal index
- remote sync
- team/multi-user conflict handling
- build-loop implementation changes

---

## File Structure

Create this structure under `<project-root>/seasoned-architect/`:

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
├── scripts/
│   ├── install-git-hook.sh
│   ├── post-commit-capture.sh
│   └── seasoned-architect-context.sh
└── tests/
    └── run.sh
```

Responsibilities:

- `.claude-plugin/plugin.json`: plugin identity only. Do not declare `skills` or `hooks` paths.
- `hooks/hooks.json`: SessionStart/SubagentStart lightweight context hooks only.
- `skills/doc-init/SKILL.md`: manual initialization workflow.
- `skills/doc-slice/SKILL.md`: manual slice scaffold workflow, including required `DOCS_MAP.md` and `WORK_BREAKDOWN.md` updates.
- `skills/doc-sync/SKILL.md`: manual raw-log-to-journal sync workflow.
- `skills/journaling/SKILL.md`: internal writing rules for evidence-based journal entries.
- `templates/*`: markdown source templates copied/adapted by skills.
- `scripts/install-git-hook.sh`: installs stable repo-local post-commit capture hook.
- `scripts/post-commit-capture.sh`: deterministic raw commit capture only.
- `scripts/seasoned-architect-context.sh`: hook context generator and unsynced commit nudge.
- `tests/run.sh`: dependency-light shell tests for structure, scripts, hooks, templates, and skills.

---

## Task 1: Scaffold plugin skeleton and structural test

**Files:**
- Create: `<project-root>/seasoned-architect/tests/run.sh`
- Create: `<project-root>/seasoned-architect/.claude-plugin/plugin.json`
- Create directories under `<project-root>/seasoned-architect/`

- [ ] **Step 1: Write failing structure test**

Create `<project-root>/seasoned-architect/tests/run.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

assert_file() {
  local path="$1"
  [[ -f "$ROOT/$path" ]] || fail "missing file: $path"
}

assert_executable() {
  local path="$1"
  [[ -x "$ROOT/$path" ]] || fail "not executable: $path"
}

assert_contains() {
  local path="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$ROOT/$path" || fail "$path does not contain: $expected"
}

assert_json_valid() {
  local path="$1"
  python3 -m json.tool "$ROOT/$path" >/dev/null || fail "invalid json: $path"
}

test_plugin_structure() {
  assert_file ".claude-plugin/plugin.json"
  assert_file "hooks/hooks.json"
  assert_file "skills/doc-init/SKILL.md"
  assert_file "skills/doc-slice/SKILL.md"
  assert_file "skills/doc-sync/SKILL.md"
  assert_file "skills/journaling/SKILL.md"
  assert_file "templates/DOCS_MAP.md"
  assert_file "templates/WORK_BREAKDOWN.md"
  assert_file "templates/structure.md"
  assert_file "templates/frontend-components.md"
  assert_file "templates/slice-plan.md"
  assert_file "templates/slice-guide.md"
  assert_file "templates/journal-entry.md"
  assert_file "scripts/install-git-hook.sh"
  assert_file "scripts/post-commit-capture.sh"
  assert_file "scripts/seasoned-architect-context.sh"
  assert_executable "scripts/install-git-hook.sh"
  assert_executable "scripts/post-commit-capture.sh"
  assert_executable "scripts/seasoned-architect-context.sh"
  assert_json_valid ".claude-plugin/plugin.json"
  pass "plugin structure"
}

main() {
  test_plugin_structure
}

main "$@"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: FAIL with `missing file: .claude-plugin/plugin.json`.

- [ ] **Step 3: Create plugin directories and manifest**

Run:

```bash
cd '<project-root>'
mkdir -p seasoned-architect/.claude-plugin seasoned-architect/hooks seasoned-architect/skills/doc-init seasoned-architect/skills/doc-slice seasoned-architect/skills/doc-sync seasoned-architect/skills/journaling seasoned-architect/templates seasoned-architect/scripts
cat > seasoned-architect/.claude-plugin/plugin.json <<'JSON'
{
  "name": "seasoned-architect",
  "description": "Keeps AI agents oriented in long-running product development through planning docs, slice handoffs, commit logs, and lazy context loading.",
  "author": {
    "name": "임승용"
  }
}
JSON
```

- [ ] **Step 4: Add temporary empty component files to move the failing test to script executability**

Run:

```bash
cd '<project-root>/seasoned-architect'
touch hooks/hooks.json skills/doc-init/SKILL.md skills/doc-slice/SKILL.md skills/doc-sync/SKILL.md skills/journaling/SKILL.md
touch templates/DOCS_MAP.md templates/WORK_BREAKDOWN.md templates/structure.md templates/frontend-components.md templates/slice-plan.md templates/slice-guide.md templates/journal-entry.md
touch scripts/install-git-hook.sh scripts/post-commit-capture.sh scripts/seasoned-architect-context.sh
chmod +x scripts/install-git-hook.sh scripts/post-commit-capture.sh scripts/seasoned-architect-context.sh
```

- [ ] **Step 5: Run test to verify current skeleton passes structure only**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: PASS `plugin structure`.

- [ ] **Step 6: Commit skeleton**

```bash
cd '<project-root>'
git add seasoned-architect
git commit -m "feat: scaffold seasoned-architect plugin"
```

---

## Task 2: Implement templates and template tests

**Files:**
- Modify: `<project-root>/seasoned-architect/tests/run.sh`
- Modify: all files under `<project-root>/seasoned-architect/templates/`

- [ ] **Step 1: Append failing template tests**

Add this function before `main()` in `seasoned-architect/tests/run.sh`:

```bash
test_templates() {
  assert_contains "templates/DOCS_MAP.md" "# Seasoned Architect Map"
  assert_contains "templates/DOCS_MAP.md" "## 읽기 우선순위"
  assert_contains "templates/DOCS_MAP.md" "전체 문서를 무작정 다 읽지 않는다"
  assert_contains "templates/WORK_BREAKDOWN.md" "# Work Breakdown"
  assert_contains "templates/WORK_BREAKDOWN.md" "Build-loop ready"
  assert_contains "templates/structure.md" "# Project Structure"
  assert_contains "templates/frontend-components.md" "# Frontend Components"
  assert_contains "templates/slice-plan.md" "mvp:"
  assert_contains "templates/slice-guide.md" "## Build-loop handoff"
  assert_contains "templates/slice-guide.md" "Read only if needed"
  assert_contains "templates/journal-entry.md" "**Verification**"
  assert_contains "templates/journal-entry.md" "**Evidence source**"
  pass "templates"
}
```

Update `main()` to:

```bash
main() {
  test_plugin_structure
  test_templates
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: FAIL on `templates/DOCS_MAP.md does not contain: # Seasoned Architect Map`.

- [ ] **Step 3: Write `DOCS_MAP.md` template**

Replace `seasoned-architect/templates/DOCS_MAP.md` with:

```markdown
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

## Slice Map

| 작업 영역 | Slice | 문서 | 코드 경로 |
|---|---|---|---|
| {{AREA_NAME}} | {{SLICE_NAME}} | `docs/agent/slices/{{SLICE_NAME}}/` | `{{CODE_PATH}}` |

## 규칙

- 맥락이 중요한 작업에서는 이 파일을 먼저 읽는다.
- 전체 문서를 무작정 다 읽지 않는다.
- 같은 세션에서 이미 읽은 문서는 파일 변경이나 refresh 요청이 없으면 다시 읽지 않는다.
- 매핑 없는 코드 영역을 반복 수정하면 이 파일 갱신을 제안한다.
```

- [ ] **Step 4: Write `WORK_BREAKDOWN.md` template**

Replace `seasoned-architect/templates/WORK_BREAKDOWN.md` with:

```markdown
# Work Breakdown

## Product Goal

- {{PRODUCT_GOAL}}

## MVPs

### MVP Alpha

#### Part: {{PART_NAME}}

##### Implementation Spec: {{SPEC_NAME}}

- Slice: {{SLICE_NAME}}
- 관련 문서: `docs/agent/slices/{{SLICE_NAME}}/`
- 관련 frontend component: {{FRONTEND_COMPONENTS}}
- 관련 architecture decision: {{ARCHITECTURE_DECISION}}
- Dependencies: {{DEPENDENCIES}}
- Build-loop ready: no

## 규칙

- 이 문서는 제품 목표에서 slice까지의 추적 문서다.
- slice가 생성되면 관련 MVP, part, spec 아래에 반드시 연결한다.
- build-loop로 구현 가능한 상태가 되면 `Build-loop ready: yes`로 바꾼다.
```

- [ ] **Step 5: Write `structure.md` template**

Replace `seasoned-architect/templates/structure.md` with:

```markdown
# Project Structure

## Project Purpose

{{PROJECT_PURPOSE}}

## Core Domain Concepts

| 개념 | 의미 | 관련 코드/문서 |
|---|---|---|
| {{DOMAIN_TERM}} | {{DOMAIN_MEANING}} | {{REFERENCE}} |

## Architecture

- Application style: {{APPLICATION_STYLE}}
- Frontend: {{FRONTEND_STACK}}
- Backend: {{BACKEND_STACK}}
- Data store: {{DATA_STORE}}
- Integration points: {{INTEGRATION_POINTS}}

## Important Decisions

| 결정 | 이유 | 날짜 |
|---|---|---|
| {{DECISION}} | {{REASON}} | {{DATE}} |

## Risky Areas

- {{RISKY_AREA}} — {{WHY_RISKY}}

## 읽기 정책

- 세션 시작 시 자동으로 읽지 않는다.
- 아키텍처, 도메인, 큰 구조 판단이 필요한 경우에만 읽는다.
```

- [ ] **Step 6: Write `frontend-components.md` template**

Replace `seasoned-architect/templates/frontend-components.md` with:

```markdown
# Frontend Components

## Pages

### {{PAGE_NAME}}

- 목적: {{PAGE_PURPOSE}}
- 주요 상태: {{PAGE_STATES}}
- 포함 컴포넌트: {{PAGE_COMPONENTS}}

## Components

### {{COMPONENT_NAME}}

- 용도: {{COMPONENT_PURPOSE}}
- variants: {{COMPONENT_VARIANTS}}
- states: {{COMPONENT_STATES}}
- 사용 금지: {{COMPONENT_NON_GOALS}}

## 읽기 정책

- UI/프론트엔드/컴포넌트 작업일 때만 읽는다.
- 백엔드/인프라/문서 작업에서는 읽지 않는다.
```

- [ ] **Step 7: Write `slice-plan.md` template**

Replace `seasoned-architect/templates/slice-plan.md` with:

```markdown
---
slice: {{SLICE_NAME}}
status: planned
mvp: {{MVP_NAME}}
part: {{PART_NAME}}
spec: {{SPEC_NAME}}
code_paths:
  - {{CODE_PATH}}
frontend_components:
  - {{FRONTEND_COMPONENT}}
architecture_decisions:
  - {{ARCHITECTURE_DECISION}}
---

# Slice Plan: {{SLICE_NAME}}

## Why

{{WHY}}

## What

{{WHAT}}

## Scope

- {{SCOPE_ITEM}}

## Non-goals

- {{NON_GOAL}}

## Success Criteria

- {{SUCCESS_CRITERION}}

## Dependencies

- {{DEPENDENCY}}
```

- [ ] **Step 8: Write `slice-guide.md` template**

Replace `seasoned-architect/templates/slice-guide.md` with:

```markdown
---
slice: {{SLICE_NAME}}
status: draft
---

# Slice Guide: {{SLICE_NAME}}

## Implementation Order

1. {{STEP_ONE}}
2. {{STEP_TWO}}
3. {{STEP_THREE}}

## Files

### Allowed files

- {{ALLOWED_FILE}}

### Do not modify

- {{FORBIDDEN_FILE}}

## Acceptance Checks

- {{ACCEPTANCE_CHECK}}

## Verification Commands

```bash
{{VERIFICATION_COMMAND}}
```

## Build-loop handoff

Seasoned Architect slice: {{SLICE_NAME}}

Read first:
- docs/agent/DOCS_MAP.md
- docs/agent/slices/{{SLICE_NAME}}/plan.md
- docs/agent/slices/{{SLICE_NAME}}/guide.md

Read only if needed:
- docs/agent/WORK_BREAKDOWN.md — MVP/part/spec 맥락이 필요할 때
- docs/agent/frontend-components.md — UI 컴포넌트 구현 판단이 필요할 때

Source of truth:
- 이 guide.md의 Scope, Non-goals, Acceptance checks를 우선한다.

Scope:
- {{SCOPE_ITEM}}

Non-goals:
- {{NON_GOAL}}

Allowed files:
- {{ALLOWED_FILE}}

Do not modify:
- {{FORBIDDEN_FILE}}

Acceptance checks:
- {{ACCEPTANCE_CHECK}}

Verification:
- {{VERIFICATION_COMMAND}}
```

- [ ] **Step 9: Write `journal-entry.md` template**

Replace `seasoned-architect/templates/journal-entry.md` with:

```markdown
## {{TIMESTAMP}} · [slice: {{SLICE_NAME}}] · commit {{COMMIT_HASH}}

- **무엇(What)**: {{WHAT}}
- **왜(Why)**: {{WHY}}
- **결과(Result)**: {{RESULT}}
- **다음(Next/Open)**: {{NEXT_OPEN}}
- **변경 파일**: {{CHANGED_FILES}}
- **Verification**:
  - `{{COMMAND}}` → {{RESULT_STATUS}}
- **Source**: `git-hook` → `ai-enriched`
- **Confidence**: {{CONFIDENCE}}
- **Evidence source**: {{EVIDENCE_SOURCE}}
```

- [ ] **Step 10: Run template tests**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: PASS `plugin structure`, PASS `templates`.

- [ ] **Step 11: Commit templates**

```bash
cd '<project-root>'
git add seasoned-architect/templates seasoned-architect/tests/run.sh
git commit -m "feat: add seasoned-architect templates"
```

---

## Task 3: Implement git hook installer and raw commit capture

**Files:**
- Modify: `<project-root>/seasoned-architect/tests/run.sh`
- Modify: `<project-root>/seasoned-architect/scripts/install-git-hook.sh`
- Modify: `<project-root>/seasoned-architect/scripts/post-commit-capture.sh`

- [ ] **Step 1: Append failing git hook tests**

Append these helper functions and tests before `main()` in `seasoned-architect/tests/run.sh`:

```bash
make_git_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.name "Seasoned Architect Test"
  git -C "$repo" config user.email "seasoned-architect@example.com"
}

common_dir_abs() {
  local repo="$1"
  local common
  common="$(git -C "$repo" rev-parse --git-common-dir)"
  case "$common" in
    /*) printf '%s\n' "$common" ;;
    *) printf '%s\n' "$repo/$common" ;;
  esac
}

test_git_hook_capture() {
  local tmp repo raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "alpha" > "$repo/a.txt"
  git -C "$repo" add a.txt
  git -C "$repo" commit -q -m "add alpha"

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
  [[ -f "$raw_log" ]] || fail "raw log was not created at common dir"
  grep -Fq '"message":"add alpha"' "$raw_log" || fail "raw log missing commit message"
  grep -Fq '"changed_files":["a.txt"]' "$raw_log" || fail "raw log missing changed file"
  [[ ! -f "$repo/docs/agent/journal/$(date +%Y-%m).md" ]] || fail "post-commit hook must not write markdown journal"

  rm -rf "$tmp"
  pass "git hook capture"
}

test_git_hook_install_idempotent() {
  local tmp repo hook_path block_count
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks"
  cat > "$repo/.git/hooks/post-commit" <<'HOOK'
#!/usr/bin/env bash
echo existing-hook >/dev/null
HOOK
  chmod +x "$repo/.git/hooks/post-commit"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")

  hook_path="$(git -C "$repo" rev-parse --git-path hooks/post-commit)"
  case "$hook_path" in
    /*) ;;
    *) hook_path="$repo/$hook_path" ;;
  esac
  block_count="$(grep -c '# seasoned-architect: begin' "$hook_path")"
  [[ "$block_count" = "1" ]] || fail "seasoned-architect hook block duplicated"
  ls "$hook_path".bak.* >/dev/null 2>&1 || fail "existing hook backup was not created"

  rm -rf "$tmp"
  pass "git hook install idempotent"
}

test_git_hook_worktree_common_log() {
  local tmp repo wt raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  wt="$tmp/wt"
  make_git_repo "$repo"

  echo "base" > "$repo/base.txt"
  git -C "$repo" add base.txt
  git -C "$repo" commit -q -m "base commit"
  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  git -C "$repo" worktree add -q -b wt-branch "$wt"
  git -C "$wt" config user.name "Seasoned Architect Test"
  git -C "$wt" config user.email "seasoned-architect@example.com"

  echo "worktree" > "$wt/wt.txt"
  git -C "$wt" add wt.txt
  git -C "$wt" commit -q -m "worktree commit"

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
  [[ -f "$raw_log" ]] || fail "worktree raw log missing from common dir"
  grep -Fq '"message":"worktree commit"' "$raw_log" || fail "worktree commit not captured in common raw log"

  git -C "$repo" worktree remove -f "$wt"
  rm -rf "$tmp"
  pass "git hook worktree common log"
}
```

Update `main()` to include:

```bash
main() {
  test_plugin_structure
  test_templates
  test_git_hook_capture
  test_git_hook_install_idempotent
  test_git_hook_worktree_common_log
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: FAIL in `test_git_hook_capture` because scripts are empty.

- [ ] **Step 3: Implement `post-commit-capture.sh`**

Replace `seasoned-architect/scripts/post-commit-capture.sh` with:

```bash
#!/usr/bin/env bash
set -u

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
common_dir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null)" || exit 0
case "$common_dir" in
  /*) common_dir_abs="$common_dir" ;;
  *) common_dir_abs="$repo_root/$common_dir" ;;
esac

agent_dir="$common_dir_abs/seasoned-architect"
raw_log="$agent_dir/raw-log.jsonl"
mkdir -p "$agent_dir" 2>/dev/null || exit 0

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

python3 - "$raw_log" <<'PY' || true
import json
import os
import subprocess
import sys

raw_log = sys.argv[1]

def git(*args):
    return subprocess.check_output(["git", *args], text=True, stderr=subprocess.DEVNULL).strip()

try:
    commit = git("rev-parse", "HEAD")
    timestamp = git("show", "-s", "--format=%cI", "HEAD")
    author = git("show", "-s", "--format=%an", "HEAD")
    message = git("show", "-s", "--format=%s", "HEAD")
    changed = subprocess.check_output(
        ["git", "diff-tree", "--no-commit-id", "--name-only", "-r", commit],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    changed_files = [line for line in changed.splitlines() if line]
    entry = {
        "commit": commit,
        "timestamp": timestamp,
        "author": author,
        "message": message,
        "changed_files": changed_files,
        "source": "git-hook",
    }
    os.makedirs(os.path.dirname(raw_log), exist_ok=True)
    with open(raw_log, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n")
except Exception:
    pass
PY

exit 0
```

- [ ] **Step 4: Implement `install-git-hook.sh`**

Replace `seasoned-architect/scripts/install-git-hook.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "seasoned-architect: not inside a git repository" >&2
  exit 1
}

common_dir="$(git -C "$repo_root" rev-parse --git-common-dir)"
case "$common_dir" in
  /*) common_dir_abs="$common_dir" ;;
  *) common_dir_abs="$repo_root/$common_dir" ;;
esac

agent_bin="$common_dir_abs/seasoned-architect/bin"
mkdir -p "$agent_bin"
cp "$script_dir/post-commit-capture.sh" "$agent_bin/post-commit-capture.sh"
chmod +x "$agent_bin/post-commit-capture.sh"

hooks_path="$(git -C "$repo_root" config --get core.hooksPath || true)"
if [[ -n "$hooks_path" ]]; then
  case "$hooks_path" in
    /*) hooks_dir="$hooks_path" ;;
    *) hooks_dir="$repo_root/$hooks_path" ;;
  esac
  mkdir -p "$hooks_dir"
  hook_path="$hooks_dir/post-commit"
else
  hook_path="$(git -C "$repo_root" rev-parse --git-path hooks/post-commit)"
  case "$hook_path" in
    /*) ;;
    *) hook_path="$repo_root/$hook_path" ;;
  esac
  mkdir -p "$(dirname "$hook_path")"
fi

capture_path="$agent_bin/post-commit-capture.sh"
block=$(cat <<BLOCK
# seasoned-architect: begin
"$capture_path" || true
# seasoned-architect: end
BLOCK
)

if [[ -f "$hook_path" ]]; then
  if grep -Fq "# seasoned-architect: begin" "$hook_path"; then
    chmod +x "$hook_path"
    echo "seasoned-architect: post-commit hook already installed at $hook_path"
    exit 0
  fi
  backup="$hook_path.bak.$(date +%Y%m%d%H%M%S)"
  cp "$hook_path" "$backup"
  {
    printf '\n%s\n' "$block"
    printf 'exit 0\n'
  } >> "$hook_path"
else
  cat > "$hook_path" <<HOOK
#!/usr/bin/env bash
$block
exit 0
HOOK
fi

chmod +x "$hook_path"
echo "seasoned-architect: installed post-commit hook at $hook_path"
```

- [ ] **Step 5: Run git hook tests**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: PASS for structure, templates, git hook capture, idempotent install, and worktree common log.

- [ ] **Step 6: Commit git hook scripts**

```bash
cd '<project-root>'
git add seasoned-architect/scripts seasoned-architect/tests/run.sh
git commit -m "feat: capture commits for agent docs"
```

---

## Task 4: Implement context hook script and hooks configuration

**Files:**
- Modify: `<project-root>/seasoned-architect/tests/run.sh`
- Modify: `<project-root>/seasoned-architect/scripts/seasoned-architect-context.sh`
- Modify: `<project-root>/seasoned-architect/hooks/hooks.json`

- [ ] **Step 1: Append failing context hook tests**

Append these tests before `main()` in `seasoned-architect/tests/run.sh`:

```bash
test_context_script_session_and_subagent() {
  local tmp repo output raw_log journal_dir
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"

  (cd "$repo" && "$ROOT/scripts/seasoned-architect-context.sh" session > "$tmp/no-docs.out")
  [[ ! -s "$tmp/no-docs.out" ]] || fail "context script should be silent before docs/agent exists"

  mkdir -p "$repo/docs/agent/journal"
  cp "$ROOT/templates/DOCS_MAP.md" "$repo/docs/agent/DOCS_MAP.md"
  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
  mkdir -p "$(dirname "$raw_log")"
  printf '%s\n' '{"commit":"abc123","timestamp":"2026-07-02T10:00:00+09:00","author":"Agent","message":"test commit","changed_files":["a.txt"],"source":"git-hook"}' > "$raw_log"

  (cd "$repo" && "$ROOT/scripts/seasoned-architect-context.sh" session > "$tmp/session.out")
  grep -Fq '"hookEventName":"SessionStart"' "$tmp/session.out" || fail "session output missing hook event"
  grep -Fq '미반영 커밋 1개 있음' "$tmp/session.out" || fail "session output missing unsynced nudge"
  grep -Fq 'Do not load all agent docs by default' "$tmp/session.out" || fail "session output missing context budget rule"

  journal_dir="$repo/docs/agent/journal"
  printf '%s\n' '## 2026-07-02 · commit abc123' > "$journal_dir/2026-07.md"
  (cd "$repo" && "$ROOT/scripts/seasoned-architect-context.sh" session > "$tmp/synced.out")
  grep -Fq '미반영 커밋' "$tmp/synced.out" && fail "synced output should not contain unsynced nudge"

  (cd "$repo" && "$ROOT/scripts/seasoned-architect-context.sh" subagent > "$tmp/subagent.out")
  grep -Fq '"hookEventName":"SubagentStart"' "$tmp/subagent.out" || fail "subagent output missing hook event"
  grep -Fq 'Build-loop handoff' "$tmp/subagent.out" || fail "subagent output missing handoff instruction"

  rm -rf "$tmp"
  pass "context script"
}

test_hooks_json() {
  assert_json_valid "hooks/hooks.json"
  assert_contains "hooks/hooks.json" "SessionStart"
  assert_contains "hooks/hooks.json" "SubagentStart"
  assert_contains "hooks/hooks.json" "${CLAUDE_PLUGIN_ROOT}/scripts/seasoned-architect-context.sh"
  pass "hooks json"
}
```

Update `main()` to include:

```bash
main() {
  test_plugin_structure
  test_templates
  test_git_hook_capture
  test_git_hook_install_idempotent
  test_git_hook_worktree_common_log
  test_context_script_session_and_subagent
  test_hooks_json
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: FAIL in `test_context_script_session_and_subagent` because context script is empty.

- [ ] **Step 3: Implement `seasoned-architect-context.sh`**

Replace `seasoned-architect/scripts/seasoned-architect-context.sh` with:

```bash
#!/usr/bin/env bash
set -u

mode="${1:-session}"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

if [[ ! -f "$repo_root/docs/agent/DOCS_MAP.md" ]]; then
  exit 0
fi

common_dir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null)" || exit 0
case "$common_dir" in
  /*) common_dir_abs="$common_dir" ;;
  *) common_dir_abs="$repo_root/$common_dir" ;;
esac

raw_log="$common_dir_abs/seasoned-architect/raw-log.jsonl"
journal_dir="$repo_root/docs/agent/journal"

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

python3 - "$mode" "$raw_log" "$journal_dir" <<'PY'
import json
import os
import sys

mode = sys.argv[1]
raw_log = sys.argv[2]
journal_dir = sys.argv[3]
hook_event = "SubagentStart" if mode == "subagent" else "SessionStart"

base_session = "\n".join([
    "Seasoned Architect active.",
    "For context-heavy work, inspect docs/agent/DOCS_MAP.md first.",
    "Let DOCS_MAP decide which docs to read.",
    "Do not load all agent docs by default.",
    "Do not re-read docs already read in this session unless files changed or the user asks to refresh.",
])

base_subagent = "\n".join([
    "Seasoned Architect active for this repo.",
    "For context-heavy work, inspect docs/agent/DOCS_MAP.md first.",
    "Read only the docs relevant to your assigned task.",
    "Do not load all agent docs by default.",
    "If a Build-loop handoff block is provided, follow that block and do not expand beyond it unless necessary.",
])

def read_commits_from_raw_log(path):
    commits = []
    if not os.path.exists(path):
        return commits
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            commit = entry.get("commit")
            if commit and commit not in commits:
                commits.append(commit)
    return commits

def read_journal_text(path):
    if not os.path.isdir(path):
        return ""
    parts = []
    for name in sorted(os.listdir(path)):
        if not name.endswith(".md"):
            continue
        full = os.path.join(path, name)
        try:
            with open(full, "r", encoding="utf-8") as f:
                parts.append(f.read())
        except OSError:
            continue
    return "\n".join(parts)

context = base_subagent if mode == "subagent" else base_session
if mode != "subagent":
    commits = read_commits_from_raw_log(raw_log)
    journal_text = read_journal_text(journal_dir)
    unsynced = [commit for commit in commits if commit not in journal_text]
    if unsynced:
        suffix = "개" if len(unsynced) > 1 else "개"
        context += f"\n\nSeasoned Architect: 미반영 커밋 {len(unsynced)}{suffix} 있음. `/seasoned-architect:doc-sync` 실행 권장."

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": hook_event,
        "additionalContext": context,
    }
}, ensure_ascii=False, separators=(",", ":")))
PY
```

- [ ] **Step 4: Implement `hooks/hooks.json`**

Replace `seasoned-architect/hooks/hooks.json` with:

```json
{
  "description": "Seasoned Architect lightweight context rules and sync nudge",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/seasoned-architect-context.sh",
            "args": ["session"],
            "timeout": 5
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/seasoned-architect-context.sh",
            "args": ["subagent"],
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 5: Run context tests**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: all tests pass.

- [ ] **Step 6: Commit hooks and context script**

```bash
cd '<project-root>'
git add seasoned-architect/hooks seasoned-architect/scripts/seasoned-architect-context.sh seasoned-architect/tests/run.sh
git commit -m "feat: add seasoned-architect context hooks"
```

---

## Task 5: Implement skills and skill tests

**Files:**
- Modify: `<project-root>/seasoned-architect/tests/run.sh`
- Modify: `<project-root>/seasoned-architect/skills/doc-init/SKILL.md`
- Modify: `<project-root>/seasoned-architect/skills/doc-slice/SKILL.md`
- Modify: `<project-root>/seasoned-architect/skills/doc-sync/SKILL.md`
- Modify: `<project-root>/seasoned-architect/skills/journaling/SKILL.md`

- [ ] **Step 1: Append failing skill tests**

Append this test before `main()` in `seasoned-architect/tests/run.sh`:

```bash
test_skills() {
  assert_contains "skills/doc-init/SKILL.md" "disable-model-invocation: true"
  assert_contains "skills/doc-init/SKILL.md" "install-git-hook.sh"
  assert_contains "skills/doc-init/SKILL.md" "WORK_BREAKDOWN.md"
  assert_contains "skills/doc-init/SKILL.md" "frontend-components.md"

  assert_contains "skills/doc-slice/SKILL.md" "disable-model-invocation: true"
  assert_contains "skills/doc-slice/SKILL.md" "MUST update"
  assert_contains "skills/doc-slice/SKILL.md" "DOCS_MAP.md"
  assert_contains "skills/doc-slice/SKILL.md" "Build-loop handoff"

  assert_contains "skills/doc-sync/SKILL.md" "disable-model-invocation: true"
  assert_contains "skills/doc-sync/SKILL.md" "git rev-parse --git-common-dir"
  assert_contains "skills/doc-sync/SKILL.md" "Evidence priority"
  assert_contains "skills/doc-sync/SKILL.md" "Verification"

  assert_contains "skills/journaling/SKILL.md" "user-invocable: false"
  assert_contains "skills/journaling/SKILL.md" "Do not invent intent"
  assert_contains "skills/journaling/SKILL.md" "Evidence source"
  pass "skills"
}
```

Update `main()` to include `test_skills` after `test_hooks_json`.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: FAIL on `skills/doc-init/SKILL.md does not contain: disable-model-invocation: true`.

- [ ] **Step 3: Write `doc-init` skill**

Replace `seasoned-architect/skills/doc-init/SKILL.md` with:

```markdown
---
name: doc-init
description: Initialize Seasoned Architect for a repository by creating docs/agent structure and installing the post-commit capture hook. Use when the user explicitly asks to set up Seasoned Architect in a repo.
argument-hint: "[optional project summary]"
disable-model-invocation: true
---

# Seasoned Architect Init

Initialize Seasoned Architect in the current Git repository.

## Rules

- Ask for confirmation before creating or overwriting files.
- Do not overwrite existing `docs/agent/**` files without showing the proposed change.
- Create only the v0.1 document set.
- Install the git hook only after explicit user approval.
- Keep generated docs concise and editable.

## Required files

Create or update:

- `docs/agent/DOCS_MAP.md`
- `docs/agent/WORK_BREAKDOWN.md`
- `docs/agent/structure.md`
- `docs/agent/frontend-components.md`
- `docs/agent/journal/`

Use templates from the plugin:

- `templates/DOCS_MAP.md`
- `templates/WORK_BREAKDOWN.md`
- `templates/structure.md`
- `templates/frontend-components.md`

## Workflow

1. Confirm the current directory is a Git repository.
2. Inspect the repository structure.
3. Draft the four core docs from the templates.
4. Show the proposed file list to the user.
5. After approval, write the files.
6. Ask whether to install the post-commit capture hook.
7. If approved, run `scripts/install-git-hook.sh` from the plugin directory.
8. Report created files and whether the hook was installed.

## Output format

Report:

- Files created
- Files skipped because they already existed
- Git hook status
- Next recommended action, usually `/seasoned-architect:doc-slice <slice-name>`
```

- [ ] **Step 4: Write `doc-slice` skill**

Replace `seasoned-architect/skills/doc-slice/SKILL.md` with:

```markdown
---
name: doc-slice
description: Create a new Seasoned Architect slice with plan.md and guide.md, then update DOCS_MAP.md and WORK_BREAKDOWN.md. Use only when the user explicitly asks to create or scaffold a slice.
argument-hint: "<slice-name>"
disable-model-invocation: true
---

# Seasoned Architect Slice

Create a new implementation slice.

## Required argument

`$ARGUMENTS` is the slice name. Use kebab-case for file paths.

## Rules

- `doc-slice` MUST update all four targets below.
- If any target cannot be safely updated, stop and ask the user for the missing information.
- Do not create a slice without updating `DOCS_MAP.md`.
- Do not create a slice without updating `WORK_BREAKDOWN.md`.
- Include a `Build-loop handoff` block in every `guide.md`.

## Required updates

1. Create `docs/agent/slices/<slice>/plan.md` from `templates/slice-plan.md`.
2. Create `docs/agent/slices/<slice>/guide.md` from `templates/slice-guide.md`.
3. Update `docs/agent/DOCS_MAP.md` with the slice path and code path.
4. Update `docs/agent/WORK_BREAKDOWN.md` with the MVP, part, spec, and slice link.

## Required questions when context is missing

Ask only for fields that cannot be inferred:

- Which MVP does this slice belong to?
- Which part does this slice belong to?
- Which implementation spec does this slice satisfy?
- What code paths may the implementation touch?
- Which files or areas must not be modified?
- What verification commands should build-loop run?

## Build-loop handoff requirements

The generated `guide.md` must contain:

- Seasoned Architect slice name
- Read first docs
- Read only if needed docs
- Source of truth
- Scope
- Non-goals
- Allowed files
- Do not modify
- Acceptance checks
- Verification commands

## Output format

Report:

- Slice path
- Files created
- `DOCS_MAP.md` entry added
- `WORK_BREAKDOWN.md` entry added
- Remaining fields needing user review
```

- [ ] **Step 5: Write `doc-sync` skill**

Replace `seasoned-architect/skills/doc-sync/SKILL.md` with:

```markdown
---
name: doc-sync
description: Sync unsynced Seasoned Architect raw commit logs into docs/agent/journal markdown entries. Use when the user asks to sync, update, or write the Seasoned Architect journal.
argument-hint: "[optional commit range]"
disable-model-invocation: true
---

# Seasoned Architect Sync

Convert raw commit facts into readable markdown journal entries.

## Raw log location

Calculate the raw log path with:

```bash
git rev-parse --git-common-dir
```

Then read:

```txt
<git-common-dir>/seasoned-architect/raw-log.jsonl
```

Do not use `git rev-parse --git-path seasoned-architect/raw-log.jsonl` for raw logs.

## Sync detection

A raw commit is synced when its commit hash appears anywhere under:

```txt
docs/agent/journal/*.md
```

Do not edit raw log lines to add `synced` state.

## Evidence priority

When writing Why, Result, Next/Open, and Evidence source, use this priority:

1. Matching slice `plan.md`
2. Matching slice `guide.md`
3. Commit message
4. Diff and changed files from `git show <commit>`
5. If evidence is insufficient, write `확인 필요`

Do not invent intent.

## Slice matching

Use `docs/agent/DOCS_MAP.md` to map changed files to slices.

- One clear slice: tag that slice.
- Multiple slices: tag all relevant slices or use `cross-cutting`.
- No mapping: tag `unassigned` and add `DOCS_MAP 갱신 필요` to `Next/Open`.

## Journal entry fields

Every entry must include:

- What
- Why
- Result
- Next/Open
- Changed files
- Verification
- Source
- Confidence
- Evidence source

If verification commands or results are not visible in commit data, write:

```markdown
- **Verification**: not recorded
```

## Output format

Report:

- Raw commits found
- Commits already synced
- Commits written to journal
- Journal file updated
- Entries needing user confirmation
```

- [ ] **Step 6: Write `journaling` internal skill**

Replace `seasoned-architect/skills/journaling/SKILL.md` with:

```markdown
---
name: journaling
description: Internal Seasoned Architect guidance for writing concise, evidence-based journal entries from git commits, slice docs, and diffs.
user-invocable: false
---

# Seasoned Architect Journaling Rules

Use these rules when writing `docs/agent/journal/YYYY-MM.md` entries.

## Core rule

Do not invent intent. If the reason for a change is not supported by slice docs, commit message, or diff, write `확인 필요`.

## Required entry shape

```markdown
## <timestamp> · [slice: <slice>] · commit <hash>

- **무엇(What)**: <what changed>
- **왜(Why)**: <evidence-backed reason or 확인 필요>
- **결과(Result)**: <observable result>
- **다음(Next/Open)**: <next step or none>
- **변경 파일**: `<file>`, `<file>`
- **Verification**:
  - `<command>` → <pass/fail/not run>
- **Source**: `git-hook` → `ai-enriched`
- **Confidence**: `raw` | `ai-enriched` | `user-confirmed`
- **Evidence source**: `slice-plan`, `slice-guide`, `commit-message`, `diff`, `user-confirmed`
```

## Evidence source rules

- Use `slice-plan` only when `plan.md` supports the statement.
- Use `slice-guide` only when `guide.md` supports the statement.
- Use `commit-message` only when the commit message states the reason or result.
- Use `diff` only for directly observable code/file changes.
- Use `user-confirmed` only after the user explicitly confirms the entry.

## Style

- Keep entries short.
- Prefer concrete file names and behavior over broad summaries.
- Mark uncertainty explicitly.
```

- [ ] **Step 7: Run skill tests**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected: all tests pass.

- [ ] **Step 8: Commit skills**

```bash
cd '<project-root>'
git add seasoned-architect/skills seasoned-architect/tests/run.sh
git commit -m "feat: add seasoned-architect skills"
```

---

## Task 6: Final verification and local plugin smoke test

**Files:**
- No code changes expected. If verification reveals a bug, fix in the owning file and rerun all tests.

- [ ] **Step 1: Run full shell test suite**

Run:

```bash
cd '<project-root>/seasoned-architect'
bash tests/run.sh
```

Expected:

```txt
PASS: plugin structure
PASS: templates
PASS: git hook capture
PASS: git hook install idempotent
PASS: git hook worktree common log
PASS: context script
PASS: hooks json
PASS: skills
```

- [ ] **Step 2: Validate JSON files**

Run:

```bash
cd '<project-root>/seasoned-architect'
python3 -m json.tool .claude-plugin/plugin.json >/dev/null
python3 -m json.tool hooks/hooks.json >/dev/null
```

Expected: no output and exit code 0.

- [ ] **Step 3: Verify scripts are executable**

Run:

```bash
cd '<project-root>/seasoned-architect'
test -x scripts/install-git-hook.sh
test -x scripts/post-commit-capture.sh
test -x scripts/seasoned-architect-context.sh
```

Expected: no output and exit code 0.

- [ ] **Step 4: Run Claude Code local plugin smoke test**

Run from a terminal with Claude Code installed:

```bash
cd '<project-root>'
claude --plugin-dir ./seasoned-architect
```

Inside Claude Code, run:

```txt
/help
```

Expected:

- `/seasoned-architect:doc-init` appears.
- `/seasoned-architect:doc-slice` appears.
- `/seasoned-architect:doc-sync` appears.
- `/seasoned-architect:journaling` does not appear in the `/` menu because `user-invocable: false`.

- [ ] **Step 5: Verify hooks load**

Inside Claude Code, run:

```txt
/hooks
```

Expected:

- Plugin hook source is visible.
- `SessionStart` hook is registered.
- `SubagentStart` hook is registered.

- [ ] **Step 6: Commit final verification fixes if any**

If no fixes were required, skip this step.

If fixes were required:

```bash
cd '<project-root>'
git add seasoned-architect
git commit -m "fix: stabilize seasoned-architect plugin verification"
```

---

## Self-Review

### Spec coverage

- Plugin skeleton: Task 1
- Templates including `WORK_BREAKDOWN.md` and `frontend-components.md`: Task 2
- Git common-dir raw log and worktree handling: Task 3
- Stable copied capture script: Task 3
- SessionStart/SubagentStart context policy: Task 4
- Unsynced commit nudge: Task 4
- `doc-init`, `doc-slice`, `doc-sync`, `journaling`: Task 5
- `doc-slice` required updates to `DOCS_MAP.md` and `WORK_BREAKDOWN.md`: Task 5
- Build-loop handoff block: Task 2 and Task 5
- Journal `Verification` and `Evidence source`: Task 2 and Task 5
- Context budget policy: Task 4 and Task 5
- Local plugin smoke test: Task 6

### Placeholder scan

The implementation plan contains template variables such as `{{SLICE_NAME}}` only inside template files. Those are intentional template slots. No implementation step is left undefined.

### Type/signature consistency

- Raw log path uses `git rev-parse --git-common-dir` in scripts and skills.
- Hook location uses `git rev-parse --git-path hooks/post-commit` in installer.
- Hook JSON calls `seasoned-architect-context.sh session` and `seasoned-architect-context.sh subagent`; the script maps those to `SessionStart` and `SubagentStart`.
- Tests call the same scripts and paths used by hooks.
