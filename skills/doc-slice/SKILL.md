---
name: doc-slice
description: Create a new Agent Docs slice with plan.md and guide.md, then update DOCS_MAP.md and WORK_BREAKDOWN.md. Use only when the user explicitly asks to create or scaffold a slice.
argument-hint: "<slice-name>"
disable-model-invocation: true
---

# Agent Docs Slice

Create a new implementation slice.

## Required argument

`$ARGUMENTS` is the slice name. Use kebab-case for file paths.

## Rules

- `doc-slice` MUST update all four targets below.
- If any target cannot be safely updated, stop and ask the user for the missing information.
- Do not create a slice without updating `DOCS_MAP.md`.
- Do not create a slice without updating `WORK_BREAKDOWN.md`.
- Include a `Build-loop handoff` block in every `guide.md`.

## Required updates

1. Create `docs/agent/slices/<slice>/plan.md` from `templates/slice-plan.md`.
2. Create `docs/agent/slices/<slice>/guide.md` from `templates/slice-guide.md`.
3. Update `docs/agent/DOCS_MAP.md` with the slice path and code path.
4. Update `docs/agent/WORK_BREAKDOWN.md` with the MVP, part, spec, and slice link.

## Required questions when context is missing

Ask only for fields that cannot be inferred:

- Which MVP does this slice belong to?
- Which part does this slice belong to?
- Which implementation spec does this slice satisfy?
- What code paths may the implementation touch?
- Which files or areas must not be modified?
- What verification commands should build-loop run?

## Build-loop handoff requirements

The generated `guide.md` must contain:

- Agent Docs slice name
- Read first docs
- Read only if needed docs
- Source of truth
- Scope
- Non-goals
- Allowed files
- Do not modify
- Acceptance checks
- Verification commands

## Output format

Report:

- Slice path
- Files created
- `DOCS_MAP.md` entry added
- `WORK_BREAKDOWN.md` entry added
- Remaining fields needing user review
