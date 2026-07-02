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
  assert_file "scripts/agent-docs-context.sh"
  assert_executable "scripts/install-git-hook.sh"
  assert_executable "scripts/post-commit-capture.sh"
  assert_executable "scripts/agent-docs-context.sh"
  assert_json_valid ".claude-plugin/plugin.json"
  pass "plugin structure"
}

main() {
  test_plugin_structure
}

main "$@"
