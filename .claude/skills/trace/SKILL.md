---
name: trace
description: Trace a requirement end-to-end through the Ralphio pipeline — definition, area, stories, implementation, verification
argument-hint: "<REQ-XXX>"
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Requirement Tracer

Trace a requirement through every stage of the Ralphio delivery pipeline.

## Input

The requirement ID is provided as `$ARGUMENTS`. It must match `REQ-` followed by a zero-padded 3-digit number (e.g., `REQ-005`).

## Validation

1. If `$ARGUMENTS` is empty, print usage and stop:
   ```
   Usage: /trace <REQ-XXX>
   Example: /trace REQ-005
   ```
2. If the format doesn't match `REQ-` + 3 digits, print:
   ```
   Invalid requirement ID. Expected format: REQ-001, REQ-012, REQ-123
   ```

## Tracing Steps

Perform all steps, then produce the final report.

### Step 1 — Definition

Read `.plan/work-breakdown.md`. Search for a line containing the REQ ID. Extract the full line as the requirement description. If not found, record as MISSING.

### Step 2 — Area Ownership

Read `.plan/traceability.md` and find the row matching the REQ ID. Extract the area column. If not found there, use Grep to search `.plan/areas/*.md` for the REQ ID — the filename indicates the area. If still not found, record as UNASSIGNED.

### Step 3 — Story Assignment

Use Grep to search `prd/US-*.json` for the REQ ID. For each match, read the JSON and confirm it appears in the `requirements` array. Collect the list of story IDs.

### Step 4 — Implementation Status

For each story from Step 3, check `status.validation.requirementsImplemented` for the REQ ID. Also note the story's current `.stage` (top-level field).

### Step 5 — Verification Status

For each story from Step 3, check `status.validation.requirementsVerified` for the REQ ID.

### Step 6 — Traceability Mapping

Read `.plan/traceability.md`. Find the full row for the REQ ID. Extract all columns: requirement, area, story, test intent.

## Output Format

```
=== Requirement Trace: <REQ_ID> ===

Pipeline Status:
  [x] Defined        — <description or "Not found in work-breakdown.md">
  [x] Area Assigned  — <area name or "No area ownership found">
  [ ] Story Assigned — <story IDs or "No stories reference this requirement">
  [ ] Implemented    — <per-story details>
  [ ] Verified       — <per-story details>
  [x] Traced         — <traceability.md mapping status>

--- Definition ---
<Full line from work-breakdown.md, or "Not found">

--- Area Ownership ---
Area: <area>
Source: <"traceability.md" or "areas/<name>.md" or "not found">

--- Stories ---
<For each story:>
  <US-XXX> — <title> [stage: <stage>]
    Implemented: <Yes/No>
    Verified: <Yes/No>

<If no stories: "No stories implement this requirement.">

--- Traceability Matrix ---
| Requirement | Area | Story | Test Intent |
|-------------|------|-------|-------------|
| <row or "No entry found"> |

--- Summary ---
<If fully traced: "Fully traced: defined → area → stories → implemented → verified">
<If gaps:>
  GAPS FOUND:
  - <gap + remediation>
```

## Remediation Suggestions

- **Not defined**: "Add to `.plan/work-breakdown.md`"
- **No area**: "Add area mapping in `.plan/traceability.md`"
- **No stories**: "Create a story in `prd/` with this REQ in its `requirements` array, or run `./orchestrator.sh plan pm --tool claude`"
- **Not implemented**: "Story `<US-XXX>` is at stage `<stage>`. Advance through build stage."
- **Not verified**: "Run story through review/test stage."
- **Traceability incomplete**: "Update `.plan/traceability.md`"

## Edge Cases

- If REQ ID not found anywhere in the project: state clearly and suggest adding it to work-breakdown.md
- If `.plan/areas/` doesn't exist: skip area file search, note planning hasn't started
- If no `prd/US-*.json` exist: note story generation hasn't run yet
