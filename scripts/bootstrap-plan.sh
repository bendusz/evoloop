#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

write_if_missing() {
  local path="$1"
  if [[ -f "$path" ]]; then
    return
  fi
  mkdir -p "$(dirname "$path")"
  cat > "$path"
  echo "Created: ${path#$ROOT_DIR/}"
}

copy_if_missing() {
  local src="$1"
  local dst="$2"
  if [[ -f "$dst" ]]; then
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "Initialized: ${dst#$ROOT_DIR/}"
}

mkdir -p \
  "$ROOT_DIR/.init" \
  "$ROOT_DIR/.temp" \
  "$ROOT_DIR/.plan/areas" \
  "$ROOT_DIR/.plan/templates" \
  "$ROOT_DIR/.log" \
  "$ROOT_DIR/.claude" \
  "$ROOT_DIR/flowchart"

write_if_missing "$ROOT_DIR/.init/README.md" <<'EOF'
# .init

Place project source material here:
- requirements
- design references
- architecture notes
- compliance/security constraints
- existing codebase context and upgrade goals

The planning workflow treats `.init/` as read-only input.
EOF

write_if_missing "$ROOT_DIR/.claude/README.md" <<'EOF'
# .claude

Optional local Claude-specific config and templates.
EOF

write_if_missing "$ROOT_DIR/flowchart/README.md" <<'EOF'
# Flowcharts

Use this folder for workflow diagrams and architecture maps.
EOF

write_if_missing "$ROOT_DIR/flowchart/workflow.mmd" <<'EOF'
flowchart TD
  INIT[".init input"] --> PLAN["plan start"]
  PLAN --> AREA["plan area (one area at a time)"]
  AREA --> REVIEW["plan review"]
  REVIEW --> REDTEAM["plan redteam"]
  REDTEAM --> PM["plan pm"]
  PM --> BUILD["run: build"]
  BUILD --> TEST["run: review/test"]
  TEST --> DEPLOY["run: deploy"]
  DEPLOY --> DONE["complete"]
  DEPLOY -->|failure + rollback| BUILD
EOF

write_if_missing "$ROOT_DIR/.plan/templates/areas.md" <<'EOF'
# Areas

| area | status | owner | priority | dependencies | criticality | open_questions |
| --- | --- | --- | --- | --- | --- | --- |
| backend | draft | team | high | none | high | 0 |

Allowed status values: `draft`, `probing`, `in_review`, `approved`, `locked`.
EOF

write_if_missing "$ROOT_DIR/.plan/templates/area.template.md" <<'EOF'
# Area: <name>

## Scope and Boundaries

## Functional Requirements

## Non-Functional Targets

## Interfaces and Contracts

## Data Model and Retention

## Security and Privacy

## Observability and Alerts

## Failure Modes and Rollback

## Capacity and Cost

## Acceptance Checks

## Open Questions

## Out of Scope

## Approval Checklist
- [ ] Scope is explicit and bounded.
- [ ] Functional requirements are testable.
- [ ] NFR targets are measurable.
- [ ] Interfaces/contracts are concrete.
- [ ] Data model and retention are defined.
- [ ] Security/privacy controls are defined.
- [ ] Observability and alert paths are defined.
- [ ] Failure and rollback paths are realistic.
- [ ] Capacity and cost assumptions are documented.
- [ ] Critical open questions are zero.
EOF

write_if_missing "$ROOT_DIR/.plan/templates/decisions.md" <<'EOF'
# Decisions

| id | date | owner | decision | rationale | impact | status |
| --- | --- | --- | --- | --- | --- | --- |
| ADR-001 | YYYY-MM-DD | team |  |  |  | proposed |
EOF

write_if_missing "$ROOT_DIR/.plan/templates/assumptions.md" <<'EOF'
# Assumptions

| id | date | owner | assumption | confidence | validation plan | expiry | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ASM-001 | YYYY-MM-DD | team |  | low/medium/high |  | YYYY-MM-DD | open |
EOF

