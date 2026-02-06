# Risk Register

| id | risk | likelihood | impact | mitigation | owner | trigger | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R-001 | Skills drift from workflow behavior after script updates. | medium | medium | Update `README.md`, `AGENTS.md`, and affected skill docs for every workflow logic change; verify with doctor checks. | maintainer | Script update without corresponding docs changes. | open |
| R-002 | Story graph deadlocks from cyclic dependencies. | low | high | Keep cycle detection in `scripts/doctor.sh`; fail preflight on any cycle. | maintainer | `./scripts/doctor.sh` reports circular dependency. | open |
| R-003 | Local machine paths or run-state files are committed to public repo. | medium | high | Enforce `.gitignore` rules for runtime/local files and run a pre-publish review checklist. | maintainer | Review finds absolute user-home paths or transient state in tracked files. | open |
