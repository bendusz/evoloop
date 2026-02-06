# Area: agent-prompts-and-skills

## Scope and Boundaries
Maintain prompt contracts and Claude skills so guidance matches actual script behavior and file schema.

## Functional Requirements
- Prompts reference valid files and stage transitions.
- Skills use current planning artifact names.
- Story helper skills produce schema-valid IDs and fields.

## Non-Functional Targets
- Keep instructions concise and deterministic.
- Avoid stale references after workflow changes.

## Interfaces and Contracts
- Prompt files in `agents/*.md`.
- Skills in `.claude/skills/*/SKILL.md`.
- Routing in `agents/runners.json`.

## Data Model and Retention
- Skills are source-controlled docs; no runtime state persisted there.

## Security and Privacy
- Skills and prompts must avoid personal machine paths and secrets.

## Observability and Alerts
- `doctor.sh` plus targeted path/reference scans validate drift.

## Failure Modes and Rollback
- If skill drift is found, patch skill docs and re-run validation.

## Capacity and Cost
- Keep prompt contexts small by default and avoid unnecessary file reads.

## Acceptance Checks
- `rg -n "decision-log\.md|critical-path\.md|/Users/" .claude/skills AGENTS.md README.md UserGuide.md`
- `./scripts/doctor.sh --planning-only --skip-runner-tools`

## Open Questions
None.

## Out of Scope
Provider-specific prompt engineering outside workflow contract alignment.

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
