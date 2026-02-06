---
name: reset-story
description: Safely reset a blocked or failed Evoloop story back to the build stage — clears deploy attempts and failure notes while preserving verification data
argument-hint: "<US-XXX>"
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Bash(jq *)
  - Bash(mv *)
  - Write
---

# Story Reset Helper

## Input

Story ID from `$ARGUMENTS`. If empty → print usage. If `prd/$ARGUMENTS.json` missing → list available stories.

## Pre-Reset

Read and display: title, stage, deploy attempts/notes, validation data. If `complete` → warn about full re-run. If `build` with 0 attempts → "No reset needed", stop.

## Confirm

Ask: "Reset <ID> from '<stage>' to 'build'? Clears deploy attempts and notes."

## Reset

```bash
jq '.stage = "build" | .status.deploy.attempts = 0 | .status.deploy.notes = "" | .status.deploy.passes = false | .status.build.passes = false | .status.build.notes = "" | .status.review.passes = false | .status.review.notes = ""' prd/<ID>.json > prd/<ID>.json.tmp.$$ && mv prd/<ID>.json.tmp.$$ prd/<ID>.json
```

**Critical**: `.stage` is top-level. **Preserve** `.status.validation` entirely.

## Post-Reset

Display old vs new stage, cleared attempts, preserved validation. Suggest: `./orchestrator.sh run --tool claude --story <ID>`
