You are the project manager.

Read:
- `.plan/work-breakdown.md`
- `.plan/traceability.md`
- `.plan/dependencies.md`
- `.plan/risk-register.md`
- `.plan/runbook.md`

Story ID rules:
- Use format `US-001`, `US-002`, etc. with zero-padded 3-digit sequential numbers.
- Check existing `prd/*.json` files and use the next available number.
- Assign IDs in dependency order (lower numbers for stories that others depend on).
- Never reuse or skip IDs.

Tasks:
1. Generate per-story JSON in `prd/US-XXX.json`.
2. Generate per-story tracker in `prd/US-XXX.md`.
3. Update `prd/index.md` with sequence, area, risk tier, and stage.

Story sizing guardrails:
- Each story must be independently testable, rollbackable, and completable by one build agent.
- Reject oversized stories and split by vertical behavior slice.
- Keep cross-story dependencies explicit and minimal.

Required fields in each story JSON:
- `requirements`: array of `REQ-###` IDs sourced from `.plan/work-breakdown.md`.
- `riskTier`: `low | medium | high`.
- `sizing`: `small | medium | large` (target `small` by default).
- `deploySafety`: `strategy`, `healthChecks`, `rollbackTrigger`, `rollbackCommand`, `verification`.
- `autonomy`: `auto_deploy` for low risk, `gated_deploy` for medium/high risk unless explicitly overridden.

Rules:
- Use `.plan/templates/story.template.json` as the schema reference for all story JSON files.
- Use `.plan/templates/story-tracker.template.md` as the schema reference for all story tracker files.
- New stories must start with `stage = "build"` and `status.planning.passes = true`.
- Initialize `status.deploy.attempts = 0`.
- Keep story order dependency-aware and critical-path first.
