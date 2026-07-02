# Seasoned Architect Skill Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `/seasoned-architect:doc-breakdown` and expand `/seasoned-architect:doc-slice` so Seasoned Architect supports the confirmed planning-to-build workflow.

**Architecture:** Keep the plugin lightweight. Implement behavior through concise `SKILL.md` instructions and template/test updates only. Do not add runtime scripts unless a deterministic operation cannot be expressed safely in skill instructions.

**Tech Stack:** Markdown skills, Bash validation script, Claude plugin manifest structure.

---

## Source Decisions

Use `/Users/seungyong/Desktop/project/Skill&Plugin/seasoned-architect/planning/seasoned-architect-skill-expansion-plan.md` as the source of truth.

Confirmed flow:

```txt
brainstorming / grill-me / visual planning
→ /seasoned-architect:doc-breakdown
→ sub agent spec review
→ /seasoned-architect:doc-slice
→ sub agent plan.md review
→ build-loop-codex
```

## File Structure

- Create `skills/doc-breakdown/SKILL.md`
  - New skill for organizing external planning artifacts into Seasoned Architect docs.
- Modify `skills/doc-slice/SKILL.md`
  - Expand from manual slice scaffolding into spec-driven automatic slicing.
- Modify `skills/doc-init/SKILL.md`
  - Change next recommended action to `/seasoned-architect:doc-breakdown`.
- Modify `templates/WORK_BREAKDOWN.md`
  - Add fields needed by doc-breakdown: MVP goal, Part goal, Implementation Spec detail, review status, slice links.
- Modify `templates/slice-plan.md`
  - Ensure fields match the new doc-slice output: source MVP, Part, Spec, scenario, scope, non-goals, data/state, acceptance.
- Modify `templates/slice-guide.md`
  - Ensure guide is per-slice and includes risk review, verification commands, and build-loop handoff.
- Modify `tests/run.sh`
  - Add assertions for the new skill and new required phrases.

Do not modify:

- `.claude-plugin/plugin.json`
- `scripts/*`
- `hooks/*`
- `skills/doc-sync/SKILL.md`
- `skills/journaling/SKILL.md`

## Task 1: Add doc-breakdown Skill and Tests

**Files:**
- Create: `skills/doc-breakdown/SKILL.md`
- Modify: `tests/run.sh`
- Modify: `skills/doc-init/SKILL.md`
- Modify: `templates/WORK_BREAKDOWN.md`

- [ ] **Step 1: Add failing validation checks first**

Update `tests/run.sh` so `test_plugin_structure` requires:

```bash
assert_file "skills/doc-breakdown/SKILL.md"
```

Update `test_skills` so it requires these strings:

```bash
assert_contains "skills/doc-breakdown/SKILL.md" "Use when"
assert_contains "skills/doc-breakdown/SKILL.md" "External planning readiness"
assert_contains "skills/doc-breakdown/SKILL.md" "Do not brainstorm inside this skill"
assert_contains "skills/doc-breakdown/SKILL.md" "sub agent"
assert_contains "skills/doc-breakdown/SKILL.md" "Implementation Spec"
assert_contains "skills/doc-breakdown/SKILL.md" "MVP checkpoints"
assert_contains "skills/doc-breakdown/SKILL.md" "Spec review status: reviewed"
assert_contains "skills/doc-init/SKILL.md" "/seasoned-architect:doc-breakdown"
assert_contains "templates/WORK_BREAKDOWN.md" "MVP goal"
assert_contains "templates/WORK_BREAKDOWN.md" "Part goal"
assert_contains "templates/WORK_BREAKDOWN.md" "Spec review status"
assert_contains "templates/WORK_BREAKDOWN.md" "Screen"
assert_contains "templates/WORK_BREAKDOWN.md" "Permissions"
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
bash tests/run.sh
```

Expected: fail because `skills/doc-breakdown/SKILL.md` does not exist yet.

- [ ] **Step 3: Create `skills/doc-breakdown/SKILL.md`**

Create a concise skill with this required behavior:

```markdown
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

## Implementation Spec

Write each spec at slice-ready detail, but not implementation-guide detail. Include screen, data, state, permissions, exception cases, and acceptance criteria. Do not include implementation file paths, edit order, or verification commands.

## Sub agent review

After drafting Implementation Specs, request a sub agent review of `WORK_BREAKDOWN.md`. Prefer the strongest available model and highest reasoning effort. Ask it to check MVP scope, Part size, spec detail, missing screens/data/exceptions/permissions/acceptance criteria, and slice-readiness.

Apply clear omissions or contradictions. Ask the user before applying findings that change product intent.

## Existing docs

Preserve existing docs. Update blank or stale areas. If new planning conflicts with existing docs, ask the user before rewriting.

## Output format

Report files updated, MVPs confirmed, Parts confirmed, Implementation Specs written, sub agent review status, findings applied, findings requiring user decision, and next action `/seasoned-architect:doc-slice`.
```

- [ ] **Step 4: Update `doc-init` next action**

Change the final output guidance in `skills/doc-init/SKILL.md` from `/seasoned-architect:doc-slice <slice-name>` to `/seasoned-architect:doc-breakdown`.

- [ ] **Step 5: Update `WORK_BREAKDOWN.md` template**

Add MVP/Part goal fields and explicit fields under each Implementation Spec:

