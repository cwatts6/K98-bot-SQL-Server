/*
KingdomScanData4 Phase 5.0 read-only preflight.

Run after the Phase 4 gate and before the Phase 5.0 migration while all
fallback-import writers are stopped.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P') IS NULL
   OR OBJECT_ID(N'dbo.UPDATE_ALL2', N'P') IS NULL
    THROW 52370, 'Phase 5.0 preflight requires the closed Phase 3 import contracts.', 1;

IF OBJECT_ID(N'dbo.vAllianceActivity_WeeklyCumulative') IS NOT NULL
    THROW 52371, 'Phase 5.0 preflight requires the closed Phase 4 retirement.', 1;

IF OBJECT_ID(N'dbo.CLAIM_KS4_IMPORT_FILE', N'P') IS NOT NULL
    THROW 52372, 'Phase 5.0 preflight found the new claim procedure already present.', 1;

IF EXISTS
(
    SELECT 1
    FROM dbo.KS4_ImportFileReceipt
    WHERE ArchiveStatus <> N'archived'
)
    THROW 52373, 'Phase 5.0 preflight found an unreconciled Phase 3 archive receipt.', 1;

DECLARE @LegacyFileExists int;
EXEC master.dbo.xp_fileexist
    N'C:\discord_file_downloader\downloads\stats.csv',
    @LegacyFileExists OUTPUT;

IF ISNULL(@LegacyFileExists, 0) = 1
    THROW 52374, 'Phase 5.0 preflight found the legacy stats.csv file.', 1;

CREATE TABLE #DirectoryEntry
(
    Subdirectory nvarchar(512) NULL,
    Depth int NULL,
    IsFile bit NULL
);

INSERT #DirectoryEntry
EXEC master.dbo.xp_dirtree
    N'C:\discord_file_downloader\downloads\Import_Ready',
    1,
    1;

IF EXISTS (SELECT 1 FROM #DirectoryEntry WHERE IsFile = 1)
    THROW 52375, 'Phase 5.0 preflight requires an empty Import_Ready directory.', 1;

TRUNCATE TABLE #DirectoryEntry;

INSERT #DirectoryEntry
EXEC master.dbo.xp_dirtree
    N'C:\discord_file_downloader\downloads\Import_Claimed',
    1,
    1;

IF EXISTS (SELECT 1 FROM #DirectoryEntry WHERE IsFile = 1)
    THROW 52376, 'Phase 5.0 preflight requires an empty Import_Claimed directory.', 1;

SELECT
    N'phase5_preflight' AS EvidenceSection,
    N'PASS' AS PreflightStatus,
    (SELECT COUNT_BIG(*) FROM dbo.KS4_ImportFileReceipt) AS ExistingReceiptRows,
    CONVERT(
        char(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE')))
        ),
        2
    ) AS ImportCoreDefinitionSha256,
    CONVERT(
        char(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(varbinary(max), OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2')))
        ),
        2
    ) AS UpdateAll2DefinitionSha256;

