#!/usr/bin/env bash
# Propagate the canonical plugin version to derived manifests.
#
# Canonical source of truth: .claude-plugin/plugin.json  ("version")
# Derived (stamped here):     .codex-plugin/plugin.json  ("version")
#
# Claude Code marketplace entries intentionally omit "version" and inherit it
# from .claude-plugin/plugin.json, so they need no syncing.
#
# Usage:
#   scripts/sync-version.sh          # write canonical version into derived manifests
#   scripts/sync-version.sh --check  # verify only; non-zero exit on drift
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mode="write"
case "${1:-}" in
  "") ;;
  --check) mode="check" ;;
  *)
    echo "usage: sync-version.sh [--check]" >&2
    exit 2
    ;;
esac

python3 - "$ROOT/.claude-plugin/plugin.json" "$ROOT/.codex-plugin/plugin.json" "$mode" <<'PY'
import json
import sys
from pathlib import Path

canonical_path, codex_path, mode = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3]

version = json.loads(canonical_path.read_text(encoding="utf-8")).get("version")
if not version:
    sys.exit(f"canonical version missing in {canonical_path}")

codex = json.loads(codex_path.read_text(encoding="utf-8"))
current = codex.get("version")
codex_label = f"{codex_path.parent.name}/{codex_path.name}"

if mode == "check":
    if current != version:
        sys.exit(f"version drift: {codex_label} is {current!r}, canonical is {version!r}")
    print(f"OK: version {version} in sync")
elif current == version:
    print(f"already in sync: {version}")
else:
    codex["version"] = version
    codex_path.write_text(json.dumps(codex, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"synced {codex_label}: {current!r} -> {version!r}")
PY
