---
name: trace
description: Trace a requirement end-to-end through the Evoloop pipeline — definition, area, stories, implementation, verification
argument-hint: "<REQ-001>"
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Requirement Tracer

## Input

REQ ID from `$ARGUMENTS` (format: `REQ-001`, 3 digits). If empty → print usage. If invalid format → show expected format.

## Tracing Steps

1. **Definition**: Read `.plan/work-breakdown.md`, find line with REQ ID → description. Missing = gap.
2. **Area**: Read `.plan/traceability.md` for REQ row → area column. Fallback: Grep `.plan/areas/*.md`. Missing = gap.
3. **Stories**: Grep `prd/US-*.json` for REQ ID, confirm in `requirements` array. Collect story IDs.
4. **Implementation**: For each story, check `status.validation.requirementsImplemented`. Note `.stage` (top-level).
5. **Verification**: For each story, check `status.validation.requirementsVerified`.
6. **Traceability**: Read `.plan/traceability.md` → full row (requirement, area, story, test intent).

## Output

```
=== Requirement Trace: <REQ_ID> ===

Pipeline:
  [x/blank] Defined — <description>
  [x/blank] Area Assigned — <area>
  [x/blank] Story Assigned — <story IDs>
  [x/blank] Implemented — <per-story>
  [x/blank] Verified — <per-story>
  [x/blank] Traced — <traceability status>

Stories:
  <US-XXX> — <title> [stage: <stage>] Implemented: Y/N | Verified: Y/N

Traceability: | Requirement | Area | Story | Test Intent |

Summary: "Fully traced" or GAPS with remediation
```

## Remediation

- Not defined → add to `.plan/work-breakdown.md`
- No area → add to `.plan/traceability.md`
- No stories → create story or run `./orchestrator.sh plan pm --tool claude`
- Not implemented → advance story through build
- Not verified → run through review/test
- No traceability row → update `.plan/traceability.md`
