#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/lib/common.sh"

CHECK_IMPLEMENTATION_GATE=true
CHECK_RUNNER_TOOLS=true
VERBOSE=false

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

usage_doctor() {
  cat <<'USAGE'
Usage:
  ./scripts/doctor.sh [--planning-only] [--skip-runner-tools] [--verbose]

Options:
  --planning-only     Skip implementation readiness gate checks.
  --skip-runner-tools Skip checking installed CLIs from agents/runners.json.
  --verbose           Print detailed command output for failed checks.
  -h, --help          Show help.
USAGE
}

print_pass() {
  local msg="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "[PASS] %s\n" "$msg"
}

print_fail() {
  local msg="$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "[FAIL] %s\n" "$msg"
}

print_warn() {
  local msg="$1"
  WARN_COUNT=$((WARN_COUNT + 1))
  printf "[WARN] %s\n" "$msg"
}

run_check() {
  local name="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    print_pass "$name"
  else
    print_fail "$name"
    if [[ "$VERBOSE" == "true" && -n "$output" ]]; then
      printf "       %s\n" "$output"
    fi
  fi
}

check_paths_exist() {
  local -a required_paths=(
    "$SCRIPT_DIR/.init"
    "$SCRIPT_DIR/.plan"
    "$SCRIPT_DIR/.plan/areas"
    "$SCRIPT_DIR/agents"
    "$SCRIPT_DIR/prd"
    "$SCRIPT_DIR/scripts"
  )
  local path
  for path in "${required_paths[@]}"; do
    if [[ ! -e "$path" ]]; then
      printf "Missing required path: %s\n" "$path"
      return 1
    fi
  done
}

check_entrypoint_executables() {
  local -a required_exec=(
    "$SCRIPT_DIR/orchestrator.sh"
    "$SCRIPT_DIR/scripts/bootstrap-plan.sh"
    "$SCRIPT_DIR/scripts/plan.sh"
    "$SCRIPT_DIR/scripts/implement.sh"
    "$SCRIPT_DIR/scripts/doctor.sh"
  )
  local file
  for file in "${required_exec[@]}"; do
    if [[ ! -x "$file" ]]; then
      printf "Not executable: %s\n" "$file"
      return 1
    fi
  done
}

check_shell_syntax() {
  local -a shell_files=(
    "$SCRIPT_DIR/orchestrator.sh"
    "$SCRIPT_DIR/scripts/bootstrap-plan.sh"
    "$SCRIPT_DIR/scripts/plan.sh"
    "$SCRIPT_DIR/scripts/implement.sh"
    "$SCRIPT_DIR/scripts/doctor.sh"
    "$SCRIPT_DIR/scripts/lib/common.sh"
  )
  local file
  for file in "${shell_files[@]}"; do
    bash -n "$file"
  done
}

