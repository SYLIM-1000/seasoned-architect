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

raw_log="$common_dir_abs/Seasoned-Architect/raw-log.jsonl"
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
        context += f"\n\nSeasoned Architect: 미반영 커밋 {len(unsynced)}개 있음. `/Seasoned-Architect:doc-sync` 실행 권장."

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": hook_event,
        "additionalContext": context,
    }
}, ensure_ascii=False, separators=(",", ":")))
PY
