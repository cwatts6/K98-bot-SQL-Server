/*
Phase 5.1 claimed-file ACL hardening verification.
Run after migrations/20260816_001_phase5_1_claim_acl_hardening.sql.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclHardenedAtUtc') IS NULL
   OR COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclOwnerIdentity') IS NULL
    THROW 52520, 'Phase 5.1 ACL verification did not find both evidence columns.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.KS4_ImportFileClaim')
      AND name = N'CK_KS4_ImportFileClaim_AclEvidence'
      AND is_disabled = 0
      AND is_not_trusted = 0
)
    THROW 52521, 'Phase 5.1 ACL evidence constraint is missing, disabled, or untrusted.', 1;

DECLARE @Definition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'));

IF @Definition IS NULL
   OR @Definition NOT LIKE N'%WHOAMI%'
   OR @Definition NOT LIKE N'%ICACLS%'
   OR @Definition NOT LIKE N'%/RESET /Q%'
   OR @Definition NOT LIKE N'%/SETOWNER "%'
   OR @Definition NOT LIKE N'%/VERIFY /Q%'
   OR @Definition NOT LIKE N'%AclHardenedAtUtc = @AclHardenedAtUtc%'
   OR @Definition NOT LIKE N'%AclOwnerIdentity = @AclOwnerIdentity%'
    THROW 52522, 'Phase 5.1 ACL verification found claim-procedure definition drift.', 1;

IF CHARINDEX(N'/RESET /Q', @Definition) >=
   CHARINDEX(N'EXEC dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', @Definition)
    THROW 52523, 'Phase 5.1 ACL verification found hashing before ACL hardening.', 1;

SELECT DB_NAME() AS DatabaseName,
       OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') AS ClaimProcedureObjectId,
       COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclHardenedAtUtc')
           AS AclHardenedAtUtcColumnLength,
       COL_LENGTH(N'dbo.KS4_ImportFileClaim', N'AclOwnerIdentity')
           AS AclOwnerIdentityColumnLength;
