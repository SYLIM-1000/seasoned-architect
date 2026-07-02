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

make_git_repo() {
  local repo="$1"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.name "Agent Docs Test"
  git -C "$repo" config user.email "agent-docs@example.com"
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
  assert_file "scripts/agent-docs-context.sh"
  assert_executable "scripts/install-git-hook.sh"
  assert_executable "scripts/post-commit-capture.sh"
  assert_executable "scripts/agent-docs-context.sh"
  assert_json_valid ".claude-plugin/plugin.json"
  pass "plugin structure"
}

test_templates() {
  assert_contains "templates/DOCS_MAP.md" "# Agent Docs Map"
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

test_git_hook_capture() {
  local tmp repo raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "alpha" > "$repo/a.txt"
  git -C "$repo" add a.txt
  git -C "$repo" commit -q -m "add alpha"

  raw_log="$(common_dir_abs "$repo")/agent-docs/raw-log.jsonl"
  [[ -f "$raw_log" ]] || fail "raw log was not created at common dir"
  grep -Fq '"message":"add alpha"' "$raw_log" || fail "raw log missing commit message"
  grep -Fq '"changed_files":["a.txt"]' "$raw_log" || fail "raw log missing changed file"
  [[ ! -f "$repo/docs/agent/journal/$(date +%Y-%m).md" ]] || fail "post-commit hook must not write markdown journal"

  rm -rf "$tmp"
  pass "git hook capture"
}

test_git_hook_install_idempotent() {
  local tmp repo hook_path original_hook block_count
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
  block_count="$(grep -c '# agent-docs: begin' "$hook_path")"
  [[ "$block_count" = "1" ]] || fail "agent-docs hook block duplicated"
  ls "$hook_path".bak.* >/dev/null 2>&1 || fail "existing hook backup was not created"
  original_hook="$(dirname "$hook_path")/post-commit.agent-docs-original"
  [[ -x "$original_hook" ]] || fail "original hook copy was not created"
  grep -Fq "existing-hook" "$original_hook" || fail "original hook copy missing existing hook content"

  rm -rf "$tmp"
  pass "git hook install idempotent"
}

test_git_hook_symlink_refuses_install() {
  local tmp repo target hook_path output status
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks"
  target="$repo/managed-post-commit"
  cat > "$target" <<'HOOK'
#!/usr/bin/env bash
echo managed-hook > managed-hook-ran
HOOK
  chmod +x "$target"
  ln -s "$target" "$repo/.git/hooks/post-commit"

  set +e
  output="$(cd "$repo" && "$ROOT/scripts/install-git-hook.sh" 2>&1)"
  status="$?"
  set -e

  hook_path="$repo/.git/hooks/post-commit"
  [[ "$status" != "0" ]] || fail "symlink hook install should fail"
  [[ -L "$hook_path" ]] || fail "symlink hook was replaced"
  [[ "$(readlink "$hook_path")" = "$target" ]] || fail "symlink target changed"
  grep -Fq "post-commit hook is a symlink" <<<"$output" || fail "symlink refusal message missing"
  grep -Fq "managed-hook" "$target" || fail "symlink target content changed"

  rm -rf "$tmp"
  pass "git hook symlink refusal"
}

test_git_hook_non_executable_not_chained() {
  local tmp repo raw_log output hook_path
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks"
  cat > "$repo/.git/hooks/post-commit" <<'HOOK'
#!/usr/bin/env bash
echo inactive-hook > inactive-hook-ran
HOOK
  chmod 0644 "$repo/.git/hooks/post-commit"

  output="$(cd "$repo" && "$ROOT/scripts/install-git-hook.sh" 2>&1)"
  echo "non executable" > "$repo/non-executable.txt"
  git -C "$repo" add non-executable.txt
  git -C "$repo" commit -q -m "capture without inactive hook"

  hook_path="$repo/.git/hooks/post-commit"
  raw_log="$(common_dir_abs "$repo")/agent-docs/raw-log.jsonl"
  grep -Fq "not executable; preserving but not chaining it" <<<"$output" || fail "non-executable hook message missing"
  ls "$hook_path".bak.* >/dev/null 2>&1 || fail "non-executable hook backup was not created"
  [[ -f "$raw_log" ]] || fail "raw log missing for non-executable hook"
  grep -Fq '"message":"capture without inactive hook"' "$raw_log" || fail "non-executable hook commit was not captured"
  [[ ! -f "$repo/inactive-hook-ran" ]] || fail "non-executable existing hook was chained"

  rm -rf "$tmp"
  pass "git hook non-executable not chained"
}

test_git_hook_existing_exit0_still_captures() {
  local tmp repo raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks"
  cat > "$repo/.git/hooks/post-commit" <<'HOOK'
#!/usr/bin/env bash
echo existing-hook > existing-hook-ran
exit 0
HOOK
  chmod +x "$repo/.git/hooks/post-commit"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "exit zero" > "$repo/exit-zero.txt"
  git -C "$repo" add exit-zero.txt
  git -C "$repo" commit -q -m "capture before exit zero"

  raw_log="$(common_dir_abs "$repo")/agent-docs/raw-log.jsonl"
  [[ -f "$repo/existing-hook-ran" ]] || fail "existing hook did not run"
  [[ -f "$raw_log" ]] || fail "raw log missing when existing hook ends with exit 0"
  grep -Fq '"message":"capture before exit zero"' "$raw_log" || fail "commit after existing exit 0 was not captured"

  rm -rf "$tmp"
  pass "git hook existing exit 0"
}

test_git_hook_guard_clause_still_captures() {
  local tmp repo raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks"
  cat > "$repo/.git/hooks/post-commit" <<'HOOK'
#!/usr/bin/env bash
if [[ -n "${SKIP_AGENT_DOCS:-}" ]]; then
  exit 0
fi
echo existing-hook > existing-hook-ran
HOOK
  chmod +x "$repo/.git/hooks/post-commit"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "guard" > "$repo/guard.txt"
  git -C "$repo" add guard.txt
  git -C "$repo" commit -q -m "capture with guard clause"

  raw_log="$(common_dir_abs "$repo")/agent-docs/raw-log.jsonl"
  [[ -f "$repo/existing-hook-ran" ]] || fail "existing guard hook did not run"
  [[ -f "$raw_log" ]] || fail "raw log missing when existing hook has guard clause"
  grep -Fq '"message":"capture with guard clause"' "$raw_log" || fail "guard clause commit was not captured"

  rm -rf "$tmp"
  pass "git hook guard clause"
}

test_git_hook_relative_helper_still_runs() {
  local tmp repo raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks/lib"
  cat > "$repo/.git/hooks/lib/helper.sh" <<'HELPER'
write_hook_side_effect() {
  echo helper > helper-hook-ran
}
HELPER
  cat > "$repo/.git/hooks/post-commit" <<'HOOK'
#!/usr/bin/env bash
hook_dir="$(cd "$(dirname "$0")" && pwd)"
source "$hook_dir/lib/helper.sh"
write_hook_side_effect
HOOK
  chmod +x "$repo/.git/hooks/post-commit"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "relative helper" > "$repo/relative-helper.txt"
  git -C "$repo" add relative-helper.txt
  git -C "$repo" commit -q -m "capture with relative helper"

  raw_log="$(common_dir_abs "$repo")/agent-docs/raw-log.jsonl"
  [[ -f "$repo/helper-hook-ran" ]] || fail "existing hook relative helper did not run"
  [[ -f "$raw_log" ]] || fail "raw log missing when existing hook uses relative helper"
  grep -Fq '"message":"capture with relative helper"' "$raw_log" || fail "relative helper commit was not captured"

  rm -rf "$tmp"
  pass "git hook relative helper"
}

test_git_hook_dollar_path_capture() {
  local tmp repo raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo-\$dollar"
  make_git_repo "$repo"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "dollar" > "$repo/dollar.txt"
  git -C "$repo" add dollar.txt
  git -C "$repo" commit -q -m "capture dollar path"

  raw_log="$(common_dir_abs "$repo")/agent-docs/raw-log.jsonl"
  [[ -f "$raw_log" ]] || fail "raw log missing when repo path contains dollar"
  grep -Fq '"message":"capture dollar path"' "$raw_log" || fail "dollar path commit was not captured"

  rm -rf "$tmp"
  pass "git hook dollar path capture"
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
  git -C "$wt" config user.name "Agent Docs Test"
  git -C "$wt" config user.email "agent-docs@example.com"

  echo "worktree" > "$wt/wt.txt"
  git -C "$wt" add wt.txt
  git -C "$wt" commit -q -m "worktree commit"

  raw_log="$(common_dir_abs "$repo")/agent-docs/raw-log.jsonl"
  [[ -f "$raw_log" ]] || fail "worktree raw log missing from common dir"
  grep -Fq '"message":"worktree commit"' "$raw_log" || fail "worktree commit not captured in common raw log"

  git -C "$repo" worktree remove -f "$wt"
  rm -rf "$tmp"
  pass "git hook worktree common log"
}

test_context_script_session_and_subagent() {
  local tmp repo output raw_log journal_dir
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"

  (cd "$repo" && "$ROOT/scripts/agent-docs-context.sh" session > "$tmp/no-docs.out")
  [[ ! -s "$tmp/no-docs.out" ]] || fail "context script should be silent before docs/agent exists"

  mkdir -p "$repo/docs/agent/journal"
  cp "$ROOT/templates/DOCS_MAP.md" "$repo/docs/agent/DOCS_MAP.md"
  raw_log="$(common_dir_abs "$repo")/agent-docs/raw-log.jsonl"
  mkdir -p "$(dirname "$raw_log")"
  printf '%s\n' '{"commit":"abc123","timestamp":"2026-07-02T10:00:00+09:00","author":"Agent","message":"test commit","changed_files":["a.txt"],"source":"git-hook"}' > "$raw_log"

  (cd "$repo" && "$ROOT/scripts/agent-docs-context.sh" session > "$tmp/session.out")
  grep -Fq '"hookEventName":"SessionStart"' "$tmp/session.out" || fail "session output missing hook event"
  grep -Fq '미반영 커밋 1개 있음' "$tmp/session.out" || fail "session output missing unsynced nudge"
  grep -Fq 'Do not load all agent docs by default' "$tmp/session.out" || fail "session output missing context budget rule"

  journal_dir="$repo/docs/agent/journal"
  printf '%s\n' '## 2026-07-02 · commit abc123' > "$journal_dir/2026-07.md"
  (cd "$repo" && "$ROOT/scripts/agent-docs-context.sh" session > "$tmp/synced.out")
  grep -Fq '미반영 커밋' "$tmp/synced.out" && fail "synced output should not contain unsynced nudge"

  (cd "$repo" && "$ROOT/scripts/agent-docs-context.sh" subagent > "$tmp/subagent.out")
  grep -Fq '"hookEventName":"SubagentStart"' "$tmp/subagent.out" || fail "subagent output missing hook event"
  grep -Fq 'Build-loop handoff' "$tmp/subagent.out" || fail "subagent output missing handoff instruction"

  rm -rf "$tmp"
  pass "context script"
}

test_hooks_json() {
  assert_json_valid "hooks/hooks.json"
  assert_contains "hooks/hooks.json" "SessionStart"
  assert_contains "hooks/hooks.json" "SubagentStart"
  assert_contains "hooks/hooks.json" '${CLAUDE_PLUGIN_ROOT}/scripts/agent-docs-context.sh'
  pass "hooks json"
}

main() {
  test_plugin_structure
  test_templates
  test_git_hook_capture
  test_git_hook_install_idempotent
  test_git_hook_symlink_refuses_install
  test_git_hook_non_executable_not_chained
  test_git_hook_existing_exit0_still_captures
  test_git_hook_guard_clause_still_captures
  test_git_hook_relative_helper_still_runs
  test_git_hook_dollar_path_capture
  test_git_hook_worktree_common_log
  test_context_script_session_and_subagent
  test_hooks_json
}

main "$@"
