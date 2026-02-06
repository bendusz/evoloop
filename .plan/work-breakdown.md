# Work Breakdown

## Requirements

- REQ-001: Orchestrator entrypoints route planning and implementation modes with strict argument validation and clear failure messages.
- REQ-002: Preflight checks validate required planning artifacts, deploy safety contracts, runner tools, and detect broken or circular story dependencies.
- REQ-003: Implementation loop enforces valid stage transitions and never reports completion when no stories are present.
- REQ-004: Skills and agent-facing guidance stay aligned with actual workflow contracts, file names, and run-time behavior.
- REQ-005: Repository defaults are safe for public publishing and do not contain user-specific local paths or machine state.

## Sequencing Notes

1. Stabilize orchestration and validation logic first (REQ-001, REQ-002, REQ-003).
2. Align prompts, skills, and docs to code behavior (REQ-004).
3. Finalize public-release hygiene and verification checks (REQ-005).

## Constraints and Guardrails

- Keep `.init/` read-only for workflow agents.
- Preserve stage-transition contract: `build -> review`, `review|test -> build|deploy`, `deploy -> build|complete|blocked`.
- Keep deploy safety and rollback requirements explicit in every deploy-stage story.
