# SQL Release Checklist

Use this checklist for production SQL deployments.

## Pre-Deployment

- [ ] SQL PR is reviewed and merged into `main`.
- [ ] Deployment is being run on the bot machine.
- [ ] SQL Server authentication model is Windows Auth.
- [ ] Current branch is `main`.
- [ ] Working tree is clean.
- [ ] `deploy/Validate-SqlRepo.ps1` passes.
- [ ] Migration file and rollback notes are reviewed.
- [ ] Bot dependency order is understood.
- [ ] Backup readiness passes for full, differential, and log backups.
- [ ] External backup copy cadence is healthy.
- [ ] Smoke test plan is ready.

## Deployment

- [ ] Pull latest SQL repo `main`.
- [ ] Run backup readiness check.
- [ ] Run deployment with the intended migration ID or all pending migrations.
- [ ] Confirm `dbo.SchemaMigrationHistory`.
- [ ] Confirm `dbo.DeploymentRunHistory`.
- [ ] Review `logs/deployment.jsonl`.

## Post-Deployment

- [ ] Run SQL smoke checks.
- [ ] Deploy bot changes only after required SQL migration is confirmed.
- [ ] Run `deploy/Invoke-DriftCheck.ps1`.
- [ ] Review generated drift report.
- [ ] Reconcile unexpected drift through PR.
- [ ] Record deployment notes and rollback posture.
- [ ] Clean up merged branches after confirmation.
