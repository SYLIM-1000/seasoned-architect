---
name: doc-slice
description: Use when confirmed Implementation Specs in docs/agent/WORK_BREAKDOWN.md need to be split into build-loop-ready slice plans and guides.
argument-hint: "[optional MVP, part, or spec filter]"
disable-model-invocation: true
---

# Seasoned Architect Slice

Turn confirmed Implementation Specs into implementation slices.

## Source

Read confirmed Implementation Specs from `docs/agent/WORK_BREAKDOWN.md`. Do not invent product goals, MVPs, Parts, architecture decisions, or missing specs.

Only slice specs with `Spec review status: reviewed`. If a target spec is `not reviewed`, `needs user decision`, or missing review status, stop and ask the user to finish `/seasoned-architect:doc-breakdown` first.

## Workflow

1. Generate slice plans first.
2. Create `docs/agent/slices/<slice>/plan.md` for each slice before any guide.
3. Ask a sub agent to review all generated plan.md files together for duplicate slices, missing slices, ordering issues, and oversized or undersized scope.
4. Apply only validated findings. Ask the user before applying findings that change product intent.
5. Create guide.md only after plan review.
6. Create one `guide.md` per slice.
7. `doc-slice` MUST update `DOCS_MAP.md` and `WORK_BREAKDOWN.md` with slice links.

## Slice size

Use a slice size that build-loop-codex can implement and verify in one pass. Prefer one screen or one tightly related feature. Split large specs into multiple slices when acceptance checks would be unclear.

## Plan requirements

Each `plan.md` must include source MVP, Part, Implementation Spec, user scenario, scope, non-goals, screen/data/state, permissions/exceptions, and acceptance criteria.

## Guide requirements

Each `guide.md` must include read-first docs, read-only-if-needed docs, scope, allowed files, do-not-modify files, implementation order, acceptance checks, verification commands, high-risk review status, and a Build-loop handoff block.

## Risk review

Flag a high-risk slice when it touches auth/permissions, payment, data deletion, privacy/security, bulk data mutation, external API integration, or core architecture change.

Review `guide.md` with a sub agent only for high-risk slice categories. Apply validated findings only.

## Verification

Infer verification commands from repo files such as `package.json`, `README.md`, `Makefile`, `pyproject.toml`, and existing docs. Ask the user when uncertain. Do not add generic commands that the repo does not support.

## Output format

Report slice paths, plan review status, findings applied, high-risk slices, guide review status when used, `DOCS_MAP.md` updates, `WORK_BREAKDOWN.md` updates, and next action `build-loop-codex`.
