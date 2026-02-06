---
name: inspect
description: Deep-dive into a specific story's state — stage, failures, dependencies, last agent output, requirement verification, and suggested next action
argument-hint: "<US-XXX>"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(jq *)
---

# Story Inspector

Provide a deep-dive into a specific Ralphio story.

## Input

The story ID is provided as `$ARGUMENTS`. It must match format `US-` followed by a zero-padded 3-digit number (e.g., `US-001`).

## Validation

1. If `$ARGUMENTS` is empty, print usage and stop:
   ```
   Usage: /inspect <US-XXX>
   Example: /inspect US-001
   ```
2. If the story file `prd/$ARGUMENTS.json` does not exist, list available stories and stop.

## Data Collection

Read these files:

1. **Story JSON**: `prd/<ID>.json` — extract all fields
2. **Story tracker**: `prd/<ID>.md` — read for agent commentary
3. **Dependency stories**: For each ID in the `dependencies` array, read its JSON to get `id`, `title`, `.stage` (top-level field)
4. **Dependents**: Search all `prd/US-*.json` for stories that list this ID in their `dependencies` array
5. **Logs**: Use Grep to search `.log/run-*/run.md` for the story ID. Read matching files to extract agent activity
6. **Pipeline state**: Read `.state/pipeline.json` to check if this is the `currentStory`

## Output Format

```
=== Story: <ID> — <title> ===

--- Details ---
Area: <area>  |  Priority: <priority>
Risk: <riskTier>  |  Size: <sizing>  |  Autonomy: <autonomy>

--- Current State ---
Stage: <stage>
Deploy attempts: <status.deploy.attempts>/3
Deploy notes: <status.deploy.notes or "none">
Pipeline status: <"Currently active" if currentStory matches, else "Not active">

--- Requirements ---
| REQ ID  | Implemented | Verified |
|---------|-------------|----------|
| REQ-001 | Yes         | No       |
| REQ-002 | No          | No       |

--- Dependencies (upstream) ---
<For each dependency:>
  <US-XXX> — <title> [<stage>]  <"BLOCKING" if stage != complete, else "OK">
<If no dependencies: "None">

--- Dependents (downstream) ---
<For each story that depends on this one:>
  <US-XXX> — <title> [<stage>]  <"WAITING" if this story != complete>
<If no dependents: "None">

--- Deploy Safety Contract ---
Strategy: <deploySafety.strategy>
Health Checks: <deploySafety.healthChecks joined>
Rollback Trigger: <deploySafety.rollbackTrigger>
Rollback Command: <deploySafety.rollbackCommand>
Verification: <deploySafety.verification joined>

--- Recent Log Activity ---
<For each matching run, most recent first (max 5):>
  Run <run-ID>: <agent> | <outcome (success/failed with exit code)>
<If no log entries: "No log activity found for this story">

--- Tracker Notes ---
<Summary of key content from the .md tracker file, or "Tracker file not found">

--- Suggested Next Action ---
<Based on current stage:>
```

## Next Action Logic

- `build`: "Story is ready for building. Run `./orchestrator.sh run --tool claude --story <ID>`"
- `review`: "Story is in code review/test. Run `./orchestrator.sh run --tool claude --story <ID>`"
- `deploy`: "Story is ready for deployment. Run `./orchestrator.sh run --tool claude --story <ID> --approve-deploy <ID>`" (if gated)
- `complete`: "Story is complete. No action needed."
- `blocked`: "Story is blocked after <N> deploy attempts. Review deploy notes above. Use `/reset-story <ID>` to retry or investigate the failure."
- If upstream dependency is not complete: "Blocked by dependency <US-XXX> which is at stage <stage>. That story must complete first."
