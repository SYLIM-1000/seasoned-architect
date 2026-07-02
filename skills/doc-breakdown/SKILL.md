---
name: doc-breakdown
description: Use when external product planning, UI planning, architecture notes, or visual planning artifacts are ready and need to be organized into Seasoned Architect docs before implementation slicing.
argument-hint: "[planning source or project summary]"
disable-model-invocation: true
---

# Seasoned Architect Breakdown

Organize confirmed external planning into Seasoned Architect docs.

## External planning readiness

Proceed only when the source material covers screens/pages, key components, data structure, roles/permissions, exception cases, and architecture direction.

If these are missing, stop and list the missing items. Do not brainstorm inside this skill. Recommend `brainstorming` or `grill-me` first.

## Required updates

Update these docs with preservation-first edits:

1. `docs/agent/structure.md`
2. `docs/agent/frontend-components.md`
3. `docs/agent/WORK_BREAKDOWN.md`

## MVP checkpoints

Pause for user confirmation at:

1. MVP candidates
2. Part candidates per MVP
3. Final Implementation Spec

Default MVP names are `Alpha`, `Beta`, and `Post-Beta`. Rename them when the project needs clearer labels such as `MVP 1`, `Internal Alpha`, or `Public Beta`.

## Implementation Spec

Write each spec at slice-ready detail, but not implementation-guide detail. Include screen, data, state, permissions, exception cases, and acceptance criteria. Do not include implementation file paths, edit order, or verification commands.

## Sub agent review

After drafting Implementation Specs, request a sub agent review of `WORK_BREAKDOWN.md`. Prefer the strongest available model and highest reasoning effort. Ask it to check MVP scope, Part size, spec detail, missing screens/data/exceptions/permissions/acceptance criteria, and slice-readiness.

Apply clear omissions or contradictions. Ask the user before applying findings that change product intent.

After the review is handled, update each affected Implementation Spec review field in `WORK_BREAKDOWN.md`: use `Spec review status: reviewed` when findings are resolved, or `Spec review status: needs user decision` when product-intent decisions remain open.

After applying review findings, present the final docs to the user for confirmation. Do not hand off to /seasoned-architect:doc-slice until the user confirms the final Implementation Specs.

## Existing docs

Preserve existing docs. Update blank or stale areas. If new planning conflicts with existing docs, ask the user before rewriting.

## Output format

Report files updated, MVPs confirmed, Parts confirmed, Implementation Specs written, sub agent review status, findings applied, findings requiring user decision, and next action `/seasoned-architect:doc-slice`.
