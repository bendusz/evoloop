#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage:
  ./orchestrator.sh plan [-agent claude|codex|gemini] [--runners <file>] [--areas area1,area2,...] [--reset] [--resume] [--skip-user-checkpoint]
  ./orchestrator.sh run [-agent claude|codex|gemini] [--runners <file>] [--story US-XXX] [--max-iterations N] [--approve-deploy US-XXX|all] [--resume] [--reset]

Granular planning (legacy/manual):
  ./orchestrator.sh plan start [-agent claude|codex|gemini] [--runners <file>] [--reset] [--resume]
  ./orchestrator.sh plan area --area <name> [-agent claude|codex|gemini] [--runners <file>] [--reset] [--resume]
  ./orchestrator.sh plan review [-agent claude|codex|gemini] [--runners <file>] [--reset] [--resume]
  ./orchestrator.sh plan redteam [-agent claude|codex|gemini] [--runners <file>] [--reset] [--resume]
  ./orchestrator.sh plan pm [-agent claude|codex|gemini] [--runners <file>] [--reset] [--resume]

Behavior:
  plan (without subcommand) runs: start -> user checkpoint -> area (all areas from .plan/areas.md) -> review -> redteam
  run runs: pm -> ./scripts/doctor.sh -> implementation loop

Notes:
- Default agent is codex with CODEX_MODEL=gpt-5.3-codex and CODEX_EFFORT=xhigh.
- Default Codex invocations include --skip-git-repo-check.
- .init/ is read-only; planning agents should not edit it.
- Passing -agent/--agent explicitly bypasses runner routing for that invocation.
- --tool is still accepted as a backward-compatible alias of -agent/--agent.
USAGE
}

trim() {
  local val="$1"
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"
  printf "%s" "$val"
}

array_contains() {
  local needle="$1"
  shift || true
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

is_plan_subcommand() {
  case "$1" in
    start|area|review|redteam|pm) return 0 ;;
    *) return 1 ;;
  esac
}

extract_area_names() {
  local areas_file="$SCRIPT_DIR/.plan/areas.md"
  if [[ ! -f "$areas_file" ]]; then
    echo "Error: missing areas map: $areas_file" >&2
    return 1
  fi

  awk -F'|' '
    /^[[:space:]]*\|/ {
      area=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", area)
      lower=tolower(area)
      if (area == "" || lower == "area" || area ~ /^-+$/) {
        next
      }
      print area
    }
  ' "$areas_file"
}

run_planning_user_checkpoint() {
  local questions_file="$SCRIPT_DIR/.plan/questions.md"
  local answers_file="$SCRIPT_DIR/.plan/answers.md"
  local line question answer
  local -a questions=()

  if [[ ! -f "$questions_file" ]]; then
    echo "Error: planning user checkpoint requires $questions_file, but it was not created." >&2
    echo "  Ensure the planner writes 4 to 5 numbered questions to $questions_file." >&2
    exit 1
  fi

  while IFS= read -r line; do
    line="$(trim "$line")"
    if [[ "$line" =~ ^[0-9]+\.[[:space:]]+(.+)$ ]]; then
      question="$(trim "${BASH_REMATCH[1]}")"
      [[ -n "$question" ]] && questions+=("$question")
    fi
  done < "$questions_file"

  if [[ "${#questions[@]}" -lt 4 || "${#questions[@]}" -gt 5 ]]; then
    echo "Error: $questions_file must contain 4 to 5 numbered questions for the user checkpoint." >&2
    echo "  Found ${#questions[@]} question(s)." >&2
    exit 1
  fi

  if [[ ! -t 0 ]]; then
    echo "Error: planning user checkpoint requires an interactive terminal." >&2
    echo "  Re-run interactively, or pass --skip-user-checkpoint to bypass intentionally." >&2
    exit 1
  fi

  echo
  echo "Planning user checkpoint: answer the planner's clarifying questions."
  echo "Questions source: $questions_file"
  printf "# Planner Answers\n\n" > "$answers_file"

  local idx=0
  while [[ "$idx" -lt "${#questions[@]}" ]]; do
    local question_num=$((idx + 1))
    echo "Q$question_num: ${questions[$idx]}"
    while true; do
      read -r -p "A$question_num: " answer
      answer="$(trim "$answer")"
      if [[ -n "$answer" ]]; then
        break
      fi
      echo "Answer cannot be empty."
    done
    printf "%d. %s\nA: %s\n\n" "$question_num" "${questions[$idx]}" "$answer" >> "$answers_file"
    idx=$((idx + 1))
  done

  echo "Saved answers to $answers_file"
}

