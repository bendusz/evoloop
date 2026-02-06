# Area: orchestration-core

## Scope and Boundaries
Define and enforce planning/implementation orchestration behavior, state transitions, locking, and preflight checks.

## Functional Requirements
- Deterministic CLI routing for `plan` and `run` modes.
- Enforced stage transition rules and dependency gating.
- Clear failure handling and run logging.

## Non-Functional Targets
- Fast preflight feedback (<2s on small repos).
- Deterministic behavior with `set -euo pipefail` and atomic writes.

## Interfaces and Contracts
- `orchestrator.sh` dispatches to `scripts/plan.sh` and `scripts/implement.sh`.
- Shared gate and helper behavior lives in `scripts/lib/common.sh`.

## Data Model and Retention
- Story specs in `prd/US-XXX.json`.
- Runtime state in `.state/pipeline.json` (local, ignored).
- Run logs in `.log/run-*/` (local, ignored).

## Security and Privacy
- No secrets in tracked files.
- `.init/` treated as read-only user input.

## Observability and Alerts
- `run.md` captures runner selection and failures.
- `doctor.sh --verbose` exposes failing checks.

## Failure Modes and Rollback
- Agent failure exits run with state updated to `agent_failed` or `crashed`.
- Deploy failures require rollback and can move story to `blocked` after max attempts.

## Capacity and Cost
- Context files constrained per story to reduce token/cost spikes.

## Acceptance Checks
- `./scripts/doctor.sh --planning-only`
- `./scripts/doctor.sh --skip-runner-tools`
- `bash -n orchestrator.sh scripts/*.sh scripts/lib/common.sh`

## Open Questions
None.

## Out of Scope
Product-specific build/test/deploy implementation details in downstream repos.

## Approval Checklist
- [x] Scope is explicit and bounded.
- [x] Functional requirements are testable.
- [x] NFR targets are measurable.
- [x] Interfaces/contracts are concrete.
- [x] Data model and retention are defined.
- [x] Security/privacy controls are defined.
- [x] Observability and alert paths are defined.
- [x] Failure and rollback paths are realistic.
- [x] Capacity and cost assumptions are documented.
- [x] Critical open questions are zero.
