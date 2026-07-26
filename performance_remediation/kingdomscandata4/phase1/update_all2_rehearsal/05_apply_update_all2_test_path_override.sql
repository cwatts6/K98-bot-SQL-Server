/*
Purpose:
    Apply the smallest possible test-only change to dbo.IMPORT_STAGING_PROC:
    replace the live downloads root with the isolated UPDATE_ALL2 rehearsal
    root.

Safety:
    - Refuses to run in production ROK_TRACKER.
    - Requires the exact restored-copy database name.
    - Requires sysadmin because the rehearsal exercises xp_cmdshell.
    - Requires exactly three known live-root references, or an already applied
      three-reference test override.
    - Does not change the repository procedure definition or production DB.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExpectedDatabase sysname = N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @LiveRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads\';
DECLARE @TestRoot nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\';
DECLARE @ExpectedReferenceCount int = 3;

IF DB_NAME() = N'ROK_TRACKER'
BEGIN
    THROW 51200,
        'Safety stop: the UPDATE_ALL2 rehearsal override cannot run in production ROK_TRACKER.',
        1;
END;

IF DB_NAME() <> @ExpectedDatabase
BEGIN
    DECLARE @WrongDatabaseMessage nvarchar(2048) =
        CONCAT(
            N'Safety stop: connected database is ',
            QUOTENAME(DB_NAME()),
            N'; expected ',
            QUOTENAME(@ExpectedDatabase),
            N'.'
        );
    THROW 51201, @WrongDatabaseMessage, 1;
END;

IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
BEGIN
    THROW 51202,
        'The rehearsal path override requires a sysadmin session.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51203,
        'Run the rehearsal path override with no existing user transaction.',
        1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.configurations
    WHERE name = N'xp_cmdshell'
      AND value_in_use = 1
)
BEGIN
    THROW 51204,
        'xp_cmdshell is not enabled; do not enable it solely through this script.',
        1;
END;

IF OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P') IS NULL
BEGIN
    THROW 51205,
        'Required procedure dbo.IMPORT_STAGING_PROC does not exist.',
        1;
END;

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
    THROW 51206,
        'Required rehearsal directory C:\discord_file_downloader\downloads_test\ does not exist or is not visible to SQL Server.',
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
    THROW 51207,
        'Required rehearsal archive directory downloads_test\Import_Archive\ does not exist or is not visible to SQL Server.',
        1;
END;

DECLARE @DefinitionBefore nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'));

IF @DefinitionBefore IS NULL
BEGIN
    THROW 51210,
        'dbo.IMPORT_STAGING_PROC exists but its definition is unavailable; verify VIEW DEFINITION and that the module is not encrypted.',
        1;
END;

DECLARE @LiveReferenceCount int =
(
    LEN(@DefinitionBefore)
        - LEN(REPLACE(@DefinitionBefore, @LiveRoot, N''))
) / LEN(@LiveRoot);

DECLARE @TestReferenceCount int =
(
    LEN(@DefinitionBefore)
        - LEN(REPLACE(@DefinitionBefore, @TestRoot, N''))
) / LEN(@TestRoot);

IF @LiveReferenceCount = @ExpectedReferenceCount
   AND @TestReferenceCount = 0
BEGIN
    DECLARE @DefinitionAfter nvarchar(max) =
        REPLACE(@DefinitionBefore, @LiveRoot, @TestRoot);

    /*
    OBJECT_DEFINITION preserves the module verb used when the procedure was
    deployed. Some restored copies therefore return CREATE PROCEDURE rather
    than ALTER PROCEDURE. The object already exists, so normalize only the
    leading module verb before replaying the otherwise unchanged definition.
    */
    DECLARE @DefinitionStart int = 1;

    WHILE @DefinitionStart <= LEN(@DefinitionAfter)
      AND UNICODE(SUBSTRING(@DefinitionAfter, @DefinitionStart, 1))
          IN (9, 10, 13, 32, 65279)
    BEGIN
        SET @DefinitionStart += 1;
    END;

    DECLARE @LeadingDefinition nvarchar(40) =
        UPPER(SUBSTRING(@DefinitionAfter, @DefinitionStart, 40));

    IF LEFT(@LeadingDefinition, LEN(N'CREATE OR ALTER PROCEDURE'))
        = N'CREATE OR ALTER PROCEDURE'
    BEGIN
        -- The stored definition can already be replayed safely.
        PRINT 'Stored module verb is CREATE OR ALTER PROCEDURE.';
    END;
    ELSE IF LEFT(@LeadingDefinition, LEN(N'CREATE OR ALTER PROC '))
        = N'CREATE OR ALTER PROC '
    BEGIN
        -- The stored definition can already be replayed safely.
        PRINT 'Stored module verb is CREATE OR ALTER PROC.';
    END;
    ELSE IF LEFT(@LeadingDefinition, LEN(N'CREATE PROCEDURE'))
        = N'CREATE PROCEDURE'
    BEGIN
        SET @DefinitionAfter =
            STUFF(
                @DefinitionAfter,
                @DefinitionStart,
                LEN(N'CREATE PROCEDURE'),
                N'ALTER PROCEDURE'
            );
    END;
    ELSE IF LEFT(@LeadingDefinition, LEN(N'CREATE PROC '))
        = N'CREATE PROC '
    BEGIN
        SET @DefinitionAfter =
            STUFF(
                @DefinitionAfter,
                @DefinitionStart,
                LEN(N'CREATE PROC'),
                N'ALTER PROC'
            );
    END;
    ELSE IF LEFT(@LeadingDefinition, LEN(N'ALTER PROCEDURE'))
        = N'ALTER PROCEDURE'
    BEGIN
        PRINT 'Stored module verb is ALTER PROCEDURE.';
    END;
    ELSE IF LEFT(@LeadingDefinition, LEN(N'ALTER PROC '))
        = N'ALTER PROC '
    BEGIN
        PRINT 'Stored module verb is ALTER PROC.';
    END;
    ELSE
    BEGIN
        THROW 51211,
            'Procedure drift detected: the stored definition does not begin with a supported CREATE/ALTER PROCEDURE verb.',
            1;
    END;

    EXEC sys.sp_executesql @DefinitionAfter;
