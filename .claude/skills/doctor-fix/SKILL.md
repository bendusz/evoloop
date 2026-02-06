---
name: doctor-fix
description: Run Ralphio doctor checks and auto-fix common issues — missing directories, non-executable scripts, missing templates, and provide remediation for manual fixes
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

Run diagnostic checks and auto-fix what can be safely fixed.

## Step 1: Run Doctor

Run `./scripts/doctor.sh --verbose` and capture the full output.

If doctor.sh itself doesn't exist or isn't executable, report:
"doctor.sh not found or not executable. Run `./scripts/bootstrap-plan.sh` to initialize the project."

## Step 2: Parse Results

Categorize each issue from doctor output as either **auto-fixable** or **manual**.

### Auto-fixable issues:

| Issue | Fix |
|-------|-----|
| Missing directory (`.log/`, `.state/`, `.plan/areas/`, `.plan/templates/`) | `mkdir -p <dir>` |
| Script not executable | `chmod +x <script>` |
| Missing template files in `.plan/templates/` | Run `./scripts/bootstrap-plan.sh` |
| Malformed JSON (fixable formatting) | Read with jq, rewrite formatted |

### Manual issues (provide detailed remediation):

| Issue | Guidance |
|-------|----------|
| TODO/TBD/FIXME in planning docs | Show exact file:line, suggest replacement text |
| Missing REQ-### IDs in work-breakdown.md | Show where to add them, reference existing IDs |
| Areas not approved/locked | List unapproved areas, suggest `./orchestrator.sh plan area --area <name>` |
| Missing planning docs | List which, explain what each should contain |
| Dependency cycles | Show the cycle, suggest which dependency to remove |
| Missing core tools (jq, rg) | Suggest `brew install jq ripgrep` |
| Missing runner tools | Show which CLI is missing based on runners.json config |
| Story schema violations | Show the story ID and specific field that's invalid |
| Deploy contract issues | Show story ID and missing deploy safety fields |

## Step 3: Confirm and Apply Auto-Fixes

Show a summary before applying:

```
=== Doctor Results ===
Issues found: <N>
  Auto-fixable: <M>
  Manual: <K>

Auto-fixes to apply:
  1. mkdir -p .log/
  2. chmod +x scripts/plan.sh
  3. Run bootstrap-plan.sh for missing templates
```

Ask for confirmation: "Apply <M> auto-fixes?"

Apply each fix and report success/failure.

## Step 4: Manual Remediation Guide

For each manual issue, provide:

```
--- Manual Fix Required ---

Issue: TODO found in .plan/runbook.md
  File: .plan/runbook.md:42
  Text: "TODO: Add deploy command"
  Fix: Replace with the actual deploy command for your project

Issue: Area 'backend' not approved
  Current status: probing
  Fix: Run `./orchestrator.sh plan area --area backend --tool claude`
```

## Step 5: Re-Verify

After applying auto-fixes, run `./scripts/doctor.sh` again.

```
=== Post-Fix Verification ===
<If all pass:> "All checks passing!"
<If remaining:> "<K> issues remaining (all require manual intervention)"
```
