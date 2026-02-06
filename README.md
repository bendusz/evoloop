# Evoloop

A self-contained multi-agent workflow for planning, building, reviewing, testing, and deploying software with strict quality gates and minimal context windows.

## Overview

Evoloop orchestrates AI agents (Claude, Codex, Gemini) through a two-phase software delivery pipeline:

1. **Planning** - Exhaustive, area-based planning with quality gates, requirement traceability, and red-team review.
2. **Implementation** - Story-by-story execution loop: build, review/test, deploy, with automatic rollback and retry.

Each agent runs with a minimal, scoped context window. Fresh agents handle each step, so no single agent needs to hold the entire project in memory.

## Prerequisites

- [jq](https://jqlang.github.io/jq/) - JSON processor
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) - fast search
- At least one AI CLI tool:
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`claude`)
  - [Codex](https://github.com/openai/codex) (`codex`)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli) (`gemini`)

## Quickstart

```bash
# 1. Bootstrap the scaffold
./scripts/bootstrap-plan.sh

# 2. Drop your source material into .init/
#    (requirements, design docs, architecture notes, etc.)

# 3. Validate readiness
./scripts/doctor.sh --planning-only

# 4. Run planning phases sequentially
./orchestrator.sh plan start --tool claude
./orchestrator.sh plan area --area backend --tool claude
./orchestrator.sh plan review --tool claude
./orchestrator.sh plan redteam --tool claude
./orchestrator.sh plan pm --tool claude

# 5. Validate everything before implementation
./scripts/doctor.sh

# 6. Run implementation
./orchestrator.sh run --tool claude
```

## Architecture

```
orchestrator.sh          # Thin CLI dispatcher
  ├── scripts/plan.sh    # Planning phase runner
  ├── scripts/implement.sh  # Implementation phase runner
  └── scripts/lib/common.sh # Shared helpers, validation, gates
```

### Directory Layout

| Directory | Purpose |
|-----------|---------|
| `.init/` | User-provided source inputs (read-only) |
| `.plan/` | Planning artifacts (areas, registers, runbook) |
| `.plan/templates/` | Schema templates for stories, areas, registers |
| `.plan/areas/` | Per-area deep-dive documents |
| `.log/` | Per-run logs and context packs |
| `.state/` | Pipeline metadata (pipeline.json, lock file) |
| `agents/` | Role prompts and runner configuration |
| `prd/` | Story JSON specs and markdown trackers |
| `scripts/` | All executable scripts |
| `flowchart/` | Workflow diagrams |

## Planning Phase

Planning is explicit, sequenced, and gate-driven through five subphases:

| Step | Agent | What It Does |
|------|-------|-------------|
| `start` | Planning Coordinator | Reads `.init/`, asks clarifying questions, creates area map and planning registers |
| `area` | Area Agent | Deepens one area at a time through `draft -> probing -> in_review -> approved -> locked` |
| `review` | Planning Reviewer | Finds gaps, produces `work-breakdown.md` with `REQ-###` IDs and `traceability.md` |
| `redteam` | Red-Team Agent | Stress-tests scale, security, rollback realism, critical-path coverage |
| `pm` | PM Agent | Converts work breakdown into story specs in `prd/` |

### Planning Exit Gate

Before PM runs and before implementation, the orchestrator enforces:

- All 8 planning docs exist (areas, work-breakdown, traceability, runbook, decisions, assumptions, dependencies, risk-register)
- `runbook.md`, `dependencies.md`, and `work-breakdown.md` contain no `TODO`/`TBD`/`FIXME`
- `work-breakdown.md` and `traceability.md` include `REQ-###` IDs
- `dependencies.md` includes a critical path section
- No area is still `draft`, `probing`, or `in_review`

## Implementation Phase

Each story progresses through strict stages handled by fresh agents:

```
build --> review/test --> deploy --> complete
  ^          |              |
  |          |              +--> blocked (after 3 failures)
  +----------+--------------+
       (on failure)
```

| Stage | Agent | Behavior |
|-------|-------|----------|
| `build` | Builder | Implements the story, commits on branch, runs build command |
| `review`/`test` | Reviewer-Test | Reviews code, fixes minor issues, adds tests, verifies requirements |
| `deploy` | Deploy | Validates deploy safety contract, deploys, verifies, rolls back on failure |

### Stage Transitions (enforced)

- `build` -> `build` | `review`
- `review`/`test` -> `build` | `deploy`
- `deploy` -> `build` | `complete` | `blocked`

### Deploy Safety

Every story carries a deploy safety contract:
- **strategy** - deployment approach (rolling, blue-green, etc.)
- **healthChecks** - post-deploy health verification steps
- **rollbackTrigger** - condition that triggers rollback
- **rollbackCommand** - exact rollback command
- **verification** - post-deploy verification steps

Deploy failures are tracked by the orchestrator. After 3 failed attempts, the story is set to `blocked`.

### Gated Deploys

Stories with `autonomy: "gated_deploy"` require explicit approval:

```bash
./orchestrator.sh run --tool claude --approve-deploy US-001
./orchestrator.sh run --tool claude --approve-deploy all
```

## Preflight Checks

Run `doctor.sh` before unattended runs:

```bash
./scripts/doctor.sh                    # Full check
./scripts/doctor.sh --planning-only    # Skip implementation gate
./scripts/doctor.sh --skip-runner-tools  # Skip CLI availability checks
./scripts/doctor.sh --verbose          # Show details on failures
```

Checks include:
- Directory scaffold and executable entrypoints
- Shell syntax validation for all scripts
- JSON validity for runners and story files
- Core tool availability (`jq`, `rg`)
- Runner CLI availability from `agents/runners.json`
- Story schema and deploy-safety contract validation
- Circular and broken dependency detection
- Planning exit gate readiness

## Agent Routing

Agents are routed via `agents/runners.json`. Each entry maps an agent name to a CLI command:

```json
{
  "default": {
    "cmd": ["claude", "--model", "opus", "--dangerously-skip-permissions", "--print"]
  },
  "builder": {
    "cmd": ["codex", "exec", "--full-auto", "--model", "gpt-5.2"]
  }
}
```

If no matching runner is configured, the orchestrator falls back to the `--tool` flag. See `agents/runners.example.json` for a multi-provider example.

Use `{{PROMPT}}` in the `cmd` array for tools that take the prompt as an argument instead of stdin.

## CLI Reference

### Planning

```bash
./orchestrator.sh plan start   [--tool claude|codex|gemini] [--runners <file>]
./orchestrator.sh plan area    --area <name> [--tool claude|codex|gemini]
./orchestrator.sh plan review  [--tool claude|codex|gemini]
./orchestrator.sh plan redteam [--tool claude|codex|gemini]
./orchestrator.sh plan pm      [--tool claude|codex|gemini]
```

### Implementation

```bash
./orchestrator.sh run [--tool claude|codex|gemini]
                      [--story US-XXX]
                      [--max-iterations N]
                      [--approve-deploy US-XXX|all]
                      [--resume]
                      [--reset]
                      [--runners <file>]
```

### Direct Entrypoints

```bash
./scripts/plan.sh start --tool claude
./scripts/implement.sh --tool claude --story US-001
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAUDE_MODEL` | `opus` | Claude model name |
| `CODEX_MODEL` | `gpt-5.2` | Codex model name |
| `CODEX_EFFORT` | `xhigh` | Codex reasoning effort |
| `GEMINI_MODEL` | `gemini-2.0-flash` | Gemini model name |

## Safety Features

- **Atomic state writes** - All JSON state updates use temp file + `mv` to prevent corruption
- **Pipeline locking** - `mkdir`-based lock prevents concurrent orchestrator instances
- **Trap handlers** - Graceful cleanup on crash or interruption (logs failure, releases lock, cleans temp files)
- **Stall detection** - Implementation exits if a story fails to advance after 3 consecutive iterations
- **Stage transition enforcement** - Invalid stage transitions are rejected
- **Dependency cycle detection** - `doctor.sh` catches circular and broken story dependencies
- **Deploy contract validation** - Placeholder text (`TODO`/`TBD`/`FIXME`) is rejected in deploy safety fields
