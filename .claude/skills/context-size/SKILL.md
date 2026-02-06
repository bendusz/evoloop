---
name: context-size
description: Estimate the total prompt size that will be sent to an AI agent when processing a Ralphio story — warns if approaching model context limits
argument-hint: "<US-XXX>"
allowed-tools:
  - Read
  - Glob
  - Bash(wc *)
  - Bash(jq *)
---

# Context Size Analyzer

Estimate total prompt size for a story to prevent exceeding model context limits.

## Input

The story ID is provided as `$ARGUMENTS`.

## Validation

1. If empty, print usage: `/context-size <US-XXX>`
2. If `prd/$ARGUMENTS.json` doesn't exist, list available stories and stop.

## Size Calculation

Read the story JSON to determine its current stage, then calculate the total context that `build_prompt()` in `common.sh` would assemble.

### Files to measure:

| Component | File | Notes |
|-----------|------|-------|
| Agent prompt | `agents/{agent}.md` | Agent determined by stage: build→builder.md, review→reviewer-test.md, deploy→deploy.md |
| Story JSON | `prd/<ID>.json` | |
| Story tracker | `prd/<ID>.md` | |
| Runbook | `.plan/runbook.md` | |
| Traceability | `.plan/traceability.md` | |
| Handoff notes | `.log/handoff-notes.md` | May not exist |
| Context files | Files from story's `context.files` array | If the story JSON has this field |

For each file, get the size in bytes using `wc -c`.

### Model limits reference:

| Model | Approx Token Limit | Approx Byte Limit |
|-------|--------------------|--------------------|
| Claude (Opus/Sonnet) | 200K tokens | ~800KB |
| Gemini 1.5 Pro | 1M tokens | ~4MB |
| Codex (GPT-4) | 128K tokens | ~512KB |

Note: 1 token ≈ 4 bytes is a rough estimate. Actual tokenization varies.

## Output Format

```
=== Context Size: <ID> (stage: <stage>) ===

Agent: <agent>.md

| Component       | File                    | Size (bytes) | Size (KB) | % of Total |
|-----------------|-------------------------|--------------|-----------|------------|
| Agent prompt    | agents/builder.md       | 4,200        | 4.1       | 12%        |
| Story JSON      | prd/US-001.json         | 1,800        | 1.8       | 5%         |
| Story tracker   | prd/US-001.md           | 3,200        | 3.1       | 9%         |
| Runbook         | .plan/runbook.md        | 2,400        | 2.3       | 7%         |
| Traceability    | .plan/traceability.md   | 5,600        | 5.5       | 16%        |
| Handoff notes   | .log/handoff-notes.md   | 1,200        | 1.2       | 3%         |
| Context: src/   | src/auth/index.ts       | 15,000       | 14.6      | 43%        |
| Context: test/  | tests/auth.test.ts      | 1,800        | 1.8       | 5%         |
|-----------------|-------------------------|--------------|-----------|------------|
| **TOTAL**       |                         | **35,200**   | **34.4**  | **100%**   |

--- Model Limit Comparison ---
Claude:  35.2KB / 800KB  (4.4%) — OK
Gemini:  35.2KB / 4,000KB (0.9%) — OK
Codex:   35.2KB / 512KB  (6.9%) — OK

<If total > 50% of any model limit:>
WARNING: Context is large. Consider:
  - Reducing context.files in the story JSON
  - Splitting large context files
  - Summarizing reference material
```

## Edge Cases

- Missing files: Show "NOT FOUND" in the table, count as 0 bytes, warn
- No `context.files` field: Skip that section, note it
- Very large total (>500KB): Prominently warn about potential issues with smaller models
