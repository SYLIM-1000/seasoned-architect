---
name: doc-sync
description: Sync unsynced Agent Docs raw commit logs into docs/agent/journal markdown entries. Use when the user asks to sync, update, or write the Agent Docs journal.
argument-hint: "[optional commit range]"
disable-model-invocation: true
---

# Agent Docs Sync

Convert raw commit facts into readable markdown journal entries.

## Raw log location

Calculate the raw log path with:

```bash
git rev-parse --git-common-dir
```

Then read:

```txt
<git-common-dir>/agent-docs/raw-log.jsonl
```

Do not use `git rev-parse --git-path agent-docs/raw-log.jsonl` for raw logs.

## Sync detection

A raw commit is synced when its commit hash appears anywhere under:

```txt
docs/agent/journal/*.md
```

Do not edit raw log lines to add `synced` state.

## Evidence priority

When writing Why, Result, Next/Open, and Evidence source, use this priority:

1. Matching slice `plan.md`
2. Matching slice `guide.md`
3. Commit message
4. Diff and changed files from `git show <commit>`
5. If evidence is insufficient, write `확인 필요`

Do not invent intent.

## Slice matching

Use `docs/agent/DOCS_MAP.md` to map changed files to slices.

- One clear slice: tag that slice.
- Multiple slices: tag all relevant slices or use `cross-cutting`.
- No mapping: tag `unassigned` and add `DOCS_MAP 갱신 필요` to `Next/Open`.

## Journal entry fields

Every entry must include:

- What
- Why
- Result
- Next/Open
- Changed files
- Verification
- Source
- Confidence
- Evidence source

If verification commands or results are not visible in commit data, write:

```markdown
- **Verification**: not recorded
```

## Output format

Report:

- Raw commits found
- Commits already synced
- Commits written to journal
- Journal file updated
- Entries needing user confirmation
