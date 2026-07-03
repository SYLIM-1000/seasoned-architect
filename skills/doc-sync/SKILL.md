---
name: doc-sync
description: Sync unsynced Seasoned Architect raw commit logs into docs/agent/journal markdown entries. Use when the user asks to sync, update, or write the Seasoned Architect journal.
argument-hint: "[optional commit range]"
---

# Seasoned Architect Sync

Convert raw commit facts into readable markdown journal entries.

## Raw log location

Calculate the raw log path with:

```bash
git rev-parse --git-common-dir
```

Then read:

```txt
<git-common-dir>/seasoned-architect/raw-log.jsonl
```

Do not use `git rev-parse --git-path seasoned-architect/raw-log.jsonl` for raw logs.

## Sync detection

A raw commit is synced when the first 7 or more characters of its hash appear anywhere under:

```txt
docs/agent/journal/*.md
```

New journal entries must still record the full 40-character hash (see the journaling skill); the prefix rule only keeps detection tolerant of older short-hash entries.

Do not edit raw log lines to add `synced` state.

## Unreachable commits

Amended or rebased-away commits stay in the raw log but are no longer reachable from any branch. Before journaling a raw commit, check reachability:

```bash
git branch --contains <commit>
```

If no branch contains the commit (or the object no longer exists), do not write a normal entry. Instead list its full hash under a `## Superseded commits` heading in the month file, one line per commit with a short reason such as `amended` or `rebased away`. This clears the session nudge without duplicating the superseding commit's entry.

## Missed commits

The post-commit hook fires only for `git commit`. Merge commits, rebased or cherry-picked commits, and commits made on machines without the hook never reach the raw log.

After processing the raw log, compare against git history:

- If the user passed a commit range argument, scan `git log <range>`.
- Otherwise scan recent history, for example `git log --since=<date of the most recent journal entry>`, or `git log -50` when the journal is empty.

Journal commits that are missing from both the raw log and the journal using the same entry rules, with `Source: git-log`.

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

When a matched slice's `코드 경로` column in the DOCS_MAP Slice Map is empty or `TBD`, fill it from the commit's changed files.

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
- Superseded commits recorded
- Missed commits recovered from `git log`
- Journal file updated
- Entries needing user confirmation
