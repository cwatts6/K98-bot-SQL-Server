/*
Phase 5.1 claimed-file ACL hardening preflight.
Run before migrations/20260816_001_phase5_1_claim_acl_hardening.sql.
The bot and all direct import writers must be stopped.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NULL
   OR OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NULL
    THROW 52500, 'Phase 5.1 ACL preflight requires the deployed Phase 5.0 claim contract.', 1;

IF COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclHardenedAtUtc') IS NOT NULL
   OR COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclOwnerIdentity') IS NOT NULL
    THROW 52501, 'Phase 5.1 ACL preflight found a partial or already-applied schema.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P')) LIKE N'%ICACLS%'
    THROW 52502, 'Phase 5.1 ACL preflight found an already-hardened or drifted claim procedure.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileClaim
    WHERE ClaimStatus NOT IN (N'archived', N'duplicate_archived')
)
    THROW 52503, 'Phase 5.1 ACL preflight requires every existing claim to be terminal.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.configurations
    WHERE name = N'xp_cmdshell'
      AND value_in_use = 1
)
    THROW 52504, 'Phase 5.1 ACL hardening requires the already-approved xp_cmdshell capability.', 1;

SELECT DB_NAME() AS DatabaseName,
       @@SERVERNAME AS ServerName,
       COUNT_BIG(*) AS ExistingClaimRows,
       SUM(CASE WHEN ClaimStatus IN (N'archived', N'duplicate_archived') THEN 1 ELSE 0 END)
           AS TerminalClaimRows
FROM dbo.KS4_ImportFileClaim;

SELECT servicename,
       service_account,
       status_desc
FROM sys.dm_server_services
WHERE servicename LIKE N'SQL Server (%';

EXEC master.dbo.xp_cmdshell N'WHOAMI';
