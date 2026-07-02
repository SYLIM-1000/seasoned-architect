#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "agent-docs: not inside a git repository" >&2
  exit 1
}

common_dir="$(git -C "$repo_root" rev-parse --git-common-dir)"
case "$common_dir" in
  /*) common_dir_abs="$common_dir" ;;
  *) common_dir_abs="$repo_root/$common_dir" ;;
esac

agent_dir="$common_dir_abs/agent-docs"
agent_bin="$agent_dir/bin"
agent_hooks="$agent_dir/hooks"
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
original_hook="$agent_hooks/original-post-commit.sh"
capture_path_literal="$(printf '%q' "$capture_path")"
original_hook_literal="$(printf '%q' "$original_hook")"

write_wrapper() {
  cat > "$hook_path" <<HOOK
#!/usr/bin/env bash
# agent-docs: begin
# agent-docs: wrapper
$capture_path_literal || true
if [[ -x $original_hook_literal ]]; then
  $original_hook_literal || true
fi
# agent-docs: end
exit 0
HOOK
}

if [[ -f "$hook_path" ]]; then
  if grep -Fq "# agent-docs: wrapper" "$hook_path"; then
    chmod +x "$hook_path"
    echo "agent-docs: post-commit hook already installed at $hook_path"
    exit 0
  fi

  backup="$hook_path.bak.$(date +%Y%m%d%H%M%S)"
  cp "$hook_path" "$backup"
  mkdir -p "$agent_hooks"
  awk '
    /^# agent-docs: begin$/ { skip = 1; next }
    /^# agent-docs: end$/ { skip = 0; next }
    !skip { print }
  ' "$hook_path" > "$original_hook"
  chmod +x "$original_hook"
fi

write_wrapper
chmod +x "$hook_path"
echo "agent-docs: installed post-commit hook at $hook_path"
