/*
Apply only to the isolated Phase 5 rehearsal database after the forward
migration. This substitutes the dedicated test root into the four routines
that own filesystem paths, or verifies an already test-bound derived migration.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 52390, 'Phase 5.0 test-path override refuses production ROK_TRACKER.', 1;

DECLARE @ProductionRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads\';
DECLARE @TestRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase5_rehearsal\';
DECLARE @ObjectName sysname;
DECLARE @Definition nvarchar(max);

DECLARE override_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ObjectName
    FROM
    (
        VALUES
            (N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', 1),
            (N'dbo.ARCHIVE_IMPORT_STAGING_FILE', 2),
            (N'dbo.CLAIM_KS4_IMPORT_FILE', 3),
            (N'dbo.IMPORT_STAGING_PROC_CORE', 4)
    ) AS ordered(ObjectName, SequenceNo)
    ORDER BY SequenceNo;

OPEN override_cursor;
FETCH NEXT FROM override_cursor INTO @ObjectName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @Definition = OBJECT_DEFINITION(OBJECT_ID(@ObjectName, N'P'));

    IF @Definition IS NULL
        THROW 52391, 'Phase 5.0 test-path override found a missing filesystem-owner definition.', 1;

    IF @Definition LIKE N'%' + @ProductionRoot + N'%'
    BEGIN
        SET @Definition = REPLACE(@Definition, @ProductionRoot, @TestRoot);
        EXEC sys.sp_executesql @Definition;
        EXEC sys.sp_refreshsqlmodule @ObjectName;
    END
    ELSE IF @Definition NOT LIKE N'%' + @TestRoot + N'%'
        THROW 52391, 'Phase 5.0 test-path override found an unexpected filesystem root.', 1;

    FETCH NEXT FROM override_cursor INTO @ObjectName;
END;

CLOSE override_cursor;
DEALLOCATE override_cursor;

IF EXISTS
(
    SELECT expected.ObjectName
    FROM
    (
        VALUES
            (N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE'),
            (N'dbo.ARCHIVE_IMPORT_STAGING_FILE'),
            (N'dbo.CLAIM_KS4_IMPORT_FILE'),
            (N'dbo.IMPORT_STAGING_PROC_CORE')
    ) AS expected(ObjectName)
    WHERE OBJECT_DEFINITION(OBJECT_ID(expected.ObjectName, N'P'))
              LIKE N'%' + @ProductionRoot + N'%'
       OR OBJECT_DEFINITION(OBJECT_ID(expected.ObjectName, N'P'))
              NOT LIKE N'%' + @TestRoot + N'%'
)
    THROW 52392, 'Phase 5.0 test-path override did not replace every filesystem owner.', 1;

SELECT
    N'phase5_test_path_override' AS EvidenceSection,
    N'PASS' AS OverrideStatus,
    DB_NAME() AS DatabaseName,
    @TestRoot AS TestRoot;
