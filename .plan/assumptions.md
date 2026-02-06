# Assumptions

| id | date | owner | assumption | confidence | validation plan | expiry | status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ASM-001 | 2026-02-06 | maintainer | Contributors can install `jq` and `rg` locally. | high | Confirm via `./scripts/doctor.sh --planning-only` in setup docs. | 2027-02-06 | active |
| ASM-002 | 2026-02-06 | maintainer | At least one supported AI CLI is available per contributor environment. | medium | Validate with runner tool checks in `./scripts/doctor.sh`. | 2026-12-31 | active |
