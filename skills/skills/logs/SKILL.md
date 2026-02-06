---
name: logs
description: Show log output from Evoloop pipeline runs — latest run summary, specific story logs, last agent invocation, or a specific run
argument-hint: "[US-XXX | last | run-YYYYMMDD-HHMMSS]"
allowed-tools:
  - Read
  - Glob
  - Grep
---

# Run Log Viewer

## Mode (from `$ARGUMENTS`)

| Argument | Mode |
|----------|------|
| (empty) | Latest run summary |
| `last` | Last agent invocation from most recent run |
| `run-YYYYMMDD-HHMMSS` | Specific run log |
| `US-XXX` | All log entries for that story across runs |
| anything else | Usage help |

## Log Structure

- `.log/run-YYYYMMDD-HHMMSS/run.md` — agent invocations
- `.log/run-YYYYMMDD-HHMMSS/context-pack.md` — files given to agents
- `.log/run-<id>/handoff-notes.md` — may exist per run
- `.state/pipeline.json` → `lastRunId`

Key patterns in `run.md`: `Runner: <agent> -> <command>`, `Agent failure: <agent> exit=<code> story=<id>`, `## Crashed`, `Start:`, `Resume:`

## Latest Run (no args)

Read `pipeline.json` for `lastRunId`, then `run.md` + `context-pack.md`. Show: run ID, start time, resume status, agent activity (agent/story/outcome), context pack, pipeline state.

## Last Agent (`last`)

Find latest run, extract last `Runner:` line + any `Agent failure:` line. Show: run, agent, runner command, story, outcome.

## Specific Run (`run-...`)

Same as latest run format. If >200 lines → first 30 + "truncated" + last 30. If not found → list available runs.

## Story Logs (`US-XXX`)

Grep all `run.md` and `context-pack.md` for story ID. Per matching run: run ID, agent, outcome, stage. Reverse chronological.

## Errors

No runs → "Run `./orchestrator.sh run --tool claude`". Run not found → list available. No matches → "No entries for {ID}".
