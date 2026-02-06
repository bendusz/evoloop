---
name: area-status
description: Show planning area readiness status -- statuses, open questions, blockers, and next actions
allowed-tools:
  - Read
  - Glob
  - Grep
argument-hint: "[area-name]"
---

# Area Readiness Checker

## Input

`$ARGUMENTS`: optional area name. If provided → detailed single-area view. If empty → all-areas summary.

## Data Source

Read `.plan/areas.md`. Missing → "Planning not started. Run `./orchestrator.sh plan start --tool claude`", stop. Empty table → "No areas defined", stop.

Parse markdown table columns: `area | status | owner | priority | dependencies | criticality | open_questions`. Status progression: `draft` → `probing` → `in_review` → `approved` → `locked`.

## Single Area Mode

If area not found → list available. If found:
- Show row data (status, owner, priority, deps, criticality, open questions)
- Read `.plan/areas/<area>.md` if exists → show content, count `[x]` vs `[ ]` checklist items
- Cross-reference dependency areas against table for approval status
- Suggest next action. Stop.

## All Areas Mode

**Status table**: `| Area | Status | Priority | Criticality | Open Qs | Deps |`
Status indicators: locked/approved → checkmark, in_review/probing → circle, draft → cross.

**Progress**: `X/Y areas complete (Z%)` where complete = approved + locked.

**Readiness**: All approved → "Ready for review. Run `./orchestrator.sh plan review --tool claude`". Otherwise list pending areas with status.

**Open Questions**: Per area with count >0. Or "None."

**Dependency Blockers**: For each area, check if dependency areas are approved/locked. Flag unmet deps. Or "No blockers."

**Next Actions** (top 3): Prioritize by: blocking other areas > high-criticality drafts > in-progress needing passes > high-priority. Give exact command: `./orchestrator.sh plan area --area <name> --tool claude`

Read-only. Do not modify files.
