# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Ralphio is a multi-agent orchestration framework for software delivery. It uses AI agents (Claude, Codex, Gemini) to plan, build, review, test, and deploy software through a two-phase pipeline: exhaustive planning, then story-by-story implementation. All orchestration is pure Bash + jq.

## Commands

```bash
# Bootstrap scaffold (creates .plan/, .init/, templates, etc.)
./scripts/bootstrap-plan.sh

# Preflight checks (run before any long operation)
./scripts/doctor.sh                        # Full check
./scripts/doctor.sh --planning-only        # Skip implementation gate
./scripts/doctor.sh --verbose              # Show failure details

# Planning (run subphases in order)
./orchestrator.sh plan start --tool claude
./orchestrator.sh plan area --area <name> --tool claude
./orchestrator.sh plan review --tool claude
./orchestrator.sh plan redteam --tool claude
./orchestrator.sh plan pm --tool claude

# Implementation
./orchestrator.sh run --tool claude
./orchestrator.sh run --tool claude --story US-001       # Single story
./orchestrator.sh run --tool claude --approve-deploy all # With deploy approval
./orchestrator.sh run --resume                           # Resume interrupted run
./orchestrator.sh run --reset --tool claude              # Clear state and restart

# Shell syntax validation (quick sanity check)
bash -n scripts/lib/common.sh && bash -n scripts/implement.sh && bash -n scripts/plan.sh

# JSON validation
jq empty agents/runners.json && jq empty prd/US-001.json
```

## Architecture

**Entrypoints**: `orchestrator.sh` is a thin dispatcher that `exec`s into `scripts/plan.sh` (planning) or `scripts/implement.sh` (implementation). All shared logic lives in `scripts/lib/common.sh` (~630 lines), which both phase scripts source.

**Two-phase pipeline**:
1. **Planning** (`plan.sh`): Runs 5 subphases sequentially — `start` (coordinator), `area` (per-area deep dive), `review` (cross-area), `redteam` (adversarial), `pm` (story generation). Each subphase builds a prompt from an agent file in `agents/` plus scoped context files, then invokes the configured AI CLI.
2. **Implementation** (`implement.sh`): Loops through stories in priority order. Each story has a `stage` field that determines which agent runs: `build` → builder, `review`/`test` → reviewer-test, `deploy` → deploy. Agents read the story JSON + tracker + runbook + traceability, then advance or revert the stage.

**Agent routing**: `run_agent_for()` in `common.sh` checks `agents/runners.json` for a per-agent CLI command, falls back to the `default` entry, then falls back to the built-in `run_agent()` which uses the `--tool` flag. The `{{PROMPT}}` placeholder in runner commands substitutes the prompt as an argument instead of piping via stdin.

**State machine**: Stories progress `build → review → deploy → complete`, with backward transitions on failure. Deploy failures are counted by the orchestrator (not agents); after 3 attempts the story is set to `blocked`. Stage transitions are enforced by `validate_story_stage_transition()`.

**Quality gates**: `validate_planning_exit_gate()` blocks PM and implementation until all 8 planning docs exist, TODOs are resolved, REQ-### IDs are present, critical path is documented, and all areas are approved/locked. `validate_story_schema()` and `validate_story_deploy_contract()` enforce the story JSON contract.

**Pipeline locking**: `mkdir`-based atomic lock at `.state/.pipeline.lock` prevents concurrent runs. Trap handlers in both `plan.sh` and `implement.sh` clean up on crash (release lock, log failure, clean temp files).

**State writes**: All JSON state mutations use atomic temp-file + `mv` pattern via `jq -n --arg` to prevent corruption and injection.

## Key Conventions

- `.init/` is **read-only** — no agent or script may modify it
- Agent prompts in `agents/*.md` define the role, required reads, tasks, and rules for each agent
- Each story has two files: `prd/US-XXX.json` (machine-readable spec) and `prd/US-XXX.md` (human-readable tracker)
- Story IDs use format `US-001` with zero-padded 3-digit sequential numbers
- Requirement IDs use format `REQ-001` and must appear in `work-breakdown.md` and `traceability.md`
- Templates in `.plan/templates/` are schema references; `bootstrap-plan.sh` copies them to `.plan/` only if the target doesn't exist
- `agents/runners.json` is the active config; `agents/runners.example.json` is a multi-provider reference
- Stall detection: if a story stays at the same stage for 3 consecutive iterations, the orchestrator exits with an error

## Editing Shell Scripts

- All scripts use `set -euo pipefail`; `common.sh` also sets `shopt -s inherit_errexit`
- When capturing command output that might fail, use `if ! output=$(cmd); then` or `cmd || rc=$?` — never bare process substitution in conditions
- All argument flags that take values validate that the next arg exists and isn't another flag (`"${2:-}" == --*` guard)
- Use `${VAR:-}` for variables that might be unset under `set -u`
- JSON writes must use `jq -n --arg` for safe value injection (never string interpolation into JSON)
- Temp files use `${file}.tmp.$$` naming and are atomically moved with `mv`

## Story JSON Schema

Required fields validated by `validate_story_schema()`:
- `riskTier`: `low | medium | high`
- `sizing`: `small | medium | large`
- `autonomy`: `auto_deploy | gated_deploy`
- `requirements`: array of strings matching `^REQ-[0-9]{3}$`
- `deploySafety`: object with `strategy` (string), `healthChecks` (array), `rollbackTrigger` (string), `rollbackCommand` (string), `verification` (array)
- `status.validation`: object

Deploy-stage stories are additionally checked for non-empty deploy safety fields and rejected if they contain `TODO`/`TBD`/`FIXME` placeholder text.
