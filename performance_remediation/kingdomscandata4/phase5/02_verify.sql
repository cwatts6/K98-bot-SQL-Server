/*
KingdomScanData4 Phase 5.0 post-migration verification.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.KS4_ImportFileClaim', N'U') IS NULL
   OR OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL2', N'P') IS NULL
    THROW 52380, 'Phase 5.0 verification found a missing claim or import object.', 1;

IF EXISTS
(
    SELECT expected.ObjectName
    FROM
    (
        VALUES
            (N'dbo.IMPORT_STAGING_PROC_CORE'),
            (N'dbo.IMPORT_STAGING_PROC'),
            (N'dbo.UPDATE_ALL'),
            (N'dbo.UPDATE_ALL2'),
            (N'dbo.ARCHIVE_IMPORT_STAGING_FILE')
    ) AS expected(ObjectName)
    LEFT JOIN sys.parameters AS actual
      ON actual.object_id = OBJECT_ID(expected.ObjectName, N'P')
     AND actual.name = N'@CompletedFileName'
     AND actual.system_type_id = TYPE_ID(N'nvarchar')
     AND actual.max_length = 520
    WHERE actual.parameter_id IS NULL
)
    THROW 52381, 'Phase 5.0 verification found an incomplete filename contract.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'))
       LIKE N'%downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', N'P'))
       LIKE N'%downloads\stats.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       LIKE N'%downloads\stats.csv%'
    THROW 52382, 'Phase 5.0 verification found the mutable legacy pathname.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
       NOT LIKE N'%stats_<32 hex>.ready.csv%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
       NOT LIKE N'%Import_Ready%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P'))
       NOT LIKE N'%Import_Claimed%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'))
       NOT LIKE N'%detected claimed-file mutation across BULK INSERT%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'))
       NOT LIKE N'%archive destination rehash changed%'
    THROW 52383, 'Phase 5.0 verification found a missing identity or rehash guard.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.KS4_ImportFileClaim')
      AND name = N'CK_KS4_ImportFileClaim_Status'
)
    THROW 52384, 'Phase 5.0 verification found a missing claim-state constraint.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.database_permissions
    WHERE major_id IN
    (
        OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE'),
        OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE'),
        OBJECT_ID(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE')
    )
      AND grantee_principal_id = DATABASE_PRINCIPAL_ID(N'public')
      AND permission_name = N'EXECUTE'
      AND state_desc <> N'DENY'
)
    THROW 52385, 'Phase 5.0 verification found an unexpected public helper grant.', 1;

SELECT
    N'phase5_verify' AS EvidenceSection,
    N'PASS' AS VerificationStatus,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileClaim) AS ClaimRows,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS ReceiptRows,
    CONVERT(
        char(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE')))
        ),
        2
    ) AS ClaimDefinitionSha256,
    CONVERT(
        char(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE')))
        ),
        2
    ) AS ImportCoreDefinitionSha256;

