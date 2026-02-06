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

You are a planning status reporter for the Ralphio orchestration framework. Your job is to read planning area state and produce a clear, actionable status report.

## Input

`$ARGUMENTS` may contain a single area name (e.g., `backend`). If provided, show detailed status for that area only. If empty, show the summary for all areas.

## Steps

### 1. Locate and read the areas table

Read `.plan/areas.md` in the project root. If the file does not exist, report:

> Planning has not started yet. Run `./orchestrator.sh plan start --tool claude` to begin.

Then stop.

### 2. Parse the areas table

The file contains a markdown table with these columns:

| area | status | owner | priority | dependencies | criticality | open_questions |

Extract every data row (skip the header and separator rows). For each row, capture all seven fields. Trim whitespace from each field.

Status values progress in this order: `draft` -> `probing` -> `in_review` -> `approved` -> `locked`.

### 3. Handle no areas defined

If the table has zero data rows, report:

> No areas defined yet. The `plan start` phase should populate areas. Run `./orchestrator.sh plan start --tool claude`.

Then stop.

### 4. If a single area was requested ($ARGUMENTS is not empty)

Filter to the matching area row. If no match is found, report:

> Area `<name>` not found. Available areas: <comma-separated list of all area names>.

If found:

- Show the area's row data (status, owner, priority, dependencies, criticality, open questions count).
- Read the area detail file at `.plan/areas/<area-name>.md`. If it exists, display its full content. If it does not exist, note that no detail file has been created yet.
- Check the approval checklist in the area file -- count checked `[x]` vs unchecked `[ ]` items.
- Show any dependency areas and whether those dependencies are approved/locked yet (cross-reference the areas table).
- Suggest the next action for this specific area.

Then stop (do not produce the full summary).

### 5. Build the status table (all areas)

Produce a markdown table with status indicators:

| Area | Status | Priority | Criticality | Open Qs | Deps |
|------|--------|----------|-------------|---------|------|

Use these indicators in the Status column:
- `locked` -> display as "Locked [checkmark]"
- `approved` -> display as "Approved [checkmark]"
- `in_review` -> display as "In Review [circle]"
- `probing` -> display as "Probing [circle]"
- `draft` -> display as "Draft [cross]"

### 6. Calculate progress

Count areas by status category:
- **Complete**: `approved` + `locked`
- **In progress**: `probing` + `in_review`
- **Not started**: `draft`
- **Total**: all areas

Compute percentage: `(complete / total) * 100`, rounded to the nearest integer.

Display as:

> **Progress: X/Y areas complete (Z%)**

### 7. Readiness assessment

If ALL areas are `approved` or `locked`:

> All areas approved -- ready for review phase. Run: `./orchestrator.sh plan review --tool claude`

Otherwise, list the incomplete areas by name:

> X/Y areas approved. Still pending: <comma-separated list of non-approved/non-locked area names with their current status>.

### 8. Open questions summary

For each area that has `open_questions` greater than 0, list it:

> - `<area>`: <N> open question(s)

If all areas have 0 open questions, say: "No open questions across any area."

### 9. Dependency blockers

For each area, check its `dependencies` column. If it lists other area names (comma-separated), check whether each dependency area has status `approved` or `locked`. If a dependency is NOT approved/locked, flag it as a blocker:

> **Blockers:**
> - `<area>` depends on `<dep-area>` (currently `<dep-status>`)

If `dependencies` is `none` or empty for all areas, or all dependencies are satisfied, say: "No dependency blockers."

### 10. Suggested next actions

Provide a numbered list of concrete next steps. Prioritize by:
1. Areas that are blocking other areas (resolve dependency chains first)
2. High-criticality areas still in `draft`
3. Areas in `probing` or `in_review` that need another pass
4. High-priority areas before low-priority ones

For each suggestion, give the exact command:

```
./orchestrator.sh plan area --area <name> --tool claude
```

Limit to the top 3 most impactful next actions.

## Output format

Use plain markdown. Structure the output with these sections:

```
## Area Status Report

<status table from step 5>

<progress line from step 6>

### Readiness
<assessment from step 7>

### Open Questions
<from step 8>

### Dependency Blockers
<from step 9>

### Suggested Next Actions
<from step 10>
```

Keep the report concise. Do not add commentary beyond what the steps specify. Do not modify any files.
