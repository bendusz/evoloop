---
name: plan-all
description: Run the full Evoloop planning pipeline — start, area processing, review, red-team, and PM story generation — in sequence with progress tracking
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
---

# Full Planning Pipeline Runner

Run all 5 subphases in order. Stop on any failure.

## Arguments

Parse `$ARGUMENTS`: `--tool <tool>` (default: `claude`), `--max-area-iterations <N>` (default: 5), `--dry-run`.

## Workflow

1. **Preflight**: `./scripts/doctor.sh --planning-only --skip-runner-tools`. Fail → suggest `/doctor-fix`, stop.
2. **Plan Start**: `./orchestrator.sh plan start --tool <tool>`. Verify `.plan/areas.md` exists after.
3. **Area Processing**: Parse `.plan/areas.md` table. For each non-approved/locked area, run `./orchestrator.sh plan area --area <name> --tool <tool>`. Re-read status after each; retry up to max iterations. If area doesn't reach approved → report and stop.
4. **Review**: `./orchestrator.sh plan review --tool <tool>`
5. **Red-Team**: `./orchestrator.sh plan redteam --tool <tool>`
6. **PM Stories**: `./orchestrator.sh plan pm --tool <tool>`
7. **Final Validation**: `./scripts/doctor.sh` (full). Pass → show counts, suggest `./orchestrator.sh run`. Fail → suggest `/validate`.

## Dry Run

Run preflight only, show areas that would be processed, print command sequence, note already-approved areas.

## Error Recovery

Show full output, identify failed step (e.g., "Failed at Step 3/6: Area Processing (area: backend)"), suggest manual retry command. Re-running `/plan-all` skips already-approved areas.
