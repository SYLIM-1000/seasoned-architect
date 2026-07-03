---
name: doc-init
description: Initialize Seasoned Architect for a repository by creating docs/agent structure and installing the post-commit capture hook. Use when the user explicitly asks to set up Seasoned Architect in a repo.
argument-hint: "[optional project summary]"
---

# Seasoned Architect Init

Initialize Seasoned Architect in the current Git repository.

## Plugin file locations

This SKILL.md lives at `<plugin-root>/skills/doc-init/SKILL.md`; the plugin root is two directories above it. Templates are at `<plugin-root>/templates/` and the hook installer at `<plugin-root>/scripts/install-git-hook.sh`. Do not search the user's repository for these files, and do not improvise replacement templates.

## Rules

- Ask for confirmation before creating or overwriting files.
- Do not overwrite existing `docs/agent/**` files without showing the proposed change.
- Create only the core document set listed below.
- Install the git hook only after explicit user approval.
- If the hook installer refuses (symlink or git-tracked hook file), relay its manual-install instructions to the user. Do not force the install.
- Keep generated docs concise and editable.

## Required files

Create or update:

- `docs/agent/DOCS_MAP.md`
- `docs/agent/WORK_BREAKDOWN.md`
- `docs/agent/structure.md`
- `docs/agent/frontend-components.md`
- `docs/agent/journal/.gitkeep` (empty directories are not tracked by git)

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
8. Ask whether to add the Seasoned Architect section to the repo's `AGENTS.md` (create the file if needed). This is the only session-start context mechanism on Codex, which does not support plugin lifecycle hooks; on Claude Code it complements the plugin hook.
9. Report created files and whether the hook was installed.

## AGENTS.md section

Append exactly this block when the user approves, skipping it if an equivalent section already exists:

```markdown
## Seasoned Architect

- For context-heavy work, read docs/agent/DOCS_MAP.md first and let it decide which docs to load.
- Do not load all docs/agent files by default.
- After commits, run /seasoned-architect:doc-sync to update docs/agent/journal.
```

## Output format

Report:

- Files created
- Files skipped because they already existed
- Git hook status (including manual instructions if the installer refused)
- AGENTS.md status
- Next recommended action, usually `/seasoned-architect:doc-breakdown`
