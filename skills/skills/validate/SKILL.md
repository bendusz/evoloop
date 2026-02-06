---
name: validate
description: Incremental planning artifact validator. Validates individual planning docs and story JSON without running the full doctor suite. Faster feedback during the planning phase.
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(jq *)
argument-hint: "[runbook | work-breakdown | traceability | dependencies | areas | stories | US-XXX]"
---

# Incremental Validator

Read-only. Do NOT create/modify files or run shell scripts. For every FAIL, include `Fix:` with specific field/line/value. Report line numbers where possible.

## Routing

| `$ARGUMENTS` | Check |
|---|---|
| (empty) | ALL: sections 1-6 + existence of decisions.md, assumptions.md, risk-register.md |
| `runbook` | Section 1 |
| `work-breakdown` | Section 2 |
| `traceability` | Section 3 |
| `dependencies` | Section 4 |
| `areas` | Section 5 |
| `stories` | Section 6 (all stories + cross-story dep checks) |
| `US-XXX` | Section 7 (single story) |
| other | Print usage, stop |

## Output Format

```
[PASS] <artifact>: <check>
[FAIL] <artifact>:<line>: <issue>
       Fix: <specific fix>
---
Validation summary: X passed, Y failed
```

## Checks

### 1. Runbook (`.plan/runbook.md`)
- Exists
- No TODO/TBD/FIXME (case-insensitive `\b(TODO|TBD|FIXME)\b`, report each with line)
- At least one fenced code block (``` pattern)

### 2. Work Breakdown (`.plan/work-breakdown.md`)
- Exists
- No TODO/TBD/FIXME
- At least one `REQ-[0-9]{3}` ID
- No `REQ-XXX` template placeholders

### 3. Traceability (`.plan/traceability.md`)
- Exists
- At least one `REQ-[0-9]{3}` ID
- No `REQ-XXX` placeholders
- Cross-reference: every REQ in work-breakdown.md appears in traceability.md

### 4. Dependencies (`.plan/dependencies.md`)
- Exists
- No TODO/TBD/FIXME
- Contains "critical path" (case-insensitive)
- Critical path section has actual content (not just placeholder text)

### 5. Areas (`.plan/areas.md`)
- Exists
- Table not empty
- No unapproved areas (`draft|probing|in_review` in table → FAIL per area with name + status)

### 6. Stories — All (`prd/US-*.json`)
- At least one story exists
- Run section 7 for each
- Cross-story: each dependency ID has a corresponding file; no circular deps (A depends on B and B depends on A)

### 7. Single Story (`prd/US-XXX.json`)
- File exists
- Valid JSON (`jq empty`)
- `riskTier`: `low|medium|high`
- `sizing`: `small|medium|large`
- `autonomy`: `auto_deploy|gated_deploy`
- `requirements`: array, every element matches `^REQ-[0-9]{3}$`
- `deploySafety`: object with `strategy` (string), `healthChecks` (array), `rollbackTrigger` (string), `rollbackCommand` (string), `verification` (array) — report each missing subfield separately
- `status.validation`: must be object
- **Deploy contract** (only if `.stage` == `deploy`): all deploySafety strings non-empty, arrays non-empty, no TODO/TBD/FIXME/placeholder text

If file missing → report and skip content checks. On all pass: `[PASS] <ID>: Schema and deploy contract valid`