```markdown
- MVP goal: {{MVP_GOAL}}
- Part goal: {{PART_GOAL}}
- Screen: {{SCREEN}}
- Data: {{DATA}}
- State: {{STATE}}
- Permissions: {{PERMISSIONS}}
- Exception cases: {{EXCEPTION_CASES}}
- Acceptance criteria: {{ACCEPTANCE_CRITERIA}}
- Spec review status: not reviewed
```

Keep `Build-loop ready: no`.

- [ ] **Step 6: Run tests and verify they pass**

Run:

```bash
bash tests/run.sh
```

Expected: all tests pass.

## Task 2: Expand doc-slice and Templates

**Files:**
- Modify: `skills/doc-slice/SKILL.md`
- Modify: `templates/slice-plan.md`
- Modify: `templates/slice-guide.md`
- Modify: `tests/run.sh`

- [ ] **Step 1: Add failing validation checks first**

Update `test_skills` in `tests/run.sh` so `skills/doc-slice/SKILL.md` must contain:

```bash
assert_contains "skills/doc-slice/SKILL.md" "Generate slice plans first"
assert_contains "skills/doc-slice/SKILL.md" "review all generated plan.md files together"
assert_contains "skills/doc-slice/SKILL.md" "Create guide.md only after plan review"
assert_contains "skills/doc-slice/SKILL.md" "high-risk slice"
assert_contains "skills/doc-slice/SKILL.md" "Infer verification commands"
assert_contains "skills/doc-slice/SKILL.md" "Spec review status: reviewed"
```

Update `test_templates` so templates must contain:

```bash
assert_contains "templates/slice-plan.md" "source_spec:"
assert_contains "templates/slice-plan.md" "Acceptance criteria"
assert_contains "templates/slice-guide.md" "High-risk review"
assert_contains "templates/slice-guide.md" "Verification commands"
```

- [ ] **Step 2: Run tests and verify they fail**

Run:

```bash
bash tests/run.sh
```

Expected: fail because `doc-slice` and templates do not yet contain the new required phrases.

- [ ] **Step 3: Rewrite `skills/doc-slice/SKILL.md` around the confirmed flow**

Keep frontmatter name `doc-slice` and `disable-model-invocation: true`.

Required behavior:

- Read confirmed Implementation Specs from `docs/agent/WORK_BREAKDOWN.md`.
- Generate slice plans first.
- Create `docs/agent/slices/<slice>/plan.md` for each slice before any guide.
- Ask a sub agent to review all generated `plan.md` files together.
- Apply only validated findings.
- Create guide.md only after plan review.
- Create one `guide.md` per slice.
- Update `DOCS_MAP.md` and `WORK_BREAKDOWN.md` with slice links.
- Flag high-risk slice categories: auth/permissions, payment, data deletion, privacy/security, bulk data mutation, external API integration, core architecture change.
- Review `guide.md` only for high-risk slice categories.
- Infer verification commands from repo files; ask the user when uncertain.

- [ ] **Step 4: Update `templates/slice-plan.md`**

Ensure it includes at least:

```markdown
---
slice:
mvp:
part:
source_spec:
---

# Slice Plan: {{SLICE_NAME}}

## Purpose

## User Scenario

## Scope

## Non-goals

## Screen / Data / State

## Permissions and Exceptions

## Acceptance criteria
```

- [ ] **Step 5: Update `templates/slice-guide.md`**

Ensure it includes at least:

```markdown
# Slice Guide: {{SLICE_NAME}}

## Read first

## Scope

## Allowed files

## Do not modify

## Implementation order

## Acceptance checks

## Verification commands

## High-risk review

## Build-loop handoff
```

- [ ] **Step 6: Run tests and verify they pass**

Run:

```bash
bash tests/run.sh
```

Expected: all tests pass.

## Task 3: Plugin Validation and Final Review Prep

**Files:**
- Modify only if validation finds a concrete issue.

- [ ] **Step 1: Run plugin tests**

Run:

```bash
bash tests/run.sh
```

Expected: all tests pass.

- [ ] **Step 2: Run Claude plugin validation**

Run:

```bash
claude plugin validate .
```

Expected: validation succeeds. A kebab-case warning for `seasoned-architect` is acceptable because the user chose that name.

- [ ] **Step 3: Search for old names**

Run:

```bash
rg -n "agent[-]docs|agent[-]docs[-]structure|agent[-]dev[-]structure" .
```

Expected: no matches. Also search for old uppercase skip-variable leftovers and update them.

- [ ] **Step 4: Prepare final sub agent review**

After local verification passes, ask a new sub agent to review the whole plugin diff. The review prompt must ask for:

- missing requirements from this plan
- incorrect skill trigger descriptions
- excessive or unclear skill instructions
- missing tests
- template inconsistencies
- old naming leftovers

Apply only confirmed issues, then rerun local verification.

## Commit Plan

1. Middle commit after this planning document is created:

```bash
git add planning/2026-07-02-skill-expansion-implementation-plan.md
git commit -m "docs: plan Seasoned Architect skill expansion"
```

2. Final implementation commit after implementation, verification, and sub agent review:

```bash
git add skills/doc-breakdown/SKILL.md skills/doc-slice/SKILL.md skills/doc-init/SKILL.md templates/WORK_BREAKDOWN.md templates/slice-plan.md templates/slice-guide.md tests/run.sh
git commit -m "feat: add Seasoned Architect breakdown workflow"
```
