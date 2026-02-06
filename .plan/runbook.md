# Runbook

## Environment and Prerequisites

- `jq` and `rg` installed and on `PATH`
- At least one configured runner CLI from `agents/runners.json`
- Run from repository root

## Build Command

```bash
bash -n orchestrator.sh scripts/*.sh scripts/lib/common.sh
```

## Test Command

```bash
./scripts/doctor.sh --planning-only
./scripts/doctor.sh --skip-runner-tools
```

## Deploy Command

```bash
git push origin main
git push origin --tags
```

## Rollback Command

```bash
git revert <release-commit-sha>
git push origin main
```

## Post-Deploy Verification

```bash
./scripts/doctor.sh --planning-only --skip-runner-tools
./orchestrator.sh --help
./scripts/doctor.sh --help
```
