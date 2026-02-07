#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$COMMON_DIR/../.." && pwd)"

PRD_DIR="$SCRIPT_DIR/prd"
LOG_ROOT="$SCRIPT_DIR/.log"
TEMP_DIR="$SCRIPT_DIR/.temp"
STATE_DIR="$SCRIPT_DIR/.state"
PIPELINE_FILE="$STATE_DIR/pipeline.json"
LOCK_FILE="$STATE_DIR/.pipeline.lock"
RUNNERS_REL="agents/runners.json"
RUNBOOK_REL=".plan/runbook.md"
RUN_LOG_TEMPLATE="$SCRIPT_DIR/.plan/run-log.template.md"
AREAS_REL=".plan/areas.md"
WORK_BREAKDOWN_REL=".plan/work-breakdown.md"
TRACEABILITY_REL=".plan/traceability.md"
DECISIONS_REL=".plan/decisions.md"
ASSUMPTIONS_REL=".plan/assumptions.md"
DEPENDENCIES_REL=".plan/dependencies.md"
RISK_REGISTER_REL=".plan/risk-register.md"
RUNBOOK="$SCRIPT_DIR/$RUNBOOK_REL"

init_common_defaults() {
  TOOL="${TOOL:-codex}"
  TOOL_EXPLICIT="${TOOL_EXPLICIT:-false}"
  MAX_ITERATIONS="${MAX_ITERATIONS:-0}"
  AREA="${AREA:-}"
  STORY_ID="${STORY_ID:-}"
  APPROVED_DEPLOYS="${APPROVED_DEPLOYS:-}"
  RESUME="${RESUME:-false}"
  RESET="${RESET:-false}"
  RUNNERS_FILE="${RUNNERS_FILE:-$SCRIPT_DIR/$RUNNERS_REL}"
}

parse_shared_args() {
  init_common_defaults
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -agent|--agent|--tool)
        if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
          echo "Error: -agent/--agent requires a value (claude|codex|gemini)." >&2
          exit 1
        fi
        TOOL="$2"
        TOOL_EXPLICIT="true"
        shift 2
        ;;
      --max-iterations)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          echo "Error: --max-iterations requires a value." >&2
          exit 1
        fi
        if [[ ! "$2" =~ ^[0-9]+$ ]]; then
          echo "Error: --max-iterations must be a non-negative integer." >&2
          exit 1
        fi
        MAX_ITERATIONS="$2"
        shift 2
        ;;
      --area)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          echo "Error: --area requires a value." >&2
          exit 1
        fi
        AREA="$2"
        shift 2
        ;;
      --story)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          echo "Error: --story requires a story ID (e.g., US-001)." >&2
          exit 1
        fi
        STORY_ID="$2"
        shift 2
        ;;
      --approve-deploy)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          echo "Error: --approve-deploy requires a value (US-XXX or all)." >&2
          exit 1
        fi
        if [[ -z "$APPROVED_DEPLOYS" ]]; then
          APPROVED_DEPLOYS="$2"
        else
          APPROVED_DEPLOYS="$APPROVED_DEPLOYS,$2"
        fi
        shift 2
        ;;
      --resume)
        RESUME=true
        shift 1
        ;;
      --reset)
        RESET=true
        shift 1
        ;;
      --runners)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          echo "Error: --runners requires a file path." >&2
          exit 1
        fi
        if [[ -L "$2" ]]; then
          echo "Error: --runners must not be a symlink: $2" >&2
          exit 1
        fi
        if [[ ! -f "$2" ]]; then
          echo "Error: runners file not found: $2" >&2
          exit 1
        fi
        RUNNERS_FILE="$2"
        shift 2
        ;;
      *)
        echo "Unknown argument: $1" >&2
        exit 1
        ;;
    esac
  done
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed." >&2
    exit 1
  fi
}

ensure_dirs() {
  mkdir -p "$LOG_ROOT" "$TEMP_DIR" "$STATE_DIR" "$SCRIPT_DIR/.plan/areas"
}

acquire_pipeline_lock() {
  if ! mkdir "$LOCK_FILE" 2>/dev/null; then
    echo "Error: another orchestrator instance is running (lock: $LOCK_FILE)." >&2
    echo "  If this is stale, remove $LOCK_FILE manually." >&2
    exit 1
  fi
}

release_pipeline_lock() {
  rm -rf "${LOCK_FILE:-}" 2>/dev/null || true
}