END;
ELSE IF @LiveReferenceCount = 0
        AND @TestReferenceCount = @ExpectedReferenceCount
BEGIN
    PRINT 'The isolated rehearsal path override is already applied.';
END;
ELSE
BEGIN
    DECLARE @UnexpectedDefinitionMessage nvarchar(2048) =
        CONCAT(
            N'Procedure drift detected: expected either ',
            @ExpectedReferenceCount,
            N' live references or ',
            @ExpectedReferenceCount,
            N' test references; found live=',
            @LiveReferenceCount,
            N', test=',
            @TestReferenceCount,
            N'.'
        );
    THROW 51208, @UnexpectedDefinitionMessage, 1;
END;

DECLARE @VerifiedDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC', N'P'));

DECLARE @VerifiedLiveReferenceCount int =
(
    LEN(@VerifiedDefinition)
        - LEN(REPLACE(@VerifiedDefinition, @LiveRoot, N''))
) / LEN(@LiveRoot);

DECLARE @VerifiedTestReferenceCount int =
(
    LEN(@VerifiedDefinition)
        - LEN(REPLACE(@VerifiedDefinition, @TestRoot, N''))
) / LEN(@TestRoot);

IF @VerifiedLiveReferenceCount <> 0
   OR @VerifiedTestReferenceCount <> @ExpectedReferenceCount
BEGIN
    THROW 51209,
        'The rehearsal path override could not be verified after ALTER PROCEDURE.',
        1;
END;

DECLARE @FixtureExists int = 0;
DECLARE @ActiveFixturePath nvarchar(4000) =
    @TestRoot + N'stats.csv';

EXEC master.dbo.xp_fileexist
    @ActiveFixturePath,
    @FixtureExists OUTPUT;

SELECT
    N'update_all2_rehearsal_path_override' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    OBJECT_SCHEMA_NAME(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC'))
        + N'.'
        + OBJECT_NAME(OBJECT_ID(N'dbo.IMPORT_STAGING_PROC'))
        AS ProcedureName,
    @LiveRoot AS LiveRootRejected,
    @TestRoot AS ActiveTestRoot,
    @VerifiedLiveReferenceCount AS LiveReferenceCount,
    @VerifiedTestReferenceCount AS TestReferenceCount,
    CONVERT(char(64), HASHBYTES('SHA2_256', @DefinitionBefore), 2)
        AS DefinitionBeforeSha256,
    CONVERT(char(64), HASHBYTES('SHA2_256', @VerifiedDefinition), 2)
        AS DefinitionAfterSha256,
    CONVERT(bit, @FixtureExists) AS StatsCsvCurrentlyVisible,
    SYSUTCDATETIME() AS AppliedAtUtc;
