---
name: clone-story
description: Clone an existing Ralphio story as a template for a new one — copies structure, resets status, prompts for changes to title, requirements, and dependencies
argument-hint: "<US-XXX>"
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(jq *)
  - Bash(mv *)
  - Write
---

# Story Cloner

Clone an existing story as a template for a new story.

## Input

The source story ID is provided as `$ARGUMENTS`.

## Validation

1. If empty, print usage: `/clone-story <US-XXX>`
2. If `prd/$ARGUMENTS.json` doesn't exist, list available stories and stop.

## Step 1: Read Source Story

Read `prd/<source-ID>.json` and display a summary:

```
Source story: <ID> — <title>
  Area: <area> | Risk: <riskTier> | Size: <sizing> | Autonomy: <autonomy>
  Requirements: <requirements list>
  Dependencies: <dependencies list>
```

## Step 2: Determine New Story ID

Find the highest existing US-XXX number in `prd/` and increment by 1. Zero-pad to 3 digits.

Print: "New story ID: <US-XXX>"

## Step 3: Gather Changes

Use AskUserQuestion to ask what the user wants to change:

1. **Title** (required): "What is the title for the new story?"
2. **Area**: "Keep area '<source-area>' or change?" Options: keep current, specify new
3. **Priority**: "What priority? (source was <N>)"
4. **Requirements**: "Keep same requirements or modify?" Show current list, allow add/remove
5. **Dependencies**: "Keep same dependencies or modify?" Show current list plus the source story as a potential new dependency. Allow add/remove.
6. **Risk/Sizing/Autonomy**: "Keep same risk tier, sizing, and autonomy levels?" If no, ask for each.
7. **Deploy Safety**: "Keep same deploy safety contract?" If no, ask for each field.

## Step 4: Build New Story JSON

Create the new story with:
- New ID
- User-provided title
- Preserved or modified fields from source
- Top-level `.stage` set to `"build"` (stage is a top-level field, not nested in status)
- Fresh status block matching the template: `status.deploy.attempts: 0`, all `passes: false`, empty validation arrays

## Step 5: Preview and Confirm

Show the complete new story JSON. Highlight what changed from source:

```
=== Clone Summary ===
Cloned from: <source-ID>
New story: <new-ID> — <new-title>

Changes from source:
  - title: "<old>" → "<new>"
  - Added dependency: US-003
  - Removed requirement: REQ-002
  - Status: reset to build (was: <source-stage>)
```

Ask for confirmation.

## Step 6: Write Files

1. Write `prd/<new-ID>.json` using atomic pattern (jq → temp file → mv)
2. Create `prd/<new-ID>.md` tracker from `.plan/templates/story-tracker.template.md` (substituting ID and title), or create a basic one if template doesn't exist

## Step 7: Validate

Validate the new story JSON against the schema (same checks as `validate_story_schema()`). Report any issues.

## Step 8: Summary

```
Story cloned: <new-ID> — <new-title>
  Files: prd/<new-ID>.json, prd/<new-ID>.md
  Cloned from: <source-ID>

Next: Run `./orchestrator.sh run --tool claude --story <new-ID>` to start implementation.
```
