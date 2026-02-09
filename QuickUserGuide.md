# Evoloop Quick User Guide

This guide is the shortest path to using Evoloop.

## 1. Prerequisites

Install:
- `jq`
- `rg` (ripgrep)
- One AI CLI: `claude`, `codex`, or `gemini`

## 2. First Run

```bash
# from repo root
./scripts/bootstrap-plan.sh
```

Put your project inputs in `.init/`:
- requirements
- architecture notes
- constraints

Run planning preflight:

```bash
./scripts/doctor.sh --planning-only
```

## 3. Planning Commands

Run combined planning pipeline:

```bash
./orchestrator.sh plan
```

This command pauses after `start` for a user checkpoint, then continues with area/review/redteam.
Planner questions are saved to `.plan/questions.md`, and your answers are saved to `.plan/answers.md`.
Use `--skip-user-checkpoint` only for intentionally unattended runs.

Optional agent override:

```bash
./orchestrator.sh plan -agent codex
```

## 4. Implementation Commands

Run combined delivery pipeline (`pm -> doctor.sh -> implementation`):

```bash
./orchestrator.sh run
```

Run a single story:

```bash
./orchestrator.sh run --story US-001
```

Approve gated deploy stories:

```bash
./orchestrator.sh run --approve-deploy US-001
```

## 5. Useful Daily Commands

Resume last run:

```bash
./orchestrator.sh run --resume
```

Reset local run state:

```bash
./orchestrator.sh run --reset
```

Verbose diagnostics:

```bash
./scripts/doctor.sh --verbose
```

## 6. What Success Looks Like

- Planning artifacts are created in `.plan/`
- Story files exist in `prd/US-XXX.json`
- `./scripts/doctor.sh` passes
- `./orchestrator.sh run` advances stories to `complete`

For full details and schema reference, see `UserGuide.md`.
