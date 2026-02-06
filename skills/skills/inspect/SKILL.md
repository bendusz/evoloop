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

## Input

Story ID from `$ARGUMENTS` (format: `US-XXX`). If empty → print usage. If `prd/$ARGUMENTS.json` missing → list available stories.

## Data Collection

1. **Story JSON**: `prd/<ID>.json` — all fields. `.stage` is top-level.
2. **Tracker**: `prd/<ID>.md`
3. **Dependencies**: For each in `dependencies` array → read JSON for `id`, `title`, `.stage`
4. **Dependents**: Search all `prd/US-*.json` for stories listing this ID in `dependencies`
5. **Logs**: Grep `.log/run-*/run.md` for story ID
6. **Pipeline**: `.state/pipeline.json` → check if `currentStory` matches

## Output

```
=== Story: <ID> — <title> ===
Area: <area> | Priority: <priority> | Risk: <riskTier> | Size: <sizing> | Autonomy: <autonomy>

Stage: <stage> | Deploy attempts: <status.deploy.attempts>/3 | Deploy notes: <notes>
Pipeline: <"Active" / "Not active">

Requirements: | REQ ID | Implemented | Verified |
Dependencies (upstream): <ID> — <title> [<stage>] BLOCKING/OK
Dependents (downstream): <ID> — <title> [<stage>] WAITING/OK
Deploy Safety: strategy, healthChecks, rollbackTrigger, rollbackCommand, verification
Recent Logs (max 5): Run <ID>: <agent> | <outcome>
Tracker Notes: <summary from .md>
```

## Next Action

- `build`/`review` → `./orchestrator.sh run --tool claude --story <ID>`
- `deploy` (gated) → `./orchestrator.sh run --tool claude --story <ID> --approve-deploy <ID>`
- `complete` → No action
- `blocked` → Review notes, `/reset-story <ID>`
- Upstream incomplete → "Blocked by <US-XXX> at <stage>"
