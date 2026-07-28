/*
Purpose:
    Redirect both Phase 3 filesystem-aware procedures from the live downloads
    root to the dedicated Phase 3 rehearsal root.

Safety:
    - Refuses production ROK_TRACKER.
    - Requires the exact representative-copy database name.
    - Requires sysadmin because the rehearsal exercises xp_cmdshell.
    - Requires the exact known path-reference count for each procedure.
    - Changes procedure text only in the representative database.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL';
DECLARE @LiveRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads\';
DECLARE @TestRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test_phase3_rehearsal\';
IF DB_NAME() = N'ROK_TRACKER'
    THROW 52010, 'Phase 3 path override refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> @ExpectedDatabase
    THROW 52011, 'Phase 3 path override is connected to the wrong database.', 1;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
    THROW 52012, 'Phase 3 path override requires a sysadmin session.', 1;

IF @@TRANCOUNT <> 0
    THROW 52013, 'Phase 3 path override requires no existing user transaction.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.configurations
    WHERE [name] = N'xp_cmdshell'
      AND value_in_use = 1
)
BEGIN
    THROW 52014,
        'xp_cmdshell is not enabled; do not enable it solely for this rehearsal.',
        1;
END;

DROP TABLE IF EXISTS #PathProbe;

CREATE TABLE #PathProbe
(
    FileExists int NULL,
    FileIsDirectory int NULL,
    ParentDirectoryExists int NULL
);

INSERT #PathProbe
EXEC master.dbo.xp_fileexist @TestRoot;

IF NOT EXISTS
(
    SELECT 1
    FROM #PathProbe
    WHERE FileIsDirectory = 1
)
BEGIN
    THROW 52015,
        'The Phase 3 rehearsal root does not exist or is not visible to SQL Server.',
        1;
END;

TRUNCATE TABLE #PathProbe;

DECLARE @ArchiveRoot nvarchar(4000) =
    @TestRoot + N'Import_Archive\';

INSERT #PathProbe
EXEC master.dbo.xp_fileexist @ArchiveRoot;

IF NOT EXISTS
(
    SELECT 1
    FROM #PathProbe
    WHERE FileIsDirectory = 1
)
BEGIN
    THROW 52016,
        'The Phase 3 rehearsal archive root does not exist or is not visible to SQL Server.',
        1;
END;

DECLARE @Modules table
(
    ModuleName sysname NOT NULL PRIMARY KEY,
    ExpectedReferenceCount int NOT NULL,
    DefinitionBeforeSha256 char(64) NULL,
    DefinitionAfterSha256 char(64) NULL
);

INSERT @Modules (ModuleName, ExpectedReferenceCount)
VALUES
    (N'dbo.IMPORT_STAGING_PROC_CORE', 3),
    (N'dbo.ARCHIVE_IMPORT_STAGING_FILE', 2),
    (N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE', 2);

DECLARE @ModuleName sysname;
DECLARE @ExpectedReferenceCount int;
DECLARE @DefinitionBefore nvarchar(max);
DECLARE @DefinitionAfter nvarchar(max);
DECLARE @LiveReferenceCount int;
DECLARE @TestReferenceCount int;
DECLARE @DefinitionStart int;
DECLARE @LeadingDefinition nvarchar(80);

BEGIN TRANSACTION;

DECLARE module_cursor CURSOR LOCAL FAST_FORWARD
FOR
    SELECT ModuleName, ExpectedReferenceCount
    FROM @Modules
    ORDER BY ModuleName;

OPEN module_cursor;
FETCH NEXT FROM module_cursor
INTO @ModuleName, @ExpectedReferenceCount;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DefinitionBefore =
        OBJECT_DEFINITION(OBJECT_ID(@ModuleName, N'P'));

    IF @DefinitionBefore IS NULL
        THROW 52017, 'A required Phase 3 filesystem procedure is unavailable.', 1;

    SET @LiveReferenceCount =
        (
            LEN(@DefinitionBefore)
                - LEN(REPLACE(@DefinitionBefore, @LiveRoot, N''))
        ) / LEN(@LiveRoot);

    SET @TestReferenceCount =
        (
            LEN(@DefinitionBefore)
                - LEN(REPLACE(@DefinitionBefore, @TestRoot, N''))
        ) / LEN(@TestRoot);

    IF @LiveReferenceCount = @ExpectedReferenceCount
       AND @TestReferenceCount = 0
    BEGIN
        SET @DefinitionAfter =
            REPLACE(@DefinitionBefore, @LiveRoot, @TestRoot);

        SET @DefinitionStart = 1;
        WHILE @DefinitionStart <= LEN(@DefinitionAfter)
          AND UNICODE(SUBSTRING(
                  @DefinitionAfter,
                  @DefinitionStart,
                  1
              )) IN (9, 10, 13, 32, 65279)
        BEGIN
            SET @DefinitionStart += 1;
        END;

        SET @LeadingDefinition =
            UPPER(SUBSTRING(@DefinitionAfter, @DefinitionStart, 80));

        SET @LeadingDefinition =
            REPLACE(
                REPLACE(
                    REPLACE(@LeadingDefinition, NCHAR(9), N' '),
                    NCHAR(10),
                    N' '
                ),
                NCHAR(13),
                N' '
            );

        WHILE CHARINDEX(N'  ', @LeadingDefinition) > 0
            SET @LeadingDefinition =
                REPLACE(@LeadingDefinition, N'  ', N' ');

        IF LEFT(
               @LeadingDefinition,
               LEN(N'CREATE OR ALTER PROCEDURE')
           ) = N'CREATE OR ALTER PROCEDURE'
        BEGIN
            PRINT @ModuleName + N' already uses CREATE OR ALTER PROCEDURE.';
        END;
        ELSE IF LEFT(
                    @LeadingDefinition,
                    LEN(N'CREATE PROCEDURE')
                ) = N'CREATE PROCEDURE'
        BEGIN
            SET @DefinitionAfter =
                STUFF(
                    @DefinitionAfter,
                    @DefinitionStart,
                    LEN(N'CREATE'),
                    N'ALTER'
                );
        END;
        ELSE IF LEFT(
                    @LeadingDefinition,
                    LEN(N'ALTER PROCEDURE')
                ) <> N'ALTER PROCEDURE'
        BEGIN
            THROW 52018,
                'A Phase 3 filesystem procedure has an unsupported module header.',
                1;
        END;

        EXEC sys.sp_executesql @DefinitionAfter;
    END;
    ELSE IF @LiveReferenceCount = 0
            AND @TestReferenceCount = @ExpectedReferenceCount
    BEGIN
        SET @DefinitionAfter = @DefinitionBefore;
    END;
    ELSE
    BEGIN
        THROW 52019,
            'A Phase 3 filesystem procedure has unexpected path-reference drift.',
            1;
    END;

    SET @DefinitionAfter =
        OBJECT_DEFINITION(OBJECT_ID(@ModuleName, N'P'));

    SET @LiveReferenceCount =
        (
            LEN(@DefinitionAfter)
                - LEN(REPLACE(@DefinitionAfter, @LiveRoot, N''))
        ) / LEN(@LiveRoot);

    SET @TestReferenceCount =
        (
            LEN(@DefinitionAfter)
                - LEN(REPLACE(@DefinitionAfter, @TestRoot, N''))
        ) / LEN(@TestRoot);

    IF @LiveReferenceCount <> 0
       OR @TestReferenceCount <> @ExpectedReferenceCount
    BEGIN
        THROW 52020,
            'A Phase 3 filesystem procedure did not retain the exact test-path override.',
            1;
    END;

    UPDATE @Modules
    SET DefinitionBeforeSha256 =
            CONVERT(
                char(64),
                HASHBYTES(N'SHA2_256', @DefinitionBefore),
                2
            ),
        DefinitionAfterSha256 =
            CONVERT(
                char(64),
                HASHBYTES(N'SHA2_256', @DefinitionAfter),
                2
            )
    WHERE ModuleName = @ModuleName;

    FETCH NEXT FROM module_cursor
    INTO @ModuleName, @ExpectedReferenceCount;
END;

CLOSE module_cursor;
DEALLOCATE module_cursor;

COMMIT TRANSACTION;

SELECT
    N'phase3_test_path_override' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    ModuleName,
    @LiveRoot AS LiveRootRejected,
    @TestRoot AS ActiveTestRoot,
    DefinitionBeforeSha256,
    DefinitionAfterSha256,
    N'PASS' AS OverrideStatus
FROM @Modules
ORDER BY ModuleName;
