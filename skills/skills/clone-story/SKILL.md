---
name: clone-story
description: Clone an existing Evoloop story as a template for a new one — copies structure, resets status, prompts for changes to title, requirements, and dependencies
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

## Input

Source story ID from `$ARGUMENTS`. If empty → print usage. If missing → list available stories.

## Workflow

1. **Read Source**: `prd/<ID>.json` → display summary (title, area, risk, sizing, autonomy, requirements, dependencies)
2. **Next ID**: Find max US-XXX in `prd/`, increment, zero-pad to 3 digits
3. **Gather Changes**: Ask interactively:
   - Title (required)
   - Area: keep or change
   - Priority
   - Requirements: keep, add, or remove
   - Dependencies: keep, add, or remove (suggest source story as potential dep)
   - Risk/Sizing/Autonomy: keep or change each
   - Deploy Safety: keep or change
4. **Build JSON**: New ID, user changes, preserved fields. `.stage` = `"build"` (top-level). Fresh status block (all passes false, attempts 0, empty validation arrays)
5. **Preview**: Show JSON, highlight changes from source. Confirm.
6. **Write**: `prd/<new-ID>.json` (atomic: jq → temp → mv). `prd/<new-ID>.md` from template or basic tracker.
7. **Validate**: Same checks as `validate_story_schema()`
8. **Summary**: Files created, cloned from, next command: `./orchestrator.sh run --tool claude --story <ID>`
