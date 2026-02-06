# Skills

Claude Code skills now live in `.claude/skills/`. See that directory for all available skills.

## Available Skills

### Tier 1 — Core Workflow
| Command | Description |
|---------|-------------|
| `/status` | Pipeline dashboard — phase, progress, blockers, next action |
| `/inspect US-XXX` | Deep-dive into a story's state, deps, logs, and verification |
| `/plan-all` | Run the full planning pipeline (start → areas → review → redteam → pm) |
| `/reset-story US-XXX` | Safely reset a blocked story back to build stage |

### Tier 2 — Significant Value
| Command | Description |
|---------|-------------|
| `/trace REQ-XXX` | Trace a requirement end-to-end through the pipeline |
| `/deps [US-XXX]` | Visualize story dependency graph with Mermaid flowchart |
| `/doctor-fix` | Run doctor checks and auto-fix common issues |
| `/new-story` | Interactive story creator with schema validation |

### Tier 3 — Situational
| Command | Description |
|---------|-------------|
| `/logs [US-XXX\|last\|run-ID]` | View pipeline run logs |
| `/context-size US-XXX` | Estimate prompt size for a story |
| `/clone-story US-XXX` | Clone a story as template for a new one |
| `/test-runbook` | Validate runbook commands are executable |
| `/area-status [area]` | Check planning area readiness |
| `/validate [artifact]` | Incremental planning artifact validation |
