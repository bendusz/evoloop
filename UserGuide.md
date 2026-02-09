# Evoloop User Guide

This guide walks you through setting up and running Evoloop end-to-end: from dropping source material into `.init/` through planning, implementation, and deployment.

---

## Table of Contents

1. [Installation](#1-installation)
2. [Project Setup](#2-project-setup)
3. [Planning Phase](#3-planning-phase)
4. [Implementation Phase](#4-implementation-phase)
5. [Story Spec Reference](#5-story-spec-reference)
6. [Agent Configuration](#6-agent-configuration)
7. [Resuming and Resetting](#7-resuming-and-resetting)
8. [Monitoring and Logs](#8-monitoring-and-logs)
9. [Troubleshooting](#9-troubleshooting)
10. [Extending Evoloop](#10-extending-evoloop)

---

## 1. Installation

### System Dependencies

Install `jq` and `ripgrep`:

```bash
# macOS
brew install jq ripgrep

# Ubuntu/Debian
sudo apt install jq ripgrep

# Arch
sudo pacman -S jq ripgrep
```

### AI CLI Tools

Install at least one. Evoloop supports mixing providers per agent.

**Claude Code** (recommended):
```bash
npm install -g @anthropic-ai/claude-code
```

**OpenAI Codex**:
```bash
npm install -g @openai/codex
```

If you configure `gpt-5.3-codex`, ensure `codex --version` is `0.98.0` or later.

**Gemini CLI**:
```bash
npm install -g @google/gemini-cli
```

### Verify Setup

```bash
./scripts/doctor.sh --planning-only --skip-runner-tools
```

This runs structural checks without requiring stories or runner tools.
When runner checks are enabled, `doctor.sh` also validates Codex CLI version requirements from `agents/runners.json` (for example, `gpt-5.3-codex` requires `codex-cli >= 0.98.0`).

---

## 2. Project Setup

### Bootstrap the Scaffold

```bash
./scripts/bootstrap-plan.sh
```

This creates the full directory structure and populates templates:

```
.init/                          # Your source material goes here
.plan/
  ├── areas.md                  # Area map (status table)
  ├── areas/                    # Per-area deep-dive docs
  ├── decisions.md              # Architecture Decision Records
  ├── assumptions.md            # Assumptions register
  ├── dependencies.md           # Cross-area deps + critical path
  ├── risk-register.md          # Risk tracking
  ├── runbook.md                # Build/test/deploy/rollback commands
  ├── work-breakdown.md         # Requirements with REQ-### IDs
  ├── traceability.md           # REQ -> area -> story -> test
  └── templates/                # Schema templates (never edited by agents)
agents/
  ├── runners.json              # Agent-to-CLI routing config
  └── *.md                      # Agent role prompts
prd/                            # Story specs (populated by PM agent)
```

### Prepare Source Material

Place everything the agents need to understand your project into `.init/`:

```
.init/
  ├── README.md                 # High-level overview (auto-created)
  ├── requirements.pdf          # Product requirements
  ├── architecture.md           # System architecture
  ├── api-spec.yaml             # API contracts
  └── existing-code-notes.md    # Context about the codebase
```

`.init/` is **read-only** by design. No agent will modify it.

---

## 3. Planning Phase

Planning runs through five sequential subphases. Each subphase uses a dedicated AI agent with a focused prompt and minimal context window.

Recommended interactive planning run:

```bash
./orchestrator.sh plan
```

This combined command runs `start -> user checkpoint -> area(all) -> review -> redteam`.
After `start`, it pauses for user answers, writes questions to `.plan/questions.md`, and stores your responses in `.plan/answers.md`.
Use `--skip-user-checkpoint` only for intentionally unattended runs.

### 3.1 Plan Start - Planning Coordinator

```bash
./orchestrator.sh plan start -agent claude
```

The planning coordinator:
- Reads everything in `.init/`
- Asks 4-5 high-risk clarifying questions
- Writes those questions to `.plan/questions.md`
- Creates the area map in `.plan/areas.md`
- Initializes area files in `.plan/areas/`
- Seeds the planning registers (decisions, assumptions, dependencies, risks)
- Confirms executable commands in `.plan/runbook.md`

**What to check after**: Open `.plan/areas.md` and verify the area breakdown makes sense. Each area should start in `draft` status.

### 3.2 Plan Area - Area Agent

```bash
./orchestrator.sh plan area --area backend -agent claude
```

Run this once per area. The area agent:
- Drives the area through status transitions: `draft -> probing -> in_review -> approved`
- Fills in all required sections (scope, requirements, NFRs, interfaces, data model, security, observability, failure modes, acceptance checks)
- Updates shared registers when new facts emerge

**Repeat for each area**:
```bash
./orchestrator.sh plan area --area frontend -agent claude
./orchestrator.sh plan area --area infrastructure -agent claude
# ... etc
```

**What to check after**: Open `.plan/areas/<name>.md` and verify the approval checklist. The area should reach `approved` status if no critical questions remain.

### 3.3 Plan Review - Planning Reviewer

```bash
./orchestrator.sh plan review -agent claude
```

The reviewer:
- Cross-checks all areas for contradictions, gaps, and weak assumptions
- Returns areas to `probing` or `in_review` if gaps exist
- When all areas are approved, produces:
  - `.plan/work-breakdown.md` with `REQ-###` requirement IDs
  - `.plan/traceability.md` mapping requirements to areas, stories, and test intent

**What to check after**: Verify `work-breakdown.md` has concrete `REQ-001`, `REQ-002`, etc. entries with clear acceptance criteria.

### 3.4 Plan Red-Team - Red-Team Agent

```bash
./orchestrator.sh plan redteam -agent claude
```

The red-team agent stress-tests the plan:
- Unrealistic scale assumptions
- Security/privacy blind spots
- Weak rollback and disaster recovery
- Ambiguous ownership and handoffs
- Brittle dependencies and missing critical-path steps

It proposes targeted fixes (not rewrites). If no high-risk findings remain, it confirms readiness for PM story generation.

### 3.5 Plan PM - PM Agent

```bash
./orchestrator.sh plan pm -agent claude
```

The PM agent:
- Converts the work breakdown into story JSON files in `prd/US-XXX.json`
- Creates markdown trackers in `prd/US-XXX.md`
- Applies dependency-aware ordering (critical path first)
- Enforces story sizing, risk tier, and deploy safety schema

**Important**: The PM step enforces the **planning exit gate** before running. If it fails, fix the reported issues first.

### Planning Exit Gate

The gate checks:

| Check | What It Validates |
|-------|------------------|
| Required docs | All 8 planning artifacts exist |
| No placeholders | `runbook.md`, `dependencies.md`, `work-breakdown.md` have no `TODO`/`TBD`/`FIXME` |
| Requirement IDs | `work-breakdown.md` and `traceability.md` contain `REQ-###` patterns |
| Critical path | `dependencies.md` has a critical path section |
| Area status | No area is still `draft`, `probing`, or `in_review` |

To check the gate manually:
```bash
./scripts/doctor.sh --skip-runner-tools
```

---

## 4. Implementation Phase

### Full Implementation Run

```bash
./scripts/doctor.sh          # Always run preflight first
./orchestrator.sh run -agent claude
```

The orchestrator loops through all stories in priority order, processing each through its current stage.

### Single Story Run

```bash
./orchestrator.sh run -agent claude --story US-001
```

Runs only the specified story through its current stage, then exits.

### Stage-by-Stage Walkthrough

#### Build Stage

The builder agent:
1. Reads the story spec, tracker, runbook, and traceability
2. Implements the story requirements
3. Runs the build command from the runbook
4. If build succeeds: sets `stage = "review"`
5. If build fails: keeps `stage = "build"` with failure notes

#### Review/Test Stage

The reviewer-test agent:
1. Reviews code for quality, security, and correctness
2. Fixes minor issues directly (style, simple bugs, missing docs)
3. Flags major issues and sends the story back to `build`
4. Adds or updates tests, runs them
5. Verifies requirement IDs against test evidence
6. If all passes: sets `stage = "deploy"`

#### Deploy Stage

The deploy agent:
1. Validates the deploy safety contract (strategy, health checks, rollback)
2. Runs the deploy command from the runbook
3. Runs post-deploy verification
4. If deploy succeeds: sets `stage = "complete"`
5. If deploy fails: rolls back, sets `stage = "build"` for retry

The orchestrator tracks deploy attempts. After 3 failures, the story is set to `blocked`.

### Approving Gated Deploys

Stories with `autonomy: "gated_deploy"` (default for medium/high risk) won't deploy without explicit approval:

```bash
# Approve a specific story
./orchestrator.sh run -agent claude --approve-deploy US-003

# Approve all stories
./orchestrator.sh run -agent claude --approve-deploy all

# Approve multiple stories
./orchestrator.sh run -agent claude --approve-deploy US-003 --approve-deploy US-005
```

### Limiting Iterations

By default, the orchestrator loops until all stories are complete or it hits a blocking condition. Limit iterations for controlled runs:

```bash
./orchestrator.sh run -agent claude --max-iterations 10
```

---

## 5. Story Spec Reference

Each story lives in `prd/US-XXX.json`. The template is at `.plan/templates/story.template.json`.

### Required Fields

```json
{
  "schemaVersion": "1",
  "id": "US-001",
  "title": "Implement user authentication",
  "area": "backend",
  "priority": 1,
  "stage": "build",
  "riskTier": "medium",
  "sizing": "small",
  "autonomy": "gated_deploy",
  "description": "Add JWT-based authentication...",
  "requirements": ["REQ-001", "REQ-002"],
  "acceptanceCriteria": ["Users can log in", "Tokens expire after 1h"],
  "dependencies": ["US-000"],
  "deploySafety": {
    "strategy": "rolling update with canary",
    "healthChecks": ["GET /health returns 200"],
    "rollbackTrigger": "error rate > 5% in 5 minutes",
    "rollbackCommand": "kubectl rollout undo deployment/auth",
    "verification": ["POST /auth/login returns 200 with valid creds"]
  },
  "context": {
    "workBreakdown": ".plan/work-breakdown.md",
    "traceability": ".plan/traceability.md",
    "runbook": ".plan/runbook.md",
    "areaDoc": ".plan/areas/backend.md",
    "files": ["src/auth/handler.ts"]
  },
  "status": {
    "planning": { "passes": true, "notes": "" },
    "build": { "passes": false, "branch": "", "commit": "", "notes": "" },
    "review": { "passes": false, "branch": "", "commit": "", "notes": "" },
    "test": { "passes": false, "command": "", "result": "", "notes": "" },
    "validation": {
      "requirementsImplemented": [],
      "requirementsVerified": [],
      "notes": ""
    },
    "deploy": {
      "passes": false,
      "attempts": 0,
      "target": "",
      "result": "",
      "rollback": "",
      "notes": ""
    }
  }
}
```

### Field Details

| Field | Values | Description |
|-------|--------|-------------|
| `stage` | `build`, `review`, `deploy`, `complete`, `blocked` | Current lifecycle stage |
| `riskTier` | `low`, `medium`, `high` | Risk classification |
| `sizing` | `small`, `medium`, `large` | Effort estimate (target `small`) |
| `autonomy` | `auto_deploy`, `gated_deploy` | Whether deploy needs explicit approval |
| `requirements` | `["REQ-001", ...]` | Requirement IDs from work-breakdown.md |
| `dependencies` | `["US-000", ...]` | Stories that must be `complete` before this one runs |

### Schema Validation

The orchestrator validates every story before processing:
- `riskTier`, `sizing`, `autonomy` must be valid enum values
- `requirements` must be an array of `REQ-###` formatted strings
- `deploySafety` must have all 5 fields present
- `status.validation` must exist

Deploy-stage stories additionally require:
- All `deploySafety` string fields must be non-empty
- `healthChecks` and `verification` arrays must be non-empty
- No placeholder text (`TODO`, `TBD`, `FIXME`) in deploy safety fields

### Story Tracker

Each story also has a markdown tracker at `prd/US-XXX.md`. Agents update this with human-readable notes as the story progresses through stages.

---

## 6. Agent Configuration

### runners.json

`agents/runners.json` maps agent names to CLI commands. Every agent checks this file before falling back to the `-agent` flag.

**Default config** (all agents use Claude):
```json
{
  "default": {
    "cmd": ["claude", "--model", "opus", "--dangerously-skip-permissions", "--print"]
  }
}
```

**Mixed-provider config** (different tools per agent):
```json
{
  "default": {
    "cmd": ["claude", "--model", "opus", "--dangerously-skip-permissions", "--print"]
  },
  "builder": {
    "cmd": ["codex", "exec", "--skip-git-repo-check", "--full-auto", "--model", "gpt-5.3-codex", "-c", "model_reasoning_effort=\"xhigh\""]
  },
  "deploy": {
    "cmd": ["gemini", "-p", "{{PROMPT}}", "--model", "gemini-2.0-flash"]
  }
}
```

#### Agent Names

These are the valid agent names for routing:

| Agent Name | Phase | Role |
|------------|-------|------|
| `planner` | Planning | Coordinator |
| `area-agent` | Planning | Area deep-dive |
| `reviewer` | Planning | Cross-area review |
| `red-team` | Planning | Adversarial review |
| `pm` | Planning | Story generation |
| `builder` | Implementation | Code implementation |
| `reviewer-test` | Implementation | Code review + testing |
| `deploy` | Implementation | Deployment |

#### Prompt Delivery

Most tools receive the prompt via **stdin** (piped from the prompt file). If a tool requires the prompt as a **command-line argument**, use the `{{PROMPT}}` placeholder:

```json
{
  "deploy": {
    "cmd": ["gemini", "-p", "{{PROMPT}}", "--model", "gemini-2.0-flash"]
  }
}
```

#### Custom Runners File

Point to a different runners file:
```bash
./orchestrator.sh run -agent claude --runners ./my-runners.json
```

### Environment Variables

Override model names without editing runners.json (only applies in `-agent` fallback mode):

```bash
CLAUDE_MODEL=sonnet ./orchestrator.sh run -agent claude
CODEX_MODEL=gpt-5.3-codex ./orchestrator.sh run -agent codex
GEMINI_MODEL=gemini-2.5-pro ./orchestrator.sh run -agent gemini
```

---

## 7. Resuming and Resetting

### Resume a Run

If a run is interrupted, resume from where it left off:

```bash
./orchestrator.sh run --resume
```

This reads the last active story from `.state/pipeline.json` and continues from that story.

### Reset All State

Clear all run history, logs, and pipeline state:

```bash
./orchestrator.sh run --reset -agent claude
```

This removes everything in `.state/`, `.log/`, and `.temp/`, then starts fresh.

**Note**: `--reset` and `--resume` cannot be used together.

---

## 8. Monitoring and Logs

### Pipeline State

Current pipeline status is stored in `.state/pipeline.json`:

```json
{
  "phase": "implementation",
  "stage": "build",
  "currentStory": "US-003",
  "lastAgent": "builder",
  "lastRunId": "20250206-143022",
  "updatedAt": "2025-02-06T14:30:22Z"
}
```

### Run Logs

Each run creates a timestamped directory under `.log/`:

```
.log/
  └── run-20250206-143022/
      ├── run.md           # Run log with agent invocations and results
      ├── context-pack.md  # Files provided to each agent
      └── handoff-notes.md # Notes passed between agents
```

### Context Packs

Every agent invocation is recorded in the context pack, showing which files were provided. This is useful for debugging when an agent produces unexpected output.

### Handoff Notes

Agents can write notes to `handoff-notes.md` in the run directory. These are automatically included in prompts for subsequent agents in the same run, enabling lightweight cross-agent communication.

---

## 9. Troubleshooting

### "Another orchestrator instance is running"

The pipeline lock at `.state/.pipeline.lock` prevents concurrent runs. If a previous run crashed without cleanup:

```bash
rm -rf .state/.pipeline.lock
```

### Doctor Fails

Run with `--verbose` to see detailed output:

```bash
./scripts/doctor.sh --verbose
```

Common failures:

| Failure | Fix |
|---------|-----|
| Missing planning artifact | Run the appropriate `plan` subphase |
| `runbook.md` contains TODO | Fill in the actual build/test/deploy commands |
| Area still in `draft` | Run `plan area --area <name>` to advance it |
| Story schema validation failed | Check `prd/US-XXX.json` against the template at `.plan/templates/story.template.json` |
| Circular dependency detected | Edit the `dependencies` arrays in the affected story JSONs |
| Runner tool not found | Install the CLI tool or update `agents/runners.json` |

### Story Stuck at Same Stage

The orchestrator detects stalls: if a story fails to advance from the same stage for 3 consecutive iterations, it exits with an error. Check:

1. The agent output in `.log/` for the latest run
2. The story's `status` block in `prd/US-XXX.json` for failure notes
3. The story's markdown tracker `prd/US-XXX.md` for agent commentary

### Deploy Blocked After 3 Attempts

When a story reaches 3 deploy failures, it's set to `blocked`. To retry:

1. Review the deploy failure notes in `prd/US-XXX.json` (`status.deploy.notes`)
2. Fix the underlying issue
3. Reset the story: set `stage` back to `build` and `status.deploy.attempts` to `0`
4. Re-run implementation

### Agent Exits Non-Zero

Agent failures are logged to the run log with the exit code:
```
Agent failure: builder exit=1 story=US-003 time=...
```

The orchestrator stops on agent failure. Check the agent's output, fix the issue, and re-run. Use `--resume` to pick up from the same story.

### Gemini Prompt Too Large

Gemini CLI may fail with `ARG_MAX` for prompts over ~200KB (since the prompt is passed as a command-line argument). The orchestrator warns at 200KB. If this happens:
- Reduce the number of files in the story's `context.files` array
- Use Claude or Codex for agents with large context needs

---

## 10. Extending Evoloop

### Adding a New Agent

1. Create a prompt file in `agents/<name>.md`
2. Add a runner entry in `agents/runners.json`
3. Wire it into the appropriate phase script (`plan.sh` or `implement.sh`)

### Customizing Templates

All templates live in `.plan/templates/`. Edit these to match your project's conventions:

- `story.template.json` - Story JSON schema
- `story-tracker.template.md` - Story markdown tracker
- `area.template.md` - Area deep-dive structure
- `runbook.md` - Build/test/deploy command template
- `areas.md`, `decisions.md`, `assumptions.md`, `dependencies.md`, `risk-register.md` - Planning register formats

Templates are only copied on bootstrap. Editing them won't affect existing files.

### Adding a New AI Provider

1. Add a case to the `run_agent()` function in `scripts/lib/common.sh`
2. Add the provider to the `-agent` validation in argument parsing
3. Update `orchestrator.sh` usage text
4. Add an example to `agents/runners.example.json`

### Custom Stage Logic

Stage transitions are enforced in `validate_story_stage_transition()` in `scripts/lib/common.sh`. To add a new stage:

1. Add the stage to the transition validation function
2. Add a case in `implement.sh`'s stage routing (`case "$stage" in`)
3. Create an agent prompt in `agents/`
4. Update the doctor checks if needed
