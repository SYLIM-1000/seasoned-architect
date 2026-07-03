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

test_plugin_structure() {
  assert_file ".claude-plugin/plugin.json"
  assert_file ".codex-plugin/plugin.json"
  assert_file ".agents/plugins/marketplace.json"
  assert_file "hooks/hooks.json"
  assert_file "skills/doc-breakdown/SKILL.md"
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
  assert_file "scripts/sync-version.sh"
  assert_executable "scripts/install-git-hook.sh"
  assert_executable "scripts/post-commit-capture.sh"
  assert_executable "scripts/seasoned-architect-context.sh"
  assert_executable "scripts/sync-version.sh"
  assert_json_valid ".claude-plugin/plugin.json"
  assert_json_valid ".codex-plugin/plugin.json"
  assert_json_valid ".agents/plugins/marketplace.json"
  pass "plugin structure"
}

test_codex_plugin_manifest() {
  python3 - "$ROOT/.codex-plugin/plugin.json" "$ROOT/.claude-plugin/plugin.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
canonical = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
manifest = json.loads(path.read_text(encoding="utf-8"))
assert manifest["name"] == "seasoned-architect"
assert manifest["version"] == canonical["version"]
assert manifest["skills"] == "./skills/"
assert "hooks" not in manifest
interface = manifest["interface"]
assert interface["displayName"] == "Seasoned Architect"
assert interface["developerName"] == "임승용"
assert "defaultPrompt" in interface
assert "Instructions" in interface["capabilities"]
PY
  pass "codex plugin manifest"
}

test_codex_marketplace_manifest() {
  python3 - "$ROOT/.agents/plugins/marketplace.json" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_text(encoding="utf-8"))
assert manifest["name"] == "seasoned-architect"
assert manifest["interface"]["displayName"] == "Seasoned Architect"
plugins = manifest["plugins"]
assert len(plugins) == 1
plugin = plugins[0]
assert plugin["name"] == "seasoned-architect"
assert plugin["source"] == {"source": "local", "path": "./"}
assert plugin["policy"] == {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}
assert plugin["category"] == "Developer Tools"
PY
  pass "codex marketplace manifest"
}

test_version_single_source() {
  python3 - "$ROOT" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])

canonical = json.loads((root / ".claude-plugin/plugin.json").read_text(encoding="utf-8"))
version = canonical.get("version")
assert version, "canonical version missing in .claude-plugin/plugin.json"

codex = json.loads((root / ".codex-plugin/plugin.json").read_text(encoding="utf-8"))
assert codex.get("version") == version, (
    f"codex version {codex.get('version')!r} != canonical {version!r}; "
    "run scripts/sync-version.sh"
)


def assert_no_pinned_version(path):
    if not path.exists():
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    for plugin in data.get("plugins", []):
        assert "version" not in plugin, (
            f"{path} plugin entry must not pin version; "
            "it inherits from .claude-plugin/plugin.json"
        )


assert_no_pinned_version(root / ".claude-plugin/marketplace.json")
assert_no_pinned_version(root.parent / ".claude-plugin/marketplace.json")
PY
  pass "version single source"
}

