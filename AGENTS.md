# AGENTS.md

## What This Project Is
This repository is a reusable multi-agent software delivery workflow.  
It is designed to keep context windows small while still enforcing high planning quality, traceability, and deployment safety.

The workflow has two phases:
1. Planning phase (no implementation work).
2. Implementation phase (story-by-story execution loop).

## Core Principles
- `.init/` is user input and must be treated as read-only by workflow agents.
- Planning must be exhaustive before implementation starts.
- Context should stay minimal: each agent reads only the files required for its step.
- Fresh agents should be used for major handoffs.
- Deploy safety and rollback paths are mandatory.

## Repository Structure
- `/orchestrator.sh`: pipeline orchestrator (`plan` and `run` combined flows).
- `/scripts/plan.sh`: planning phase runner.
- `/scripts/implement.sh`: implementation phase runner.
- `/scripts/lib/common.sh`: shared orchestration logic and gates.
- `/scripts/doctor.sh`: preflight validator.
- `/agents/`: role prompts (planner, area, reviewer, red-team, PM, builder, reviewer-test, deploy).
- `/.plan/`: planning artifacts and templates.
- `/prd/`: story specs (`US-XXX.json`) and trackers (`US-XXX.md`).
- `/.log/`: run logs and context packs.
- `/.state/`: pipeline state.
- `/flowchart/`: workflow diagrams.

## Required Planning Artifacts
Before PM story generation and implementation, these must exist:
- `.plan/areas.md`
- `.plan/work-breakdown.md`
- `.plan/traceability.md`
- `.plan/runbook.md`
- `.plan/decisions.md`
- `.plan/assumptions.md`
- `.plan/dependencies.md`
- `.plan/risk-register.md`

Additional planning gate requirements:
- `.plan/runbook.md`, `.plan/dependencies.md`, and `.plan/work-breakdown.md` must not contain `TODO`, `TBD`, or `FIXME`.
- `work-breakdown.md` and `traceability.md` must include `REQ-###` IDs.
- `dependencies.md` must include a `critical path` section.
- No area can remain in `draft`, `probing`, or `in_review`.

## Standard Operator Flow
1. Bootstrap scaffold:
   - `./scripts/bootstrap-plan.sh`
2. Planning preflight:
   - `./scripts/doctor.sh --planning-only`
3. Run planning pipeline:
   - `./orchestrator.sh plan` (runs `start -> area(all) -> review -> redteam`)
4. Run delivery pipeline:
   - `./orchestrator.sh run` (runs `pm -> doctor.sh -> implementation loop`)
   - For gated deploy stories, pass explicit approval:
     - `./orchestrator.sh run --approve-deploy US-001`

Agent selection:
- Use `-agent` (or `--agent`) to override the default provider.
- Example: `./orchestrator.sh plan -agent codex`
- Default is Codex (`gpt-5.3-codex`, `xhigh`).
- `gpt-5.3-codex` requires Codex CLI version `0.98.0` or later.

Direct entrypoint equivalents:
- Planning: `./scripts/plan.sh ...`
- Implementation: `./scripts/implement.sh ...`

## Story Contract (Implementation)
Each `prd/US-XXX.json` should include:
- `riskTier`: `low | medium | high`
- `sizing`: `small | medium | large`
- `autonomy`: `auto_deploy | gated_deploy`
- `requirements`: `REQ-###` IDs
- `deploySafety`: strategy, healthChecks, rollbackTrigger, rollbackCommand, verification
- `status.validation`: requirementsImplemented, requirementsVerified

Deploy-stage stories must have a non-empty deploy safety contract.
Stories with dependencies should not run until dependency stories are `complete`.

Implementation stage transitions are enforced:
- `build -> build | review`
- `review | test -> build | deploy`
- `deploy -> build | complete | blocked`

## Agent Rules
- Do not edit `.init/`.
- Keep edits scoped to assigned files and phase.
- Preserve detail when updating plan docs; do not collapse specifics into vague summaries.
- Keep cross-area dependencies explicit.
- Use `agents/runners.json` for tool routing.
- If `autonomy = "gated_deploy"`, deploy should require explicit user approval.

## Maintenance Rules
- When workflow logic changes, update:
  - `/README.md`
  - `/AGENTS.md`
  - relevant files under `/agents/` and `/scripts/`
- Run `./scripts/doctor.sh` after major workflow changes.
