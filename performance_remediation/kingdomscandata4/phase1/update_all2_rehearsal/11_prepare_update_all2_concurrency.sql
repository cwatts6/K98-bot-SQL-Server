SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4];

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @ExpectedSnapshot sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE';
DECLARE @ActiveFixture nvarchar(4000) =
    N'C:\discord_file_downloader\downloads_test\stats.csv';
DECLARE @FixturePresent int = 0;
DECLARE @BeforeKs4Rows bigint;
DECLARE @BeforeKs5Rows bigint;
DECLARE @BeforeKs4Scan bigint;
DECLARE @BeforeKs5Scan bigint;
DECLARE @SnapshotKs4Rows bigint;
DECLARE @SnapshotKs5Rows bigint;
DECLARE @SnapshotKs4Scan bigint;
DECLARE @SnapshotKs5Scan bigint;
DECLARE @RunId uniqueidentifier = NEWID();

IF DB_NAME() <> @ExpectedDatabase
BEGIN
    THROW 51093,
        'Refusing to prepare concurrency outside the guarded rehearsal database.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51093,
        'Concurrency preparation requires a session with no open transaction.',
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
    THROW 51093,
        'The guarded pristine snapshot is not online for this rehearsal database.',
        1;
END;

IF COALESCE(
    OBJECT_DEFINITION(
        OBJECT_ID(N'dbo.CREATE_THE_AVERAGES', N'P')
    ),
    N''
) LIKE N'%K98_UPDATE_ALL2_PHASE_B_FAILURE%'
BEGIN
    THROW 51093,
        'The controlled Phase-B failure stub is still installed. Reset first.',
        1;
END;

EXEC master.dbo.xp_fileexist
    @ActiveFixture,
    @FixturePresent OUTPUT;

IF @FixturePresent <> 1
BEGIN
    THROW 51093,
        'The representative fixture is not present at the guarded test path.',
        1;
END;

SELECT
    @BeforeKs4Rows = COUNT_BIG(*),
    @BeforeKs4Scan = MAX(SCANORDER)
FROM dbo.KingdomScanData4;

SELECT
    @BeforeKs5Rows = COUNT_BIG(*),
    @BeforeKs5Scan = MAX(SCANORDER)
FROM dbo.KingdomScanData5;

SELECT
    @SnapshotKs4Rows = COUNT_BIG(*),
    @SnapshotKs4Scan = MAX(SCANORDER)
FROM
    [ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE].dbo.KingdomScanData4;

SELECT
    @SnapshotKs5Rows = COUNT_BIG(*),
    @SnapshotKs5Scan = MAX(SCANORDER)
FROM
    [ROK_TRACKER_BACKUP_TEST_KS4_UPDATE_ALL2_PRISTINE].dbo.KingdomScanData5;

IF @BeforeKs4Rows <> @SnapshotKs4Rows
   OR @BeforeKs5Rows <> @SnapshotKs5Rows
   OR @BeforeKs4Scan <> @SnapshotKs4Scan
   OR @BeforeKs5Scan <> @SnapshotKs5Scan
BEGIN
    THROW 51093,
        'The rehearsal database does not match its pristine snapshot.',
        1;
END;

DROP TABLE IF EXISTS dbo.K98_UpdateAll2ConcurrencyResult;
DROP TABLE IF EXISTS dbo.K98_UpdateAll2ConcurrencyReady;
DROP TABLE IF EXISTS dbo.K98_UpdateAll2ConcurrencyControl;

CREATE TABLE dbo.K98_UpdateAll2ConcurrencyControl
(
    ControlId tinyint NOT NULL
        CONSTRAINT PK_K98_UpdateAll2ConcurrencyControl
        PRIMARY KEY,
    RunId uniqueidentifier NOT NULL,
    PreparedAtUtc datetime2(7) NOT NULL,
    StartAtUtc datetime2(7) NULL,
    BeforeKs4Rows bigint NOT NULL,
    BeforeKs5Rows bigint NOT NULL,
    BeforeKs4Scan bigint NOT NULL,
    BeforeKs5Scan bigint NOT NULL,
    CONSTRAINT CK_K98_UpdateAll2ConcurrencyControl_Id
        CHECK (ControlId = 1)
);

CREATE TABLE dbo.K98_UpdateAll2ConcurrencyReady
(
    RunId uniqueidentifier NOT NULL,
    SessionLabel nchar(1) NOT NULL,
    SessionId smallint NOT NULL,
    ReadyAtUtc datetime2(7) NOT NULL,
    CONSTRAINT PK_K98_UpdateAll2ConcurrencyReady
        PRIMARY KEY (RunId, SessionLabel),
    CONSTRAINT UQ_K98_UpdateAll2ConcurrencyReady_Session
        UNIQUE (RunId, SessionId),
    CONSTRAINT CK_K98_UpdateAll2ConcurrencyReady_Label
        CHECK (SessionLabel IN (N'A', N'B'))
);

CREATE TABLE dbo.K98_UpdateAll2ConcurrencyResult
(
    RunId uniqueidentifier NOT NULL,
    SessionLabel nchar(1) NOT NULL,
    SessionId smallint NOT NULL,
    StartedAtUtc datetime2(7) NOT NULL,
    CompletedAtUtc datetime2(7) NOT NULL,
    ElapsedMilliseconds bigint NOT NULL,
    ErrorNumber int NULL,
    ErrorMessage nvarchar(4000) NULL,
    TransactionCountAfterCall int NOT NULL,
    XactStateAfterCall int NOT NULL,
    TransactionCountAfterCleanup int NOT NULL,
    CONSTRAINT PK_K98_UpdateAll2ConcurrencyResult
        PRIMARY KEY (RunId, SessionLabel)
);

INSERT INTO dbo.K98_UpdateAll2ConcurrencyControl
(
    ControlId,
    RunId,
    PreparedAtUtc,
    StartAtUtc,
    BeforeKs4Rows,
    BeforeKs5Rows,
    BeforeKs4Scan,
    BeforeKs5Scan
)
VALUES
(
    1,
    @RunId,
    SYSUTCDATETIME(),
    NULL,
    @BeforeKs4Rows,
    @BeforeKs5Rows,
    @BeforeKs4Scan,
    @BeforeKs5Scan
);

SELECT
    N'update_all2_concurrency_prepare' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    @RunId AS RunId,
    @BeforeKs4Rows AS BeforeKs4Rows,
    @BeforeKs5Rows AS BeforeKs5Rows,
    @BeforeKs4Scan AS BeforeKs4Scan,
    @BeforeKs5Scan AS BeforeKs5Scan,
    @FixturePresent AS FixturePresent,
    N'Open 12_run_update_all2_concurrency_session.sql in two SSMS windows, then execute both windows.'
        AS OperatorNextStep;
