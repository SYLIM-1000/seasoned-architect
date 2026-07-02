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
  block_count="$(grep -c '# agent-docs: begin' "$hook_path")"
  [[ "$block_count" = "1" ]] || fail "agent-docs hook block duplicated"
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

main() {
  test_plugin_structure
  test_templates
  test_git_hook_capture
  test_git_hook_install_idempotent
  test_git_hook_worktree_common_log
}

main "$@"
