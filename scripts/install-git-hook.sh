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

agent_dir="$common_dir_abs/seasoned-architect"
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

if [[ -L "$hook_path" ]]; then
  echo "seasoned-architect: post-commit hook is a symlink; refusing automatic install. Add the capture command to your hook manager manually." >&2
  exit 1
fi

agent_bin="$agent_dir/bin"
mkdir -p "$agent_bin"
cp "$script_dir/post-commit-capture.sh" "$agent_bin/post-commit-capture.sh"
chmod +x "$agent_bin/post-commit-capture.sh"

capture_path="$agent_bin/post-commit-capture.sh"
hook_dir="$(dirname "$hook_path")"
original_hook="$hook_dir/post-commit.seasoned-architect-original"
legacy_plugin_name="Seasoned""-Architect"
legacy_named_original_hook="$hook_dir/post-commit.${legacy_plugin_name}-original"
legacy_original_hook="$agent_dir/hooks/original-post-commit.sh"
capture_path_literal="$(printf '%q' "$capture_path")"
original_hook_literal="$(printf '%q' "$original_hook")"

# A hook file inside the working tree (core.hooksPath like .husky) may be a
# shared, committed file; rewriting it would dirty or break the team's setup.
hook_rel=""
case "$hook_path" in
  "$common_dir_abs"/*) ;;
  "$repo_root"/*) hook_rel="${hook_path#"$repo_root"/}" ;;
esac

if [[ -n "$hook_rel" ]]; then
  if [[ -f "$hook_path" ]] && git -C "$repo_root" ls-files --error-unmatch "$hook_rel" >/dev/null 2>&1; then
    if grep -Fq "# seasoned-architect: wrapper" "$hook_path"; then
      echo "seasoned-architect: post-commit hook already installed at $hook_path (tracked file left unchanged)"
      exit 0
    fi
    echo "seasoned-architect: $hook_rel is tracked by git (shared hook manager such as husky); refusing automatic install." >&2
    echo "seasoned-architect: add this line to that hook manually:" >&2
    echo "  $capture_path_literal || true" >&2
    exit 1
  fi
  echo "seasoned-architect: post-commit hook at $hook_rel is inside the repository working tree; avoid committing it." >&2
fi

write_wrapper() {
  local chain_original="${1:-0}"
  cat > "$hook_path" <<HOOK
#!/usr/bin/env bash
# seasoned-architect: begin
# seasoned-architect: wrapper
$capture_path_literal || true
HOOK
  if [[ "$chain_original" = "1" ]]; then
    cat >> "$hook_path" <<HOOK
if [[ -x $original_hook_literal ]]; then
  $original_hook_literal || true
fi
HOOK
  fi
  cat >> "$hook_path" <<'HOOK'
# seasoned-architect: end
exit 0
HOOK
}

chain_original=0
if [[ -f "$hook_path" ]]; then
  if grep -Fq "# seasoned-architect: wrapper" "$hook_path" || grep -Fq "# ${legacy_plugin_name}: wrapper" "$hook_path"; then
    if [[ ! -e "$original_hook" && -f "$legacy_named_original_hook" ]]; then
      cp "$legacy_named_original_hook" "$original_hook"
      chmod +x "$original_hook"
    elif [[ ! -e "$original_hook" && -f "$legacy_original_hook" ]]; then
      cp "$legacy_original_hook" "$original_hook"
      chmod +x "$original_hook"
    fi
    if [[ -x "$original_hook" ]]; then
      chain_original=1
    fi
    write_wrapper "$chain_original"
    chmod +x "$hook_path"
    echo "seasoned-architect: post-commit hook already installed at $hook_path"
    exit 0
  fi

  backup="$hook_path.bak.$(date +%Y%m%d%H%M%S)"
  cp "$hook_path" "$backup"
  if [[ -x "$hook_path" ]]; then
    cp "$hook_path" "$original_hook"
    chmod +x "$original_hook"
    chain_original=1
  else
    rm -f "$original_hook"
    echo "seasoned-architect: existing post-commit is not executable; preserving but not chaining it" >&2
  fi
fi

write_wrapper "$chain_original"
chmod +x "$hook_path"
echo "seasoned-architect: installed post-commit hook at $hook_path"
