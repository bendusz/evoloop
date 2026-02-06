#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  ./orchestrator.sh plan start [--tool claude|codex|gemini]
  ./orchestrator.sh plan area --area <name> [--tool claude|codex|gemini]
  ./orchestrator.sh plan review [--tool claude|codex|gemini]
  ./orchestrator.sh plan redteam [--tool claude|codex|gemini]
  ./orchestrator.sh plan pm [--tool claude|codex|gemini]
  ./orchestrator.sh run [--max-iterations N] [--tool claude|codex|gemini] [--story US-XXX] [--approve-deploy US-XXX|all] [--resume] [--reset] [--runners <file>]

Notes:
- Per-agent runner commands are configured via agents/runners.json by default.
- If you use --tool (fallback mode), you can override models via env vars:
  - CLAUDE_MODEL (default: opus)
  - CODEX_MODEL (default: gpt-5.2)
  - CODEX_EFFORT (default: xhigh)
  - GEMINI_MODEL (default: gemini-2.0-flash)
- .init/ is read-only; planning agents should not edit it.
USAGE
}

MODE="${1:-}"

case "$MODE" in
  plan)
    shift || true
    exec "$SCRIPT_DIR/scripts/plan.sh" "$@"
    ;;
  run)
    shift || true
    exec "$SCRIPT_DIR/scripts/implement.sh" "$@"
    ;;
  help|--help|-h)
    usage
    exit 0
    ;;
  "")
    usage
    exit 1
    ;;
  *)
    echo "Error: unknown mode '$MODE'" >&2
    usage
    exit 1
    ;;
esac
