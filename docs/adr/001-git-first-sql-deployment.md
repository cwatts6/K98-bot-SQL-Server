# ADR 001: Git-First SQL Deployment

## Status

Accepted for initial implementation.

## Context

The SQL repository has historically acted as a production schema snapshot. The export workflow
captures what Production became, but it does not prove that a change was reviewed, promoted, or
deployed from Git.

The K98 bot repositories already use reviewed Git branches, validation, promotion notes, and
deployment guardrails. SQL needs the same operational posture.

## Decision

Git is the authoritative source for intentional SQL changes.

SQL changes are delivered through reviewed migrations in `migrations/`. Production schema exports
remain available for drift detection, audit evidence, and recovery support, but exports must not
silently overwrite `main`.

## Options Considered

- Keep Production-to-Git exports as the primary workflow. This preserves the current routine but
  leaves Production as the real source of truth and keeps review after the fact.
- Adopt a native migration workflow. This adds structure while staying lightweight enough for the
  current single-production environment.
- Adopt Flyway or Liquibase immediately. These tools may be useful later, but they would add
  operational complexity before the K98-specific process is stable.

## Consequences

- Normal SQL work starts in Git, goes through PR review, and deploys from `main`.
- `sql_schema/` becomes reference and drift evidence, not the primary deployment mechanism.
- Direct Production edits become emergency hotfixes that must be reconciled back into Git.
- Deployments require backup readiness, migration history, deployment run history, and structured
  logs.

## Follow-Up Work

- Add CI validation for SQL PRs.
- Add DEV or UAT SQL environments.
- Evaluate Flyway or Liquibase once the native process is proven.
- Add monitoring agents over deployment, export, drift, and validation JSONL logs.
