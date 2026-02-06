#!/bin/bash
set -euo pipefail

# --- Trap handlers for graceful cleanup on failure or interruption ---
_plan_cleanup() {
  local exit_code=$?
  if [[ "$exit_code" -eq 0 ]]; then
    return
  fi

  # Log the failure if RUN_LOG exists
  if [[ -n "${RUN_LOG:-}" && -f "$RUN_LOG" ]]; then
    printf "\n## Crashed\n\nExit code: %s\nTime: %s\n" "$exit_code" "$(date)" >> "$RUN_LOG" 2>/dev/null || true
  fi

  # Update pipeline state to error/crashed
  if [[ -n "${PIPELINE_FILE:-}" && -d "${STATE_DIR:-}" ]]; then
    update_pipeline_state "planning" "crashed" "null" "unknown" "$(basename "${RUN_DIR:-unknown}")" 2>/dev/null || true
  fi

  # Clean up temp prompt files
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -f "$TEMP_DIR"/prompt-*.md 2>/dev/null || true
  fi

  # Release pipeline lock
  rm -rf "${LOCK_FILE:-}" 2>/dev/null || true
}

_plan_interrupted() {
  echo "Interrupted by user." >&2
  exit 130
}

trap _plan_cleanup EXIT
trap _plan_interrupted INT TERM
# --- End trap handlers ---

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/lib/common.sh"

usage_plan() {
  cat <<'USAGE'
Usage:
  ./scripts/plan.sh start [--tool claude|codex|gemini] [--runners <file>] [--reset] [--resume]
  ./scripts/plan.sh area --area <name> [--tool claude|codex|gemini] [--runners <file>] [--reset] [--resume]
  ./scripts/plan.sh review [--tool claude|codex|gemini] [--runners <file>] [--reset] [--resume]
  ./scripts/plan.sh redteam [--tool claude|codex|gemini] [--runners <file>] [--reset] [--resume]
  ./scripts/plan.sh pm [--tool claude|codex|gemini] [--runners <file>] [--reset] [--resume]
USAGE
}