run_plan_pipeline() {
  local -a shared_args=()
  local -a start_only_args=()
  local -a areas=()
  local areas_override=""
  local require_user_checkpoint="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -agent|--agent|--tool)
        if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
          echo "Error: -agent/--agent requires a value (claude|codex|gemini)." >&2
          exit 1
        fi
        shared_args+=("--agent" "$2")
        shift 2
        ;;
      --runners)
        if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
          echo "Error: --runners requires a file path." >&2
          exit 1
        fi
        shared_args+=("--runners" "$2")
        shift 2
        ;;
      --areas)
        if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
          echo "Error: --areas requires a comma-separated value list." >&2
          exit 1
        fi
        areas_override="$2"
        shift 2
        ;;
      --reset|--resume)
        start_only_args+=("$1")
        shift 1
        ;;
      --skip-user-checkpoint)
        require_user_checkpoint="false"
        shift 1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Error: unknown plan option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  local -a step_cmd=()

  echo "Running planning pipeline: start -> user-checkpoint -> area(all) -> review -> redteam"
  step_cmd=("$SCRIPT_DIR/scripts/plan.sh" "start")
  if [[ "${#shared_args[@]}" -gt 0 ]]; then
    step_cmd+=("${shared_args[@]}")
  fi
  if [[ "${#start_only_args[@]}" -gt 0 ]]; then
    step_cmd+=("${start_only_args[@]}")
  fi
  "${step_cmd[@]}"

  if [[ "$require_user_checkpoint" == "true" ]]; then
    run_planning_user_checkpoint
  fi

  if [[ -n "$areas_override" ]]; then
    local raw_area
    IFS=',' read -r -a areas <<< "$areas_override"
    local -a normalized=()
    for raw_area in "${areas[@]}"; do
      raw_area="$(trim "$raw_area")"
      [[ -z "$raw_area" ]] && continue
      if ! array_contains "$raw_area" "${normalized[@]+"${normalized[@]}"}"; then
        normalized+=("$raw_area")
      fi
    done
    areas=("${normalized[@]}")
  else
    local discovered
    while IFS= read -r discovered; do
      discovered="$(trim "$discovered")"
      [[ -z "$discovered" ]] && continue
      if ! array_contains "$discovered" "${areas[@]+"${areas[@]}"}"; then
        areas+=("$discovered")
      fi
    done < <(extract_area_names)
  fi

  if [[ "${#areas[@]}" -eq 0 ]]; then
    echo "Error: no areas found. Update .plan/areas.md or pass --areas area1,area2." >&2
    exit 1
  fi

  local area
  for area in "${areas[@]}"; do
    echo "Running plan area for: $area"
    step_cmd=("$SCRIPT_DIR/scripts/plan.sh" "area" "--area" "$area")
    if [[ "${#shared_args[@]}" -gt 0 ]]; then
      step_cmd+=("${shared_args[@]}")
    fi
    "${step_cmd[@]}"
  done

  step_cmd=("$SCRIPT_DIR/scripts/plan.sh" "review")
  if [[ "${#shared_args[@]}" -gt 0 ]]; then
    step_cmd+=("${shared_args[@]}")
  fi
  "${step_cmd[@]}"

  step_cmd=("$SCRIPT_DIR/scripts/plan.sh" "redteam")
  if [[ "${#shared_args[@]}" -gt 0 ]]; then
    step_cmd+=("${shared_args[@]}")
  fi
  "${step_cmd[@]}"
}

run_release_pipeline() {
  local -a shared_args=()
  local -a implement_args=()
  local -a step_cmd=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -agent|--agent|--tool)
        if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
          echo "Error: -agent/--agent requires a value (claude|codex|gemini)." >&2
          exit 1
        fi
        shared_args+=("--agent" "$2")
        shift 2
        ;;
      --runners)
        if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
          echo "Error: --runners requires a file path." >&2
          exit 1
        fi
        shared_args+=("--runners" "$2")
        shift 2
        ;;
      --max-iterations|--story|--approve-deploy)
        if [[ -z "${2:-}" || "${2:-}" == -* ]]; then
          echo "Error: $1 requires a value." >&2
          exit 1
        fi
        implement_args+=("$1" "$2")
        shift 2
        ;;
      --resume|--reset)
        implement_args+=("$1")
        shift 1
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Error: unknown run option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  echo "Running release pipeline: pm -> doctor -> implementation"
  step_cmd=("$SCRIPT_DIR/scripts/plan.sh" "pm")
  if [[ "${#shared_args[@]}" -gt 0 ]]; then
    step_cmd+=("${shared_args[@]}")
  fi
  "${step_cmd[@]}"
  "$SCRIPT_DIR/scripts/doctor.sh"

  step_cmd=("$SCRIPT_DIR/scripts/implement.sh")
  if [[ "${#shared_args[@]}" -gt 0 ]]; then
    step_cmd+=("${shared_args[@]}")
  fi
  if [[ "${#implement_args[@]}" -gt 0 ]]; then
    step_cmd+=("${implement_args[@]}")
  fi
  exec "${step_cmd[@]}"
}

MODE="${1:-}"

case "$MODE" in
  plan)
    shift || true
    if [[ $# -gt 0 ]] && is_plan_subcommand "$1"; then
      exec "$SCRIPT_DIR/scripts/plan.sh" "$@"
    fi
    run_plan_pipeline "$@"
    ;;
  run)
    shift || true
    run_release_pipeline "$@"
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
