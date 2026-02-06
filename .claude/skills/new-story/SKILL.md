---
name: new-story
description: Interactively create a new Ralphio story — auto-generates next ID, validates requirements and dependencies, writes both JSON and markdown files
disable-model-invocation: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(jq *)
  - Bash(mv *)
  - Write
---

# Interactive Story Creator

Walk the user through creating a new story with proper schema validation.

## Step 1: Determine Next Story ID

Use Glob to find all `prd/US-*.json` files. Extract the numeric portion of each ID, find the maximum, and increment by 1. Zero-pad to 3 digits. If no stories exist, start with US-001.

Print: "Next story ID: <US-XXX>"

## Step 2: Gather Story Details

Ask the user for each field. Use the AskUserQuestion tool for fields with meaningful choices.

### Required fields:

1. **Title**: Ask as free text. This should be a concise description of what the story delivers.

2. **Area**: If `.plan/areas.md` exists, parse it to show available areas. Ask the user to pick one or enter a custom area.

3. **Priority**: Ask for an integer. Show existing story priorities for context.

4. **Risk Tier**: Ask with options: `low`, `medium`, `high`. Explain: low = routine change, medium = touches critical paths, high = infrastructure or security-sensitive.

5. **Sizing**: Ask with options: `small`, `medium`, `large`. Explain: small = hours, medium = 1-2 days, large = 3+ days.

6. **Autonomy**: Ask with options: `auto_deploy`, `gated_deploy`. Explain: auto_deploy = agent can deploy without approval, gated_deploy = requires human `--approve-deploy` flag.

7. **Requirements**: Read `.plan/work-breakdown.md` and show available REQ-### IDs. Ask which to assign. Validate each ID exists in work-breakdown.md. Must be an array of `REQ-XXX` strings.

8. **Dependencies**: Show existing stories with their IDs and titles. Ask which this story depends on. Validate each dependency exists as a story file.

9. **Deploy Safety Contract**:
   - `strategy`: Ask for deploy strategy (e.g., "rolling update", "blue-green", "canary")
   - `healthChecks`: Ask for health check commands/URLs (array of strings)
   - `rollbackTrigger`: Ask what condition triggers rollback
   - `rollbackCommand`: Ask for the rollback command
   - `verification`: Ask for post-deploy verification steps (array of strings)

## Step 3: Build the JSON

Construct the story JSON:

```json
{
  "id": "<US-XXX>",
  "title": "<title>",
  "area": "<area>",
  "priority": <priority>,
  "riskTier": "<low|medium|high>",
  "sizing": "<small|medium|large>",
  "autonomy": "<auto_deploy|gated_deploy>",
  "requirements": ["REQ-001", "REQ-002"],
  "dependencies": ["US-001"],
  "stage": "build",
  "deploySafety": {
    "strategy": "<strategy>",
    "healthChecks": ["<check1>", "<check2>"],
    "rollbackTrigger": "<trigger>",
    "rollbackCommand": "<command>",
    "verification": ["<step1>", "<step2>"]
  },
  "context": {
    "workBreakdown": ".plan/work-breakdown.md",
    "traceability": ".plan/traceability.md",
    "runbook": ".plan/runbook.md",
    "areaDoc": ".plan/areas/<area>.md",
    "files": []
  },
  "status": {
    "planning": { "passes": true, "notes": "" },
    "build": { "passes": false, "branch": "", "commit": "", "notes": "" },
    "review": { "passes": false, "branch": "", "commit": "", "notes": "" },
    "test": { "passes": false, "command": "", "result": "", "notes": "" },
    "validation": {
      "requirementsImplemented": [],
      "requirementsVerified": [],
      "notes": ""
    },
    "deploy": { "passes": false, "attempts": 0, "target": "", "result": "", "rollback": "", "notes": "" }
  }
}
```

## Step 4: Preview and Confirm

Show the complete JSON to the user for review. Ask for confirmation before writing.

## Step 5: Write Files

1. Write `prd/<ID>.json` using the atomic pattern: write to temp file with jq, then mv
2. Read `.plan/templates/story-tracker.template.md` if it exists. Use it as a template for `prd/<ID>.md`, substituting the story ID and title. If no template, create a basic tracker markdown with the story details.

## Step 6: Validate

Run the same validation that `validate_story_schema()` performs:
- Check all required fields present
- Check riskTier is low|medium|high
- Check sizing is small|medium|large
- Check autonomy is auto_deploy|gated_deploy
- Check requirements match REQ-### format
- Check deploySafety has all subfields

Report validation result. If any issues, offer to fix them.

## Step 7: Summary

```
Story created: <US-XXX> — <title>
  Files: prd/<ID>.json, prd/<ID>.md
  Area: <area> | Risk: <risk> | Size: <size>
  Requirements: <N> | Dependencies: <N>

Next: Run `./orchestrator.sh run --tool claude --story <ID>` to start implementation.
```
