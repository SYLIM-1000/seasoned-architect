# Seasoned Architect Map

## 읽기 우선순위

항상 먼저:
- `docs/agent/DOCS_MAP.md`

slice 구현 시:
- 해당 slice의 `plan.md`
- 해당 slice의 `guide.md`

build-loop 구현 시:
- 해당 slice `guide.md`의 `Build-loop handoff` 블록
- handoff에 명시된 필수 문서만

MVP/part/spec 맥락이 헷갈릴 때만:
- `docs/agent/WORK_BREAKDOWN.md`

UI/컴포넌트 작업일 때만:
- `docs/agent/frontend-components.md`

최근 진행 확인이 필요할 때만:
- 최신 `journal/YYYY-MM.md`의 관련 commit/slice 부분

## Slice Map

| 작업 영역 | Slice | 문서 | 코드 경로 |
|---|---|---|---|
| {{AREA_NAME}} | {{SLICE_NAME}} | `docs/agent/slices/{{SLICE_NAME}}/` | `{{CODE_PATH}}` |

## 규칙

- 맥락이 중요한 작업에서는 이 파일을 먼저 읽는다.
- 전체 문서를 무작정 다 읽지 않는다.
- 같은 세션에서 이미 읽은 문서는 파일 변경이나 refresh 요청이 없으면 다시 읽지 않는다.
- 매핑 없는 코드 영역을 반복 수정하면 이 파일 갱신을 제안한다.