validate_planning_exit_gate() {
  if ! command -v rg >/dev/null 2>&1; then
    echo "Error: ripgrep (rg) is required for planning gate validation but not installed." >&2
    exit 1
  fi

  local -a required_files=(
    "$AREAS_REL"
    "$WORK_BREAKDOWN_REL"
    "$TRACEABILITY_REL"
    "$RUNBOOK_REL"
    "$DECISIONS_REL"
    "$ASSUMPTIONS_REL"
    "$DEPENDENCIES_REL"
    "$RISK_REGISTER_REL"
  )

  local missing=0
  for rel in "${required_files[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$rel" ]]; then
      echo "Error: missing planning artifact: $rel" >&2
      missing=1
    fi
  done
  if [[ "$missing" -ne 0 ]]; then
    echo "Planning exit gate failed: required planning artifacts are missing." >&2
    exit 1
  fi

  local -a todo_checked_files=("$RUNBOOK" "$SCRIPT_DIR/$DEPENDENCIES_REL" "$SCRIPT_DIR/$WORK_BREAKDOWN_REL")
  local todo_file
  for todo_file in "${todo_checked_files[@]}"; do
      if rg -n -i '\b(TODO|TBD|FIXME)\b' "$todo_file" >/dev/null 2>&1; then
          echo "Planning exit gate failed: $(basename "$todo_file") still contains TODO/TBD/FIXME placeholders." >&2
          exit 1
      fi
  done

  if ! rg -q 'REQ-[0-9]{3}' "$SCRIPT_DIR/$WORK_BREAKDOWN_REL"; then
    echo "Planning exit gate failed: $WORK_BREAKDOWN_REL must contain requirement IDs like REQ-001." >&2
    exit 1
  fi

  if ! rg -q 'REQ-[0-9]{3}' "$SCRIPT_DIR/$TRACEABILITY_REL"; then
    echo "Planning exit gate failed: $TRACEABILITY_REL must map requirement IDs to tests/stories." >&2
    exit 1
  fi

  if ! rg -q -i 'critical path' "$SCRIPT_DIR/$DEPENDENCIES_REL"; then
    echo "Planning exit gate failed: $DEPENDENCIES_REL must document the critical path." >&2
    exit 1
  fi

  if rg -n -i '\|\s*(draft|probing|in_review)\s*\|' "$SCRIPT_DIR/$AREAS_REL" >/dev/null 2>&1; then
    echo "Planning exit gate failed: one or more areas are still draft/probing/in_review." >&2
    exit 1
  fi
}

