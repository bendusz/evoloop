---
name: doctor-fix
description: Run Evoloop doctor checks and auto-fix common issues — missing directories, non-executable scripts, missing templates, and provide remediation for manual fixes
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - Write
---

# Doctor Auto-Fix

## Step 1: Run Doctor

Run `./scripts/doctor.sh --verbose`. If missing/not executable → "Run `./scripts/bootstrap-plan.sh`".

## Step 2: Categorize Issues

**Auto-fixable**:
| Issue | Fix |
|-------|-----|
| Missing directory (`.log/`, `.state/`, `.plan/areas/`, `.plan/templates/`) | `mkdir -p` |
| Script not executable | `chmod +x` |
| Missing templates in `.plan/templates/` | Run `./scripts/bootstrap-plan.sh` |
| Malformed JSON (formatting) | Read with jq, rewrite |

**Manual** (provide file:line + remediation):
- TODO/TBD/FIXME in planning docs → show exact location, suggest replacement
- Missing REQ-### IDs → show where to add, reference existing
- Areas not approved → suggest `./orchestrator.sh plan area --area <name>`
- Missing planning docs → list which, explain contents
- Dependency cycles → show cycle, suggest removal
- Missing tools (jq, rg) → `brew install jq ripgrep`
- Missing runner tools → show which CLI per runners.json
- Story schema/deploy contract violations → show story ID + invalid field

## Step 3: Confirm & Apply

Show summary (N issues, M auto-fixable, K manual). Ask confirmation. Apply fixes, report each.

## Step 4: Manual Guide

For each manual issue: file:line, issue text, concrete fix.

## Step 5: Re-Verify

Run `./scripts/doctor.sh` again. Report "All passing" or "K remaining (manual)".