test_templates() {
  assert_contains "templates/DOCS_MAP.md" "# Seasoned Architect Map"
  assert_contains "templates/DOCS_MAP.md" "## 읽기 우선순위"
  assert_contains "templates/DOCS_MAP.md" "전체 문서를 무작정 다 읽지 않는다"
  assert_contains "templates/WORK_BREAKDOWN.md" "# Work Breakdown"
  assert_contains "templates/WORK_BREAKDOWN.md" "Build-loop ready"
  assert_contains "templates/WORK_BREAKDOWN.md" "MVP goal"
  assert_contains "templates/WORK_BREAKDOWN.md" "Part goal"
  assert_contains "templates/WORK_BREAKDOWN.md" "Spec review status"
  assert_contains "templates/WORK_BREAKDOWN.md" "Screen"
  assert_contains "templates/WORK_BREAKDOWN.md" "Permissions"
  assert_contains "templates/structure.md" "# Project Structure"
  assert_contains "templates/frontend-components.md" "# Frontend Components"
  assert_contains "templates/slice-plan.md" "mvp:"
  assert_contains "templates/slice-plan.md" "source_spec:"
  assert_contains "templates/slice-plan.md" "Acceptance criteria"
  assert_contains "templates/slice-guide.md" "## Build-loop handoff"
  assert_contains "templates/slice-guide.md" "High-risk review"
  assert_contains "templates/slice-guide.md" "Verification commands"
  assert_contains "templates/slice-guide.md" "Read only if needed"
  assert_contains "templates/journal-entry.md" "**Verification**"
  assert_contains "templates/journal-entry.md" "**Evidence source**"
  assert_contains "templates/journal-entry.md" "{{FULL_COMMIT_HASH}}"
  pass "templates"
}

test_skill_frontmatter_codex_compatible() {
  ! grep -R "disable-model-invocation: true" "$ROOT/skills" || fail "Codex rejects disable-model-invocation: true"
  ! grep -R "disable_model_invocation: true" "$ROOT/skills" || fail "Codex rejects disable_model_invocation: true"
  pass "skill frontmatter codex compatible"
}

