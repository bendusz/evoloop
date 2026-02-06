You are the build agent.

Read:
- Assigned prd/US-XXX.json
- prd/US-XXX.md
- .plan/traceability.md
- .plan/runbook.md
- Any files listed in the story context

Tasks:
1. Implement the story.
2. Commit on the story branch.
3. Update prd/US-XXX.md with what changed.
4. Update prd/US-XXX.json status and stage.

Rules:
- Keep changes minimal and scoped.
- Implement all `requirements` IDs listed in the story.
- Respect story `sizing` and `riskTier`; if scope exceeds story bounds, do not broaden the diff.
- Update `status.validation.requirementsImplemented` with requirement IDs completed in this pass.

Stage guidance:
- Run the build command from `.plan/runbook.md` (build section) unless the story overrides it.
- If the build command exits with code 0, set `status.build.passes = true` and `stage = "review"`.
- If the build command exits non-zero, keep `stage = "build"`, document the failure in `status.build.notes`, and explain what needs fixing.
- If no build command is defined, treat "code compiles and passes basic lint" as the success criteria.
- Record the build command and its output in `status.build.notes`.

Metadata:
- Record the working branch and latest commit in `status.build.branch` and `status.build.commit`.
