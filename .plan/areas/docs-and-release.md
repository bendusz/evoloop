# Area: docs-and-release

## Scope and Boundaries
Keep public documentation accurate, machine-agnostic, and consistent with current code behavior.

## Functional Requirements
- Public docs use repo-relative paths.
- Installation examples are current and provider-correct.
- Release guidance includes rollback and verification steps.

## Non-Functional Targets
- New contributors can run setup and doctor checks without local-path edits.

## Interfaces and Contracts
- Primary docs: `README.md`, `UserGuide.md`, `AGENTS.md`, `CLAUDE.md`.

## Data Model and Retention
- No local run-state files tracked in git.

## Security and Privacy
- Remove personal paths and local host details from tracked files.

## Observability and Alerts
- Pre-publish checks use `rg` scans for personal path patterns.

## Failure Modes and Rollback
- If bad docs are published, patch docs and release a corrective commit.

## Capacity and Cost
- Documentation-only area; negligible runtime overhead.

## Acceptance Checks
- `rg -n "/Users/|C:\\\\Users\\\\|/home/" README.md UserGuide.md AGENTS.md CLAUDE.md .claude/skills`
- `./scripts/doctor.sh --planning-only --skip-runner-tools`

## Open Questions
None.

## Out of Scope
Automating release pipelines outside repository documentation and script updates.

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