run_plan() {
  ensure_dirs
  init_pipeline_state
  init_run
  case "$SUBMODE" in
    start)
      append_context_pack "Planner" ".init/README.md" ".init/" "$AREAS_REL" "$RUNBOOK_REL" "$DECISIONS_REL" "$ASSUMPTIONS_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL"
      local prompt_file="$TEMP_DIR/prompt-planner.md"
      build_prompt "$SCRIPT_DIR/agents/planner.md" "$prompt_file" ".init/README.md" ".init/" "$AREAS_REL" "$RUNBOOK_REL" "$DECISIONS_REL" "$ASSUMPTIONS_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL"
      local rc=0
      run_agent_for "planner" "$prompt_file" || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        echo "Error: agent 'planner' failed for submode start (exit code $rc)." >&2
        printf "Agent failure: %s exit=%d submode=%s time=%s\n" "planner" "$rc" "start" "$(date)" >> "$RUN_LOG"
        update_pipeline_state "planning" "agent_failed" "null" "planner" "$(basename "$RUN_DIR")"
        exit "$rc"
      fi
      update_pipeline_state "planning" "planner" "null" "planner" "$(basename "$RUN_DIR")"
      ;;
    area)
      if [[ -z "$AREA" ]]; then
        echo "Error: --area is required for 'plan area'." >&2
        exit 1
      fi
      local area_file="$SCRIPT_DIR/.plan/areas/$AREA.md"
      if [[ ! -f "$area_file" ]]; then
        echo "Error: area file not found: $area_file" >&2
        exit 1
      fi
      append_context_pack "Area: $AREA" "$AREAS_REL" "$area_file" ".init/README.md" "$DECISIONS_REL" "$ASSUMPTIONS_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL"
      local prompt_file="$TEMP_DIR/prompt-area-$AREA.md"
      build_prompt "$SCRIPT_DIR/agents/area-agent.md" "$prompt_file" "$AREAS_REL" "$area_file" ".init/README.md" ".init/" "$DECISIONS_REL" "$ASSUMPTIONS_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL"
      local rc=0
      run_agent_for "area-agent" "$prompt_file" || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        echo "Error: agent 'area-agent' failed for submode area (exit code $rc)." >&2
        printf "Agent failure: %s exit=%d submode=%s time=%s\n" "area-agent" "$rc" "area" "$(date)" >> "$RUN_LOG"
        update_pipeline_state "planning" "agent_failed" "$AREA" "area-agent" "$(basename "$RUN_DIR")"
        exit "$rc"
      fi
      update_pipeline_state "planning" "area" "$AREA" "area-agent" "$(basename "$RUN_DIR")"
      ;;
    review)
      append_context_pack "Planning Review" "$AREAS_REL" ".plan/areas/" "$DECISIONS_REL" "$ASSUMPTIONS_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL" "$RUNBOOK_REL"
      local prompt_file="$TEMP_DIR/prompt-reviewer.md"
      build_prompt "$SCRIPT_DIR/agents/reviewer.md" "$prompt_file" "$AREAS_REL" ".plan/areas/" "$DECISIONS_REL" "$ASSUMPTIONS_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL" "$RUNBOOK_REL"
      local rc=0
      run_agent_for "reviewer" "$prompt_file" || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        echo "Error: agent 'reviewer' failed for submode review (exit code $rc)." >&2
        printf "Agent failure: %s exit=%d submode=%s time=%s\n" "reviewer" "$rc" "review" "$(date)" >> "$RUN_LOG"
        update_pipeline_state "planning" "agent_failed" "null" "reviewer" "$(basename "$RUN_DIR")"
        exit "$rc"
      fi
      update_pipeline_state "planning" "review" "null" "reviewer" "$(basename "$RUN_DIR")"
      ;;
    redteam)
      append_context_pack "Planning Red Team" "$AREAS_REL" ".plan/areas/" "$DECISIONS_REL" "$ASSUMPTIONS_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL" "$RUNBOOK_REL"
      local prompt_file="$TEMP_DIR/prompt-red-team.md"
      build_prompt "$SCRIPT_DIR/agents/red-team.md" "$prompt_file" "$AREAS_REL" ".plan/areas/" "$DECISIONS_REL" "$ASSUMPTIONS_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL" "$RUNBOOK_REL"
      local rc=0
      run_agent_for "red-team" "$prompt_file" || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        echo "Error: agent 'red-team' failed for submode redteam (exit code $rc)." >&2
        printf "Agent failure: %s exit=%d submode=%s time=%s\n" "red-team" "$rc" "redteam" "$(date)" >> "$RUN_LOG"
        update_pipeline_state "planning" "agent_failed" "null" "red-team" "$(basename "$RUN_DIR")"
        exit "$rc"
      fi
      update_pipeline_state "planning" "redteam" "null" "red-team" "$(basename "$RUN_DIR")"
      ;;
    pm)
      validate_planning_exit_gate
      append_context_pack "PM" "$WORK_BREAKDOWN_REL" "$TRACEABILITY_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL" "$RUNBOOK_REL"
      local prompt_file="$TEMP_DIR/prompt-pm.md"
      build_prompt "$SCRIPT_DIR/agents/pm.md" "$prompt_file" "$WORK_BREAKDOWN_REL" "$TRACEABILITY_REL" "$DEPENDENCIES_REL" "$RISK_REGISTER_REL" "$RUNBOOK_REL"
      local rc=0
      run_agent_for "pm" "$prompt_file" || rc=$?
      if [[ "$rc" -ne 0 ]]; then
        echo "Error: agent 'pm' failed for submode pm (exit code $rc)." >&2
        printf "Agent failure: %s exit=%d submode=%s time=%s\n" "pm" "$rc" "pm" "$(date)" >> "$RUN_LOG"
        update_pipeline_state "planning" "agent_failed" "null" "pm" "$(basename "$RUN_DIR")"
        exit "$rc"
      fi
      update_pipeline_state "planning" "pm" "null" "pm" "$(basename "$RUN_DIR")"
      ;;
    *)
      echo "Error: plan requires a subcommand: start | area | review | redteam | pm" >&2
      usage_plan
      exit 1
      ;;
  esac
}

MODE="plan"
SUBMODE="${1:-}"
if [[ -z "$SUBMODE" ]]; then
  usage_plan
  exit 1
fi
if [[ "$SUBMODE" == "help" || "$SUBMODE" == "--help" || "$SUBMODE" == "-h" ]]; then
  usage_plan
  exit 0
fi
shift || true
parse_shared_args "$@"

cd "$SCRIPT_DIR"
run_plan
