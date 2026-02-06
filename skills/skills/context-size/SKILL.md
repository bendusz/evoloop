---
name: context-size
description: Estimate the total prompt size that will be sent to an AI agent when processing an Evoloop story — warns if approaching model context limits
argument-hint: "<US-XXX>"
allowed-tools:
  - Read
  - Glob
  - Bash(wc *)
  - Bash(jq *)
---

# Context Size Analyzer

## Input

Story ID from `$ARGUMENTS`. If empty → print usage. If missing → list stories.

## Calculation

Read story JSON for stage, then measure all files `build_prompt()` would assemble:

| Component | File | Notes |
|-----------|------|-------|
| Agent prompt | `agents/{agent}.md` | build→builder.md, review→reviewer-test.md, deploy→deploy.md |
| Story JSON | `prd/<ID>.json` | |
| Story tracker | `prd/<ID>.md` | |
| Runbook | `.plan/runbook.md` | |
| Traceability | `.plan/traceability.md` | |
| Handoff notes | `.log/run-<run-id>/handoff-notes.md` | May not exist |
| Context files | From story's `context.files` array | If present |

Size each with `wc -c`.

## Model Limits

| Model | ~Tokens | ~Bytes |
|-------|---------|--------|
| Claude (Opus/Sonnet) | 200K | ~800KB |
| Gemini 1.5 Pro | 1M | ~4MB |
| Codex (GPT-5) | 200K | ~800KB |

(1 token ≈ 4 bytes rough estimate)

## Output

```
=== Context Size: <ID> (stage: <stage>) ===
Agent: <agent>.md

| Component | File | Bytes | KB | % |
...
| TOTAL | | | | 100% |

Model Limits: Claude X/800KB | Gemini X/4000KB | Codex X/800KB
```

Warn if >50% of any model limit. Missing files → "NOT FOUND", 0 bytes. >500KB → prominent warning.
