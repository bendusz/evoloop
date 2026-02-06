---
name: new-story
description: Interactively create a new Evoloop story — auto-generates next ID, validates requirements and dependencies, writes both JSON and markdown files
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(jq *)
  - Bash(mv *)
  - Write
---

# Interactive Story Creator

## Step 1: Next ID

Glob `prd/US-*.json`, find max number, increment, zero-pad to 3 digits. Default: US-001.

## Step 2: Gather Details

Ask for each field interactively:

1. **Title**: free text
2. **Area**: show areas from `.plan/areas.md` if exists, pick or custom
3. **Priority**: integer, show existing for context
4. **Risk Tier**: `low` | `medium` | `high`
5. **Sizing**: `small` | `medium` | `large`
6. **Autonomy**: `auto_deploy` | `gated_deploy`
7. **Requirements**: show REQ-### from `.plan/work-breakdown.md`, validate format
8. **Dependencies**: show existing stories, validate each exists
9. **Deploy Safety**: `strategy` (string), `healthChecks` (array), `rollbackTrigger` (string), `rollbackCommand` (string), `verification` (array)

## Step 3: Build JSON

Schema: `id`, `title`, `area`, `priority`, `riskTier`, `sizing`, `autonomy`, `requirements[]`, `dependencies[]`, `stage: "build"` (top-level), `deploySafety{}`, `context{}` (workBreakdown, traceability, runbook, areaDoc, files[]), `status{}` (planning, build, review, test, validation, deploy — all fresh/empty). Reference `.plan/templates/story.template.json` for exact shape.

## Step 4: Preview & Confirm

Show complete JSON. Confirm before writing.

## Step 5: Write Files

1. `prd/<ID>.json` via atomic write (jq → temp → mv)
2. `prd/<ID>.md` from `.plan/templates/story-tracker.template.md` (substitute ID/title), or basic tracker

## Step 6: Validate

Check: required fields present, riskTier/sizing/autonomy enum values, requirements match `REQ-###`, deploySafety subfields complete.

## Step 7: Summary

```
Story created: <US-XXX> — <title>
  Files: prd/<ID>.json, prd/<ID>.md
  Area: <area> | Risk: <risk> | Size: <size>
  Requirements: <N> | Dependencies: <N>
Next: ./orchestrator.sh run --tool claude --story <ID>
```
