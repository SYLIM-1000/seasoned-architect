#!/usr/bin/env bash
set -u

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
common_dir="$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null)" || exit 0
case "$common_dir" in
  /*) common_dir_abs="$common_dir" ;;
  *) common_dir_abs="$repo_root/$common_dir" ;;
esac

agent_dir="$common_dir_abs/agent-docs"
raw_log="$agent_dir/raw-log.jsonl"
mkdir -p "$agent_dir" 2>/dev/null || exit 0

command -v python3 >/dev/null 2>&1 || exit 0

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
        ["git", "diff-tree", "--root", "--no-commit-id", "--name-only", "-r", commit],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    entry = {
        "commit": commit,
        "timestamp": timestamp,
        "author": author,
        "message": message,
        "changed_files": [line for line in changed.splitlines() if line],
        "source": "git-hook",
    }
    os.makedirs(os.path.dirname(raw_log), exist_ok=True)
    with open(raw_log, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n")
except Exception:
    pass
PY

exit 0
