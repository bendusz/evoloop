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
- `/Users/ben/code/ralphio/orchestrator.sh`: thin CLI dispatcher (`plan` or `run`).
- `/Users/ben/code/ralphio/scripts/plan.sh`: planning phase runner.
- `/Users/ben/code/ralphio/scripts/implement.sh`: implementation phase runner.
- `/Users/ben/code/ralphio/scripts/lib/common.sh`: shared orchestration logic and gates.
- `/Users/ben/code/ralphio/scripts/doctor.sh`: preflight validator.
- `/Users/ben/code/ralphio/agents/`: role prompts (planner, area, reviewer, red-team, PM, builder, reviewer-test, deploy).
- `/Users/ben/code/ralphio/.plan/`: planning artifacts and templates.
- `/Users/ben/code/ralphio/prd/`: story specs (`US-XXX.json`) and trackers (`US-XXX.md`).
- `/Users/ben/code/ralphio/.log/`: run logs and context packs.
- `/Users/ben/code/ralphio/.state/`: pipeline state.
- `/Users/ben/code/ralphio/flowchart/`: workflow diagrams.

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
3. Run planning subphases:
   - `./orchestrator.sh plan start --tool claude`
   - `./orchestrator.sh plan area --area <area> --tool claude`
   - `./orchestrator.sh plan review --tool claude`
   - `./orchestrator.sh plan redteam --tool claude`
   - `./orchestrator.sh plan pm --tool claude`
4. Full preflight before implementation:
   - `./scripts/doctor.sh`
5. Run implementation loop:
   - `./orchestrator.sh run --tool claude`
   - For gated deploy stories, pass explicit approval:
     - `./orchestrator.sh run --tool claude --approve-deploy US-001`

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
  - `/Users/ben/code/ralphio/README.md`
  - `/Users/ben/code/ralphio/AGENTS.md`
  - relevant files under `/Users/ben/code/ralphio/agents/` and `/Users/ben/code/ralphio/scripts/`
- Run `./scripts/doctor.sh` after major workflow changes.
