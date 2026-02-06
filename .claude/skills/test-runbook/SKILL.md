---
name: test-runbook
description: Validate that commands in .plan/runbook.md are executable — checks executables, config files, environment variables, and TODO placeholders
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(which *)
  - Bash(command -v *)
  - Bash(*--version*)
  - Bash(test -f *)
  - Bash(test -d *)
  - Bash(printenv *)
---

# Runbook Command Validator

Validate that commands in `.plan/runbook.md` are executable in the current environment.

## Step 1: Read the Runbook

Read `.plan/runbook.md`.

- **File doesn't exist**: FAIL. Print: "`.plan/runbook.md` not found. Run `./scripts/bootstrap-plan.sh` to create it." Stop.
- **Empty/headings only**: FAIL. Print: "Runbook has no commands defined." Stop.

## Step 2: Check for TODO / TBD / FIXME

Scan for `TODO`, `TBD`, `FIXME` (case-insensitive). These block `validate_planning_exit_gate()` in `common.sh`.

For each match, record line number, section, and text. Flag as **blocking issues** at top of report.

## Step 3: Extract Commands

Parse fenced code blocks (````bash` or `````). For each:

1. Note the runbook section (Build, Test, Deploy, Rollback, etc.)
2. Extract command lines (skip `#` comments and blanks)
3. For multi-line commands with `&&`/`||`/`|`, split into individual executables
4. Note any `$VAR` / `${VAR}` references for env var checks

If no code blocks found: WARN. Commands should be in fenced blocks.

## Step 4: Validate Each Command

### 4a. Executable Exists

Extract the base executable (first word, ignoring `sudo`/`env`/`nohup` prefixes). Run `command -v <executable>`.

- PASS: Found at path
- FAIL: Not found. Suggest install (e.g., `brew install <pkg>`)

### 4b. Referenced Config Files

Check for implicit config files by executable:
- `npm` → `package.json`
- `make` → `Makefile`
- `docker build` → `Dockerfile`
- `docker-compose` → `docker-compose.yml` or `compose.yml`
- `cargo` → `Cargo.toml`
- `go` → `go.mod`
- `pip` → `requirements.txt`
- `poetry` → `pyproject.toml`

Also check explicit paths referenced in commands (e.g., `./scripts/deploy.sh`).

- PASS: File exists
- WARN: Implicit file not found (may be generated)
- FAIL: Explicit path not found

### 4c. Environment Variables

For `$VAR`/`${VAR}` in commands, check with `printenv`.

- PASS: Set and non-empty
- WARN: Not set (may be runtime/CI-injected)

### 4d. Tool Version (optional)

Run `<executable> --version` to verify the tool works (not just exists on PATH).

- PASS: Version returned
- WARN: Non-zero exit or no output (informational)

## Step 5: Report

### Blocking Issues (if any)

TODO/TBD/FIXME placeholders with line numbers.

### Command Validation Results

```
| Section  | Command         | Executable | Status | Notes                        |
|----------|-----------------|------------|--------|------------------------------|
| Build    | npm run build   | npm        | PASS   | v20.11.0                     |
| Test     | pytest tests/   | pytest     | FAIL   | Not found. brew install python|
| Deploy   | kubectl apply   | kubectl    | WARN   | Found, but KUBECONFIG not set|
```

### Environment Variables

List all referenced variables and their status (set / not set).

### Suggested Fixes

Concrete remediation for each FAIL and WARN.

### Summary

- All clear: "Runbook valid. X commands checked, all passed."
- Warnings: "Y warnings across X commands."
- Failures: "Z failures and Y warnings. Fix before running `orchestrator.sh run`."

## Safety Rules

- NEVER execute deploy, rollback, or destructive commands
- NEVER run `rm`, `delete`, `destroy`, `drop`, `kill`, `stop`
- NEVER run commands from Deploy or Rollback sections
- NEVER pipe to `sh`, `bash`, or `eval`
- Only use `which`, `command -v`, `--version`, `test -f`, and `printenv`
