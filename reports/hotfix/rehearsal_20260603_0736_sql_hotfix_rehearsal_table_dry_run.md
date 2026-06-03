# SQL Hotfix Rehearsal Report

Hotfix ID: rehearsal_20260603_0736_sql_hotfix_rehearsal_table_dry_run
Date/time UTC: 2026-06-03 07:36
Operator: Codex via `9SX2VF4\CodexSandboxOffline`
Environment: Codex desktop session, not the SQL production host
Server: MINI_AMD
Database: ROK_TRACKER
Related bot issue/PR: N/A
Related SQL issue/PR: TBD if owner-run rehearsal is completed

## 1. Incident Summary

This was a controlled emergency hotfix rehearsal dry run for the SQL Git-first promotion process.

The intended low-risk production-style change is to create the isolated empty table
`dbo.SqlHotfixRehearsal`. The table is not used by bot runtime behavior and exists only to prove
the hotfix, drift, reconciliation, and final verification process.

## 2. Decision To Bypass Standard SQL PR Flow

This was not a real incident. The owner approved a controlled rehearsal to prove the emergency
hotfix process after Phase 2A standards were merged and deployed.

Risk accepted: none to bot runtime behavior. The rehearsal object is deliberately isolated.

## 3. Backup Confirmation

Backup readiness could not be confirmed from this Codex session.

Attempted command:

```powershell
.\deploy\Test-SqlBackupReadiness.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER" `
  -BackupPath "C:\sql_backup"
```

Result:

```text
Invoke-Sqlcmd: The target principal name is incorrect. Cannot generate SSPI context.
```

Read-only SqlClient fallback check also failed with the same SSPI error.

This session is running on `9SX2VF4` as `9SX2VF4\CodexSandboxOffline`, not on `MINI_AMD`.

Owner-run requirement: run backup readiness on `MINI_AMD` before applying the rehearsal SQL.

## 4. Production Change Applied

No production SQL was applied from Codex.

Owner-run rehearsal SQL:

```sql
IF OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SqlHotfixRehearsal
    (
        RehearsalId INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SqlHotfixRehearsal PRIMARY KEY,
        CreatedAtUtc DATETIME2(0) NOT NULL
            CONSTRAINT DF_SqlHotfixRehearsal_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        Notes NVARCHAR(4000) NULL
    );
END;
```

## 5. Validation Performed

Git/schema pre-check:

- `SqlHotfixRehearsal` was not present in `sql_schema/*.sql`.

Production pre-check attempted:

```sql
SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;
```

Result: not executable from this Codex session due SSPI authentication failure.

Owner-run validation:

```sql
SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;

SELECT TOP (5)
    RehearsalId,
    CreatedAtUtc,
    Notes
FROM dbo.SqlHotfixRehearsal
ORDER BY RehearsalId DESC;
```

## 6. Drift And Export Evidence

Not run from Codex because Production authentication failed before the rehearsal change.

Owner-run command after applying the direct SQL:

```powershell
cd C:\K98-bot-SQL-Server
.\deploy\Invoke-DriftCheck.ps1 `
  -RepoPath C:\K98-bot-SQL-Server `
  -ServerName "MINI_AMD" `
  -DatabaseName "ROK_TRACKER"
```

Expected drift summary:

- Added table: `dbo.SqlHotfixRehearsal`

Unexpected drift summary:

- TBD by owner-run drift report

## 7. Git Reconciliation

Not completed because the production-style SQL was not applied.

Owner-run follow-up after drift is captured:

1. Create a SQL branch from current `main`.
2. Create a reconciliation migration.
3. Add `sql_schema/dbo.SqlHotfixRehearsal.Table.sql`.
4. Declare rollback classification and data-safety metadata.
5. Run `.\deploy\Validate-SqlRepo.ps1`.
6. Open a SQL PR.
7. After merge, deploy/reconcile and run final drift check.

Recommended migration metadata:

```sql
/*
MigrationId: YYYYMMDD_NNN_reconcile_sql_hotfix_rehearsal_table
Purpose: Reconcile controlled emergency hotfix rehearsal table
Author: cwatts
CreatedUtc: YYYY-MM-DD
RequiresBackup: Yes
RiskLevel: Low
Rollback: Included
RollbackScript: migrations/rollback/YYYYMMDD_NNN_reconcile_sql_hotfix_rehearsal_table_rollback.sql
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') AS ObjectId;
RelatedBotPR:
RelatedSQLPR:
*/
```

## 8. Rollback / Forward-Fix Notes

The rehearsal table is safely reversible if no runtime dependency is added.

Rollback script should drop only the isolated rehearsal table:

```sql
IF OBJECT_ID(N'dbo.SqlHotfixRehearsal', N'U') IS NOT NULL
BEGIN
    DROP TABLE dbo.SqlHotfixRehearsal;
END;
```

Do not execute rollback automatically. Use it only if the owner decides the rehearsal object should
be removed after proving the process.

## 9. Final Status

Final status:

- incomplete, with owner-run steps listed

Outstanding risks:

- None to bot runtime from Codex, because no production SQL was applied.
- Owner-run production authentication and backup readiness are required before the live rehearsal.

Follow-up tasks:

- Run the rehearsal from `MINI_AMD` or an approved SQL-authenticated admin session.
- Capture drift evidence.
- Reconcile through Git.
- Run final drift check.

Deferred optimisations:

- None.

