# SQL Release Checklist

Use this checklist for production SQL deployments.

## Pre-Deployment

- [ ] Bot-machine shell was bootstrapped from `C:\discord_file_downloader`.
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

## Rollback Review

- [ ] Migration declares one rollback classification: `Included`, `Manual`, `Forward Fix Only`, or `Not Possible`.
- [ ] `Rollback: Included` has a reviewed matching file under `migrations/rollback/`.
- [ ] Rollback file includes `RollbackForMigrationId:`.
- [ ] Non-reversible migrations explain why rollback is unsafe.
- [ ] Forward-fix or restore-from-backup decision point is documented where rollback is unsafe.
- [ ] Data-loss risk is understood before deployment.

## Data Migration Review

- [ ] `DataChange:` is set correctly.
- [ ] `DataChange: Yes` includes or references a data safety plan.
- [ ] Preview row-count query was reviewed.
- [ ] Expected row-count range is documented.
- [ ] Transaction and locking/runtime risk are understood.
- [ ] Pre-validation and post-validation queries are ready.
- [ ] Bot behavior impact is understood where config or bot-facing data changes.

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

## Emergency Hotfix Pre-Checks

- [ ] Incident qualifies for emergency SQL hotfix path.
- [ ] Owner/operator approval is recorded.
- [ ] Hotfix report was created from `reports/hotfix/hotfix_template.md`.
- [ ] Backup readiness was confirmed or override was explicitly approved.
- [ ] Backup readiness warnings were recorded and accepted.
- [ ] Object or data pre-check confirms expected starting state.
- [ ] Exact minimum SQL was reviewed before execution.
- [ ] Rollback, forward-fix, or restore decision point is documented.

## Emergency Hotfix Post-Checks

- [ ] Exact SQL executed, timestamp, rows affected, and affected objects are recorded.
- [ ] SQL smoke check completed.
- [ ] Bot smoke check completed where relevant.
- [ ] Production drift evidence was captured with `deploy/Invoke-DriftCheck.ps1`.
- [ ] Drift report contains only expected drift, or unexpected drift is documented.
- [ ] Reconciliation migration was created or owner-run reconciliation is listed.
- [ ] Schema snapshot was copied from the drift export.
- [ ] Rollback script exists and validates when `Rollback: Included`.
- [ ] `deploy/Validate-SqlRepo.ps1` passes before PR.
- [ ] SQL PR links the hotfix report and export branch.
- [ ] After PR merge, `Deploy-SqlMigration.ps1 -ValidationOnly` is reviewed.
- [ ] Idempotent reconciliation migration is deployed from `main` to record migration history.
- [ ] Final `Deploy-SqlMigration.ps1 -ValidationOnly` pending migration count is zero.
- [ ] Final drift check is clean or accepted drift is documented.
- [ ] `dbo.SchemaMigrationHistory` confirms the reconciliation migration is applied.
- [ ] Hotfix report final status is complete.

## Nightly Export Task

- [ ] Old `Export-SqlSchemaAndPush.ps1` scheduled task is disabled.
- [ ] `K98 SQL Nightly Schema Export` scheduled task is installed.
- [ ] New task action points to `deploy\Invoke-NightlyProdSchemaExport.ps1`.
- [ ] Manual task run completed successfully.
- [ ] SQL repo returned to clean `main` after the task.
- [ ] Any pushed `export/prod-schema-*` branch was reviewed or intentionally left for drift review.
