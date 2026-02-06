---
name: status
description: Show the current Ralphio pipeline state at a glance — phase, planning progress, implementation progress, blockers, and next suggested action
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(jq *)
---

# Pipeline Status Dashboard

Show a comprehensive status overview of the Ralphio pipeline.

## Data Collection

Gather data from these sources in parallel:

1. **Pipeline state**: Read `.state/pipeline.json` for `phase`, `stage`, `currentStory`, `lastAgent`, `lastRunId`, `updatedAt`
2. **Stories**: Use Glob to find all `prd/US-*.json` files. For each, extract `id`, `title`, `.stage` (top-level field), `priority`, `riskTier`, `sizing`, `status.deploy.attempts` using jq
3. **Areas**: Read `.plan/areas.md` and parse the markdown table for area name, status, priority, criticality, and open_questions columns
4. **Planning docs**: Check existence of all 8 required planning docs in `.plan/`: `areas.md`, `dependencies.md`, `risk-register.md`, `decision-log.md`, `work-breakdown.md`, `traceability.md`, `runbook.md`, `critical-path.md`
5. **Lock**: Check if `.state/.pipeline.lock` directory exists (indicates pipeline is currently running)

## Edge Cases

- If `.state/pipeline.json` does not exist: report "Pipeline not initialized. Run `./scripts/bootstrap-plan.sh` to set up the project."
- If no `prd/US-*.json` files exist: skip implementation section, note "No stories generated yet"
- If `.plan/areas.md` does not exist: skip planning section, note "Planning not started"

## Output Format

Print a dashboard with these sections:

```
=== Ralphio Pipeline Status ===
Updated: <updatedAt from pipeline.json>
Lock: <Active / None>

--- Pipeline ---
Phase: <phase>  |  Stage: <stage>
Current Story: <currentStory or "none">
Last Agent: <lastAgent>  |  Last Run: <lastRunId>

--- Planning Progress ---
Documents: <N>/8 complete
  [x] areas.md
  [x] runbook.md
  [ ] critical-path.md   <-- missing
  ...

Areas: <N approved/locked> / <total>
  | Area | Status | Priority | Criticality | Open Questions |
  |------|--------|----------|-------------|----------------|
  | ...  | ...    | ...      | ...         | ...            |

--- Implementation Progress ---
Stories: <complete>/<total> complete

  | ID     | Title            | Stage   | Risk | Size   | Deploy Attempts |
  |--------|------------------|---------|------|--------|-----------------|
  | US-001 | Setup auth       | review  | high | medium | 0               |
  | US-002 | Add logging      | complete| low  | small  | 0               |
  | US-003 | Deploy infra     | blocked | high | large  | 3               |

By stage:
  build: N  |  review: N  |  deploy: N  |  complete: N  |  blocked: N

--- Blockers ---
<List any blocked stories with their deploy.notes or "No blockers">

--- Next Action ---
<Suggest the next command to run based on current state>
```

## Next Action Logic

Determine the suggested next action based on pipeline state:

- If pipeline not initialized: "Run `./scripts/bootstrap-plan.sh`"
- If planning docs incomplete: "Run `./orchestrator.sh plan start --tool claude`"
- If areas not all approved: "Run `./orchestrator.sh plan area --area <first-unapproved> --tool claude`"
- If planning docs complete but no stories: "Run `./orchestrator.sh plan pm --tool claude`"
- If stories exist with incomplete ones: "Run `./orchestrator.sh run --tool claude`"
- If blocked stories exist: "Consider `/reset-story <US-XXX>` for blocked stories, or review failure notes with `/inspect <US-XXX>`"
- If all stories complete: "All stories complete! Pipeline finished."
- If lock is active: "Pipeline is currently running. Wait for it to finish or check logs with `/logs`"
