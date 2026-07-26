SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4];

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @ExpectedSnapshot sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
DECLARE @FailureProcedure nvarchar(517) =
    N'dbo.CREATE_THE_AVERAGES';
DECLARE @FailureErrorNumber int = 51091;
DECLARE @OriginalDefinition nvarchar(max);
DECLARE @InstalledDefinition nvarchar(max);

IF DB_NAME() <> @ExpectedDatabase
BEGIN
    THROW 51090,
        'Refusing to install the Phase-B failure outside the guarded rehearsal database.',
        1;
END;

IF NOT EXISTS (
    SELECT 1
    FROM sys.databases AS snapshot_db
    INNER JOIN sys.databases AS source_db
        ON source_db.database_id = snapshot_db.source_database_id
    WHERE snapshot_db.name = @ExpectedSnapshot
      AND snapshot_db.state_desc = N'ONLINE'
      AND source_db.name = @ExpectedDatabase
)
BEGIN
    THROW 51090,
        'The guarded pristine snapshot is not online for this rehearsal database.',
        1;
END;

IF OBJECT_ID(@FailureProcedure, N'P') IS NULL
BEGIN
    THROW 51090,
        'dbo.CREATE_THE_AVERAGES was not found in the rehearsal database.',
        1;
END;

SET @OriginalDefinition =
    OBJECT_DEFINITION(OBJECT_ID(@FailureProcedure, N'P'));

IF @OriginalDefinition LIKE
    N'%K98_UPDATE_ALL2_PHASE_B_FAILURE%'
BEGIN
    THROW 51090,
        'The controlled Phase-B failure is already installed. Reset from the snapshot before retrying.',
        1;
END;

EXEC sys.sp_executesql N'
ALTER PROCEDURE dbo.CREATE_THE_AVERAGES
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    -- K98_UPDATE_ALL2_PHASE_B_FAILURE
    THROW 51091,
        ''Controlled UPDATE_ALL2 Phase-B rehearsal failure.'',
        1;
END;
';

SET @InstalledDefinition =
    OBJECT_DEFINITION(OBJECT_ID(@FailureProcedure, N'P'));

IF @InstalledDefinition NOT LIKE
    N'%K98_UPDATE_ALL2_PHASE_B_FAILURE%'
BEGIN
    THROW 51090,
        'The controlled Phase-B failure could not be verified after installation.',
        1;
END;

SELECT
    N'update_all2_phase_b_failure_install' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @ExpectedSnapshot AS SnapshotName,
    N'ONLINE' AS RequiredSnapshotState,
    @FailureProcedure AS FailureProcedure,
    @FailureErrorNumber AS ExpectedErrorNumber,
    CONVERT(
        varchar(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(varbinary(max), @OriginalDefinition)
        ),
        2
    ) AS OriginalDefinitionSha256,
    CONVERT(
        varchar(64),
        HASHBYTES(
            'SHA2_256',
            CONVERT(varbinary(max), @InstalledDefinition)
        ),
        2
    ) AS InstalledDefinitionSha256,
    SYSUTCDATETIME() AS InstalledAtUtc,
    N'Run the controlled Phase-B failure wrapper. Reset from the pristine snapshot immediately after collecting evidence.'
        AS OperatorNextStep;
