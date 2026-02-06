---
name: reset-story
description: Safely reset a blocked or failed Ralphio story back to the build stage — clears deploy attempts and failure notes while preserving verification data
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

Safely reset a blocked or failed story back to the `build` stage.

## Input

The story ID is provided as `$ARGUMENTS`.

## Validation

1. If `$ARGUMENTS` is empty, print usage and stop:
   ```
   Usage: /reset-story <US-XXX>
   Example: /reset-story US-003
   ```
2. If `prd/$ARGUMENTS.json` does not exist, list available stories and stop.

## Pre-Reset State

Read `prd/<ID>.json` and display the current state:

```
=== Current State: <ID> ===
Title: <title>
Stage: <stage>
Deploy attempts: <status.deploy.attempts>
Deploy notes: <status.deploy.notes>
Requirements implemented: <status.validation.requirementsImplemented>
Requirements verified: <status.validation.requirementsVerified>
```

If the story stage is `complete`, warn:
"This story is already complete. Resetting it will re-run it through the entire build/review/deploy cycle. Are you sure?"

If the story stage is `build` with 0 deploy attempts, inform:
"This story is already at the build stage with no deploy attempts. No reset needed."
Stop here unless the user confirms they want to proceed anyway.

## Confirmation

Ask the user for confirmation before proceeding:
"Reset <ID> from stage '<stage>' to 'build'? This will clear deploy attempts and notes."

## Reset Operation

Use jq to update the story JSON with these changes:
- Set `.stage` to `"build"` (top-level field, NOT `.status.stage`)
- Set `.status.deploy.attempts` to `0`
- Set `.status.deploy.notes` to `""`
- Set `.status.deploy.passes` to `false`
- Set `.status.build.passes` to `false`
- Set `.status.build.notes` to `""`
- Set `.status.review.passes` to `false`
- Set `.status.review.notes` to `""`
- **Preserve** `.status.validation` entirely (requirementsImplemented, requirementsVerified, notes)
- **Preserve** all other fields unchanged

Use the project's atomic write convention:

```bash
jq '.stage = "build" | .status.deploy.attempts = 0 | .status.deploy.notes = "" | .status.deploy.passes = false | .status.build.passes = false | .status.build.notes = "" | .status.review.passes = false | .status.review.notes = ""' prd/<ID>.json > prd/<ID>.json.tmp.$$ && mv prd/<ID>.json.tmp.$$ prd/<ID>.json
```

## Post-Reset Verification

Read the updated JSON and display:

```
=== Reset Complete: <ID> ===
Stage: build (was: <old-stage>)
Deploy attempts: 0 (was: <old-attempts>)
Deploy notes: cleared
Requirements implemented: <preserved list>
Requirements verified: <preserved list>

Note: Review prd/<ID>.md tracker — it may contain agent notes from the previous attempt.
Next: Run `./orchestrator.sh run --tool claude --story <ID>` to re-process this story.
```
