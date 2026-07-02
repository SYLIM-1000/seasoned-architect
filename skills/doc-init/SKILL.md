---
name: doc-init
description: Initialize Seasoned Architect for a repository by creating docs/agent structure and installing the post-commit capture hook. Use when the user explicitly asks to set up Seasoned Architect in a repo.
argument-hint: "[optional project summary]"
disable-model-invocation: true
---

# Seasoned Architect Init

Initialize Seasoned Architect in the current Git repository.

## Rules

- Ask for confirmation before creating or overwriting files.
- Do not overwrite existing `docs/agent/**` files without showing the proposed change.
- Create only the v0.1 document set.
- Install the git hook only after explicit user approval.
- Keep generated docs concise and editable.

## Required files

Create or update:

- `docs/agent/DOCS_MAP.md`
- `docs/agent/WORK_BREAKDOWN.md`
- `docs/agent/structure.md`
- `docs/agent/frontend-components.md`
- `docs/agent/journal/`

Use templates from the plugin:

- `templates/DOCS_MAP.md`
- `templates/WORK_BREAKDOWN.md`
- `templates/structure.md`
- `templates/frontend-components.md`

## Workflow

1. Confirm the current directory is a Git repository.
2. Inspect the repository structure.
3. Draft the four core docs from the templates.
4. Show the proposed file list to the user.
5. After approval, write the files.
6. Ask whether to install the post-commit capture hook.
7. If approved, run `scripts/install-git-hook.sh` from the plugin directory.
8. Report created files and whether the hook was installed.

## Output format

Report:

- Files created
- Files skipped because they already existed
- Git hook status
- Next recommended action, usually `/Seasoned-Architect:doc-slice <slice-name>`
