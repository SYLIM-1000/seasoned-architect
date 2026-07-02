---
slice: {{SLICE_NAME}}
status: draft
---

# Slice Guide: {{SLICE_NAME}}

## Read first

- docs/agent/DOCS_MAP.md
- docs/agent/WORK_BREAKDOWN.md
- docs/agent/slices/{{SLICE_NAME}}/plan.md

## Scope

- {{SCOPE_ITEM}}

## Allowed files

- {{ALLOWED_FILE}}

## Do not modify

- {{FORBIDDEN_FILE}}

## Implementation order

1. {{STEP_ONE}}
2. {{STEP_TWO}}
3. {{STEP_THREE}}

## Acceptance checks

- {{ACCEPTANCE_CHECK}}

## Verification commands

```bash
{{VERIFICATION_COMMAND}}
```

## High-risk review

- Risk category: {{RISK_CATEGORY}}
- Review status: {{HIGH_RISK_REVIEW_STATUS}}
- Findings applied: {{FINDINGS_APPLIED}}

## Build-loop handoff

Seasoned Architect slice: {{SLICE_NAME}}

Read first:
- docs/agent/DOCS_MAP.md
- docs/agent/slices/{{SLICE_NAME}}/plan.md
- docs/agent/slices/{{SLICE_NAME}}/guide.md

Read only if needed:
- docs/agent/WORK_BREAKDOWN.md — MVP/part/spec 맥락이 필요할 때
- docs/agent/frontend-components.md — UI 컴포넌트 구현 판단이 필요할 때
- docs/agent/structure.md — 아키텍처 맥락이 필요할 때

Source of truth:
- 이 guide.md의 Scope, Non-goals, Acceptance checks를 우선한다.

Scope:
- {{SCOPE_ITEM}}

Non-goals:
- {{NON_GOAL}}

Allowed files:
- {{ALLOWED_FILE}}

Do not modify:
- {{FORBIDDEN_FILE}}

Acceptance checks:
- {{ACCEPTANCE_CHECK}}

Verification commands:
- {{VERIFICATION_COMMAND}}
