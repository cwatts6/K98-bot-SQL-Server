# ADR 003: SQL CI, Backup Policy, And Export Monitoring

## Status

Accepted for Phase 2B implementation.

## Context

Phase 1 established Git-first SQL deployment, backup readiness checks, drift exports, and
structured logs. Phase 2A proved the emergency hotfix and rollback evidence path.

The next operational risks are unsafe SQL pull requests, noisy backup-threshold interpretation,
and failed nightly schema exports that are only visible when an operator inspects logs or Task
Scheduler manually.

## Decision

SQL pull requests will run read-only GitHub Actions validation. CI calls the repository validator
instead of duplicating migration rules in workflow YAML. CI also parses PowerShell deployment
scripts, scans practical credential patterns, checks documentation paths, and proves that the
nightly export wrapper does not normally push directly to `main`.

SQLFluff is introduced as an advisory T-SQL linter for migration and rollback scripts only. It is
not yet a blocking gate because exported schema snapshots are generated and SQLFluff rule tuning
needs review against real K98 migrations.

Backup thresholds remain compatible with the proven production policy:

- full backup freshness is blocking
- transaction log backup freshness is blocking when the recovery model requires log backups
- differential backup freshness is warning-only

A config example documents those values and can be copied to a local uncommitted config file for
operator-approved overrides.

Nightly export health is checked by a separate monitoring script that reads structured export logs
and scheduled-task state when available. It does not deploy SQL, alter scheduled tasks, or push Git
branches.

## Options Considered

- Make SQLFluff blocking immediately. Rejected for Phase 2B because generated SQL snapshots and
  existing style conventions need tuning first.
- Add SqlPackage / DACPAC validation now. Deferred until tool installation, artifact policy, and
  non-production validation targets are approved.
- Add tSQLt now. Deferred until a DEV or UAT SQL Server exists; Production must not host PR test
  objects.
- Add TSQLLint now. Deferred as an optional fallback if SQLFluff proves unsuitable.

## Consequences

- PRs get automated structural validation without live Production SQL access.
- SQLFluff warnings are visible to reviewers but do not block merges during the pilot.
- Backup warnings are deliberate policy outcomes rather than surprise noise.
- Failed or stale nightly exports have a direct operator check and future agent hook.
