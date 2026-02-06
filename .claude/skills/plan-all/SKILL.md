---
name: plan-all
description: Run the full Ralphio planning pipeline — start, area processing, review, red-team, and PM story generation — in sequence with progress tracking
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
---

# Full Planning Pipeline Runner

Run all 5 planning subphases in sequence, with preflight checks and progress tracking.

## Arguments

Parse `$ARGUMENTS` for optional flags:
- `--tool <tool>`: AI CLI to use (default: `claude`). Valid: claude, codex, gemini
- `--max-area-iterations <N>`: Max iterations per area (default: 5)
- `--dry-run`: Show what would be executed without running anything

## Workflow

Execute these steps in order. Stop immediately on any failure.

### Step 0: Preflight

Run `./scripts/doctor.sh --planning-only --skip-runner-tools` to verify the environment.

If doctor fails, show the output and suggest running `/doctor-fix` to resolve issues. Stop here.

Print: "Preflight passed. Starting planning pipeline..."

### Step 1: Plan Start

Print: "Step 1/5: Running planning coordinator..."

Run: `./orchestrator.sh plan start --tool <tool>`

If it fails (non-zero exit), show the output and stop with:
"Planning start failed. Check the output above and review `.log/` for details."

After success, verify `.plan/areas.md` exists and has content.

### Step 2: Area Processing

Print: "Step 2/5: Processing areas..."

Read `.plan/areas.md` and parse the markdown table to extract area names from the first column. Skip the header row and any separator rows.

For each area whose status is NOT `approved` or `locked`:

```
  Processing area: <name> (iteration 1/<max>)
```

Run: `./orchestrator.sh plan area --area <name> --tool <tool>`

After each run, re-read `.plan/areas.md` and check the area's status. If now `approved` or `locked`, move to next area. Otherwise, re-run up to `--max-area-iterations` times.

If an area does not reach `approved` after max iterations:
"Area '<name>' did not reach approved status after <N> iterations. Current status: <status>. You may need to run `/area-status` to diagnose or manually advance it."
Stop here.

After all areas are approved, print: "All areas approved."

### Step 3: Plan Review

Print: "Step 3/5: Running cross-area review..."

Run: `./orchestrator.sh plan review --tool <tool>`

If it fails, show output and stop.

### Step 4: Red-Team Review

Print: "Step 4/5: Running adversarial red-team review..."

Run: `./orchestrator.sh plan redteam --tool <tool>`

If it fails, show output and stop.

### Step 5: PM Story Generation

Print: "Step 5/5: Running PM story generation..."

Run: `./orchestrator.sh plan pm --tool <tool>`

If it fails, show output and stop.

### Final Validation

Run `./scripts/doctor.sh` (full check) to validate the complete plan.

If doctor passes:
```
Planning pipeline complete!
  Areas: <N> approved
  Stories: <N> generated in prd/
  Next: Run `./orchestrator.sh run --tool <tool>` to start implementation
```

If doctor fails, show the failures and suggest running `/validate` for details.

## Dry Run Mode

If `--dry-run` is specified, do NOT execute any orchestrator commands. Instead:
1. Run the preflight check
2. Read `.plan/areas.md` to show which areas would be processed
3. Print the full sequence of commands that would be executed
4. Report any areas already approved that would be skipped

## Error Recovery

If any step fails:
1. Show the full error output
2. Show which step failed (e.g., "Failed at Step 2/5: Area Processing (area: backend)")
3. Suggest the manual command to retry just that step
4. Note that you can resume from where you left off by re-running `/plan-all` — already-approved areas will be skipped