check_json_files() {
  local failed=0
  if [[ -f "$SCRIPT_DIR/agents/runners.json" ]]; then
    if ! jq empty "$SCRIPT_DIR/agents/runners.json" 2>&1; then
      failed=1
    fi
  fi
  if [[ -f "$SCRIPT_DIR/agents/runners.example.json" ]]; then
    if ! jq empty "$SCRIPT_DIR/agents/runners.example.json" 2>&1; then
      failed=1
    fi
  fi
  shopt -s nullglob
  local story
  for story in "$SCRIPT_DIR"/prd/*.json; do
    if ! jq empty "$story" 2>&1; then
      failed=1
    fi
  done
  return $failed
}

check_core_tools() {
  command -v jq >/dev/null 2>&1
  command -v rg >/dev/null 2>&1
}

check_runner_tools() {
  require_jq
  if [[ ! -f "$RUNNERS_FILE" ]]; then
    printf "Missing runners file: %s\n" "$RUNNERS_FILE"
    return 1
  fi

  local -a binaries=()
  local bin
  while IFS= read -r bin; do
    [[ -n "$bin" ]] && binaries+=("$bin")
  done < <(
    jq -r '
      .[]?.cmd? // empty
      | if type=="array" and length > 0 then .[0] else empty end
    ' "$RUNNERS_FILE" | sort -u
  )

  if [[ "${#binaries[@]}" -eq 0 ]]; then
    printf "No runner commands found in %s\n" "$RUNNERS_FILE"
    return 1
  fi

  for bin in "${binaries[@]}"; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      printf "Missing runner tool: %s\n" "$bin"
      return 1
    fi
  done
}

check_story_schema_all() {
  shopt -s nullglob
  local -a stories=("$SCRIPT_DIR"/prd/*.json)
  if [[ "${#stories[@]}" -eq 0 ]]; then
    print_warn "No story JSON files found under prd/"
    return 0
  fi

  local story
  for story in "${stories[@]}"; do
    if ! (validate_story_schema "$story" >/dev/null 2>&1); then
      printf "Invalid story schema: %s\n" "$story"
      return 1
    fi
  done
}

check_deploy_contract_for_deploy_stage() {
  shopt -s nullglob
  local story
  local stage
  for story in "$SCRIPT_DIR"/prd/*.json; do
    stage=$(jq -r '.stage // "build"' "$story")
    if [[ "$stage" == "deploy" ]]; then
      if ! (validate_story_deploy_contract "$story" >/dev/null 2>&1); then
        printf "Deploy contract incomplete: %s\n" "$story"
        return 1
      fi
    fi
  done
}

array_contains() {
  local needle="$1"
  shift || true
  local candidate
  for candidate in "$@"; do
    if [[ "$candidate" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

_dep_cycle_dfs() {
  local story_id="$1"
  local dep

  if array_contains "$story_id" "${_dep_cycle_stack[@]-}"; then
    _dep_cycle_path=("${_dep_cycle_stack[@]-}" "$story_id")
    return 1
  fi

  if array_contains "$story_id" "${_dep_cycle_visited[@]-}"; then
    return 0
  fi

  _dep_cycle_stack+=("$story_id")

  while IFS= read -r dep; do
    [[ -z "$dep" ]] && continue

    if [[ ! -f "$SCRIPT_DIR/prd/$dep.json" ]]; then
      _dep_cycle_error="Broken dependency: $story_id depends on $dep (file not found)"
      return 1
    fi

    if ! _dep_cycle_dfs "$dep"; then
      return 1
    fi
  done < <(jq -r '.dependencies[]? // empty' "$SCRIPT_DIR/prd/$story_id.json")

  _dep_cycle_stack=("${_dep_cycle_stack[@]:0:${#_dep_cycle_stack[@]}-1}")
  _dep_cycle_visited+=("$story_id")
  return 0
}

check_no_dependency_cycles() {
  require_jq
  shopt -s nullglob
  local -a stories=("$SCRIPT_DIR"/prd/*.json)
  if [[ "${#stories[@]}" -eq 0 ]]; then
    return 0
  fi

  local story story_id cycle_path=""
  for story in "${stories[@]}"; do
    story_id=$(jq -r '.id' "$story")
    if [[ -z "$story_id" || "$story_id" == "null" ]]; then
      printf "Invalid story ID in %s\n" "$story"
      return 1
    fi
  done

  _dep_cycle_stack=()
  _dep_cycle_visited=()
  _dep_cycle_path=()
  _dep_cycle_error=""

  for story in "${stories[@]}"; do
    story_id=$(jq -r '.id' "$story")
    if ! _dep_cycle_dfs "$story_id"; then
      if [[ -n "$_dep_cycle_error" ]]; then
        printf "%s\n" "$_dep_cycle_error"
      else
        cycle_path=$(printf '%s -> ' "${_dep_cycle_path[@]-}")
        cycle_path="${cycle_path% -> }"
        printf "Circular dependency detected: %s\n" "$cycle_path"
      fi
      return 1
    fi
  done
}

check_planning_gate() {
  validate_planning_exit_gate 2>&1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --planning-only)
      CHECK_IMPLEMENTATION_GATE=false
      shift
      ;;
    --skip-runner-tools)
      CHECK_RUNNER_TOOLS=false
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      usage_doctor
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage_doctor
      exit 1
      ;;
  esac
done

cd "$SCRIPT_DIR"
parse_shared_args

echo "Running workflow preflight checks..."
run_check "Required directory scaffold exists" check_paths_exist
run_check "Core scripts are executable" check_entrypoint_executables
run_check "Shell scripts parse cleanly" check_shell_syntax
run_check "Core JSON files are valid" check_json_files
run_check "Core dependencies (jq, rg) are installed" check_core_tools
run_check "Story schema contract passes" check_story_schema_all
run_check "Deploy-stage stories have deploy safety contract" check_deploy_contract_for_deploy_stage
run_check "No circular or broken story dependencies" check_no_dependency_cycles

if [[ "$CHECK_RUNNER_TOOLS" == "true" ]]; then
  run_check "Runner tools from agents/runners.json are installed" check_runner_tools
else
  print_warn "Skipped runner tool checks (--skip-runner-tools)"
fi

if [[ "$CHECK_IMPLEMENTATION_GATE" == "true" ]]; then
  run_check "Planning exit gate passes (implementation ready)" check_planning_gate
else
  print_warn "Skipped implementation readiness gate (--planning-only)"
fi

echo
printf "Summary: %d passed, %d failed, %d warnings\n" "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
