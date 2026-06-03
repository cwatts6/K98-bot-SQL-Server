# ADR 002: SQL Emergency Hotfix And Rollback Standards

## Status

Accepted for Phase 2A implementation.

## Context

The SQL repository now uses Git-first migration deployment. Normal SQL work should move through a
reviewed PR, merge to `main`, backup readiness check, controlled deployment, and drift validation.

Production incidents may still require a direct SQL hotfix when waiting for the standard PR flow
would create unacceptable operational risk. Without a formal emergency path, direct production
changes can leave Git and Production drifting, rollback confidence unclear, and future migrations
riskier.

## Decision

Direct production hotfixes remain discouraged, but the repo will support a documented emergency
path with required evidence, drift capture, Git reconciliation, and final status reporting.

Rollback classification is mandatory for migrations. Rollback scripts are optional because some
SQL changes cannot be reversed safely. When rollback would create false confidence, the migration
must declare manual recovery, forward-fix, or restore-from-backup expectations instead.

Hotfix evidence is stored under `reports/hotfix/` because these are operational incident records,
not general documentation.

## Consequences

- Emergency SQL changes must start or complete a hotfix report.
- Backup readiness must be confirmed or explicitly overridden by the owner.
- Production drift caused by a hotfix must be exported and reconciled through Git.
- Reversible migrations can include reviewed rollback scripts under `migrations/rollback/`.
- Non-reversible migrations must state why rollback is unsafe and how recovery would proceed.
- Data migrations require explicit safety metadata when they affect existing data.

## Follow-Up Work

- Add CI enforcement for SQL validation.
- Add scheduled monitoring over SQL export/drift/deployment JSONL logs.
- Consider DEV/UAT rehearsal environments when infrastructure is available.
- Evaluate automated rollback orchestration only after manual rollback standards have several
  clean production cycles.

