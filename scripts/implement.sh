#!/bin/bash
set -euo pipefail

# --- Trap handlers for graceful cleanup on failure or interruption ---
_impl_exit_code=0

_impl_cleanup() {
  _impl_exit_code=$?
  if [[ "$_impl_exit_code" -ne 0 ]]; then
    # Log the failure if RUN_LOG exists
    if [[ -n "${RUN_LOG:-}" && -f "$RUN_LOG" ]]; then
      printf "\n## Crashed\n\nExit code: %s\nTime: %s\n" "$_impl_exit_code" "$(date)" >> "$RUN_LOG" 2>/dev/null || true
    fi

    # Update pipeline state to error/crashed
    if [[ -n "${PIPELINE_FILE:-}" && -d "${STATE_DIR:-}" ]]; then
      update_pipeline_state "implementation" "crashed" "${_impl_story_id:-unknown}" "${_impl_agent:-unknown}" "$(basename "${RUN_DIR:-unknown}")" 2>/dev/null || true
    fi
  fi

  # Clean up temp prompt files
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -f "$TEMP_DIR"/prompt-*.md 2>/dev/null || true
  fi

  # Release pipeline lock
  rm -rf "${LOCK_FILE:-}" 2>/dev/null || true
}

_impl_interrupted() {
  echo "Interrupted by user." >&2
  exit 130
}

# Variables to track current story/agent for the EXIT trap.
# These are updated inside run_implementation so the trap can reference them.
_impl_story_id=""
_impl_agent=""

trap _impl_cleanup EXIT
trap _impl_interrupted INT TERM
# --- End trap handlers ---

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/lib/common.sh"

usage_implement() {
  cat <<'USAGE'
Usage:
  ./scripts/implement.sh [--max-iterations N] [-agent claude|codex|gemini] [--story US-XXX] [--approve-deploy US-XXX|all] [--resume] [--reset] [--runners <file>]
USAGE
}

