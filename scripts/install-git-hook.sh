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

agent_bin="$common_dir_abs/agent-docs/bin"
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
# agent-docs: begin
"$capture_path" || true
# agent-docs: end
BLOCK
)

if [[ -f "$hook_path" ]]; then
  if grep -Fq "# agent-docs: begin" "$hook_path"; then
    chmod +x "$hook_path"
    echo "agent-docs: post-commit hook already installed at $hook_path"
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
echo "agent-docs: installed post-commit hook at $hook_path"
