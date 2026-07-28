/*
Purpose:
    Execute one committed UPDATE_ALL2 import against the isolated Phase 3
    fixture and verify database/file receipt consistency.

Safety:
    - Refuses production and any database other than the exact representative.
    - Requires both filesystem procedures to use the Phase 3 test root.
    - Requires an empty receipt table and one staged fixture.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 52050, 'Phase 3 committed-import rehearsal refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52051, 'Phase 3 committed-import rehearsal is connected to the wrong database.', 1;

IF @@TRANCOUNT <> 0
    THROW 52052, 'Phase 3 committed-import rehearsal requires no existing transaction.', 1;

DECLARE @LiveRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads\';
DECLARE @TestRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\';
DECLARE @ImportDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC_CORE', N'P'));
DECLARE @ArchiveDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.ARCHIVE_IMPORT_STAGING_FILE', N'P'));

IF @ImportDefinition LIKE N'%' + @LiveRoot + N'%'
   OR @ArchiveDefinition LIKE N'%' + @LiveRoot + N'%'
   OR @ImportDefinition NOT LIKE N'%' + @TestRoot + N'%'
   OR @ArchiveDefinition NOT LIKE N'%' + @TestRoot + N'%'
BEGIN
    THROW 52053, 'Phase 3 committed-import rehearsal requires the isolated test-path override.', 1;
END;

IF EXISTS (SELECT 1 FROM dbo.KS4_ImportFileReceipt)
    THROW 52054, 'Phase 3 committed-import rehearsal requires an empty receipt table.', 1;

DECLARE @ActivePath nvarchar(4000) =
    @TestRoot + N'stats.csv';
DECLARE @ActiveExists int = 0;

EXEC master.dbo.xp_fileexist
    @ActivePath,
    @ActiveExists OUTPUT;

IF ISNULL(@ActiveExists, 0) <> 1
    THROW 52055, 'Phase 3 committed-import rehearsal could not find the staged fixture.', 1;

DECLARE @BeforeKS4Rows bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4);
DECLARE @BeforeKS5Rows bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5);
DECLARE @BeforeKS4MaxScan int =
    (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4);
DECLARE @BeforeKS5MaxScan int =
    (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData5);
DECLARE @StartedAtUtc datetime2(3) = SYSUTCDATETIME();

EXEC dbo.UPDATE_ALL2;

DECLARE @CompletedAtUtc datetime2(3) = SYSUTCDATETIME();
DECLARE @AfterKS4Rows bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData4);
DECLARE @AfterKS5Rows bigint =
    (SELECT COUNT_BIG(*) FROM dbo.KingdomScanData5);
DECLARE @AfterKS4MaxScan int =
    (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4);
DECLARE @AfterKS5MaxScan int =
    (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData5);

IF @AfterKS4MaxScan <> @BeforeKS4MaxScan + 1
   OR @AfterKS5MaxScan <> @BeforeKS5MaxScan + 1
   OR @AfterKS4MaxScan <> @AfterKS5MaxScan
BEGIN
    THROW 52056, 'Phase 3 committed import allocated an unexpected scan order.', 1;
END;

IF @AfterKS4Rows <> @BeforeKS4Rows + 411
   OR @AfterKS5Rows <> @BeforeKS5Rows + 411
BEGIN
    THROW 52057, 'Phase 3 committed import changed an unexpected KS4/KS5 row count.', 1;
END;

IF (SELECT COUNT_BIG(*)
    FROM dbo.KingdomScanData4
    WHERE SCANORDER = @AfterKS4MaxScan) <> 411
   OR (SELECT COUNT_BIG(DISTINCT GovernorID)
       FROM dbo.KingdomScanData4
       WHERE SCANORDER = @AfterKS4MaxScan) <> 411
   OR EXISTS
   (
       SELECT GovernorID
       FROM dbo.KingdomScanData4
       WHERE SCANORDER = @AfterKS4MaxScan
       GROUP BY GovernorID
       HAVING COUNT_BIG(*) > 1
   )
BEGIN
    THROW 52058, 'Phase 3 committed import produced an invalid KS4 logical-key set.', 1;
END;

IF EXISTS (SELECT 1 FROM dbo.IMPORT_STAGING)
    THROW 52059, 'Phase 3 committed import left canonical staging residue.', 1;

DECLARE @ReceiptDigest binary(32);
DECLARE @ArchivePath nvarchar(4000);
DECLARE @ReceiptStatus nvarchar(20);
DECLARE @ReceiptRowCount int;
DECLARE @ArchiveExists int = 0;

SELECT
    @ReceiptDigest = FileDigest,
    @ArchivePath = ArchivePath,
    @ReceiptStatus = ArchiveStatus,
    @ReceiptRowCount = [RowCount]
FROM dbo.KS4_ImportFileReceipt
WHERE ScanOrder = @AfterKS4MaxScan;

IF @ReceiptDigest IS NULL
   OR @ReceiptStatus <> N'archived'
   OR @ReceiptRowCount <> 411
BEGIN
    THROW 52060, 'Phase 3 committed import did not produce one archived 411-row receipt.', 1;
END;

SET @ActiveExists = 0;
EXEC master.dbo.xp_fileexist
    @ActivePath,
    @ActiveExists OUTPUT;
EXEC master.dbo.xp_fileexist
    @ArchivePath,
    @ArchiveExists OUTPUT;

IF ISNULL(@ActiveExists, 0) = 1
   OR ISNULL(@ArchiveExists, 0) <> 1
BEGIN
    THROW 52061, 'Phase 3 committed import has inconsistent source/archive file disposition.', 1;
END;

SELECT
    N'phase3_committed_import' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @BeforeKS4Rows AS BeforeKS4Rows,
    @AfterKS4Rows AS AfterKS4Rows,
    @BeforeKS5Rows AS BeforeKS5Rows,
    @AfterKS5Rows AS AfterKS5Rows,
    @AfterKS4MaxScan AS ImportedScanOrder,
    411 AS ImportedGovernorRows,
    CONVERT(char(64), @ReceiptDigest, 2) AS FileDigestSha256,
    @ArchivePath AS ArchivePath,
    @ReceiptStatus AS ArchiveStatus,
    DATEDIFF_BIG(millisecond, @StartedAtUtc, @CompletedAtUtc)
        AS DurationMs,
    XACT_STATE() AS FinalXactState,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