run_implementation() {
  require_jq
  ensure_dirs
  init_pipeline_state

  # Read resume target BEFORE init_run overwrites pipeline state
  local _resume_story=""
  if [[ "$RESUME" == "true" && -f "$PIPELINE_FILE" ]]; then
    _resume_story=$(jq -r '.currentStory // empty' "$PIPELINE_FILE" 2>/dev/null)
  fi

  init_run
  validate_planning_exit_gate

  if [[ -n "$_resume_story" && "$_resume_story" != "null" ]]; then
    echo "Resuming from story: $_resume_story"
    STORY_ID="$_resume_story"
  fi

  stall_count=0
  last_story_id=""

  local i=0
  while true; do
    i=$((i + 1))
    if [[ "$MAX_ITERATIONS" -gt 0 && "$i" -gt "$MAX_ITERATIONS" ]]; then
      break
    fi

    local story_file
    if [[ -n "$STORY_ID" ]]; then
      story_file="$PRD_DIR/$STORY_ID.json"
      if [[ ! -f "$story_file" ]]; then
        echo "Error: story file not found: $story_file" >&2
        exit 1
      fi
    else
      story_file=$(next_story_file)
    fi

    if [[ -z "$story_file" ]]; then
      if [[ "$(all_complete)" == "true" ]]; then
        echo "All stories complete."
        exit 0
      fi
      echo "No runnable stories found: pending stories have unmet dependencies or are blocked." >&2
      exit 1
    fi

    local story_id
    local stage
    story_id=$(jq -r '.id' "$story_file")
    _impl_story_id="$story_id"
    if [[ "$story_id" != "$last_story_id" ]]; then
      stall_count=0
      last_story_id="$story_id"
    fi
    stage=$(jq -r '.stage // "build"' "$story_file")
    validate_story_schema "$story_file"
    if ! story_dependencies_satisfied "$story_file"; then
      echo "Error: story $story_id has unmet dependencies." >&2
      exit 1
    fi

    if [[ "$stage" == "deploy" ]]; then
      validate_story_deploy_contract "$story_file"
      require_deploy_approval "$story_file" "$story_id"
    fi

    local agent
    case "$stage" in
      build)
        agent="builder"
        ;;
      review|test)
        agent="reviewer-test"
        ;;
      deploy)
        agent="deploy"
        ;;
      complete)
        if [[ -n "$STORY_ID" ]]; then
          echo "Story $story_id already complete."
          exit 0
        fi
        continue
        ;;
      blocked)
        echo "Story $story_id is blocked. Review prd/$story_id.md for details." >&2
        exit 1
        ;;
      *)
        echo "Error: unknown stage '$stage' for $story_file" >&2
        exit 1
        ;;
    esac
    _impl_agent="$agent"

    local tracker_file="$PRD_DIR/$story_id.md"
    local files=("$story_file" "$tracker_file")
    if [[ "$agent" == "builder" || "$agent" == "reviewer-test" || "$agent" == "deploy" ]]; then
      files+=("$RUNBOOK_REL")
    fi
    if [[ "$agent" == "builder" || "$agent" == "reviewer-test" ]]; then
      files+=("$TRACEABILITY_REL")
    fi

    local extra_files
    if ! extra_files=$(jq -r '.context.files[]? // empty' "$story_file" 2>/dev/null); then
      echo "Warning: failed to read context.files from $story_file" >&2
      extra_files=""
    fi
    if [[ -n "$extra_files" ]]; then
      while IFS= read -r f; do
        [[ -n "$f" ]] && files+=("$f")
      done <<< "$extra_files"
    fi

    append_context_pack "${agent} - ${story_id}" "${files[@]}"
    local prompt_file="$TEMP_DIR/prompt-${agent}-${story_id}.md"
    build_prompt "$SCRIPT_DIR/agents/${agent}.md" "$prompt_file" "${files[@]}"

    if [[ "$agent" == "deploy" ]]; then
      local current_attempts
      current_attempts=$(jq -r '.status.deploy.attempts // 0' "$story_file")
      if [[ "$current_attempts" -ge 3 ]]; then
        echo "Error: deployment failed after 3 attempts for $story_id. Setting to blocked." >&2
        local tmp_sf="${story_file}.tmp.$$"
        jq '.stage = "blocked"' "$story_file" > "$tmp_sf" && mv "$tmp_sf" "$story_file"
        exit 1
      fi
      # Increment attempts before running the agent
      local tmp_sf="${story_file}.tmp.$$"
      jq '.status.deploy.attempts += 1' "$story_file" > "$tmp_sf" && mv "$tmp_sf" "$story_file"
    fi

    echo "Running $agent for $story_id (stage: $stage)."
    update_pipeline_state "implementation" "$stage" "$story_id" "$agent" "$(basename "$RUN_DIR")"
    local rc=0
    run_agent_for "$agent" "$prompt_file" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      echo "Error: agent '$agent' failed for story $story_id (exit code $rc)." >&2
      printf "Agent failure: %s exit=%d story=%s time=%s\n" "$agent" "$rc" "$story_id" "$(date)" >> "$RUN_LOG"
      update_pipeline_state "implementation" "agent_failed" "$story_id" "$agent" "$(basename "$RUN_DIR")"
      exit "$rc"
    fi

    local updated_stage
    updated_stage=$(jq -r '.stage // "build"' "$story_file")
    validate_story_stage_transition "$stage" "$updated_stage" "$story_file"

    if [[ "$updated_stage" == "$stage" ]]; then
      stall_count=$((stall_count + 1))
      if [[ "$stall_count" -ge 3 ]]; then
        echo "Error: story $story_id stuck at stage '$stage' for $stall_count consecutive iterations." >&2
        echo "  Agent is not advancing the story. Review agent output and prd/$story_id.json." >&2
        exit 1
      fi
      echo "Warning: story $story_id did not advance from stage '$stage' (attempt $stall_count/3)." >&2
    else
      stall_count=0
    fi

    stage="$updated_stage"

    if [[ "$agent" == "deploy" ]]; then
      local passes
      passes=$(jq -r '.status.deploy.passes // false' "$story_file")
      if [[ "$passes" == "true" ]]; then
        echo "Deployment passed for $story_id."
      fi
    fi

    if [[ "$(all_complete)" == "true" ]]; then
      echo "All stories complete."
      exit 0
    fi

    if [[ -n "$STORY_ID" ]]; then
      echo "Single-story run complete."
      exit 0
    fi
  done

  echo "Reached max iterations ($MAX_ITERATIONS) without completing all stories." >&2
  exit 1
}

MODE="run"
SUBMODE="run"
if [[ "${1:-}" == "help" || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage_implement
  exit 0
fi
parse_shared_args "$@"

cd "$SCRIPT_DIR"
run_implementation
