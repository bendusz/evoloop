---
name: status
description: Show the current Evoloop pipeline state at a glance — phase, planning progress, implementation progress, blockers, and next suggested action
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(jq *)
---

# Pipeline Status Dashboard

## Data Collection (parallel)

1. **Pipeline state**: `.state/pipeline.json` → `phase`, `stage`, `currentStory`, `lastAgent`, `lastRunId`, `updatedAt`
2. **Stories**: Glob `prd/US-*.json` → extract `id`, `title`, `.stage` (top-level), `priority`, `riskTier`, `sizing`, `status.deploy.attempts`
3. **Areas**: `.plan/areas.md` → parse table for name, status, priority, criticality, open_questions
4. **Planning docs**: Check existence of 8 required docs in `.plan/`: `areas.md`, `work-breakdown.md`, `traceability.md`, `runbook.md`, `decisions.md`, `assumptions.md`, `dependencies.md`, `risk-register.md`
5. **Lock**: Check `.state/.pipeline.lock` directory exists

**Edge cases**: No `pipeline.json` → "Not initialized, run `bootstrap-plan.sh`". No stories → skip implementation. No `areas.md` → skip planning.

## Output

```
=== Evoloop Pipeline Status ===
Updated: <updatedAt>  |  Lock: <Active/None>

--- Pipeline ---
Phase: <phase>  |  Stage: <stage>
Current Story: <currentStory>  |  Last Agent: <lastAgent>  |  Last Run: <lastRunId>

--- Planning Progress ---
Documents: <N>/8 complete  [x] areas.md  [ ] assumptions.md ...
Areas: <N approved/locked>/<total>
  | Area | Status | Priority | Criticality | Open Questions |

--- Implementation Progress ---
Stories: <complete>/<total>
  | ID | Title | Stage | Risk | Size | Deploy Attempts |
By stage: build: N | review: N | deploy: N | complete: N | blocked: N

--- Blockers ---
<Blocked stories with deploy.notes or "No blockers">

--- Next Action ---
```

## Next Action Logic

- Not initialized → `./scripts/bootstrap-plan.sh`
- Docs incomplete → `./orchestrator.sh plan start --tool claude`
- Areas unapproved → `./orchestrator.sh plan area --area <name> --tool claude`
- No stories → `./orchestrator.sh plan pm --tool claude`
- Incomplete stories → `./orchestrator.sh run --tool claude`
- Blocked → `/reset-story <ID>` or `/inspect <ID>`
- All complete → "Pipeline finished."
- Lock active → "Pipeline running. Check `/logs`"
