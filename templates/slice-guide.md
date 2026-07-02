---
slice: {{SLICE_NAME}}
status: draft
---

# Slice Guide: {{SLICE_NAME}}

## Implementation Order

1. {{STEP_ONE}}
2. {{STEP_TWO}}
3. {{STEP_THREE}}

## Files

### Allowed files

- {{ALLOWED_FILE}}

### Do not modify

- {{FORBIDDEN_FILE}}

## Acceptance Checks

- {{ACCEPTANCE_CHECK}}

## Verification Commands

```bash
{{VERIFICATION_COMMAND}}
```

## Build-loop handoff

Seasoned Architect slice: {{SLICE_NAME}}

Read first:
- docs/agent/DOCS_MAP.md
- docs/agent/slices/{{SLICE_NAME}}/plan.md
- docs/agent/slices/{{SLICE_NAME}}/guide.md

Read only if needed:
- docs/agent/WORK_BREAKDOWN.md — MVP/part/spec 맥락이 필요할 때
- docs/agent/frontend-components.md — UI 컴포넌트 구현 판단이 필요할 때

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

Verification:
- {{VERIFICATION_COMMAND}}
