# Decisions

| id | date | owner | decision | rationale | impact | status |
| --- | --- | --- | --- | --- | --- | --- |
| ADR-001 | 2026-02-06 | maintainer | Keep orchestration in Bash + jq with strict gating in `scripts/doctor.sh`. | Minimal runtime dependencies and transparent behavior for contributors. | Enables easy local validation and low-friction contributions. | accepted |
| ADR-002 | 2026-02-06 | maintainer | Keep agent routing in `agents/runners.json` with tool fallback support. | Allows per-agent provider choice without code changes. | Supports mixed-provider workflows and easier adoption. | accepted |
