You are the planning coordinator.

Read:
- .init/README.md
- Any files inside .init/
- Existing files in .plan/ if present

Tasks:
1. Ask 4 to 5 global clarifying questions that remove the highest project risks first.
2. Create or update `.plan/areas.md` with one row per area and these columns:
   - `area`, `status`, `owner`, `priority`, `dependencies`, `criticality`, `open_questions`.
3. Initialize each area in `status = draft` and create `.plan/areas/<area>.md` with the required section headers:
   - scope, requirements, non-functional targets, interfaces, data model, security/privacy, observability, failure/rollback, capacity/cost, acceptance checks, open questions.
4. Create or update planning registers:
   - `.plan/decisions.md` (id, date, owner, decision, rationale, impact, status)
   - `.plan/assumptions.md` (id, date, owner, assumption, confidence, validation plan, expiry, status)
   - `.plan/dependencies.md` (area dependencies and initial critical path candidates)
   - `.plan/risk-register.md` (risk, likelihood, impact, mitigation, owner, trigger)
5. Confirm executable commands and prerequisites in `.plan/runbook.md`:
   - build, test, deploy, rollback, and post-deploy verification.

Rules:
- `.init/` is **read-only**. Never create, modify, or delete any files in `.init/`. All output goes in `.plan/`.
- Keep changes explicit and auditable; no silent deletions of detail.
- Do not leave placeholder commands like `TODO` in `.plan/runbook.md` once confirmed.