validate_story_schema() {
  local story_file="$1"
  if [[ ! -f "$story_file" ]]; then
    echo "Error: story file does not exist: $story_file" >&2
    exit 1
  fi
  if ! jq empty "$story_file" 2>/dev/null; then
    echo "Error: $story_file is not valid JSON. Run: jq . '$story_file' to see parse errors." >&2
    exit 1
  fi
  local validation_output
  if ! validation_output=$(jq -e '
    (.riskTier | type == "string" and test("^(low|medium|high)$")) and
    (.sizing | type == "string" and test("^(small|medium|large)$")) and
    (.autonomy | type == "string" and test("^(auto_deploy|gated_deploy)$")) and
    (.requirements | type == "array" and all(test("^REQ-[0-9]{3}$"))) and
    (.deploySafety | type == "object") and
    (.deploySafety.strategy | type == "string") and
    (.deploySafety.healthChecks | type == "array") and
    (.deploySafety.rollbackTrigger | type == "string") and
    (.deploySafety.rollbackCommand | type == "string") and
    (.deploySafety.verification | type == "array") and
    (.status.validation | type == "object")
  ' "$story_file" 2>&1); then
    echo "Error: story schema validation failed for $story_file" >&2
    if [[ -n "$validation_output" ]]; then
      echo "  Details: $validation_output" >&2
    fi
    exit 1
  fi
}

validate_story_deploy_contract() {
  local story_file="$1"
  if [[ ! -f "$story_file" ]]; then
    echo "Error: story file does not exist: $story_file" >&2
    exit 1
  fi
  if ! jq empty "$story_file" 2>/dev/null; then
    echo "Error: $story_file is not valid JSON." >&2
    exit 1
  fi
  local validation_output
  if ! validation_output=$(jq -e '
    (.deploySafety.strategy | type == "string" and length > 0) and
    (.deploySafety.healthChecks | type == "array" and length > 0) and
    (.deploySafety.rollbackTrigger | type == "string" and length > 0) and
    (.deploySafety.rollbackCommand | type == "string" and length > 0) and
    (.deploySafety.verification | type == "array" and length > 0)
  ' "$story_file" 2>&1); then
    echo "Error: deploy safety contract incomplete for $story_file." >&2
    if [[ -n "$validation_output" ]]; then
      echo "  Details: $validation_output" >&2
    fi
    exit 1
  fi

  # Check for placeholder text in deploy safety string fields
  local placeholder_check
  placeholder_check=$(jq -r '
      [.deploySafety.strategy, .deploySafety.rollbackTrigger, .deploySafety.rollbackCommand]
      | map(select(test("(?i)^\\s*(TODO|TBD|FIXME|placeholder)\\s*$")))
      | length
  ' "$story_file")
  if [[ "$placeholder_check" -gt 0 ]]; then
      echo "Error: deploy safety contract contains placeholder text (TODO/TBD/FIXME) in $story_file." >&2
      exit 1
  fi
}

init_pipeline_state() {
  if [[ "$RESET" == "true" && "$RESUME" == "true" ]]; then
    echo "Error: --reset and --resume cannot be used together." >&2
    exit 1
  fi

  if [[ "$RESET" == "true" ]]; then
    rm -rf "$STATE_DIR"/* "$LOG_ROOT"/* "$TEMP_DIR"/* 2>/dev/null || true
    mkdir -p "$STATE_DIR" "$LOG_ROOT" "$TEMP_DIR"
    if [[ -f "$PIPELINE_FILE" ]]; then
      echo "Warning: --reset failed to clear $PIPELINE_FILE. Check file permissions." >&2
    fi
  fi

  if [[ ! -f "$PIPELINE_FILE" ]]; then
    local tmp_file="${PIPELINE_FILE}.tmp.$$"
    jq -n '{
      phase: "init",
      stage: "not_started",
      currentStory: null,
      lastAgent: null,
      lastRunId: null,
      updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }' > "$tmp_file" && mv "$tmp_file" "$PIPELINE_FILE"
  fi
}

update_pipeline_state() {
  local phase="$1"
  local stage="$2"
  local current_story="${3:-null}"
  local last_agent="${4:-null}"
  local last_run_id="${5:-null}"
  local tmp_file="${PIPELINE_FILE}.tmp.$$"

  # Strip wrapping quotes if callers passed "\"value\"" style
  current_story="${current_story//\"/}"
  [[ -z "$current_story" ]] && current_story="null"

  jq -n \
    --arg phase "$phase" \
    --arg stage "$stage" \
    --arg story "$current_story" \
    --arg agent "$last_agent" \
    --arg run_id "$last_run_id" \
    '{
      phase: $phase,
      stage: $stage,
      currentStory: (if $story == "null" then null else $story end),
      lastAgent: (if $agent == "null" then null else $agent end),
      lastRunId: (if $run_id == "null" then null else $run_id end),
      updatedAt: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
    }' > "$tmp_file" && mv "$tmp_file" "$PIPELINE_FILE"
}

init_run() {
  # Clean stale prompt files from previous runs
  rm -f "$TEMP_DIR"/prompt-*.md 2>/dev/null || true

  acquire_pipeline_lock

  local ts
  ts=$(date +"%Y%m%d-%H%M%S")
  RUN_DIR="$LOG_ROOT/run-$ts"
  mkdir -p "$RUN_DIR" "$TEMP_DIR"

  CONTEXT_PACK="$RUN_DIR/context-pack.md"
  cat <<EOF_CTX > "$CONTEXT_PACK"
# Context Pack

Run: $ts
EOF_CTX

  RUN_LOG="$RUN_DIR/run.md"
  if [[ -f "$RUN_LOG_TEMPLATE" ]]; then
    cp "$RUN_LOG_TEMPLATE" "$RUN_LOG"
    printf "\nStart: %s\n" "$(date)" >> "$RUN_LOG"
  else
    printf "# Run Log\n\nStart: %s\n" "$(date)" > "$RUN_LOG"
  fi
  printf "Resume: %s\n" "$RESUME" >> "$RUN_LOG"

  update_pipeline_state "${MODE:-unknown}" "${SUBMODE:-run}" "null" "orchestrator" "$ts"
}

append_context_pack() {
  local header="$1"
  shift
  {
    printf "\n## %s\n\n" "$header"
    printf "Files:\n"
    for f in "$@"; do
      printf "- %s\n" "$f"
    done
  } >> "$CONTEXT_PACK"
}

build_prompt() {
  local agent_file="$1"
  local prompt_file="$2"
  shift 2
  local files=("$@")

  if [[ ! -f "$agent_file" ]]; then
    echo "Error: agent prompt file not found: $agent_file" >&2
    echo "  Ensure the file exists in the agents/ directory." >&2
    exit 1
  fi

  cat "$agent_file" > "$prompt_file"
  printf "\n" >> "$prompt_file"
  printf "Read only these files unless absolutely required:\n" >> "$prompt_file"
  for f in "${files[@]}"; do
    printf "- %s\n" "$f" >> "$prompt_file"
  done
  printf "\nContext pack: %s\n" "$CONTEXT_PACK" >> "$prompt_file"

  # Include handoff notes from previous agents if available
  if [[ -n "${RUN_DIR:-}" ]]; then
    local handoff_notes="$RUN_DIR/handoff-notes.md"
    if [[ -f "$handoff_notes" ]]; then
      printf "\n## Handoff Notes from Previous Agents\n\n" >> "$prompt_file"
      cat "$handoff_notes" >> "$prompt_file"
    fi
    printf "\nIf you discover important context for the next agent, append it to: %s\n" "$handoff_notes" >> "$prompt_file"
  fi
}

run_agent() {
  local prompt_file="$1"
  case "$TOOL" in
    claude)
      claude --model "${CLAUDE_MODEL:-opus}" --dangerously-skip-permissions --print < "$prompt_file"
      ;;
    codex)
      codex exec --full-auto --model "${CODEX_MODEL:-gpt-5.3-codex}" -c "model_reasoning_effort=\"${CODEX_EFFORT:-extrahigh}\"" < "$prompt_file"
      ;;
    gemini)
      local prompt_size
      prompt_size=$(wc -c < "$prompt_file")
      if [[ "$prompt_size" -gt 200000 ]]; then
          echo "Warning: prompt file is $(( prompt_size / 1024 ))KB. Gemini CLI may fail with ARG_MAX for prompts over ~200KB." >&2
      fi
      gemini -p "$(cat "$prompt_file")" --model "${GEMINI_MODEL:-gemini-2.0-flash}"
      ;;
    *)
      echo "Error: Unsupported tool '$TOOL'." >&2
      exit 1
      ;;
  esac
}

run_agent_for() {
  local agent_name="$1"
  local prompt_file="$2"

  if [[ "${TOOL_EXPLICIT:-false}" == "true" ]]; then
    printf "Runner: %s -> tool=%s (explicit)\n" "$agent_name" "$TOOL" >> "$RUN_LOG"
    run_agent "$prompt_file"
    return
  fi

  if [[ -f "$RUNNERS_FILE" ]]; then
    require_jq

    # Fail fast if runners.json is not valid JSON
    if ! jq empty "$RUNNERS_FILE" 2>/dev/null; then
      echo "Error: $RUNNERS_FILE is not valid JSON." >&2
      exit 1
    fi

    local runner_label="default"

    if jq -e --arg a "$agent_name" '.[$a].cmd? and (.[$a].cmd|type=="array") and (.[$a].cmd|length>0)' "$RUNNERS_FILE" >/dev/null 2>&1; then
      runner_label="$agent_name"
    elif ! jq -e '.default.cmd? and (.default.cmd|type=="array") and (.default.cmd|length>0)' "$RUNNERS_FILE" >/dev/null 2>&1; then
      echo "Warning: no runner config for agent '$agent_name' and no valid default in $RUNNERS_FILE. Falling back to -agent=$TOOL." >&2
      runner_label=""
    fi

    if [[ -n "$runner_label" ]]; then
      local -a cmd=()
      local cmd_part
      while IFS= read -r cmd_part; do
        cmd+=("$cmd_part")
      done < <(jq -r --arg a "$runner_label" '.[$a].cmd[]' "$RUNNERS_FILE")
      printf "Runner: %s -> %s\n" "$agent_name" "${cmd[*]}" >> "$RUN_LOG"
      local uses_prompt_arg="false"
      for part in "${cmd[@]}"; do
        if [[ "$part" == "{{PROMPT}}" ]]; then
          uses_prompt_arg="true"
          break
        fi
      done

      if [[ "$uses_prompt_arg" == "true" ]]; then
        local prompt_text
        prompt_text="$(cat "$prompt_file")"
        for idx in "${!cmd[@]}"; do
          if [[ "${cmd[$idx]}" == "{{PROMPT}}" ]]; then
            cmd[$idx]="$prompt_text"
          fi
        done
        "${cmd[@]}"
      else
        "${cmd[@]}" < "$prompt_file"
      fi
      return
    fi
  fi

  printf "Runner: %s -> tool=%s (builtin)\n" "$agent_name" "$TOOL" >> "$RUN_LOG"
  run_agent "$prompt_file"
}

validate_story_stage_transition() {
  local from_stage="$1"
  local to_stage="$2"
  local story_file="$3"

  case "$from_stage" in
    build)
      if [[ "$to_stage" != "build" && "$to_stage" != "review" ]]; then
        echo "Error: invalid stage transition for $story_file: build -> $to_stage" >&2
        exit 1
      fi
      ;;
    review|test)
      if [[ "$to_stage" != "build" && "$to_stage" != "deploy" ]]; then
        echo "Error: invalid stage transition for $story_file: $from_stage -> $to_stage" >&2
        exit 1
      fi
      ;;
    deploy)
      if [[ "$to_stage" != "build" && "$to_stage" != "complete" && "$to_stage" != "blocked" ]]; then
        echo "Error: invalid stage transition for $story_file: deploy -> $to_stage" >&2
        exit 1
      fi
      ;;
    *)
      echo "Error: unexpected from_stage '$from_stage' for $story_file" >&2
      exit 1
      ;;
  esac
}

# Note: Only checks direct dependencies. Transitive checking is not needed because
# a story cannot reach "complete" stage without its own dependencies being satisfied first.
# Circular dependencies are caught by doctor.sh check_no_dependency_cycles.
story_dependencies_satisfied() {
  local story_file="$1"
  local deps_output
  if ! deps_output=$(jq -r '.dependencies[]? // empty' "$story_file" 2>/dev/null); then
    echo "Error: failed to read dependencies from $story_file" >&2
    return 1
  fi

  local dependency dep_file dep_stage
  while IFS= read -r dependency; do
    [[ -z "$dependency" ]] && continue
    dep_file="$PRD_DIR/$dependency.json"
    if [[ ! -f "$dep_file" ]]; then
      return 1
    fi
    if ! dep_stage=$(jq -r '.stage // "build"' "$dep_file" 2>/dev/null); then
      echo "Error: failed to read stage from $dep_file" >&2
      return 1
    fi
    if [[ "$dep_stage" != "complete" ]]; then
      return 1
    fi
  done <<< "$deps_output"
}

deploy_approval_granted() {
  local story_id="$1"
  local approved_id

  [[ -z "$APPROVED_DEPLOYS" ]] && return 1

  IFS=',' read -r -a approved_ids <<< "$APPROVED_DEPLOYS"
  for approved_id in "${approved_ids[@]}"; do
    if [[ "$approved_id" == "all" || "$approved_id" == "$story_id" ]]; then
      return 0
    fi
  done

  return 1
}

require_deploy_approval() {
  local story_file="$1"
  local story_id="$2"
  local autonomy

  autonomy=$(jq -r '.autonomy // "gated_deploy"' "$story_file")
  if [[ "$autonomy" != "gated_deploy" ]]; then
    return
  fi

  if deploy_approval_granted "$story_id"; then
    return
  fi

  echo "Error: story $story_id requires explicit deploy approval." >&2
  echo "Re-run with --approve-deploy $story_id (or --approve-deploy all)." >&2
  exit 1
}

next_story_file() {
  local best_file=""
  local best_priority=999999
  local nullglob_was_set=false
  shopt -q nullglob && nullglob_was_set=true
  shopt -s nullglob
  for f in "$PRD_DIR"/*.json; do
    local stage priority
    if ! jq empty "$f" 2>/dev/null; then
      echo "Warning: skipping corrupt JSON file: $f" >&2
      continue
    fi
    stage=$(jq -r '.stage // "build"' "$f")
    if [[ "$stage" == "complete" || "$stage" == "blocked" ]]; then
      continue
    fi
    if ! story_dependencies_satisfied "$f"; then
      continue
    fi
    priority=$(jq -r '.priority // 999999' "$f")
    if (( priority < best_priority )); then
      best_priority=$priority
      best_file="$f"
    fi
  done
  "$nullglob_was_set" || shopt -u nullglob
  echo "$best_file"
}

all_complete() {
  local nullglob_was_set=false
  shopt -q nullglob && nullglob_was_set=true
  shopt -s nullglob
  local -a stories=("$PRD_DIR"/*.json)
  if [[ "${#stories[@]}" -eq 0 ]]; then
    "$nullglob_was_set" || shopt -u nullglob
    echo "false"
    return
  fi
  for f in "${stories[@]}"; do
    local stage
    if ! jq empty "$f" 2>/dev/null; then
      echo "Warning: skipping corrupt JSON file: $f" >&2
      echo "false"
      "$nullglob_was_set" || shopt -u nullglob
      return
    fi
    stage=$(jq -r '.stage // "build"' "$f")
    if [[ "$stage" != "complete" ]]; then
      echo "false"
      "$nullglob_was_set" || shopt -u nullglob
      return
    fi
  done
  "$nullglob_was_set" || shopt -u nullglob
  echo "true"
}