write_if_missing "$ROOT_DIR/.plan/templates/dependencies.md" <<'EOF'
# Dependencies

## Cross-Area Dependencies

| from | to | contract | risk | owner | status |
| --- | --- | --- | --- | --- | --- |

## Critical Path

1. (Define the critical path sequence here.)
EOF

write_if_missing "$ROOT_DIR/.plan/templates/risk-register.md" <<'EOF'
# Risk Register

| id | risk | likelihood | impact | mitigation | owner | trigger | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-001 |  | low/medium/high | low/medium/high |  |  |  | open |
EOF

write_if_missing "$ROOT_DIR/.plan/templates/runbook.md" <<'EOF'
# Runbook

## Environment and Prerequisites

## Build Command
TODO

## Test Command
TODO

## Deploy Command
TODO

## Rollback Command
TODO

## Post-Deploy Verification
TODO
EOF

write_if_missing "$ROOT_DIR/.plan/templates/work-breakdown.md" <<'EOF'
# Work Breakdown

## Requirements

- REQ-XXX: <requirement>

## Sequencing Notes

## Constraints and Guardrails
EOF

write_if_missing "$ROOT_DIR/.plan/templates/traceability.md" <<'EOF'
# Traceability

| requirement | area | story | test intent |
| --- | --- | --- | --- |
| REQ-XXX |  |  |  |
EOF

write_if_missing "$ROOT_DIR/.plan/templates/story.template.json" <<'EOF'
{
  "schemaVersion": "1",
  "id": "US-XXX",
  "title": "",
  "area": "",
  "priority": 1,
  "stage": "build",
  "riskTier": "low",
  "sizing": "small",
  "autonomy": "gated_deploy",
  "description": "",
  "requirements": [],
  "acceptanceCriteria": [],
  "dependencies": [],
  "deploySafety": {
    "strategy": "",
    "healthChecks": [],
    "rollbackTrigger": "",
    "rollbackCommand": "",
    "verification": []
  },
  "context": {
    "workBreakdown": ".plan/work-breakdown.md",
    "traceability": ".plan/traceability.md",
    "runbook": ".plan/runbook.md",
    "areaDoc": ".plan/areas/<area>.md",
    "files": []
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
    "deploy": { "passes": false, "attempts": 0, "target": "", "result": "", "rollback": "", "notes": "" }
  }
}
EOF

write_if_missing "$ROOT_DIR/.plan/templates/story-tracker.template.md" <<'EOF'
# US-XXX: <title>

**Area:** <area>
**Priority:** <N>
**Risk Tier:** low|medium|high
**Sizing:** small|medium|large
**Stage:** build

## Requirements
- REQ-XXX: <requirement description>

## Acceptance Criteria
- [ ] <criterion>

## Build Notes

## Review Notes

## Test Results

## Deploy Results

## Requirement Verification
- REQ-XXX: <verification evidence>
EOF

copy_if_missing "$ROOT_DIR/.plan/templates/areas.md" "$ROOT_DIR/.plan/areas.md"
copy_if_missing "$ROOT_DIR/.plan/templates/decisions.md" "$ROOT_DIR/.plan/decisions.md"
copy_if_missing "$ROOT_DIR/.plan/templates/assumptions.md" "$ROOT_DIR/.plan/assumptions.md"
copy_if_missing "$ROOT_DIR/.plan/templates/dependencies.md" "$ROOT_DIR/.plan/dependencies.md"
copy_if_missing "$ROOT_DIR/.plan/templates/risk-register.md" "$ROOT_DIR/.plan/risk-register.md"
copy_if_missing "$ROOT_DIR/.plan/templates/runbook.md" "$ROOT_DIR/.plan/runbook.md"
copy_if_missing "$ROOT_DIR/.plan/templates/work-breakdown.md" "$ROOT_DIR/.plan/work-breakdown.md"
copy_if_missing "$ROOT_DIR/.plan/templates/traceability.md" "$ROOT_DIR/.plan/traceability.md"

echo "Planning scaffold ready."