test_skills() {
  assert_contains "skills/doc-breakdown/SKILL.md" "Use when"
  assert_contains "skills/doc-breakdown/SKILL.md" "External planning readiness"
  assert_contains "skills/doc-breakdown/SKILL.md" "Do not brainstorm inside this skill"
  assert_contains "skills/doc-breakdown/SKILL.md" "sub agent"
  assert_contains "skills/doc-breakdown/SKILL.md" "Implementation Spec"
  assert_contains "skills/doc-breakdown/SKILL.md" "MVP checkpoints"
  assert_contains "skills/doc-breakdown/SKILL.md" "Spec review status: reviewed"
  assert_contains "skills/doc-breakdown/SKILL.md" "Do not hand off to /seasoned-architect:doc-slice until the user confirms"

  assert_contains "skills/doc-init/SKILL.md" "install-git-hook.sh"
  assert_contains "skills/doc-init/SKILL.md" "WORK_BREAKDOWN.md"
  assert_contains "skills/doc-init/SKILL.md" "frontend-components.md"
  assert_contains "skills/doc-init/SKILL.md" "/seasoned-architect:doc-breakdown"
  assert_contains "skills/doc-init/SKILL.md" "two directories above"
  assert_contains "skills/doc-init/SKILL.md" "journal/.gitkeep"
  assert_contains "skills/doc-init/SKILL.md" "AGENTS.md"
  ! grep -Fq "v0.1 document set" "$ROOT/skills/doc-init/SKILL.md" || fail "doc-init still references v0.1 document set"

  assert_contains "skills/doc-slice/SKILL.md" "MUST update"
  assert_contains "skills/doc-slice/SKILL.md" "DOCS_MAP.md"
  assert_contains "skills/doc-slice/SKILL.md" "Build-loop handoff"
  assert_contains "skills/doc-slice/SKILL.md" "Generate slice plans first"
  assert_contains "skills/doc-slice/SKILL.md" "review all generated plan.md files together"
  assert_contains "skills/doc-slice/SKILL.md" "Create guide.md only after plan review"
  assert_contains "skills/doc-slice/SKILL.md" "high-risk slice"
  assert_contains "skills/doc-slice/SKILL.md" "Infer verification commands"
  assert_contains "skills/doc-slice/SKILL.md" "Spec review status: reviewed"
  assert_contains "skills/doc-slice/SKILL.md" "build-loop skill"
  ! grep -Fq "build-loop-codex" "$ROOT/skills/doc-slice/SKILL.md" || fail "doc-slice must not hardcode build-loop-codex"

  assert_contains "skills/doc-sync/SKILL.md" "git rev-parse --git-common-dir"
  assert_contains "skills/doc-sync/SKILL.md" "Evidence priority"
  assert_contains "skills/doc-sync/SKILL.md" "Verification"
  assert_contains "skills/doc-sync/SKILL.md" "first 7"
  assert_contains "skills/doc-sync/SKILL.md" "Unreachable commits"
  assert_contains "skills/doc-sync/SKILL.md" "Superseded commits"
  assert_contains "skills/doc-sync/SKILL.md" "Missed commits"
  assert_contains "skills/doc-sync/SKILL.md" "git-log"

  assert_contains "skills/journaling/SKILL.md" "user-invocable: false"
  assert_contains "skills/journaling/SKILL.md" "Do not invent intent"
  assert_contains "skills/journaling/SKILL.md" "Evidence source"
  assert_contains "skills/journaling/SKILL.md" "full 40-character commit hash"
  pass "skills"
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

test_git_hook_core_hooks_path_capture() {
  local tmp repo raw_log hook_path
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  git -C "$repo" config core.hooksPath .custom-hooks

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  hook_path="$repo/.custom-hooks/post-commit"
  [[ -x "$hook_path" ]] || fail "core.hooksPath post-commit hook was not created"

  echo "custom hooks" > "$repo/custom-hooks.txt"
  git -C "$repo" add custom-hooks.txt
  git -C "$repo" commit -q -m "capture custom hooks path"

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
  [[ -f "$raw_log" ]] || fail "raw log missing with core.hooksPath"
  grep -Fq '"message":"capture custom hooks path"' "$raw_log" || fail "core.hooksPath commit was not captured"

  rm -rf "$tmp"
  pass "git hook core.hooksPath capture"
}

test_git_hook_space_path_capture() {
  local tmp repo raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo with spaces"
  make_git_repo "$repo"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "spaces" > "$repo/spaces.txt"
  git -C "$repo" add spaces.txt
  git -C "$repo" commit -q -m "capture space path"

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
  [[ -f "$raw_log" ]] || fail "raw log missing when repo path contains spaces"
  grep -Fq '"message":"capture space path"' "$raw_log" || fail "space path commit was not captured"

  rm -rf "$tmp"
  pass "git hook space path capture"
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
  block_count="$(grep -c '# seasoned-architect: begin' "$hook_path")"
  [[ "$block_count" = "1" ]] || fail "seasoned-architect hook block duplicated"
  ls "$hook_path".bak.* >/dev/null 2>&1 || fail "existing hook backup was not created"
  original_hook="$(dirname "$hook_path")/post-commit.seasoned-architect-original"
  [[ -x "$original_hook" ]] || fail "original hook copy was not created"
  grep -Fq "existing-hook" "$original_hook" || fail "original hook copy missing existing hook content"

  rm -rf "$tmp"
  pass "git hook install idempotent"
}

test_git_hook_legacy_marker_migrates() {
  local tmp repo hook_path original_hook legacy_original_hook legacy_name block_count
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks"
  hook_path="$repo/.git/hooks/post-commit"
  legacy_name="Seasoned""-Architect"
  legacy_original_hook="$repo/.git/hooks/post-commit.${legacy_name}-original"

  cat > "$legacy_original_hook" <<'HOOK'
#!/usr/bin/env bash
echo legacy-original >/dev/null
HOOK
  chmod +x "$legacy_original_hook"

  {
    echo '#!/usr/bin/env bash'
    echo "# ${legacy_name}: begin"
    echo "# ${legacy_name}: wrapper"
    echo '/path/to/old/capture || true'
    echo "# ${legacy_name}: end"
    echo 'exit 0'
  } > "$hook_path"
  chmod +x "$hook_path"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")

  block_count="$(grep -c '# seasoned-architect: begin' "$hook_path")"
  [[ "$block_count" = "1" ]] || fail "legacy hook was not rewritten with lowercase marker"
  ! grep -Fq "# ${legacy_name}: wrapper" "$hook_path" || fail "legacy hook marker remained"
  original_hook="$repo/.git/hooks/post-commit.seasoned-architect-original"
  [[ -x "$original_hook" ]] || fail "legacy original hook was not migrated"
  grep -Fq "legacy-original" "$original_hook" || fail "legacy original hook content missing"

  rm -rf "$tmp"
  pass "git hook legacy marker migrates"
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
  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
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

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
  [[ -f "$repo/existing-hook-ran" ]] || fail "existing hook did not run"
  [[ -f "$raw_log" ]] || fail "raw log missing when existing hook ends with exit 0"
  grep -Fq '"message":"capture before exit zero"' "$raw_log" || fail "commit after existing exit 0 was not captured"

  rm -rf "$tmp"
  pass "git hook existing exit 0"
}

test_git_hook_capture_before_executable_original() {
  local tmp repo raw_log order_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks"
  cat > "$repo/.git/hooks/post-commit" <<'HOOK'
#!/usr/bin/env bash
repo_root="$(git rev-parse --show-toplevel)"
common_dir="$(git -C "$repo_root" rev-parse --git-common-dir)"
case "$common_dir" in
  /*) common_dir_abs="$common_dir" ;;
  *) common_dir_abs="$repo_root/$common_dir" ;;
esac
raw_log="$common_dir_abs/seasoned-architect/raw-log.jsonl"
order_log="$repo_root/order.log"
if [[ -f "$raw_log" ]]; then
  echo "capture-before-original" >> "$order_log"
else
  echo "original-before-capture" >> "$order_log"
fi
HOOK
  chmod +x "$repo/.git/hooks/post-commit"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "ordered" > "$repo/ordered.txt"
  git -C "$repo" add ordered.txt
  git -C "$repo" commit -q -m "capture before original"

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
  order_log="$repo/order.log"
  [[ -f "$raw_log" ]] || fail "raw log missing for executable original order test"
  [[ -f "$order_log" ]] || fail "existing executable hook did not write order log"
  grep -Fxq "capture-before-original" "$order_log" || fail "capture did not run before executable original hook"
  ! grep -Fxq "original-before-capture" "$order_log" || fail "original hook ran before capture"

  rm -rf "$tmp"
  pass "git hook capture before executable original"
}

test_git_hook_guard_clause_still_captures() {
  local tmp repo raw_log
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.git/hooks"
  cat > "$repo/.git/hooks/post-commit" <<'HOOK'
#!/usr/bin/env bash
if [[ -n "${SKIP_SEASONED_ARCHITECT:-}" ]]; then
  exit 0
fi
echo existing-hook > existing-hook-ran
HOOK
  chmod +x "$repo/.git/hooks/post-commit"

  (cd "$repo" && "$ROOT/scripts/install-git-hook.sh")
  echo "guard" > "$repo/guard.txt"
  git -C "$repo" add guard.txt
  git -C "$repo" commit -q -m "capture with guard clause"

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
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

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
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

  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
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

test_context_script_short_hash_synced() {
  local tmp repo raw_log full_hash
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/docs/agent/journal"
  cp "$ROOT/templates/DOCS_MAP.md" "$repo/docs/agent/DOCS_MAP.md"

  full_hash="9259b90748d0ea266432440e208a802322250ce3"
  raw_log="$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl"
  mkdir -p "$(dirname "$raw_log")"
  printf '{"commit":"%s","timestamp":"2026-07-03T10:00:00+09:00","author":"Agent","message":"short hash","changed_files":["a.txt"],"source":"git-hook"}\n' "$full_hash" > "$raw_log"

  printf '## 2026-07-03 · [slice: x] · commit %s\n' "${full_hash:0:7}" > "$repo/docs/agent/journal/2026-07.md"
  (cd "$repo" && "$ROOT/scripts/seasoned-architect-context.sh" session > "$tmp/short.out")
  grep -Fq '미반영 커밋' "$tmp/short.out" && fail "short-hash journal entry must count as synced"

  printf '## 2026-07-03 · [slice: x] · commit unrelated\n' > "$repo/docs/agent/journal/2026-07.md"
  (cd "$repo" && "$ROOT/scripts/seasoned-architect-context.sh" session > "$tmp/unsynced.out")
  grep -Fq '미반영 커밋 1개 있음' "$tmp/unsynced.out" || fail "genuinely unsynced commit must still be nudged"

  rm -rf "$tmp"
  pass "context script short hash synced"
}

test_git_hook_tracked_hook_refuses_install() {
  local tmp repo hook_path output status
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  mkdir -p "$repo/.husky"
  hook_path="$repo/.husky/post-commit"
  cat > "$hook_path" <<'HOOK'
#!/usr/bin/env bash
echo husky-hook >/dev/null
HOOK
  chmod +x "$hook_path"
  git -C "$repo" add .husky/post-commit
  git -C "$repo" commit -qm "add husky hook"
  git -C "$repo" config core.hooksPath .husky

  set +e
  output="$(cd "$repo" && "$ROOT/scripts/install-git-hook.sh" 2>&1)"
  status="$?"
  set -e

  [[ "$status" != "0" ]] || fail "tracked hook install should fail"
  grep -Fq "tracked by git" <<<"$output" || fail "tracked hook refusal message missing"
  grep -Fq "post-commit-capture.sh" <<<"$output" || fail "tracked hook refusal must include manual capture command"
  grep -Fq "husky-hook" "$hook_path" || fail "tracked hook content changed"
  ! grep -Fq "seasoned-architect" "$hook_path" || fail "tracked hook was rewritten"

  rm -rf "$tmp"
  pass "git hook tracked hook refusal"
}

test_git_hook_untracked_worktree_hook_warns() {
  local tmp repo output
  tmp="$(mktemp -d)"
  repo="$tmp/repo"
  make_git_repo "$repo"
  git -C "$repo" config core.hooksPath .githooks

  output="$(cd "$repo" && "$ROOT/scripts/install-git-hook.sh" 2>&1)"
  grep -Fq "inside the repository working tree" <<<"$output" || fail "in-worktree hook warning missing"
  [[ -x "$repo/.githooks/post-commit" ]] || fail "in-worktree hook was not installed"

  echo "warned" > "$repo/warned.txt"
  git -C "$repo" add warned.txt
  git -C "$repo" commit -qm "capture with in-worktree hook"
  [[ -f "$(common_dir_abs "$repo")/seasoned-architect/raw-log.jsonl" ]] || fail "raw log missing for in-worktree hook"

  rm -rf "$tmp"
  pass "git hook untracked worktree warning"
}

test_hooks_json() {
  assert_json_valid "hooks/hooks.json"
  assert_contains "hooks/hooks.json" "SessionStart"
  assert_contains "hooks/hooks.json" "SubagentStart"
  assert_contains "hooks/hooks.json" '${CLAUDE_PLUGIN_ROOT}/scripts/seasoned-architect-context.sh'
  pass "hooks json"
}

main() {
  test_plugin_structure
  test_codex_plugin_manifest
  test_codex_marketplace_manifest
  test_version_single_source
  test_templates
  test_skill_frontmatter_codex_compatible
  test_skills
  test_git_hook_capture
  test_git_hook_core_hooks_path_capture
  test_git_hook_space_path_capture
  test_git_hook_install_idempotent
  test_git_hook_legacy_marker_migrates
  test_git_hook_symlink_refuses_install
  test_git_hook_non_executable_not_chained
  test_git_hook_existing_exit0_still_captures
  test_git_hook_capture_before_executable_original
  test_git_hook_guard_clause_still_captures
  test_git_hook_relative_helper_still_runs
  test_git_hook_dollar_path_capture
  test_git_hook_worktree_common_log
  test_git_hook_tracked_hook_refuses_install
  test_git_hook_untracked_worktree_hook_warns
  test_context_script_session_and_subagent
  test_context_script_short_hash_synced
  test_hooks_json
}

main "$@"
