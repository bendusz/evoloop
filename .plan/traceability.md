# Traceability

| requirement | area | story | test intent |
| --- | --- | --- | --- |
| REQ-001 | orchestration-core | US-001 | Verify `orchestrator.sh` routes modes and invalid arguments fail fast with usage output. |
| REQ-002 | orchestration-core | US-001 | Run `./scripts/doctor.sh` to validate gates and dependency integrity checks. |
| REQ-003 | orchestration-core | US-001 | Validate implementation loop behavior with empty and populated `prd/` states. |
| REQ-004 | agent-prompts-and-skills | US-001 | Check `.claude/skills` instructions match current docs, paths, and file contracts. |
| REQ-005 | docs-and-release | US-001 | Confirm no local-machine paths/state are tracked and docs are repo-relative. |
