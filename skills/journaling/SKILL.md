---
name: journaling
description: Internal Seasoned Architect guidance for writing concise, evidence-based journal entries from git commits, slice docs, and diffs.
user-invocable: false
---

# Seasoned Architect Journaling Rules

Use these rules when writing `docs/agent/journal/YYYY-MM.md` entries.

## Core rule

Do not invent intent. If the reason for a change is not supported by slice docs, commit message, or diff, write `확인 필요`.

## Commit hash rule

Write the full 40-character commit hash in the entry heading. Never shorten it: sync detection matches journal text against raw-log hashes, and short hashes break that match.

## Required entry shape

```markdown
## <timestamp> · [slice: <slice>] · commit <full 40-character hash>

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

## Source values

- `git-hook`: the commit came from the raw log written by the post-commit hook.
- `git-log`: the commit was recovered by the doc-sync missed-commit fallback (merge commits, rebased commits, commits made without the hook).

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
