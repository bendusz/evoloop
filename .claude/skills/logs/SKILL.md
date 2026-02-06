---
name: logs
description: Show log output from Ralphio pipeline runs — latest run summary, specific story logs, last agent invocation, or a specific run
argument-hint: "[US-XXX | last | run-YYYYMMDD-HHMMSS]"
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Run Log Viewer

Read pipeline run logs and present them in a readable format.

## Determine Mode

Parse `$ARGUMENTS`:

1. **Empty**: Show the latest run log summary
2. **`last`**: Show the last agent invocation from the most recent run
3. **`run-YYYYMMDD-HHMMSS`** (starts with `run-`): Show that specific run's log
4. **`US-XXX`** (starts with `US-`): Show all log entries for that story across all runs
5. **Anything else**: Show usage help

## How to Find Logs

- **Log directory**: `.log/` contains run directories named `run-YYYYMMDD-HHMMSS/`
- **Run log**: Each run directory has `run.md` with agent invocations
- **Context pack**: Each run directory has `context-pack.md` listing files given to agents
- **Handoff notes**: `.log/handoff-notes.md` persists across runs
- **Pipeline state**: `.state/pipeline.json` has `lastRunId`

Use Glob with `.log/run-*/run.md` to discover runs. Sort reverse-chronologically by directory name.

## Log File Format

Key patterns in `run.md`:
- `Runner: <agent> -> <command>` — agent invocation
- `Agent failure: <agent> exit=<code> story=<id> time=<timestamp>` — failure
- `## Crashed` section — abnormal termination
- `Start: <timestamp>` — run start time
- `Resume: true|false` — resumed run indicator

## Mode: Latest Run Summary (no arguments)

1. Read `.state/pipeline.json` for `lastRunId`
2. Read `.log/run-{lastRunId}/run.md` and `context-pack.md`
3. Present:

```
=== Run: run-20260205-221930 ===
Started: Thu Feb  5 22:19:30 GMT 2026
Resume: no

--- Agent Activity ---
1. builder -> claude --model opus ...
   Story: US-001 | Outcome: FAILED (exit 1)

2. reviewer-test -> tool=claude (builtin)
   Story: US-002 | Outcome: success

--- Context Pack ---
- builder - US-001: prd/US-001.json, prd/US-001.md, .plan/runbook.md

--- Pipeline State ---
Phase: run | Stage: run
Current story: US-001 | Last agent: builder
```

## Mode: Last Agent Invocation (`last`)

1. Find latest run directory
2. Find the last `Runner:` line in `run.md`
3. Check for corresponding `Agent failure:` line
4. Present:

```
=== Last Agent Invocation ===
Run: run-20260205-221930
Agent: builder
Runner: claude --model opus ...
Story: US-001
Outcome: FAILED (exit 1)
```

## Mode: Specific Run (`run-YYYYMMDD-HHMMSS`)

1. Check if `.log/{argument}/run.md` exists. If not, list available runs.
2. Present same format as latest run summary
3. If content exceeds 200 lines, show first 30 + "... truncated ..." + last 30

## Mode: Story Logs (`US-XXX`)

1. Grep all `.log/run-*/run.md` and `.log/run-*/context-pack.md` for the story ID
2. For each matching run, extract: run ID, agent, outcome, stage
3. Present reverse-chronologically:

```
=== Logs for US-001 ===

--- run-20260205-221930 ---
Agent: builder | Stage: build
Outcome: FAILED (exit 1)

--- run-20260205-214200 ---
Agent: builder | Stage: build
Outcome: success
```

## Error Handling

- No `.log/` or no runs: "No pipeline runs found. Run `./orchestrator.sh run --tool claude` to start."
- Specified run not found: list available runs
- No matches for story: "No log entries found for {ID}."
- Pipeline state missing: note pipeline not initialized
