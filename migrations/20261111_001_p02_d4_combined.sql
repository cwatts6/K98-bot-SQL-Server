/*
MigrationId: 20261111_001_p02_d4_combined
Purpose: Install combined P02 maintenance and approved legacy boundaries over Phase 1
Author: Codex (operator-approved source implementation; deployment separate)
CreatedUtc: 2026-11-11
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Required
DataChange: Yes
DataSafetyPlan: Included
DataSafetyNotes: Exact drained coordinator owns transaction and receipt. Create four new ledgers once; preserve all existing work, queue and capture rows. Precommit failure rolls back; committed receipt resumes forward without replay or reseeding. No numeric downgrade.
EstimatedRowsAffected: Eight initial rows in three new ledgers; fourth new ledger starts empty
*/
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 52981,'D4 release-owned transaction required.',1;
IF DB_NAME()<>N'ROK_TRACKER' THROW 52981,'Exact D4 production database required.',1;
-- dbo.MaintenanceBackupWork
EXEC sys.sp_executesql N'SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.MaintenanceBackupWork (
    ID tinyint NOT NULL CONSTRAINT PK_MaintenanceBackupWork PRIMARY KEY CONSTRAINT CK_MaintenanceBackupWork_ID CHECK (ID=1),
    DueGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceBackupWork_DueGeneration DEFAULT 0,
    RequestedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceBackupWork_RequestedGeneration DEFAULT 0,
    ClaimedGeneration bigint NULL,
    ClaimID uniqueidentifier NULL,
    State varchar(12) NOT NULL CONSTRAINT DF_MaintenanceBackupWork_State DEFAULT ''requested''
        CONSTRAINT CK_MaintenanceBackupWork_State CHECK (State IN (''pending'',''running'',''requested'',''failed'',''unknown'')),
    DueUTC datetime2(3) NULL, StartedUTC datetime2(3) NULL, RequestedUTC datetime2(3) NULL,
    FirstFailure varchar(32) NULL, FirstFailureUTC datetime2(3) NULL, LastFailure varchar(32) NULL,
    CONSTRAINT CK_MaintenanceBackupWork_Generation CHECK (DueGeneration>=RequestedGeneration AND RequestedGeneration>=0
        AND (ClaimedGeneration IS NULL OR (ClaimedGeneration>0 AND ClaimedGeneration<=DueGeneration)))
);
INSERT dbo.MaintenanceBackupWork(ID) VALUES(1);';
-- dbo.MaintenanceConfigurationWork
EXEC sys.sp_executesql N'SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.MaintenanceConfigurationWork (
    ID int NOT NULL CONSTRAINT PK_MaintenanceConfigurationWork PRIMARY KEY CONSTRAINT CK_MaintenanceConfigurationWork_ID CHECK(ID=1),
    DueRows bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_DueRows DEFAULT 0,
    CompletedRows bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_CompletedRows DEFAULT 0,
    LastBatchRows int NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_LastBatchRows DEFAULT 0,
    LastScan int NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_LastScan DEFAULT 0,
    LargeBatchGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_LargeBatchGeneration DEFAULT 0,
    CompletedLargeBatchGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_CompletedLargeBatchGeneration DEFAULT 0,
    UpkeepCompletedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_UpkeepCompletedGeneration DEFAULT 0,
    UpkeepDisposition varchar(12) NOT NULL CONSTRAINT DF_MaintenanceConfigurationWork_UpkeepDisposition DEFAULT ''not_run'' CONSTRAINT CK_MaintenanceConfigurationWork_Disposition CHECK(UpkeepDisposition IN (''not_run'',''ineligible'',''complete'')),
    FirstLogErrorNumber int NULL,
    CONSTRAINT CK_MaintenanceConfigurationWork_Rows CHECK
      (DueRows>=CompletedRows AND CompletedRows>=0 AND LastBatchRows>=0),
    CONSTRAINT CK_MaintenanceConfigurationWork_Generation CHECK
      (LargeBatchGeneration>=CompletedLargeBatchGeneration AND CompletedLargeBatchGeneration>=0
       AND UpkeepCompletedGeneration>=0)
);
INSERT dbo.MaintenanceConfigurationWork(ID) VALUES(1);';
-- dbo.MaintenanceKvkWork
EXEC sys.sp_executesql N'SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.MaintenanceKvkWork (
    KVKNo int NOT NULL CONSTRAINT PK_MaintenanceKvkWork PRIMARY KEY,
    DueGeneration bigint NOT NULL,
    CompletedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceKvkWork_CompletedGeneration DEFAULT(0),
    DueObjectID int NOT NULL,
    DueObjectCreateDate datetime NOT NULL,
    DueHeaderRevision int NOT NULL,
    State varchar(12) NOT NULL CONSTRAINT DF_MaintenanceKvkWork_State DEFAULT(''pending''),
    ClaimID uniqueidentifier NULL,
    ClaimedGeneration bigint NULL,
    ClaimedObjectID int NULL,
    ClaimedObjectCreateDate datetime NULL,
    ClaimedHeaderRevision int NULL,
    FirstErrorNumber int NULL,
    FirstErrorUTC datetime2(3) NULL,
    LastErrorNumber int NULL,
    CompletedUTC datetime2(3) NULL,
    CONSTRAINT CK_MaintenanceKvkWork_Generation CHECK
        (KVKNo>0 AND DueGeneration>0 AND CompletedGeneration>=0
         AND CompletedGeneration<=DueGeneration AND DueHeaderRevision>0),
    CONSTRAINT CK_MaintenanceKvkWork_State CHECK
        (State IN (''pending'',''running'',''complete'',''failed'',''unknown''))
);';
-- dbo.MaintenanceWork
EXEC sys.sp_executesql N'SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.MaintenanceWork (
    Kind varchar(24) NOT NULL CONSTRAINT PK_MaintenanceWork PRIMARY KEY,
    DueGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_Due DEFAULT 0,
    CompletedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_Completed DEFAULT 0,
    KS4DueGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_KS4Due DEFAULT 0,
    KS4CompletedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_KS4Done DEFAULT 0,
    DashboardDueGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_DashboardDueGeneration DEFAULT 0,
    DashboardCompletedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_DashboardCompletedGeneration DEFAULT 0,
    SummaryDueGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_SummaryDueGeneration DEFAULT 0,
    SummaryCompletedGeneration bigint NOT NULL CONSTRAINT DF_MaintenanceWork_SummaryCompletedGeneration DEFAULT 0,
    CONSTRAINT CK_MaintenanceWork_Final CHECK (
        DashboardCompletedGeneration>=0 AND DashboardCompletedGeneration<=DashboardDueGeneration
        AND DashboardDueGeneration<=DueGeneration AND SummaryCompletedGeneration>=0
        AND SummaryCompletedGeneration<=SummaryDueGeneration AND SummaryDueGeneration<=DueGeneration
        AND (Kind=''final_stats'' OR (DashboardDueGeneration=0 AND SummaryDueGeneration=0))),
    ClaimedGeneration bigint NULL,
    ClaimID uniqueidentifier NULL,
    LastRequestID uniqueidentifier NULL,
    State varchar(12) NOT NULL CONSTRAINT DF_MaintenanceWork_State DEFAULT ''complete'',
    DueUTC datetime2(3) NULL,
    StartedUTC datetime2(3) NULL,
    CompletedUTC datetime2(3) NULL,
    FirstErrorNumber int NULL,
    FirstErrorUTC datetime2(3) NULL,
    LastErrorNumber int NULL,
    CONSTRAINT CK_MaintenanceWork_Kind CHECK (Kind IN
        (''import'',''configuration'',''player_report'',''kvk_output'',''final_stats'',''post_import'')),
    CONSTRAINT CK_MaintenanceWork_State CHECK (State IN
        (''pending'',''running'',''complete'',''failed'',''unknown'')),
    CONSTRAINT CK_MaintenanceWork_KS4 CHECK
        (KS4CompletedGeneration>=0 AND KS4DueGeneration>=KS4CompletedGeneration
         AND KS4DueGeneration<=DueGeneration AND (Kind=''import'' OR KS4DueGeneration=0)),
    CONSTRAINT CK_MaintenanceWork_Generation CHECK
        (DueGeneration>=CompletedGeneration AND CompletedGeneration>=0
         AND (ClaimedGeneration IS NULL OR
              (ClaimedGeneration>0 AND ClaimedGeneration<=DueGeneration)))
);
INSERT dbo.MaintenanceWork(Kind) VALUES (''import''),(''configuration''),(''player_report''),
    (''kvk_output''),(''final_stats''),(''post_import'');';
-- dbo.usp_P02LegacyQueueState
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_P02LegacyQueueState @LedgerPresent bit OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Only this fixed metadata observation crosses execution context. Queue DML
    -- remains in the caller-context APIs. A changed owner fails closed.
    IF USER_ID() <> 1
        THROW 52942, ''Legacy backup queue deployment state is unavailable; no queue work was performed.'', 1;
    SET @LedgerPresent = CASE WHEN OBJECT_ID(N''dbo.MaintenanceBackupWork'') IS NULL THEN 0 ELSE 1 END;
END;';
-- dbo.CREATE_DELTA_TABLES
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[CREATE_DELTA_TABLES]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- ✅ Ensures transaction rolls back on any error
    
    DECLARE @StartTime DATETIME2 = SYSUTCDATETIME();
    DECLARE @RowsProcessed INT = 0;
    DECLARE @NewMaxScan INT = 0;
    

    DECLARE @DeltaPreprocessingLockResult int;
    DECLARE @DeltaPreprocessingLockHeld bit = 0;
    DECLARE @DeltaPreprocessingLockResource nvarchar(255) =
        N''K98:TargetPublication:DeltaPreprocessing'';

    EXEC @DeltaPreprocessingLockResult = sys.sp_getapplock
        @Resource = @DeltaPreprocessingLockResource,
        @LockMode = N''Exclusive'',
        @LockOwner = N''Session'',
        @LockTimeout = 60000,
        @DbPrincipal = N''public'';

    IF @DeltaPreprocessingLockResult < 0
        THROW 52622, ''CREATE_DELTA_TABLES could not acquire the shared delta-preprocessing mutex.'', 1;

    SET @DeltaPreprocessingLockHeld = 1;

    BEGIN TRY

    ----------------------------------------------------------------
    -- Step 1: Determine what''s already been processed
    ----------------------------------------------------------------
    DECLARE @LastProcessedScan INT;
    
    PRINT ''----------------------------------------'';
    PRINT ''Starting delta processing at '' + CONVERT(VARCHAR(30), @StartTime, 120);

	DECLARE @DeltaMetricsExists BIT = CASE WHEN OBJECT_ID(N''dbo.DeltaMetrics'', N''U'') IS NOT NULL THEN 1 ELSE 0 END;

    IF @DeltaMetricsExists = 0
    BEGIN
        RAISERROR(''DeltaMetrics table missing. Run dbo.DeltaMetrics.Build.sql to create/backfill before executing CREATE_DELTA_TABLES.'', 16, 1);
        RETURN;
    END

    
    -- Find the highest scan order we''ve already processed across all delta tables
    SELECT @LastProcessedScan = ISNULL(MAX(MaxDelta), 0)
    FROM (
        SELECT MAX(DeltaOrder) AS MaxDelta FROM dbo.DeltaMetrics
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM DeadsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HelpsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSASSISTDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSGatheredDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM POWERDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM KillPointsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HealedTroopsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RangedPointsDelta
    ) AS AllDeltas;

    -- ✅ Data integrity check: Verify all delta tables are in sync
    DECLARE @MinMaxDelta FLOAT, @MaxMaxDelta FLOAT;
    SELECT 
        @MinMaxDelta = MIN(MaxDelta),
        @MaxMaxDelta = MAX(MaxDelta)
    FROM (
        SELECT MAX(DeltaOrder) AS MaxDelta FROM dbo.DeltaMetrics
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T4KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM T5KillDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM DeadsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HelpsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSASSISTDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RSSGatheredDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM POWERDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM KillPointsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM HealedTroopsDelta
        UNION ALL
        SELECT MAX(DeltaOrder) FROM RangedPointsDelta
    ) AS AllDeltas;
    
    IF @MinMaxDelta <> @MaxMaxDelta
    BEGIN
        PRINT ''❌ ERROR: Delta tables are out of sync!'';
        PRINT ''   Minimum MaxDeltaOrder: '' + CAST(@MinMaxDelta AS VARCHAR(20));
        PRINT ''   Maximum MaxDeltaOrder: '' + CAST(@MaxMaxDelta AS VARCHAR(20));
        PRINT '''';
        PRINT ''Detailed breakdown:'';
        
		SELECT 
            ''DeltaMetrics'' AS TableName, 
            MAX(DeltaOrder) AS MaxDeltaOrder, 
            COUNT(*) AS TotalRows 
        FROM dbo.DeltaMetrics
        UNION ALL
        SELECT 
            ''T4T5KillDelta'' AS TableName, 
            MAX(DeltaOrder) AS MaxDeltaOrder, 
            COUNT(*) AS TotalRows 
        FROM T4T5KillDelta
        UNION ALL
        SELECT ''T4KillDelta'', MAX(DeltaOrder), COUNT(*) FROM T4KillDelta
        UNION ALL
        SELECT ''T5KillDelta'', MAX(DeltaOrder), COUNT(*) FROM T5KillDelta
        UNION ALL
        SELECT ''DeadsDelta'', MAX(DeltaOrder), COUNT(*) FROM DeadsDelta
        UNION ALL
        SELECT ''HelpsDelta'', MAX(DeltaOrder), COUNT(*) FROM HelpsDelta
        UNION ALL
        SELECT ''RSSASSISTDelta'', MAX(DeltaOrder), COUNT(*) FROM RSSASSISTDelta
        UNION ALL
        SELECT ''RSSGatheredDelta'', MAX(DeltaOrder), COUNT(*) FROM RSSGatheredDelta
        UNION ALL
        SELECT ''POWERDelta'', MAX(DeltaOrder), COUNT(*) FROM POWERDelta
        UNION ALL
        SELECT ''KillPointsDelta'', MAX(DeltaOrder), COUNT(*) FROM KillPointsDelta
        UNION ALL
        SELECT ''HealedTroopsDelta'', MAX(DeltaOrder), COUNT(*) FROM HealedTroopsDelta
        UNION ALL
        SELECT ''RangedPointsDelta'', MAX(DeltaOrder), COUNT(*) FROM RangedPointsDelta
        ORDER BY MaxDeltaOrder DESC;
        
        RAISERROR(''Delta tables are out of sync. Please fix manually before proceeding.'', 16, 1);
        RETURN;
    END

    IF @LastProcessedScan IS NULL SET @LastProcessedScan = 0;
    
    PRINT ''Last processed scan order: '' + CAST(@LastProcessedScan AS VARCHAR(20));

    ----------------------------------------------------------------
    -- Step 2: Build base data for NEW scans only
    ----------------------------------------------------------------
    SELECT 
        GovernorID,
        SCANORDER,
        SUM(T4_Kills) AS T4_Kills,
        SUM(T5_Kills) AS T5_Kills,
        SUM([T4&T5_Kills]) AS T4T5_Kills,
        SUM([Power]) AS Power,
        SUM([KillPoints]) AS KillPoints,
        SUM([Deads]) AS Deads,
        SUM([Helps]) AS Helps,
        SUM([RSSAssistance]) AS RSSAssist,
        SUM([RSS_Gathered]) AS RSSGathered,
        SUM([HealedTroops]) AS HealedTroops,
        SUM([RangedPoints]) AS RangedPoints
    INTO #NewScans
    FROM dbo.kingdomscandata4
    WHERE SCANORDER > @LastProcessedScan
    GROUP BY GovernorID, SCANORDER;

    SELECT @RowsProcessed = COUNT(*) FROM #NewScans;
    SELECT @NewMaxScan = ISNULL(MAX(SCANORDER), @LastProcessedScan) FROM #NewScans;

    IF @RowsProcessed = 0
    BEGIN
        PRINT ''No new scans to process.'';
        PRINT ''----------------------------------------'';
        DROP TABLE #NewScans;

        EXEC @DeltaPreprocessingLockResult = sys.sp_releaseapplock
            @Resource = @DeltaPreprocessingLockResource,
            @LockOwner = N''Session'',
            @DbPrincipal = N''public'';

        IF @DeltaPreprocessingLockResult < 0
            THROW 52623, ''CREATE_DELTA_TABLES could not release the shared delta-preprocessing mutex.'', 1;

        SET @DeltaPreprocessingLockHeld = 0;
        RETURN;
    END

    PRINT ''New scan orders found: '' + CAST(@LastProcessedScan AS VARCHAR(20)) + '' to '' + CAST(@NewMaxScan AS VARCHAR(20));
    PRINT ''Processing '' + CAST(@RowsProcessed AS VARCHAR(10)) + '' new scan records...'';

    CREATE CLUSTERED INDEX IX_NewScans ON #NewScans (GovernorID, SCANORDER);

----------------------------------------------------------------
-- Step 3: Get ABSOLUTE VALUES at the last processed scan
----------------------------------------------------------------

PRINT ''Calculating absolute values at last processed scan...'';

;WITH LastAbsoluteValues AS (
    SELECT 
        GovernorID,
        SUM(T4KillsDelta) AS T4_Kills_Absolute,
        SUM(T5KillsDelta) AS T5_Kills_Absolute,
        SUM(T4T5KillsDelta) AS T4T5_Kills_Absolute,
        SUM(Power_Delta) AS Power_Absolute,
        SUM(KillPointsDelta) AS KillPoints_Absolute,
        SUM(DeadsDelta) AS Deads_Absolute,
        SUM(HelpsDelta) AS Helps_Absolute,
        SUM(RSSAssistDelta) AS RSSAssist_Absolute,
        SUM(RSSGatheredDelta) AS RSSGathered_Absolute,
        SUM(HealedTroopsDelta) AS HealedTroops_Absolute,
        SUM(RangedPointsDelta) AS RangedPoints_Absolute
    FROM dbo.DeltaMetrics dm
    WHERE dm.DeltaOrder <= @LastProcessedScan
    GROUP BY GovernorID
)
SELECT * INTO #LastAbsoluteValues FROM LastAbsoluteValues;

CREATE CLUSTERED INDEX IX_LastAbsolute ON #LastAbsoluteValues (GovernorID);

----------------------------------------------------------------
-- Step 4: Calculate deltas = CurrentValue - PreviousValue
----------------------------------------------------------------

PRINT ''Calculating deltas...'';

;WITH AbsoluteValues AS (
    SELECT
        ns.GovernorID,
        ns.SCANORDER,
        ns.T4_Kills AS T4_Current,
        ns.T5_Kills AS T5_Current,
        ns.T4T5_Kills AS T4T5_Current,
        ns.Power AS Power_Current,
        ns.KillPoints AS KillPoints_Current,
        ns.Deads AS Deads_Current,
        ns.Helps AS Helps_Current,
        ns.RSSAssist AS RSSAssist_Current,
        ns.RSSGathered AS RSSGathered_Current,
        ns.HealedTroops AS HealedTroops_Current,
        ns.RangedPoints AS RangedPoints_Current
    FROM #NewScans ns
),
AbsoluteWithLag AS (
    SELECT
        GovernorID,
        SCANORDER,
        T4_Current,
        LAG(T4_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T4_Previous,
        T5_Current,
        LAG(T5_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T5_Previous,
        T4T5_Current,
        LAG(T4T5_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS T4T5_Previous,
        Power_Current,
        LAG(Power_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Power_Previous,
        KillPoints_Current,
        LAG(KillPoints_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS KillPoints_Previous,
        Deads_Current,
        LAG(Deads_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Deads_Previous,
        Helps_Current,
        LAG(Helps_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS Helps_Previous,
        RSSAssist_Current,
        LAG(RSSAssist_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RSSAssist_Previous,
        RSSGathered_Current,
        LAG(RSSGathered_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RSSGathered_Previous,
        HealedTroops_Current,
        LAG(HealedTroops_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS HealedTroops_Previous,
        RangedPoints_Current,
        LAG(RangedPoints_Current, 1) OVER (PARTITION BY GovernorID ORDER BY SCANORDER) AS RangedPoints_Previous
    FROM AbsoluteValues
),
DeltaCalculations AS (
    SELECT
        awl.GovernorID,
        awl.SCANORDER,
        CAST(ISNULL(awl.T4_Current - ISNULL(awl.T4_Previous, ISNULL(lav.T4_Kills_Absolute, 0)), awl.T4_Current) AS FLOAT) AS T4_Delta,
        CAST(ISNULL(awl.T5_Current - ISNULL(awl.T5_Previous, ISNULL(lav.T5_Kills_Absolute, 0)), awl.T5_Current) AS FLOAT) AS T5_Delta,
        CAST(ISNULL(awl.T4T5_Current - ISNULL(awl.T4T5_Previous, ISNULL(lav.T4T5_Kills_Absolute, 0)), awl.T4T5_Current) AS FLOAT) AS T4T5_Delta,
        CAST(ISNULL(awl.Power_Current - ISNULL(awl.Power_Previous, ISNULL(lav.Power_Absolute, 0)), awl.Power_Current) AS FLOAT) AS Power_Delta,
        CAST(ISNULL(awl.KillPoints_Current - ISNULL(awl.KillPoints_Previous, ISNULL(lav.KillPoints_Absolute, 0)), awl.KillPoints_Current) AS BIGINT) AS KillPoints_Delta,
        CAST(ISNULL(awl.Deads_Current - ISNULL(awl.Deads_Previous, ISNULL(lav.Deads_Absolute, 0)), awl.Deads_Current) AS FLOAT) AS Deads_Delta,
        CAST(ISNULL(awl.Helps_Current - ISNULL(awl.Helps_Previous, ISNULL(lav.Helps_Absolute, 0)), awl.Helps_Current) AS FLOAT) AS Helps_Delta,
        CAST(ISNULL(awl.RSSAssist_Current - ISNULL(awl.RSSAssist_Previous, ISNULL(lav.RSSAssist_Absolute, 0)), awl.RSSAssist_Current) AS FLOAT) AS RSSAssist_Delta,
        CAST(ISNULL(awl.RSSGathered_Current - ISNULL(awl.RSSGathered_Previous, ISNULL(lav.RSSGathered_Absolute, 0)), awl.RSSGathered_Current) AS FLOAT) AS RSSGathered_Delta,
        CAST(ISNULL(awl.HealedTroops_Current - ISNULL(awl.HealedTroops_Previous, ISNULL(lav.HealedTroops_Absolute, 0)), awl.HealedTroops_Current) AS BIGINT) AS HealedTroops_Delta,
        CAST(ISNULL(awl.RangedPoints_Current - ISNULL(awl.RangedPoints_Previous, ISNULL(lav.RangedPoints_Absolute, 0)), awl.RangedPoints_Current) AS BIGINT) AS RangedPoints_Delta
    FROM AbsoluteWithLag awl
    LEFT JOIN #LastAbsoluteValues lav ON awl.GovernorID = lav.GovernorID
)
SELECT * INTO #DeltaCalculations FROM DeltaCalculations;
    
    ----------------------------------------------------------------
    -- Step 5: INSERT with TRANSACTION (all-or-nothing)
    ----------------------------------------------------------------
    
    PRINT ''Inserting deltas into tables (transactional)...'';
    
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @InsertedRows INT;
        
        INSERT INTO T4KillDelta (GovernorID, DeltaOrder, T4KILLSDelta)
        SELECT GovernorID, SCANORDER, T4_Delta FROM #DeltaCalculations;
        SET @InsertedRows = @@ROWCOUNT;
        PRINT ''  T4KillDelta: '' + CAST(@InsertedRows AS VARCHAR(10)) + '' rows'';

        INSERT INTO T5KillDelta (GovernorID, DeltaOrder, T5KILLSDelta)
        SELECT GovernorID, SCANORDER, T5_Delta FROM #DeltaCalculations;
        PRINT ''  T5KillDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO T4T5KillDelta (GovernorID, DeltaOrder, [T4&T5_KILLSDelta])
        SELECT GovernorID, SCANORDER, T4T5_Delta FROM #DeltaCalculations;
        PRINT ''  T4T5KillDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO POWERDelta (GovernorID, DeltaOrder, [Power_Delta])
        SELECT GovernorID, SCANORDER, Power_Delta FROM #DeltaCalculations;
        PRINT ''  POWERDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO KillPointsDelta (GovernorID, DeltaOrder, KillPointsDelta)
        SELECT GovernorID, SCANORDER, KillPoints_Delta FROM #DeltaCalculations;
        PRINT ''  KillPointsDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO DeadsDelta (GovernorID, DeltaOrder, DeadsDelta)
        SELECT GovernorID, SCANORDER, Deads_Delta FROM #DeltaCalculations;
        PRINT ''  DeadsDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO HelpsDelta (GovernorID, DeltaOrder, HelpsDelta)
        SELECT GovernorID, SCANORDER, Helps_Delta FROM #DeltaCalculations;
        PRINT ''  HelpsDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO RSSASSISTDelta (GovernorID, DeltaOrder, RSSAssistDelta)
        SELECT GovernorID, SCANORDER, RSSAssist_Delta FROM #DeltaCalculations;
        PRINT ''  RSSASSISTDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO RSSGatheredDelta (GovernorID, DeltaOrder, RSSGatheredDelta)
        SELECT GovernorID, SCANORDER, RSSGathered_Delta FROM #DeltaCalculations;
        PRINT ''  RSSGatheredDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO HealedTroopsDelta (GovernorID, DeltaOrder, HealedTroopsDelta)
        SELECT GovernorID, SCANORDER, HealedTroops_Delta FROM #DeltaCalculations;
        PRINT ''  HealedTroopsDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';

        INSERT INTO RangedPointsDelta (GovernorID, DeltaOrder, RangedPointsDelta)
        SELECT GovernorID, SCANORDER, RangedPoints_Delta FROM #DeltaCalculations;
        PRINT ''  RangedPointsDelta: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';
				
        INSERT INTO dbo.DeltaMetrics (
            DeltaOrder,
            GovernorID,
            T4KillsDelta,
            T5KillsDelta,
            T4T5KillsDelta,
            Power_Delta,
            KillPointsDelta,
            DeadsDelta,
            HelpsDelta,
            RSSAssistDelta,
            RSSGatheredDelta,
            HealedTroopsDelta,
            RangedPointsDelta
        )
        SELECT
            SCANORDER,
            GovernorID,
            T4_Delta,
            T5_Delta,
            T4T5_Delta,
            Power_Delta,
            KillPoints_Delta,
            Deads_Delta,
            Helps_Delta,
            RSSAssist_Delta,
            RSSGathered_Delta,
            HealedTroops_Delta,
            RangedPoints_Delta
        FROM #DeltaCalculations DC
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.DeltaMetrics dm
            WHERE dm.DeltaOrder = DC.SCANORDER
              AND dm.GovernorID = DC.GovernorID
        );
        PRINT ''  DeltaMetrics: '' + CAST(@@ROWCOUNT AS VARCHAR(10)) + '' rows'';
        
        EXEC dbo.usp_MaintenanceConfigurationDue @RowsProcessed=@RowsProcessed,@LastScan=@NewMaxScan;
        COMMIT TRANSACTION;
        PRINT ''✅ All delta inserts committed successfully.'';
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        
        PRINT ''❌ ERROR: Transaction rolled back!'';
        PRINT ''Error Message: '' + ERROR_MESSAGE();
        PRINT ''Error Number: '' + CAST(ERROR_NUMBER() AS VARCHAR(10));
        PRINT ''Error Line: '' + CAST(ERROR_LINE() AS VARCHAR(10));
        
        -- Cleanup
        DROP TABLE #NewScans;
        DROP TABLE #LastAbsoluteValues;
        DROP TABLE #DeltaCalculations;
        
        THROW;
    END CATCH

    -- Cleanup temp tables
    DROP TABLE #NewScans;
    DROP TABLE #LastAbsoluteValues;
    DROP TABLE #DeltaCalculations;

    EXEC @DeltaPreprocessingLockResult = sys.sp_releaseapplock
        @Resource = @DeltaPreprocessingLockResource,
        @LockOwner = N''Session'',
        @DbPrincipal = N''public'';

    IF @DeltaPreprocessingLockResult < 0
        THROW 52623, ''CREATE_DELTA_TABLES could not release the shared delta-preprocessing mutex.'', 1;

    SET @DeltaPreprocessingLockHeld = 0;
    END TRY
    BEGIN CATCH
        IF @DeltaPreprocessingLockHeld = 1
        BEGIN
            EXEC @DeltaPreprocessingLockResult = sys.sp_releaseapplock
                @Resource = @DeltaPreprocessingLockResource,
                @LockOwner = N''Session'',
                @DbPrincipal = N''public'';
        END;

        THROW;
    END CATCH;

    -- Optional upkeep and timing logs run only through the durable worker.
    SET NOCOUNT OFF;
END';
-- dbo.SP_Stats_for_Upload
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[SP_Stats_for_Upload]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @LatestKVK int,
        @MaxScan int,
        @KvkEndScanValue float,
        @KvkEndScan int,
        @ExpectedFinalScan int,
        @ProvenFinalScan int,
        @HeaderRowCount int,
        @HeaderRevision int,
        @HeaderState nvarchar(24),
        @FinalizationBasis nvarchar(24),
        @FinalDataAtUtc datetime2(0),
        @CurrentHeaderScan int,
        @CurrentHeaderRowCount int,
        @CurrentHeaderRevision int,
        @CurrentHeaderState nvarchar(24),
        @SourceRowCount bigint = 0,
        @InvalidGovernorRows bigint = 0,
        @DuplicateGovernorGroups bigint = 0,
        @WrongKvkRows bigint = 0,
        @CandidateRowCount bigint = 0,
        @PublishedRowCount bigint = 0,
        @ProvenScanDate datetime2(0),
        @ProvenScanDateMax datetime2(0),
        @ScanDateRowCount bigint = 0,
        @TableName sysname,
        @TableObjectName nvarchar(260),
        @TableNameFull nvarchar(260),
        @sql nvarchar(max),
        @Diagnostic nvarchar(2048),
        @FailureStage nvarchar(64) = N''preflight'',
        @ImportLockResult int,
        @LockResult int,
        @InitialTranCount int = @@TRANCOUNT,
        @StartedTransaction bit = 0,
        @SavepointCreated bit = 0;

    BEGIN TRY
        IF @InitialTranCount = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTransaction = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION StatsForUploadPublishSave;
            SET @SavepointCreated = 1;
        END;

        SET @FailureStage = N''import-lock'';
        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 52820, ''SP_Stats_for_Upload: KS4 import lock could not be acquired.'', 1;

        SET @FailureStage = N''publication-lock'';
        EXEC @LockResult = sys.sp_getapplock
            @Resource = N''K98:StatsForUpload:Publish'',
            @LockMode = N''Exclusive'',
            @LockOwner = N''Transaction'',
            @LockTimeout = 60000,
            @DbPrincipal = N''public'';

        IF @LockResult < 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: publication lock failed; lock result='', @LockResult, ''.''
            );
            THROW 52803, @Diagnostic, 1;
        END;

        SET @FailureStage = N''eligibility-snapshot'';
        SELECT @MaxScan = MAX(SCANORDER)
        FROM dbo.KingdomScanData4 WITH (UPDLOCK, HOLDLOCK);

        IF @MaxScan IS NULL
            THROW 52800, ''SP_Stats_for_Upload: no scan data is available.'', 1;

        SELECT TOP (1) @LatestKVK = KVKVersion
        FROM dbo.ProcConfig WITH (UPDLOCK, HOLDLOCK)
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CONVERT(int, ConfigValue) IS NOT NULL
          AND ConfigValue = CONVERT(float, TRY_CONVERT(int, ConfigValue))
          AND TRY_CONVERT(int, ConfigValue) <= @MaxScan
        ORDER BY KVKVersion DESC;

        IF @LatestKVK IS NULL OR @LatestKVK <= 0 OR @LatestKVK > 2147483647
            THROW 52801, ''SP_Stats_for_Upload: no valid eligible KVK was found.'', 1;

        SELECT @KvkEndScanValue = ConfigValue
        FROM dbo.ProcConfig WITH (UPDLOCK, HOLDLOCK)
        WHERE KVKVersion = CONVERT(int, @LatestKVK)
          AND ConfigKey = ''KVK_END_SCAN'';

        SET @KvkEndScan = TRY_CONVERT(int, @KvkEndScanValue);

        IF @KvkEndScan IS NULL
           OR @KvkEndScan <= 0
           OR @KvkEndScanValue <> CONVERT(float, @KvkEndScan)
            THROW 52802, ''SP_Stats_for_Upload: KVK_END_SCAN is missing or is not a positive integral scan.'', 1;

        SET @ExpectedFinalScan = CASE
            WHEN @MaxScan > @KvkEndScan THEN @KvkEndScan
            ELSE @MaxScan
        END;

        SET @FailureStage = N''header-preflight'';
        SELECT
            @ProvenFinalScan = FinalScanOrder,
            @HeaderRowCount = OutputRowCount,
            @HeaderRevision = Revision,
            @HeaderState = State,
            @FinalizationBasis = FinalizationBasis,
            @FinalDataAtUtc = FinalDataAtUtc
        FROM dbo.KVKFinalReportHeader
        WHERE KVK_NO = CONVERT(int, @LatestKVK);

        IF @ProvenFinalScan IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: missing output header for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan, ''.''
            );
            THROW 52804, @Diagnostic, 1;
        END;

        IF @HeaderState <> N''OUTPUT_COMPLETE''
           OR @HeaderRevision IS NULL OR @HeaderRevision <= 0
           OR @HeaderRowCount IS NULL OR @HeaderRowCount <= 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: invalid output header for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', proven scan='', COALESCE(CONVERT(varchar(20), @ProvenFinalScan), ''NULL''),
                '', revision='', COALESCE(CONVERT(varchar(20), @HeaderRevision), ''NULL''), ''.''
            );
            THROW 52805, @Diagnostic, 1;
        END;

        IF @ProvenFinalScan <> @ExpectedFinalScan
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: stale output for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', proven scan='', @ProvenFinalScan,
                '', revision='', @HeaderRevision, ''.''
            );
            THROW 52806, @Diagnostic, 1;
        END;

        SET @TableName = N''EXCEL_FOR_KVK_'' + CONVERT(nvarchar(20), @LatestKVK);
        SET @TableObjectName = N''dbo.'' + @TableName;
        SET @TableNameFull = QUOTENAME(N''dbo'') + N''.'' + QUOTENAME(@TableName);

        IF OBJECT_ID(@TableObjectName, N''U'') IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source object '', @TableObjectName,
                '' is missing for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan, ''.''
            );
            THROW 52807, @Diagnostic, 1;
        END;

        SET @FailureStage = N''scan-date'';
        SELECT
            @ScanDateRowCount = COUNT_BIG(*),
            @ProvenScanDate = MIN(CONVERT(datetime2(0), ScanDate)),
            @ProvenScanDateMax = MAX(CONVERT(datetime2(0), ScanDate))
        FROM dbo.KingdomScanData4
        WHERE SCANORDER = @ProvenFinalScan;

        IF @ScanDateRowCount <= 0 OR @ProvenScanDate IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source scan date is missing for KVK='', @LatestKVK,
                '', proven scan='', @ProvenFinalScan, ''.''
            );
            THROW 52808, @Diagnostic, 1;
        END;

        IF @ProvenScanDate <> @ProvenScanDateMax
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source scan date is inconsistent for KVK='', @LatestKVK,
                '', proven scan='', @ProvenFinalScan, ''.''
            );
            THROW 52809, @Diagnostic, 1;
        END;

        SET @FailureStage = N''source-shape'';
        SET @sql = N''
            SELECT
                @pSourceRowCount = COUNT_BIG(*),
                @pInvalidGovernorRows = COALESCE(SUM(CONVERT(bigint, CASE
                    WHEN TRY_CONVERT(bigint, [Gov_ID]) IS NULL
                      OR TRY_CONVERT(bigint, [Gov_ID]) <= 0 THEN 1 ELSE 0 END)), 0),
                @pWrongKvkRows = COALESCE(SUM(CONVERT(bigint, CASE
                    WHEN TRY_CONVERT(int, [KVK_NO]) <> @pLatestKVK
                      OR [KVK_NO] IS NULL THEN 1 ELSE 0 END)), 0)
            FROM '' + @TableNameFull + N'' WITH (HOLDLOCK);

            SELECT @pDuplicateGovernorGroups = COUNT_BIG(*)
            FROM
            (
                SELECT TRY_CONVERT(bigint, [Gov_ID]) AS GovernorID
                FROM '' + @TableNameFull + N'' WITH (HOLDLOCK)
                GROUP BY TRY_CONVERT(bigint, [Gov_ID])
                HAVING COUNT_BIG(*) > 1
            ) AS duplicates;'';

        EXEC sys.sp_executesql
            @sql,
            N''@pLatestKVK int, @pSourceRowCount bigint OUTPUT, @pInvalidGovernorRows bigint OUTPUT, @pWrongKvkRows bigint OUTPUT, @pDuplicateGovernorGroups bigint OUTPUT'',
            @pLatestKVK = @LatestKVK,
            @pSourceRowCount = @SourceRowCount OUTPUT,
            @pInvalidGovernorRows = @InvalidGovernorRows OUTPUT,
            @pWrongKvkRows = @WrongKvkRows OUTPUT,
            @pDuplicateGovernorGroups = @DuplicateGovernorGroups OUTPUT;

        IF @SourceRowCount <= 0
            THROW 52810, ''SP_Stats_for_Upload: proven source output contains no rows.'', 1;

        IF @SourceRowCount <> @HeaderRowCount
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source/header row-count mismatch for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', revision='', @HeaderRevision,
                '', header rows='', @HeaderRowCount,
                '', source rows='', @SourceRowCount, ''.''
            );
            THROW 52811, @Diagnostic, 1;
        END;

        IF @InvalidGovernorRows > 0 OR @DuplicateGovernorGroups > 0 OR @WrongKvkRows > 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: invalid source identity for KVK='', @LatestKVK,
                '', invalid governors='', @InvalidGovernorRows,
                '', duplicate governor groups='', @DuplicateGovernorGroups,
                '', wrong KVK rows='', @WrongKvkRows, ''.''
            );
            THROW 52812, @Diagnostic, 1;
        END;

        SET @FailureStage = N''candidate-build'';
        SELECT TOP (0) *
        INTO #StatsForUploadCandidate
        FROM dbo.STATS_FOR_UPLOAD;

        SET @sql = N''
            INSERT INTO #StatsForUploadCandidate
            (
                [Rank],[KVK_RANK],[Gov_ID],[Governor_Name],
                [Starting Power],[Power_Delta],
                [Civilization],[KvKPlayed],[MostKvKKill],[MostKvKDead],[MostKvKHeal],
                [Acclaim],[HighestAcclaim],[AOOJoined],[AOOWon],[AOOAvgKill],[AOOAvgDead],[AOOAvgHeal],[Conduct],
                [Starting_T4&T5_KILLS],[T4_KILLS],[T5_KILLS],[T4&T5_Kills],[KILLS_OUTSIDE_KVK],[Kill Target],[% of Kill Target],
                [Starting_Deads],[Deads_Delta],[DEADS_OUTSIDE_KVK],[T4_Deads],[T5_Deads],[Dead_Target],[% of Dead Target],
                [Zeroed],[DKP_SCORE],[DKP Target],[% of DKP Target],
                [HelpsDelta],[RSS_Assist_Delta],[RSS_Gathered_Delta],
                [Pass 4 Kills],[Pass 6 Kills],[Pass 7 Kills],[Pass 8 Kills],
                [Pass 4 Deads],[Pass 6 Deads],[Pass 7 Deads],[Pass 8 Deads],
                [Starting_HealedTroops],[HealedTroopsDelta],
                [Starting_KillPoints],[KillPointsDelta],
                [RangedPoints],[RangedPointsDelta],[AutarchTimes],
                [Max_PreKvk_Points],[Max_HonorPoints],[PreKvk_Rank],[Honor_Rank],
                [KVK_NO],[LAST_REFRESH],[STATUS]
            )
            SELECT
                [Rank], [KVK_RANK], CAST([Gov_ID] AS bigint), RTRIM([Governor_Name]),
                [Starting Power], ISNULL([Power_Delta], 0),
                [Civilization], ISNULL([KvKPlayed], 0), ISNULL([MostKvKKill], 0),
                ISNULL([MostKvKDead], 0), ISNULL([MostKvKHeal], 0),
                ISNULL([Acclaim], 0), ISNULL([HighestAcclaim], 0), ISNULL([AOOJoined], 0),
                ISNULL([AOOWon], 0), ISNULL([AOOAvgKill], 0), ISNULL([AOOAvgDead], 0),
                ISNULL([AOOAvgHeal], 0), [Conduct],
                ISNULL([Starting_T4&T5_KILLS], 0), ISNULL([T4_KILLS], 0),
                ISNULL([T5_KILLS], 0), ISNULL([T4&T5_Kills], 0), ISNULL([KILLS_OUTSIDE_KVK], 0),
                ISNULL([Kill Target], 0), ISNULL([% of Kill Target], 0),
                ISNULL([Starting_Deads], 0), ISNULL([Deads_Delta], 0),
                ISNULL([DEADS_OUTSIDE_KVK], 0), ISNULL([T4_Deads], 0), ISNULL([T5_Deads], 0),
                ISNULL([Dead_Target], 0), ISNULL([% of Dead Target], 0),
                ISNULL([Zeroed], 0), ISNULL([DKP_SCORE], 0), ISNULL([DKP Target], 0),
                ISNULL([% of DKP Target], 0), ISNULL([HelpsDelta], 0),
                ISNULL([RSS_Assist_Delta], 0), ISNULL([RSS_Gathered_Delta], 0),
                ISNULL([Pass 4 Kills], 0), ISNULL([Pass 6 Kills], 0),
                ISNULL([Pass 7 Kills], 0), ISNULL([Pass 8 Kills], 0),
                ISNULL([Pass 4 Deads], 0), ISNULL([Pass 6 Deads], 0),
                ISNULL([Pass 7 Deads], 0), ISNULL([Pass 8 Deads], 0),
                ISNULL([Starting_HealedTroops], 0), ISNULL([HealedTroopsDelta], 0),
                ISNULL([Starting_KillPoints], 0), ISNULL([KillPointsDelta], 0),
                ISNULL([RangedPoints], 0), ISNULL([RangedPointsDelta], 0), ISNULL([AutarchTimes], 0),
                ISNULL([Max_PreKvk_Points], 0), ISNULL([Max_HonorPoints], 0),
                ISNULL([PreKvk_Rank], 0), ISNULL([Honor_Rank], 0),
                [KVK_NO], @pProvenScanDate,
                CASE
                    WHEN CAST([Gov_ID] AS bigint) IN
                    (
                        SELECT GovernorID
                        FROM dbo.EXEMPT_FROM_STATS
                        WHERE KVK_NO IN (0, @pLatestKVK)
                    ) THEN N''''EXEMPT''''
                    ELSE N''''INCLUDED''''
                END
            FROM '' + @TableNameFull + N'' WITH (HOLDLOCK);'';

        EXEC sys.sp_executesql
            @sql,
            N''@pLatestKVK int, @pProvenScanDate datetime2(0)'',
            @pLatestKVK = @LatestKVK,
            @pProvenScanDate = @ProvenScanDate;

        SELECT
            @CandidateRowCount = COUNT_BIG(*),
            @InvalidGovernorRows = COALESCE(SUM(CONVERT(bigint, CASE
                WHEN Gov_ID IS NULL OR Gov_ID <= 0 THEN 1 ELSE 0 END)), 0),
            @WrongKvkRows = COALESCE(SUM(CONVERT(bigint, CASE
                WHEN KVK_NO <> CONVERT(int, @LatestKVK) OR KVK_NO IS NULL THEN 1 ELSE 0 END)), 0)
        FROM #StatsForUploadCandidate;

        SELECT @DuplicateGovernorGroups = COUNT_BIG(*)
        FROM
        (
            SELECT Gov_ID
            FROM #StatsForUploadCandidate
            GROUP BY Gov_ID
            HAVING COUNT_BIG(*) > 1
        ) AS duplicates;

        IF @CandidateRowCount <= 0 OR @CandidateRowCount <> @SourceRowCount
            THROW 52813, ''SP_Stats_for_Upload: candidate row count does not match the proven source.'', 1;

        IF @InvalidGovernorRows > 0 OR @DuplicateGovernorGroups > 0 OR @WrongKvkRows > 0
            THROW 52814, ''SP_Stats_for_Upload: candidate identity validation failed.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM #StatsForUploadCandidate
            WHERE LAST_REFRESH IS NULL OR LAST_REFRESH <> @ProvenScanDate
        )
            THROW 52815, ''SP_Stats_for_Upload: candidate LAST_REFRESH is not coherent with the proven scan.'', 1;

        SET @FailureStage = N''header-recheck'';
        SELECT
            @CurrentHeaderScan = FinalScanOrder,
            @CurrentHeaderRowCount = OutputRowCount,
            @CurrentHeaderRevision = Revision,
            @CurrentHeaderState = State
        FROM dbo.KVKFinalReportHeader WITH (UPDLOCK, HOLDLOCK)
        WHERE KVK_NO = CONVERT(int, @LatestKVK);

        IF @CurrentHeaderScan IS NULL
           OR @CurrentHeaderRowCount IS NULL
           OR @CurrentHeaderRevision IS NULL
           OR @CurrentHeaderState IS NULL
           OR @CurrentHeaderScan <> @ProvenFinalScan
           OR @CurrentHeaderRowCount <> @HeaderRowCount
           OR @CurrentHeaderRevision <> @HeaderRevision
           OR @CurrentHeaderState <> @HeaderState
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: output provenance changed during publication for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', initial revision='', @HeaderRevision,
                '', current revision='', COALESCE(CONVERT(varchar(20), @CurrentHeaderRevision), ''NULL''), ''.''
            );
            THROW 52816, @Diagnostic, 1;
        END;

        SET @FailureStage = N''target-replacement'';
        DELETE FROM dbo.STATS_FOR_UPLOAD;

        INSERT INTO dbo.STATS_FOR_UPLOAD
        SELECT *
        FROM #StatsForUploadCandidate;

        SET @PublishedRowCount = @@ROWCOUNT;

        IF @PublishedRowCount <> @CandidateRowCount
            THROW 52817, ''SP_Stats_for_Upload: published row count does not match the validated candidate.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.STATS_FOR_UPLOAD
            WHERE Gov_ID IS NULL OR Gov_ID <= 0
               OR KVK_NO IS NULL OR KVK_NO <> CONVERT(int, @LatestKVK)
               OR LAST_REFRESH IS NULL OR LAST_REFRESH <> @ProvenScanDate
        )
        OR EXISTS
        (
            SELECT Gov_ID
            FROM dbo.STATS_FOR_UPLOAD
            GROUP BY Gov_ID
            HAVING COUNT_BIG(*) > 1
        )
            THROW 52818, ''SP_Stats_for_Upload: post-publication row-shape validation failed.'', 1;

        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''STATS_FOR_UPLOAD'';
        SET @FailureStage = N''maintenance-registration'';
        EXEC dbo.usp_MaintenanceDue @Kind=''player_report'';

        IF @StartedTransaction = 1
            COMMIT TRANSACTION;

        PRINT CONCAT(
            ''SP_Stats_for_Upload: completed KVK='', @LatestKVK,
            '', expected scan='', @ExpectedFinalScan,
            '', proven scan='', @ProvenFinalScan,
            '', header revision='', @HeaderRevision,
            '', basis='', @FinalizationBasis,
            '', generated at='', CONVERT(varchar(19), @FinalDataAtUtc, 120),
            '', source rows='', @SourceRowCount,
            '', published rows='', @PublishedRowCount,
            '', source scan date='', CONVERT(varchar(19), @ProvenScanDate, 120), ''.''
        );
    END TRY
    BEGIN CATCH
        DECLARE @ErrorNumber int = ERROR_NUMBER();
        DECLARE @ErrorMessage nvarchar(2048) = ERROR_MESSAGE();

        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        ELSE IF @SavepointCreated = 1 AND XACT_STATE() = 1
            ROLLBACK TRANSACTION StatsForUploadPublishSave;

        IF @ErrorNumber BETWEEN 52800 AND 52820
            THROW;

        SET @Diagnostic = CONCAT(
            ''SP_Stats_for_Upload: failed at stage='', @FailureStage,
            '', KVK='', COALESCE(CONVERT(varchar(20), @LatestKVK), ''NULL''),
            '', expected scan='', COALESCE(CONVERT(varchar(20), @ExpectedFinalScan), ''NULL''),
            '', proven scan='', COALESCE(CONVERT(varchar(20), @ProvenFinalScan), ''NULL''),
            '', header revision='', COALESCE(CONVERT(varchar(20), @HeaderRevision), ''NULL''),
            '', source rows='', @SourceRowCount,
            '', published rows='', @PublishedRowCount,
            '', SQL error='', @ErrorNumber,
            '', detail='', LEFT(@ErrorMessage, 600), ''.''
        );
        THROW 52819, @Diagnostic, 1;
    END CATCH;
END';
-- dbo.TEST
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[TEST]
WITH EXECUTE AS CALLER
AS
BEGIN
    THROW 52940, ''dbo.TEST is retired by P02 D4; no work was performed. Use the supported import/report workflow.'', 1;
END';
-- dbo.UPDATE_ALL
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[UPDATE_ALL]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL,
    @CompletedFileName [nvarchar](260)
WITH EXECUTE AS CALLER
AS
BEGIN
    THROW 52940, ''dbo.UPDATE_ALL is retired by P02 D4; no work was performed. Use the supported import/report workflow.'', 1;
END';
-- dbo.UPDATE_ALL2
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[UPDATE_ALL2]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL,
    @CompletedFileName [nvarchar](260),
    @ExportPreparationID uniqueidentifier = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    -- REQUIRED SET Options for DML against indexed views / persisted computed columns
    SET ANSI_NULLS ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET QUOTED_IDENTIFIER ON;
    SET NUMERIC_ROUNDABORT OFF;

    IF @@TRANCOUNT <> 0
        THROW 51818, ''UPDATE_ALL2 refuses caller-owned transactions; execute the public entry point with no active transaction.'', 1;

    IF @ExportPreparationID IS NOT NULL
    BEGIN
        DECLARE @ExecutionResource nvarchar(255)=N''S11:stats-import:'' + LOWER(CONVERT(nvarchar(36),@ExportPreparationID));
        IF COALESCE(APPLOCK_MODE(N''public'',@ExecutionResource,N''Session''),N''NoLock'') <> N''Exclusive''
           OR NOT EXISTS (SELECT 1 FROM dbo.StatsImportExecution WHERE PreparationID=@ExportPreparationID
               AND CompletedFileName=@CompletedFileName AND State=''running'' AND Resolution IS NULL)
            THROW 51960, ''Exact S11 wrapper session and running receipt required.'', 1;
    END;

    SET XACT_ABORT ON;

    DECLARE @rc INT, @rowsKS5 INT, @rowsKS4 INT = 0;
    DECLARE @ImportLockResult INT;
    DECLARE @AllocatedScanOrder INT;
    DECLARE @StagedRows INT;
    DECLARE @ImportFileDigest BINARY(32);
    DECLARE @ImportClaimedPath NVARCHAR(4000);
    DECLARE @ImportArchivePath NVARCHAR(4000);
    DECLARE @ImportError NVARCHAR(2000);
    DECLARE @ArchiveReturnCode INT;
    DECLARE @CurrentAuditPhase NVARCHAR(64) = N''update_all2_start'';
    DECLARE @UpdateAll2PhaseAudit TABLE (
        SequenceNo INT IDENTITY(1,1) NOT NULL,
        PhaseName NVARCHAR(64) NOT NULL,
        PhaseStatus NVARCHAR(32) NOT NULL,
        StartedAtUtc DATETIME2(3) NOT NULL,
        CompletedAtUtc DATETIME2(3) NULL,
        DurationMs INT NULL,
        RowsIn INT NULL,
        RowsOut INT NULL,
        DetailsJson NVARCHAR(MAX) NULL,
        ErrorType NVARCHAR(128) NULL,
        ErrorText NVARCHAR(2000) NULL
    );

    BEGIN TRY
        EXEC dbo.CLAIM_KS4_IMPORT_FILE
            @CompletedFileName = @CompletedFileName,
            @FileDigest = @ImportFileDigest OUTPUT,
            @ClaimedPath = @ImportClaimedPath OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT;

        ----------------------------------------------------------------
        -- Phase A: Import → KS5 → (maybe) KS4  [commit early]
        ----------------------------------------------------------------
        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51810, ''UPDATE_ALL2 could not acquire the KingdomScanData4 import mutex within 60000 ms; Phase A was not started.'', 1;

        -- Get deterministic defaults from KS. Choose "latest" row by [Last Update] if present.
        DECLARE @actual_param1 FLOAT = NULL,
                @actual_param2 NVARCHAR(100) = NULL;

        SELECT TOP (1)
            @actual_param1 = COALESCE(@param1, KINGDOM_RANK, 0),
            @actual_param2 = COALESCE(@param2, KINGDOM_SEED, N'''')
        FROM dbo.KS
        WHERE KINGDOM_RANK IS NOT NULL OR KINGDOM_SEED IS NOT NULL
        ORDER BY [Last Update] DESC; 

        IF @actual_param1 IS NULL SET @actual_param1 = COALESCE(@param1, 0);
        IF @actual_param2 IS NULL SET @actual_param2 = COALESCE(@param2, N'''');

        DECLARE @StartTime DATETIME = GETDATE();

        -- 1) Refresh latest data
        EXEC @rc = dbo.IMPORT_STAGING_PROC_CORE
            @CompletedFileName = @CompletedFileName,
            @ImportFileDigest = @ImportFileDigest OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT,
            @ImportError = @ImportError OUTPUT;
        IF @rc <> 0
        BEGIN
            SET @ImportError = COALESCE(
                @ImportError,
                N''UPDATE_ALL2 stopped because IMPORT_STAGING_PROC failed without returning error detail.''
            );
            THROW 51819, @ImportError, 1;
        END

        SELECT
            @AllocatedScanOrder = MIN(SCANORDER),
            @StagedRows = COUNT(*)
        FROM dbo.IMPORT_STAGING;

        IF @AllocatedScanOrder IS NULL
           OR @AllocatedScanOrder <> (SELECT MAX(SCANORDER) FROM dbo.IMPORT_STAGING)
           OR @StagedRows <> (SELECT COUNT(DISTINCT [Governor ID]) FROM dbo.IMPORT_STAGING)
            THROW 51811, ''UPDATE_ALL2 rejected empty, mixed-scan, or duplicate-governor canonical staging.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @AllocatedScanOrder
        )
            THROW 51812, ''UPDATE_ALL2 refused to reuse an existing KingdomScanData5 SCANORDER.'', 1;

        -- 2) Insert into KingdomScanData5
        INSERT INTO dbo.KingdomScanData5 (
              PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
            , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
            , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
            , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
        )
        SELECT
              ROW_NUMBER() OVER (ORDER BY [Power] DESC, [Governor ID] ASC) AS PowerRank
            , RTRIM([Name])
            , [Governor ID]
            , NULLIF(
				  LTRIM(RTRIM(
					REPLACE(REPLACE(CONVERT(nvarchar(255), [Alliance]), CHAR(13), ''''), CHAR(10), '''')
				  )),
				  N''''
			  ) AS Alliance
            , [Power]
            , [Total Kill Points]
            , [Dead Troops]
            , [T1-Kills], [T2-Kills], [T3-Kills], [T4-Kills], [T5-Kills]
            , [Kills (T4+)]
            , [KILLS]
            , [RSS Gathered], [RSS Assistance], [Alliance Helps]
            , [ScanDate], [SCANORDER]
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , [HealedTroops], [RangedPoints], [Civilization], [AutarchTimes], [KvKPlayed], [MostKvKKill], [MostKvKDead], [MostKvKHeal]
            , [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon], [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct]
        FROM dbo.IMPORT_STAGING WITH (TABLOCK);

        SET @rowsKS5 = @@ROWCOUNT;

        IF @rowsKS5 = 0
        BEGIN
            RAISERROR(''No rows inserted into KingdomScanData5 (IMPORT_STAGING was empty).'', 16, 1);
        END

        IF @rowsKS5 <> @StagedRows
           OR EXISTS
              (
                  SELECT 1
                  FROM dbo.KingdomScanData5
                  WHERE SCANORDER = @AllocatedScanOrder
                  GROUP BY SCANORDER, GovernorID
                  HAVING COUNT_BIG(*) > 1
              )
            THROW 51813, ''UPDATE_ALL2 KingdomScanData5 row-count or duplicate-key validation failed.'', 1;

        -- Cache MAX(SCANORDER) values to avoid repeated scans
        DECLARE @MaxScanOrder5 INT = (SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData5 ORDER BY SCANORDER DESC);
        DECLARE @MaxScanOrder4 INT = (SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData4 ORDER BY SCANORDER DESC);

        IF @MaxScanOrder5 <> @AllocatedScanOrder
            THROW 51814, ''UPDATE_ALL2 allocated scan does not match the latest KingdomScanData5 scan.'', 1;

        -- 3) Promote to KS4 if newer
        IF @MaxScanOrder5 > @MaxScanOrder4
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.KingdomScanData4
                WHERE SCANORDER = @AllocatedScanOrder
            )
                THROW 51815, ''UPDATE_ALL2 refused to reuse an existing KingdomScanData4 SCANORDER.'', 1;

            INSERT INTO dbo.KingdomScanData4 (
                  PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , RSS_Gathered, RSSAssistance, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
            )
            SELECT
                  PowerRank, GovernorName, GovernorID,
                  NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), ''''),
                  [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @MaxScanOrder5

            SET @rowsKS4 = @@ROWCOUNT;

            IF @rowsKS4 <> @rowsKS5
               OR EXISTS
                  (
                      SELECT 1
                      FROM dbo.KingdomScanData4
                      WHERE SCANORDER = @AllocatedScanOrder
                      GROUP BY SCANORDER, GovernorID
                      HAVING COUNT_BIG(*) > 1
                  )
                THROW 51816, ''UPDATE_ALL2 KingdomScanData4 row-count or duplicate-key validation failed.'', 1;

			EXEC [dbo].[Refresh_PlayerScanMeta] @MinScanOrder = @MaxScanOrder5

        END

        EXEC dbo.usp_UpsertGovernorNameHistoryForScan @ScanOrder = @MaxScanOrder5;

        -- 4) Truncate staging (safe post-insert)
        TRUNCATE TABLE dbo.IMPORT_STAGING;

        IF @ExportPreparationID IS NOT NULL
        BEGIN
            UPDATE dbo.StatsImportExecution SET State=''import_committed'', ScanOrder=@AllocatedScanOrder,
                UpdatedUTC=SYSUTCDATETIME(), Version=Version+1
            WHERE PreparationID=@ExportPreparationID AND CompletedFileName=@CompletedFileName AND State=''running'';
            IF @@ROWCOUNT <> 1 THROW 51960, ''Missing exact Phase A execution receipt.'', 1;
            -- Created only with the import commit. Historical partial work is never
            -- backfilled into this contract from a reservation or phase audit row.
            INSERT dbo.StatsImportReportContinuation
                (PreparationID,InputDigest,ScanOrder,LatestScanOrder,KingdomRank,KingdomSeed,
                 ConfigurationJson,RowsKS5,RowsKS4,ImportStartedUTC)
            SELECT @ExportPreparationID,@ImportFileDigest,@AllocatedScanOrder,
                (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4),@actual_param1,@actual_param2,
                (SELECT KVKVersion,ConfigKey,ConfigValue,LastUpdated
                 FROM dbo.ProcConfig WITH (HOLDLOCK)
                 ORDER BY KVKVersion,ConfigKey FOR JSON PATH,INCLUDE_NULL_VALUES),
                @rowsKS5,@rowsKS4,@StartTime;

        END;
        DECLARE @ImportKS4 bit=CASE WHEN @rowsKS4>0 THEN 1 ELSE 0 END;
        EXEC dbo.usp_MaintenanceDue @Kind=''import'',@RequestID=@ExportPreparationID,@ImportKS4=@ImportKS4;
        COMMIT;  -- ✅ Import is now durable even if later steps fail

        EXEC @ArchiveReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
            @CompletedFileName = @CompletedFileName;

        IF @ArchiveReturnCode <> 0
            THROW 51817, ''UPDATE_ALL2 committed Phase A but the immutable-file archive handoff did not complete.'', 1;

        -- Return / Log Phase A summary values
        SELECT
            @MaxScanOrder5    AS Ks5_MaxScanOrder,
            @rowsKS5          AS Ks5_RowsInserted,
            @rowsKS4          AS Ks4_RowsInserted,
            (SELECT COUNT(*) FROM dbo.IMPORT_STAGING) AS ImportStaging_RowsAfterPhaseA,
            (SELECT COUNT(*) FROM dbo.KingdomScanData4 WHERE SCANORDER = @MaxScanOrder4) AS Ks4_RowsInLatest,
            @ImportArchivePath AS ArchivedFilePath;

        -- Reporting uses transactional checkpoints. Recovery calls this reporting-only
        -- procedure, never UPDATE_ALL2 or its committed import stage.
        EXEC dbo.usp_S11CompleteStatsReportsCore
            @CompletedFileName=@CompletedFileName, @ExportPreparationID=@ExportPreparationID,
            @actual_param1=@actual_param1, @actual_param2=@actual_param2,
            @rowsKS5=@rowsKS5, @rowsKS4=@rowsKS4, @StartTime=@StartTime;

    END TRY
	BEGIN CATCH
		DECLARE @ErrNum  INT = ERROR_NUMBER();
		DECLARE @ErrMsg  NVARCHAR(MAX) = ERROR_MESSAGE();
		DECLARE @ErrLine INT = ERROR_LINE();
		DECLARE @ErrProc NVARCHAR(200) = ERROR_PROCEDURE();
        DECLARE @PersistedImportError NVARCHAR(2000) =
            LEFT(
                COALESCE(
                    @ImportError,
                    CONCAT(
                        N''Error '',
                        ERROR_NUMBER(),
                        N'' in '',
                        COALESCE(ERROR_PROCEDURE(), N''UPDATE_ALL2''),
                        N'' line '',
                        ERROR_LINE(),
                        N'': '',
                        COALESCE(ERROR_MESSAGE(), N''(no message)'')
                    )
                ),
                2000
            );

		-- ✅ capture transaction state before doing anything
		DECLARE @XState INT = XACT_STATE();

		-- ✅ if a transaction exists, you MUST rollback first (especially if @XState = -1)
		IF @XState <> 0
			ROLLBACK;

        BEGIN TRY
            UPDATE dbo.KS4_ImportFileClaim
            SET LastError = @PersistedImportError
            WHERE CompletedFileName = @CompletedFileName
              AND ClaimStatus = N''claimed'';
        END TRY
        BEGIN CATCH
            -- Never mask the original UPDATE_ALL2 failure.
        END CATCH;

		-- ✅ now you''re in autocommit, logging is allowed
		BEGIN TRY
			INSERT INTO dbo.ErrorAudit (
				ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo
			)
			VALUES (
				GETDATE(), ISNULL(@ErrProc, ''UPDATE_ALL2''), @ErrNum, @ErrMsg, @ErrLine,
				N''XACT_STATE='' + CAST(@XState AS NVARCHAR(10)) +
				N''; CurrentPhase='' + ISNULL(@CurrentAuditPhase, N''unknown'') +
				N''; Phase info: KS5_Rows='' + ISNULL(CAST(@rowsKS5 AS NVARCHAR(20)), N''NULL'') +
				N'', KS4_Rows='' + ISNULL(CAST(@rowsKS4 AS NVARCHAR(20)), N''NULL'')
			);
		END TRY
		BEGIN CATCH
			-- If even logging fails, don''t mask the original error
		END CATCH;

		THROW;
	END CATCH
END';
-- dbo.UPDATE_RALLY_DATA
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[UPDATE_RALLY_DATA]
WITH EXECUTE AS CALLER
AS
BEGIN
    THROW 52940, ''dbo.UPDATE_RALLY_DATA is retired by P02 D4; no work was performed. Use the supported import/report workflow.'', 1;
END';
-- dbo.sp_ExcelOutput_ByKVK
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[sp_ExcelOutput_ByKVK]
	@KVK [int],
	@Scan [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE 
        @CURRENTKVK3      INT,
        @KVK_END_SCAN     INT,
        @LASTKVKEND       INT,
        @PASS4END         INT,
        @PASS6END         INT,
        @PASS7END         INT,
        @PRE_PASS_4_SCAN  INT,
        @MaxAvailableScan INT,
        @LatestScanToUse  INT;

    -- Load KVK config
    SELECT
        @CURRENTKVK3     = CAST(MAX(CASE WHEN ConfigKey = ''CURRENTKVK3''     THEN ConfigValue END) AS INT),
        @KVK_END_SCAN    = CAST(MAX(CASE WHEN ConfigKey = ''KVK_END_SCAN''    THEN ConfigValue END) AS INT),
        @LASTKVKEND      = CAST(MAX(CASE WHEN ConfigKey = ''LASTKVKEND''      THEN ConfigValue END) AS INT),
        @PASS4END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS4END''        THEN ConfigValue END) AS INT),
        @PASS6END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS6END''        THEN ConfigValue END) AS INT),
        @PASS7END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS7END''        THEN ConfigValue END) AS INT),
        @PRE_PASS_4_SCAN = CAST(MAX(CASE WHEN ConfigKey = ''PRE_PASS_4_SCAN'' THEN ConfigValue END) AS INT)
    FROM dbo.ProcConfig
    WHERE KVKVersion = @KVK;

    IF @KVK_END_SCAN IS NULL OR @LASTKVKEND IS NULL OR @PRE_PASS_4_SCAN IS NULL
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Missing KVK window config for KVK=%d (one of KVK_END_SCAN/LASTKVKEND/PRE_PASS_4_SCAN is NULL).'', 16, 1, @KVK);
        RETURN;
    END

    -- Cap @Scan to available data (safety if caller passed a future scan)
    SELECT @MaxAvailableScan = MAX(ScanOrder) FROM dbo.KingdomScanData4;
    IF @MaxAvailableScan IS NULL
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: No scan data available.'', 16, 1);
        RETURN;
    END
    IF @Scan > @MaxAvailableScan SET @Scan = @MaxAvailableScan;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @Scan
    )
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Requested final ScanOrder=%d has no source rows.'', 16, 1, @Scan);
        RETURN;
    END

    -- Determine which scan to use for latest data
    -- For completed KVKs use KVK_END_SCAN, for current KVK use MaxAvailableScan
    SET @LatestScanToUse = CASE 
        WHEN @MaxAvailableScan > @KVK_END_SCAN THEN @KVK_END_SCAN
        ELSE @MaxAvailableScan
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @LatestScanToUse
    )
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Resolved final ScanOrder=%d has no source rows.'', 16, 1, @LatestScanToUse);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @MaintenanceSchemaResult int;
        EXEC @MaintenanceSchemaResult=sys.sp_getapplock @Resource=N''K98:maintenance-schema:v1'',
            @LockMode=''Shared'',@LockOwner=''Transaction'',@LockTimeout=0;
        IF @MaintenanceSchemaResult<0
            THROW 51966,''KVK publication deferred while maintenance owns schema.'',1;

        -- Fresh staging
        TRUNCATE TABLE dbo.STAGING_STATS;

    -----------------------------------------------
    -- Build/refresh ranked PreKvk & Honor tables (so we can join ranks quickly)
    -----------------------------------------------
    EXEC dbo.sp_Build_Prekvk_And_Honor_Rankings;

    -----------------------------------------------
     -- 1. Snapshot (materialize once for reuse) - REDUCED COLUMNS
    -----------------------------------------------
    CREATE TABLE #Snapshot (
        GovernorID        bigint           NOT NULL PRIMARY KEY CLUSTERED,
        GovernorName      nvarchar(255)  NULL,
        PowerRank         int           NULL,
        [Power]           bigint        NULL,
        [Civilization]    nvarchar(100)  NULL,
        [KvKPlayed]       int           NULL,
        [Deads]           bigint        NULL,
        [T4&T5_KILLS]     bigint        NULL,
        [HealedTroops]    bigint        NULL,
        [KillPoints]      bigint        NULL,
        [AutarchTimes]    bigint        NULL,
        MaxPreKvkPoints   bigint        NULL,
        PreKvkRank        int           NULL,
        MaxHonorPoints    bigint        NULL,
        HonorRank         int           NULL,
		RangedPoints     bigint  NULL
    );

    INSERT INTO #Snapshot (
          GovernorID
        , GovernorName
        , PowerRank
        , [Power]
        , [Civilization]
        , [KvKPlayed]
        , [Deads]
        , [T4&T5_KILLS]
        , [HealedTroops]
        , [KillPoints]
        , [AutarchTimes]
        , MaxPreKvkPoints
        , PreKvkRank
        , MaxHonorPoints
        , HonorRank
		, RangedPoints
    )
    SELECT
        ksd.GovernorID,
        ksd.GovernorName,
        ksd.PowerRank,
        ksd.[Power],
        ksd.[Civilization],
        ksd.[KvKPlayed],
		ksd.[Deads],
		ksd.[T4&T5_KILLS], 
		ksd.[HealedTroops], 
		ksd.[KillPoints],
		ksd.[AutarchTimes],
        pk.MaxPreKvkPoints    AS MaxPreKvkPoints,
        pk.PreKvk_Rank        AS PreKvkRank,
        hn.MaxHonorPoints     AS MaxHonorPoints,
        hn.Honor_Rank         AS HonorRank,
		ksd.[RangedPoints]
    FROM dbo.KingdomScanData4 ksd
    LEFT JOIN dbo.PreKvk_Scores_Ranked pk
      ON pk.GovernorID = ksd.GovernorID AND pk.KVK_NO = @CURRENTKVK3
    LEFT JOIN dbo.KVK_Honor_Ranked hn
      ON hn.GovernorID = ksd.GovernorID AND hn.KVK_NO = @CURRENTKVK3
    WHERE ksd.ScanOrder = @Scan;

    -----------------------------------------------
    -- 1b. LATEST data (for completed/current KVK stats)
    -----------------------------------------------
    CREATE TABLE #LATEST (
        GovernorID       bigint  NOT NULL PRIMARY KEY CLUSTERED,
        MostKvKKill      bigint  NULL,
        MostKvKDead      bigint  NULL,
        MostKvKHeal      bigint  NULL,
        Acclaim          bigint  NULL,
        HighestAcclaim   bigint  NULL,
        AOOJoined        bigint  NULL,
        AOOWon           int     NULL,
        AOOAvgKill       bigint  NULL,
        AOOAvgDead       bigint  NULL,
        AOOAvgHeal       bigint  NULL,
        Conduct          decimal(5,2) NULL
    );

    INSERT INTO #LATEST (
          GovernorID
        , MostKvKKill
        , MostKvKDead
        , MostKvKHeal
        , Acclaim
        , HighestAcclaim
        , AOOJoined
        , AOOWon
        , AOOAvgKill
        , AOOAvgDead
        , AOOAvgHeal
        , Conduct
    )
    SELECT
        ksd.GovernorID,
        ksd.MostKvKKill,
        ksd.MostKvKDead,
        ksd.MostKvKHeal,
        ksd.Acclaim,
        ksd.HighestAcclaim,
        ksd.AOOJoined,
        ksd.AOOWon,
        ksd.AOOAvgKill,
        ksd.AOOAvgDead,
        ksd.AOOAvgHeal,
        ksd.Conduct
    FROM dbo.KingdomScanData4 ksd
    WHERE ksd.ScanOrder = @LatestScanToUse;

	CREATE TABLE #GovernorList (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED
    );

    INSERT INTO #GovernorList (GovernorID)
    SELECT s.GovernorID
    FROM #Snapshot s
    WHERE s.GovernorID IS NOT NULL;

    -----------------------------------------------
    -- 2. Consolidated Deads Delta (filtered to snapshot)
    -----------------------------------------------
    CREATE TABLE #Deads (
        GovernorID        bigint  NOT NULL PRIMARY KEY CLUSTERED,
        DeadsDelta        bigint  NOT NULL,
        DeadsDeltaOutKVK  bigint  NOT NULL,
        P4DeadsDelta      bigint  NOT NULL,
        P6DeadsDelta      bigint  NOT NULL,
        P7DeadsDelta      bigint  NOT NULL,
        P8DeadsDelta      bigint  NOT NULL
    );

    INSERT INTO #Deads (GovernorID, DeadsDelta, DeadsDeltaOutKVK, P4DeadsDelta, P6DeadsDelta, P7DeadsDelta, P8DeadsDelta)
    SELECT 
        d.GovernorID,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @LASTKVKEND      AND d.DeltaOrder <= @PRE_PASS_4_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @PASS4END THEN d.DeadsDelta ELSE 0 END) AS P4DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS4END        AND d.DeltaOrder <= @PASS6END THEN d.DeadsDelta ELSE 0 END) AS P6DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS6END        AND d.DeltaOrder <= @PASS7END THEN d.DeadsDelta ELSE 0 END) AS P7DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS7END        AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS P8DeadsDelta
    FROM dbo.DeadsDelta d
    INNER JOIN #GovernorList gl ON gl.GovernorID = d.GovernorID
    WHERE d.DeltaOrder > @LASTKVKEND AND d.DeltaOrder <= @KVK_END_SCAN
    GROUP BY d.GovernorID;

    -----------------------------------------------
    -- 3. Consolidated Kills Delta (T4&T5)
    -----------------------------------------------
    CREATE TABLE #Kills (
        GovernorID      bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T4T5KillsDelta  bigint  NOT NULL,
        KillsOutsideKVK bigint  NOT NULL,
        P4Kills         bigint  NOT NULL,
        P6Kills         bigint  NOT NULL,
        P7Kills         bigint  NOT NULL,
        P8Kills         bigint  NOT NULL
    );

    INSERT INTO #Kills (GovernorID, T4T5KillsDelta, KillsOutsideKVK, P4Kills, P6Kills, P7Kills, P8Kills)
    SELECT 
        k.GovernorID,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
        SUM(CASE WHEN k.DeltaOrder > @LASTKVKEND      AND k.DeltaOrder <= @PRE_PASS_4_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @PASS4END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS4END        AND k.DeltaOrder <= @PASS6END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS6END        AND k.DeltaOrder <= @PASS7END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS7END        AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
    FROM dbo.T4T5KillDelta k
    INNER JOIN #GovernorList gl ON gl.GovernorID = k.GovernorID
    WHERE k.DeltaOrder > @LASTKVKEND AND k.DeltaOrder <= @KVK_END_SCAN
    GROUP BY k.GovernorID;

    -----------------------------------------------
    -- 4. T4 / T5 splits
    -----------------------------------------------
    CREATE TABLE #KillsT4 (
        GovernorID   bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T4KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT4 (GovernorID, T4KillsDelta)
    SELECT t4.GovernorID, SUM(COALESCE(t4.T4KILLSDelta, 0)) AS T4KillsDelta
    FROM dbo.T4KillDelta t4
    INNER JOIN #GovernorList gl ON gl.GovernorID = t4.GovernorID
    WHERE t4.DeltaOrder > @PRE_PASS_4_SCAN AND t4.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t4.GovernorID;

    CREATE TABLE #KillsT5 (
        GovernorID   bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T5KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT5 (GovernorID, T5KillsDelta)
    SELECT t5.GovernorID, SUM(COALESCE(t5.T5KILLSDelta, 0)) AS T5KillsDelta
    FROM dbo.T5KillDelta t5
    INNER JOIN #GovernorList gl ON gl.GovernorID = t5.GovernorID
    WHERE t5.DeltaOrder > @PRE_PASS_4_SCAN AND t5.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t5.GovernorID;

	----------------------------------------------- 
	-- 5. KillPointsDelta aggregation (use same window as other deltas) 
	----------------------------------------------- 
    CREATE TABLE #KillPoints (
        GovernorID      bigint  NOT NULL PRIMARY KEY CLUSTERED,
        KillPointsDelta bigint  NOT NULL
    );

	INSERT INTO #KillPoints (GovernorID, KillPointsDelta)
	SELECT kp.GovernorID, SUM(COALESCE(kp.KillPointsDelta, 0)) AS KillPointsDelta
	FROM dbo.KillPointsDelta kp
    INNER JOIN #GovernorList gl ON gl.GovernorID = kp.GovernorID
	WHERE kp.DeltaOrder > @PRE_PASS_4_SCAN AND kp.DeltaOrder <= @KVK_END_SCAN 
	GROUP BY kp.GovernorID;

    -----------------------------------------------
    -- 6. Other deltas (use @Scan as lower bound)
    -----------------------------------------------
    CREATE TABLE #Helps (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED,
        HelpsDelta bigint NOT NULL
    );

    INSERT INTO #Helps (GovernorID, HelpsDelta)
    SELECT h.GovernorID, SUM(COALESCE(h.HelpsDelta, 0)) AS HelpsDelta
    FROM dbo.HelpsDelta h
    INNER JOIN #GovernorList gl ON gl.GovernorID = h.GovernorID
    WHERE h.DeltaOrder > @Scan AND h.DeltaOrder <= @KVK_END_SCAN
    GROUP BY h.GovernorID;

    CREATE TABLE #RSSAssist (
        GovernorID     bigint NOT NULL PRIMARY KEY CLUSTERED,
        RSSAssistDelta bigint NOT NULL
    );

    INSERT INTO #RSSAssist (GovernorID, RSSAssistDelta)
    SELECT ra.GovernorID, SUM(COALESCE(ra.RSSASSISTDelta, 0)) AS RSSAssistDelta
    FROM dbo.RSSASSISTDelta ra
    INNER JOIN #GovernorList gl ON gl.GovernorID = ra.GovernorID
    WHERE ra.DeltaOrder > @Scan AND ra.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ra.GovernorID;

    CREATE TABLE #RSSGathered (
        GovernorID       bigint NOT NULL PRIMARY KEY CLUSTERED,
        RSSGatheredDelta bigint NOT NULL
    );

    INSERT INTO #RSSGathered (GovernorID, RSSGatheredDelta)
    SELECT rg.GovernorID, SUM(COALESCE(rg.RSSGatheredDelta, 0)) AS RSSGatheredDelta
    FROM dbo.RSSGatheredDelta rg
    INNER JOIN #GovernorList gl ON gl.GovernorID = rg.GovernorID
    WHERE rg.DeltaOrder > @Scan AND rg.DeltaOrder <= @KVK_END_SCAN
    GROUP BY rg.GovernorID;

    CREATE TABLE #Power (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED,
        PowerDelta bigint NOT NULL
    );

    INSERT INTO #Power (GovernorID, PowerDelta)
    SELECT p.GovernorID, SUM(COALESCE(p.Power_Delta, 0)) AS PowerDelta
    FROM dbo.PowerDelta p
    INNER JOIN #GovernorList gl ON gl.GovernorID = p.GovernorID
    WHERE p.DeltaOrder > @Scan AND p.DeltaOrder <= @KVK_END_SCAN
    GROUP BY p.GovernorID;

    CREATE TABLE #Healed (
        GovernorID        bigint NOT NULL PRIMARY KEY CLUSTERED,
        HealedTroopsDelta bigint NOT NULL
    );

	INSERT INTO #Healed (GovernorID, HealedTroopsDelta)
    SELECT ht.GovernorID, SUM(COALESCE(ht.HealedTroopsDelta, 0)) AS HealedTroopsDelta
    FROM dbo.HealedTroopsDelta ht
    INNER JOIN #GovernorList gl ON gl.GovernorID = ht.GovernorID
    WHERE ht.DeltaOrder > @PRE_PASS_4_SCAN AND ht.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ht.GovernorID;

    CREATE TABLE #Ranged (
        GovernorID        bigint NOT NULL PRIMARY KEY CLUSTERED,
        RangedPointsDelta bigint NOT NULL
    );

	INSERT INTO #Ranged (GovernorID, RangedPointsDelta)
    SELECT r.GovernorID, SUM(COALESCE(r.RangedPointsDelta, 0)) AS RangedPointsDelta
    FROM dbo.RangedPointsDelta r
    INNER JOIN #GovernorList gl ON gl.GovernorID = r.GovernorID
    WHERE r.DeltaOrder > @Scan AND r.DeltaOrder <= @KVK_END_SCAN
    GROUP BY r.GovernorID;

    -----------------------------------------------
    -- 7. Stage - NOW USING #LATEST FOR MOVED COLUMNS
    -----------------------------------------------
	INSERT INTO dbo.STAGING_STATS (
		  GovernorID
		, PowerRank
		, [Power]
		, Power_Delta
		, GovernorName
		, T4KillsDelta
		, T5KillsDelta
		, [T4&T5_KILLSDelta]
		, [KILLS_OUTSIDE_KVK]
		, [P4T4&T5_KILLSDelta]
		, [P6T4&T5_KillsDelta]
		, [P7T4&T5_KillsDelta]
		, [P8T4&T5_KillsDelta]
		, DeadsDelta
		, [DEADS_OUTSIDE_KVK]
		, P4DeadsDelta
		, P6DeadsDelta
		, P7DeadsDelta
		, P8DeadsDelta
		, HelpsDelta
		, RSSASSISTDelta
		, RSSGatheredDelta
		, HealedTroops
		, RangedPoints
		, RangedPointsDelta
		, AutarchTimes
		, Civilization
		, KvKPlayed
		, MostKvKKill
		, MostKvKDead
		, MostKvKHeal
		, Acclaim
		, HighestAcclaim
		, AOOJoined
		, AOOWon
		, AOOAvgKill
		, AOOAvgDead
		, AOOAvgHeal
		, Conduct
		, KillPointsDelta
		, KillPoints
		, HealedTroopsDelta
		, [Starting_Deads]
		, [Starting_T4&T5_KILLS]
		, MaxPreKvkPoints
		, MaxHonorPoints
		, PreKvkRank
		, HonorRank
	)
	SELECT
		  s.GovernorID
		, s.PowerRank
		, s.[Power]
		, COALESCE(p.PowerDelta, 0)                 AS Power_Delta
		, s.GovernorName
		, COALESCE(kt4.T4KillsDelta, 0)             AS T4KillsDelta
		, COALESCE(kt5.T5KillsDelta, 0)             AS T5KillsDelta
		, COALESCE(k.T4T5KillsDelta, 0)             AS [T4&T5_KILLSDelta]
		, COALESCE(k.KillsOutsideKVK, 0)            AS [KILLS_OUTSIDE_KVK]
		, COALESCE(k.P4Kills, 0)                    AS [P4T4&T5_KILLSDelta]
		, COALESCE(k.P6Kills, 0)                    AS [P6T4&T5_KillsDelta]
		, COALESCE(k.P7Kills, 0)                    AS [P7T4&T5_KillsDelta]
		, COALESCE(k.P8Kills, 0)                    AS [P8T4&T5_KillsDelta]
		, COALESCE(d.DeadsDelta, 0)                 AS DeadsDelta
		, COALESCE(d.DeadsDeltaOutKVK, 0)           AS [DEADS_OUTSIDE_KVK]
		, COALESCE(d.P4DeadsDelta, 0)               AS P4DeadsDelta
		, COALESCE(d.P6DeadsDelta, 0)               AS P6DeadsDelta
		, COALESCE(d.P7DeadsDelta, 0)               AS P7DeadsDelta
		, COALESCE(d.P8DeadsDelta, 0)               AS P8DeadsDelta
		, COALESCE(h.HelpsDelta, 0)                 AS HelpsDelta
		, COALESCE(ra.RSSAssistDelta, 0)            AS RSSASSISTDelta
		, COALESCE(rg.RSSGatheredDelta, 0)          AS RSSGatheredDelta
		, COALESCE(s.HealedTroops, 0)               AS HealedTroops
		, COALESCE(s.RangedPoints, 0)             AS RangedPoints        
		, COALESCE(ran.RangedPointsDelta, 0)        AS RangedPointsDelta
		, COALESCE(s.AutarchTimes, 0)               AS AutarchTimes
		, s.Civilization
		, COALESCE(s.KvKPlayed, 0)                  AS KvKPlayed
		, COALESCE(lst.MostKvKKill, 0)              AS MostKvKKill        -- FROM #LATEST
		, COALESCE(lst.MostKvKDead, 0)              AS MostKvKDead        -- FROM #LATEST
		, COALESCE(lst.MostKvKHeal, 0)              AS MostKvKHeal        -- FROM #LATEST
		, COALESCE(lst.Acclaim, 0)                  AS Acclaim            -- FROM #LATEST
		, COALESCE(lst.HighestAcclaim, 0)           AS HighestAcclaim     -- FROM #LATEST
		, COALESCE(lst.AOOJoined, 0)                AS AOOJoined          -- FROM #LATEST
		, COALESCE(lst.AOOWon, 0)                   AS AOOWon             -- FROM #LATEST
		, COALESCE(lst.AOOAvgKill, 0)               AS AOOAvgKill         -- FROM #LATEST
		, COALESCE(lst.AOOAvgDead, 0)               AS AOOAvgDead         -- FROM #LATEST
		, COALESCE(lst.AOOAvgHeal, 0)               AS AOOAvgHeal         -- FROM #LATEST
		, lst.Conduct                                AS Conduct            -- FROM #LATEST
		, COALESCE(kp.KillPointsDelta, 0)           AS KillPointsDelta
		, COALESCE(s.KillPoints, 0)                 AS KillPoints
		, COALESCE(he.HealedTroopsDelta, 0)         AS HealedTroopsDelta
		, COALESCE(s.Deads, 0)                      AS [Starting_Deads]
		, COALESCE(s.[T4&T5_KILLS], 0)              AS [Starting_T4&T5_KILLS]
		, COALESCE(s.MaxPreKvkPoints, 0)            AS MaxPreKvkPoints
		, COALESCE(s.MaxHonorPoints, 0)             AS MaxHonorPoints
		, COALESCE(s.PreKvkRank, 0)                 AS PreKvkRank
		, COALESCE(s.HonorRank, 0)                  AS HonorRank
	FROM #Snapshot s
	LEFT JOIN #LATEST      lst ON lst.GovernorID = s.GovernorID  -- NEW JOIN
	LEFT JOIN #Power       p   ON p.GovernorID   = s.GovernorID
	LEFT JOIN #KillsT4     kt4 ON kt4.GovernorID = s.GovernorID
	LEFT JOIN #KillsT5     kt5 ON kt5.GovernorID = s.GovernorID
	LEFT JOIN #Kills       k   ON k.GovernorID   = s.GovernorID
	LEFT JOIN #KillPoints  kp  ON kp.GovernorID  = s.GovernorID
	LEFT JOIN #Deads       d   ON d.GovernorID   = s.GovernorID
	LEFT JOIN #Helps       h   ON h.GovernorID   = s.GovernorID
	LEFT JOIN #RSSAssist   ra  ON ra.GovernorID  = s.GovernorID
	LEFT JOIN #RSSGathered rg  ON rg.GovernorID  = s.GovernorID
	LEFT JOIN #Healed      he  ON he.GovernorID  = s.GovernorID
	LEFT JOIN #Ranged      ran ON ran.GovernorID = s.GovernorID   
	WHERE s.GovernorID IS NOT NULL;


    -- Cleanup temps from stage step
    DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot, #LATEST, #Healed, #Ranged, #KillPoints, #GovernorList;

    -----------------------------------------------
    -- 8. DKP + HoH (normalize DKP column name)
    -----------------------------------------------
    SELECT  S1.[GovernorID],
            CASE WHEN z.GovernorID = s1.GovernorID
                 THEN ROUND((S1.[T4&T5_KILLSDelta]*3 + (S1.[DeadsDelta] * 0.1) * 8), 0)
                 ELSE ROUND((S1.[T4&T5_KILLSDelta]*3 +  S1.[DeadsDelta]      * 8), 0)
            END AS [DKP_SCORE]
    INTO #DKP
    FROM dbo.STAGING_STATS AS S1
    LEFT JOIN dbo.ZEROED    AS Z ON Z.GovernorID = S1.GovernorID AND Z.ScanOrder = @Scan;

    SELECT GovernorID, MAX(T4_Deads) AS [T4 Deads], MAX(T5_Deads) AS [T5 Deads], MAX(KVK_START_SCANORDER) AS SCANORDER 
    INTO #HD1
    FROM dbo.HoH_Deads 
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 9. Dynamic final table (typed columns!)
    -----------------------------------------------
    DECLARE @ExcelTbl       sysname       = N''EXCEL_FOR_KVK_'' + CAST(@KVK AS nvarchar(10));
    DECLARE @TargetsTbl     sysname       = N''TARGETS_''       + CAST(@KVK AS nvarchar(10));
    DECLARE @ExcelTblFull   nvarchar(260) = QUOTENAME(''dbo'') + N''.'' + QUOTENAME(@ExcelTbl);
    DECLARE @TargetsTblFull nvarchar(260) = QUOTENAME(''dbo'') + N''.'' + QUOTENAME(@TargetsTbl);

    DECLARE @sql nvarchar(max) = N'''';

    SET @sql += N''DROP TABLE IF EXISTS '' + @ExcelTblFull + N'';'' + CHAR(10);

    SET @sql += N''
    SELECT TOP (5000)
        S.[PowerRank]                                                AS [Rank],
        CAST(ROW_NUMBER() OVER (ORDER BY D.[DKP_SCORE] DESC) AS int) AS [KVK_RANK],
        S.[GovernorID]                                               AS [Gov_ID],
        CAST(COALESCE(NM.GovernorName,S.[GovernorName]) AS nvarchar(255)) AS [Governor_Name],

        CAST(S.[Power] AS bigint)                                    AS [Starting Power],
        CAST(S.Power_Delta AS bigint)                                AS [Power_Delta],

        CAST(S.[Civilization] AS nvarchar(100))                      AS [Civilization],
        CAST(S.[KvKPlayed] AS int)                                   AS [KvKPlayed],
        CAST(S.[MostKvKKill] AS bigint)                              AS [MostKvKKill],
        CAST(S.[MostKvKDead] AS bigint)                              AS [MostKvKDead],
        CAST(S.[MostKvKHeal] AS bigint)                              AS [MostKvKHeal],
        CAST(S.[Acclaim] AS bigint)                                  AS [Acclaim],
        CAST(S.[HighestAcclaim] AS bigint)                           AS [HighestAcclaim],
        CAST(S.[AOOJoined] AS bigint)                                AS [AOOJoined],
        CAST(S.[AOOWon] AS int)                                      AS [AOOWon],
        CAST(S.[AOOAvgKill] AS bigint)                               AS [AOOAvgKill],
        CAST(S.[AOOAvgDead] AS bigint)                               AS [AOOAvgDead],
        CAST(S.[AOOAvgHeal] AS bigint)                               AS [AOOAvgHeal],
        CAST(S.[Conduct] AS decimal(5,2))                             AS [Conduct],

        CAST(S.[Starting_T4&T5_KILLS] AS bigint)                     AS [Starting_T4&T5_KILLS],
        CAST(S.[T4KillsDelta] AS bigint)                             AS [T4_KILLS],
        CAST(S.[T5KillsDelta] AS bigint)                             AS [T5_KILLS],
        CAST(S.[T4&T5_KILLSDelta] AS bigint)                         AS [T4&T5_Kills],
        CAST(S.KILLS_OUTSIDE_KVK AS bigint)                          AS [KILLS_OUTSIDE_KVK],

        CAST(T.[Kill_Target] AS bigint)                                 AS [Kill Target],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE ROUND( (CAST(S.[T4&T5_KILLSDelta] AS decimal(19,2)) / CAST(T.[Kill_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Kill Target],

        CAST(S.[Starting_Deads] AS bigint)                           AS [Starting_Deads],
        CAST(S.[DeadsDelta] AS bigint)                               AS [Deads_Delta],
        CAST(S.DEADS_OUTSIDE_KVK AS bigint)                          AS [DEADS_OUTSIDE_KVK],

        CAST(COALESCE(HD.[T4 Deads], 0) AS bigint)                   AS [T4_Deads],
        CAST(COALESCE(HD.[T5 Deads], 0) AS bigint)                   AS [T5_Deads],

        CAST(T.[Dead_Target] AS bigint)                                 AS [Dead_Target],
        CAST(
            CASE
                WHEN T.[Dead_Target] = 0 THEN 0
                WHEN Z.GovernorID = S.GovernorID
                    THEN ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) * 0.1 / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
                ELSE ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Dead Target],

        CAST(Z.Zeroed AS bit)                                        AS [Zeroed],

        CAST(D.[DKP_SCORE] AS bigint)                                AS [DKP_SCORE],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE (CAST(T.Kill_Target AS bigint) * 3 + CAST(T.Dead_Target AS bigint) * 8)
            END
            AS bigint
        )                                                            AS [DKP Target],

        CAST(
            CASE
                WHEN (CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) = 0 THEN 0
                ELSE ROUND(
                    (CAST(D.[DKP_SCORE] AS decimal(19,2)) /
                     CAST((CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) AS decimal(19,2))) * 100,
                    2
                )
            END
            AS decimal(9,2)
        )                                                            AS [% of DKP Target],

        CAST(S.[HelpsDelta] AS bigint)                               AS [HelpsDelta],
        CAST(S.[RSSASSISTDelta] AS bigint)                           AS [RSS_Assist_Delta],
        CAST(S.[RSSGatheredDelta] AS bigint)                         AS [RSS_Gathered_Delta],

        CAST(S.[P4T4&T5_KillsDelta] AS bigint)                       AS [Pass 4 Kills],
        CAST(S.[P6T4&T5_KillsDelta] AS bigint)                       AS [Pass 6 Kills],
        CAST(S.[P7T4&T5_KillsDelta] AS bigint)                       AS [Pass 7 Kills],
        CAST(S.[P8T4&T5_KillsDelta] AS bigint)                       AS [Pass 8 Kills],

        CAST(S.P4DeadsDelta AS bigint)                               AS [Pass 4 Deads],
        CAST(S.P6DeadsDelta AS bigint)                               AS [Pass 6 Deads],
        CAST(S.P7DeadsDelta AS bigint)                               AS [Pass 7 Deads],
        CAST(S.P8DeadsDelta AS bigint)                               AS [Pass 8 Deads],

        CAST(S.[HealedTroops] AS bigint)                             AS [Starting_HealedTroops],
        CAST(S.[HealedTroopsDelta] AS bigint)                        AS [HealedTroopsDelta],

        CAST(S.[KillPoints] AS bigint)                               AS [Starting_KillPoints],
        CAST(S.[KillPointsDelta] AS bigint)                          AS [KillPointsDelta],

        CAST(S.[RangedPoints] AS bigint)                             AS [RangedPoints],
        CAST(S.[RangedPointsDelta] AS bigint)                        AS [RangedPointsDelta],

        CAST(S.[AutarchTimes] AS bigint)                             AS [AutarchTimes],

        CAST(S.[MaxPreKvkPoints] AS bigint)                          AS [Max_PreKvk_Points],
        CAST(S.[MaxHonorPoints] AS bigint)                           AS [Max_HonorPoints],
        CAST(S.[PreKvkRank] AS bigint)                               AS [PreKvk_Rank],
        CAST(S.[HonorRank] AS bigint)                                AS [Honor_Rank],

        CAST(@pKVK AS int)                                           AS [KVK_NO]
    INTO '' + @ExcelTblFull + N''
    FROM dbo.STAGING_STATS AS S
    LEFT JOIN dbo.v_ReportGovernorNames NM ON NM.GovernorID=S.GovernorID
    LEFT JOIN #HD1  AS HD ON S.GovernorID = HD.GovernorID
    LEFT JOIN '' + @TargetsTblFull + N'' AS T ON T.GovernorID = S.GovernorID
    LEFT JOIN #DKP  AS D  ON D.GovernorID = S.GovernorID
    LEFT JOIN dbo.ZEROED AS Z ON Z.GovernorID = S.GovernorID AND Z.ScanOrder = @pScan
    ORDER BY S.PowerRank ASC;'';

	IF CHARINDEX(N''COALESCE(HD.[T4 Deads]'', @sql) = 0
	BEGIN
		RAISERROR(''HD reference missing from SQL string (string likely broken).'',16,1);
	END

    EXEC sp_executesql
        @sql,
        N''@pScan int, @pKVK int'',
        @pScan = @Scan,
        @pKVK  = @KVK;

    DROP TABLE IF EXISTS #DKP, #HD1;

    EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;
    EXEC dbo.usp_RecordKvkFinalReportCompletion
        @KVKNo = @KVK,
        @FinalScanOrder = @LatestScanToUse,
        @FinalizationBasis = N''LIVE_OUTPUT'';

        EXEC dbo.usp_MaintenanceKvkDue @KVKNo=@KVK;

	        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    PRINT ''Completed KVK '' + CAST(@KVK AS varchar(10))
        + '' with ScanOrder='' + CAST(@Scan AS varchar(20))
        + '', LatestScanUsed='' + CAST(@LatestScanToUse AS varchar(20))
        + '' at '' + CONVERT(varchar, GETDATE(), 120);
END';
-- dbo.usp_CleanupLogBackupTriggerQueue
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[usp_CleanupLogBackupTriggerQueue]
	@RetentionDays [int] = 30
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    -- A drained, coordinated D4 transition preserves the historical queue.
    -- Observe only this fixed identity under dbo; caller metadata DENYs cannot
    -- disguise the new deployment. The queue operation retains caller context.
    DECLARE @P02LedgerPresent bit;
    EXEC dbo.usp_P02LegacyQueueState @LedgerPresent=@P02LedgerPresent OUTPUT;
    IF @P02LedgerPresent IS NULL
        THROW 52942, ''Legacy backup queue deployment state is unavailable; no queue work was performed.'', 1;
    IF @P02LedgerPresent = 1
        THROW 52941, ''Legacy backup queue is held by P02 maintenance; historical rows must be preserved.'', 1;

    
    DECLARE @CutoffDate DATETIME2 = DATEADD(DAY, -@RetentionDays, SYSDATETIME());
    DECLARE @RowsDeleted INT;
    
    DELETE FROM dbo.LogBackupTriggerQueue
    WHERE Processed = 1
      AND ProcessedTime < @CutoffDate;
    
    SET @RowsDeleted = @@ROWCOUNT;
    
    PRINT ''Deleted '' + CAST(@RowsDeleted AS VARCHAR(10)) + '' processed records older than '' + 
          CAST(@RetentionDays AS VARCHAR(10)) + '' days.'';
    
    RETURN @RowsDeleted;
END';
-- dbo.usp_GetPendingLogBackupTriggers
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[usp_GetPendingLogBackupTriggers]
	@MaxAge [int] = 60
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    -- A drained, coordinated D4 transition preserves the historical queue.
    -- Observe only this fixed identity under dbo; caller metadata DENYs cannot
    -- disguise the new deployment. The queue operation retains caller context.
    DECLARE @P02LedgerPresent bit;
    EXEC dbo.usp_P02LegacyQueueState @LedgerPresent=@P02LedgerPresent OUTPUT;
    IF @P02LedgerPresent IS NULL
        THROW 52942, ''Legacy backup queue deployment state is unavailable; no queue work was performed.'', 1;
    IF @P02LedgerPresent = 1
        THROW 52941, ''Legacy backup queue is held by P02 maintenance; historical rows must be preserved.'', 1;

    
    SELECT 
        ID,
        TriggerTime,
        ProcedureName,
        Reason,
        LogUsedPctBefore,
        DATEDIFF(SECOND, TriggerTime, SYSDATETIME()) AS AgeSeconds
    FROM dbo.LogBackupTriggerQueue
    WHERE Processed = 0
      AND TriggerTime >= DATEADD(MINUTE, -@MaxAge, SYSDATETIME())
    ORDER BY TriggerTime ASC;
END';
-- dbo.usp_MaintenanceBackupAcknowledge
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceBackupAcknowledge
    @ClaimID uniqueidentifier, @Generation bigint, @Outcome varchar(12), @Failure varchar(32)=NULL
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2 OR
        COALESCE(APPLOCK_MODE(''public'',''K98:post-import-stats:v1'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Exact backup session owner required.'',1;
    IF @Outcome NOT IN (''requested'',''failed'',''unknown'') OR @Outcome IS NULL
        THROW 51962,''Unsupported backup outcome.'',1;
    UPDATE dbo.MaintenanceBackupWork SET
        RequestedGeneration=CASE WHEN @Outcome=''requested'' THEN @Generation ELSE RequestedGeneration END,
        RequestedUTC=CASE WHEN @Outcome=''requested'' THEN SYSUTCDATETIME() ELSE RequestedUTC END,
        State=CASE WHEN @Outcome=''requested'' AND DueGeneration>@Generation THEN ''pending'' ELSE @Outcome END,
        FirstFailure=CASE WHEN @Outcome<>''requested'' THEN COALESCE(FirstFailure,@Failure,''dispatch_unknown'') ELSE FirstFailure END,
        FirstFailureUTC=CASE WHEN @Outcome<>''requested'' THEN COALESCE(FirstFailureUTC,SYSUTCDATETIME()) ELSE FirstFailureUTC END,
        LastFailure=CASE WHEN @Outcome<>''requested'' THEN COALESCE(@Failure,''dispatch_unknown'') END
      WHERE ID=1 AND State=''running'' AND ClaimID=@ClaimID AND ClaimedGeneration=@Generation;
    IF @@ROWCOUNT<>1 THROW 51964,''Backup claim changed; retain original outcome.'',1;
    SELECT State,DueGeneration,RequestedGeneration,ClaimedGeneration,ClaimID
      FROM dbo.MaintenanceBackupWork WHERE ID=1;
END;';
-- dbo.usp_MaintenanceBackupClaim
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceBackupClaim @ClaimID uniqueidentifier
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON; SET LOCK_TIMEOUT 0;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2 OR @ClaimID IS NULL
        THROW 51962,''Backup claim requires dedicated autocommit ownership.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:post-import-stats:v1'',''Session''),''NoLock'')<>''NoLock''
        THROW 51962,''Backup claim cannot adopt pre-existing ownership.'',1;
    DECLARE @r int;
    EXEC @r=sys.sp_getapplock @Resource=''K98:post-import-stats:v1'',
        @LockMode=''Exclusive'',@LockOwner=''Session'',@LockTimeout=0;
    IF @r<0
    BEGIN
        SELECT CAST(''busy'' AS varchar(12)) State,DueGeneration,RequestedGeneration,ClaimedGeneration,ClaimID
          FROM dbo.MaintenanceBackupWork WHERE ID=1;
        RETURN;
    END;
    -- Guard is held on this session until the caller acknowledges cleanup.
    -- Committed summary demand is sufficient. Backup relief must not wait for
    -- statistics/CHECKPOINT, whose separate log-headroom gate can defer upkeep.
    DECLARE @summary bigint;
    SELECT @summary=SummaryDueGeneration FROM dbo.MaintenanceWork WHERE Kind=''final_stats'';
    IF OBJECT_ID(''dbo.LogBackupTriggerQueue'',''U'') IS NOT NULL AND @summary>0
        UPDATE dbo.MaintenanceBackupWork SET DueGeneration=@summary,DueUTC=SYSUTCDATETIME(),
            State=CASE WHEN State=''requested'' THEN ''pending'' ELSE State END
          WHERE ID=1 AND DueGeneration<@summary;
    UPDATE dbo.MaintenanceBackupWork SET State=''unknown'',
        FirstFailure=COALESCE(FirstFailure,''owner_absent''),
        FirstFailureUTC=COALESCE(FirstFailureUTC,SYSUTCDATETIME()),LastFailure=''owner_absent''
      WHERE ID=1 AND State=''running'';
    UPDATE dbo.MaintenanceBackupWork SET State=''running'',ClaimID=@ClaimID,
        ClaimedGeneration=DueGeneration,StartedUTC=SYSUTCDATETIME()
      WHERE ID=1 AND State=''pending'' AND DueGeneration>RequestedGeneration
        AND DueGeneration<=@summary;
    SELECT State,DueGeneration,RequestedGeneration,ClaimedGeneration,ClaimID
      FROM dbo.MaintenanceBackupWork WHERE ID=1;
END;';
-- dbo.usp_MaintenanceConfiguration
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceConfiguration
    @RowsProcessed bigint, @LastBatchRows int, @NewMaxScan int,
    @LargeBatchDue bit, @Generation bigint
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Direct calls must obey the same session boundary as the worker.
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51962,''Maintenance child requires its own autocommit session.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:StatsForUpload:Publish'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance player publication guard required.'',1;
    DECLARE @StartTime datetime2=SYSUTCDATETIME();
    DECLARE @MaintenanceRowThreshold int=5000,@MaintenanceHourThreshold int=168;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:post-import-stats:v1'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''k98-legacy-output-snapshot'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''K98:TargetPublication:DeltaPreprocessing'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''K98:maintenance-schema:v1'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Exact maintenance session guards required.'',1;
    ----------------------------------------------------------------
    -- Step 6: LIGHTWEIGHT MAINTENANCE
    ----------------------------------------------------------------

    DECLARE @ShouldRunMaintenance BIT = 0;
    DECLARE @LastMaintenanceTime DATETIME2;
    DECLARE @TotalRowsSinceLastMaintenance bigint;

    IF OBJECT_ID(''dbo.DeltaProcessingLog'', ''U'') IS NOT NULL
    BEGIN
        SELECT TOP 1
            @LastMaintenanceTime = ExecutionTime,
            @TotalRowsSinceLastMaintenance =
                (SELECT SUM(RowsProcessed)
                 FROM dbo.DeltaProcessingLog
                 WHERE ExecutionTime > ISNULL((SELECT TOP 1 ExecutionTime
                                               FROM dbo.DeltaProcessingLog
                                               WHERE MaintenanceRan = 1
                                               ORDER BY ExecutionTime DESC), ''1900-01-01''))
        FROM dbo.DeltaProcessingLog
        WHERE MaintenanceRan = 1
        ORDER BY ExecutionTime DESC;

        IF @LastMaintenanceTime IS NULL
            OR DATEDIFF(HOUR, @LastMaintenanceTime, SYSUTCDATETIME()) >= @MaintenanceHourThreshold
            OR COALESCE(@TotalRowsSinceLastMaintenance,0)+(@RowsProcessed-@LastBatchRows) >= @MaintenanceRowThreshold
        BEGIN
            SET @ShouldRunMaintenance = 1;
        END
    END
    ELSE
    BEGIN
        IF @LargeBatchDue=1
            SET @ShouldRunMaintenance = 1;
    END

    IF @ShouldRunMaintenance = 1
    BEGIN
        PRINT ''Running weekly maintenance...'';
        PRINT ''Days since last maintenance: '' + CAST(DATEDIFF(DAY, ISNULL(@LastMaintenanceTime, ''1900-01-01''), SYSUTCDATETIME()) AS VARCHAR(10));
        PRINT ''Rows since last maintenance: '' + CAST(ISNULL(@TotalRowsSinceLastMaintenance, @RowsProcessed) AS VARCHAR(10));

        UPDATE STATISTICS T4KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS T5KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS T4T5KillDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS POWERDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS KillPointsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS DeadsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS HelpsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RSSASSISTDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RSSGatheredDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS HealedTroopsDelta WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS RangedPointsDelta WITH SAMPLE 25 PERCENT;
		UPDATE STATISTICS DeltaMetrics WITH SAMPLE 25 PERCENT;
        UPDATE STATISTICS dbo.kingdomscandata4 WITH SAMPLE 25 PERCENT;

        PRINT ''Statistics updated (25% sample).'';

        -- Index maintenance code (same as before)
        DECLARE @TableName NVARCHAR(128);
        DECLARE @IndexName NVARCHAR(128);
        DECLARE @Fragmentation FLOAT;
        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @IndexesChecked INT = 0;
        DECLARE @IndexesMaintained INT = 0;

        CREATE TABLE #IndexFragmentation (
            TableName NVARCHAR(128),
            IndexName NVARCHAR(128),
            FragmentationPercent FLOAT,
            PageCount BIGINT
        );

        INSERT INTO #IndexFragmentation
        SELECT
            OBJECT_NAME(ips.object_id) AS TableName,
            i.name AS IndexName,
            ips.avg_fragmentation_in_percent AS FragmentationPercent,
            ips.page_count AS PageCount
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, ''LIMITED'') ips
        INNER JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
        WHERE OBJECT_NAME(ips.object_id) IN (
            ''T4KillDelta'', ''T5KillDelta'', ''T4T5KillDelta'', ''POWERDelta'',
            ''KillPointsDelta'', ''DeadsDelta'', ''HelpsDelta'', ''RSSASSISTDelta'',
            ''RSSGatheredDelta'', ''HealedTroopsDelta'', ''RangedPointsDelta'',
			''DeltaMetrics'', ''kingdomscandata4''
        )
        AND OBJECT_SCHEMA_NAME(ips.object_id)=N''dbo''
        AND i.name IS NOT NULL
        AND ips.page_count > 1000;

        SELECT @IndexesChecked = COUNT(*) FROM #IndexFragmentation;

        DECLARE index_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT TableName, IndexName, FragmentationPercent
        FROM #IndexFragmentation
        WHERE FragmentationPercent > 15
        ORDER BY FragmentationPercent DESC;

        OPEN index_cursor;
        FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @Fragmentation;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @Fragmentation > 50
            BEGIN
                SET @SQL = N''ALTER INDEX '' + QUOTENAME(@IndexName) + N'' ON [dbo].'' + QUOTENAME(@TableName) + N'' REBUILD WITH (ONLINE = OFF, SORT_IN_TEMPDB = ON, MAXDOP = 2);'';
                PRINT ''Rebuilding: '' + @IndexName + '' on '' + @TableName + '' ('' + CAST(CAST(@Fragmentation AS DECIMAL(5,2)) AS VARCHAR(10)) + ''% fragmented)'';
            END
            ELSE
            BEGIN
                SET @SQL = N''ALTER INDEX '' + QUOTENAME(@IndexName) + N'' ON [dbo].'' + QUOTENAME(@TableName) + N'' REORGANIZE;'';
                PRINT ''Reorganizing: '' + @IndexName + '' on '' + @TableName + '' ('' + CAST(CAST(@Fragmentation AS DECIMAL(5,2)) AS VARCHAR(10)) + ''% fragmented)'';
            END

            BEGIN TRY
                EXEC sp_executesql @SQL;
                SET @IndexesMaintained = @IndexesMaintained + 1;
            END TRY
            BEGIN CATCH
                THROW; -- Preserve the actual first child failure; never claim successful upkeep.
            END CATCH

            FETCH NEXT FROM index_cursor INTO @TableName, @IndexName, @Fragmentation;
        END

        CLOSE index_cursor;
        DEALLOCATE index_cursor;
        DROP TABLE #IndexFragmentation;

        PRINT ''Index maintenance: '' + CAST(@IndexesMaintained AS VARCHAR(10)) + '' of '' + CAST(@IndexesChecked AS VARCHAR(10)) + '' indexes maintained.'';
    END
    ELSE
    BEGIN
        PRINT ''Skipping maintenance - next scheduled in '' +
              CAST(@MaintenanceHourThreshold - DATEDIFF(HOUR, ISNULL(@LastMaintenanceTime, SYSUTCDATETIME()), SYSUTCDATETIME()) AS VARCHAR(10)) +
              '' hours or after '' +
              CAST(@MaintenanceRowThreshold - ISNULL(@TotalRowsSinceLastMaintenance, 0) AS VARCHAR(10)) +
              '' more rows.'';
    END

    ----------------------------------------------------------------
    -- Step 7: Performance Logging
    ----------------------------------------------------------------
    UPDATE dbo.MaintenanceConfigurationWork SET UpkeepCompletedGeneration=@Generation,
        UpkeepDisposition=CASE WHEN @ShouldRunMaintenance=1 THEN ''complete'' ELSE ''ineligible'' END WHERE ID=1;
    DECLARE @ElapsedMS INT = DATEDIFF(MILLISECOND, @StartTime, SYSUTCDATETIME());

    BEGIN TRY
    IF OBJECT_ID(''dbo.DeltaProcessingLog'', ''U'') IS NOT NULL
    BEGIN
        INSERT INTO dbo.DeltaProcessingLog (RowsProcessed, LastScanProcessed, ElapsedMS, MaintenanceRan, Notes)
        VALUES (
            @RowsProcessed,
            @NewMaxScan,
            @ElapsedMS,
            @ShouldRunMaintenance,
            CASE
                WHEN @ShouldRunMaintenance = 1 THEN ''Deferred upkeep completed; coalesced rows; maintenance duration only''
                ELSE ''Deferred upkeep not eligible; coalesced rows; maintenance duration only''
            END
        );
    END

    END TRY
    BEGIN CATCH
        DECLARE @logError int=ERROR_NUMBER();
        BEGIN TRY
            UPDATE dbo.MaintenanceConfigurationWork
               SET FirstLogErrorNumber=COALESCE(FirstLogErrorNumber,@logError) WHERE ID=1;
        END TRY
        BEGIN CATCH
            -- Diagnostic persistence must not replace the original timing-log error.
        END CATCH;
        -- The durable upkeep generation above remains independent. A failed
        -- packet cannot automatically replay completed upkeep for a timing log.
        THROW;
    END CATCH;
END;';
-- dbo.usp_MaintenanceConfigurationDue
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceConfigurationDue
    @RowsProcessed int, @LastScan int
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT=0 OR @RowsProcessed<=0 THROW 51962,''Configuration due requires its business transaction and positive rows.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:TargetPublication:DeltaPreprocessing'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Configuration due requires its delta owner.'',1;
    EXEC dbo.usp_MaintenanceDue @Kind=''configuration'';
    DECLARE @generation bigint=(SELECT DueGeneration FROM dbo.MaintenanceWork WHERE Kind=''configuration'');
    UPDATE dbo.MaintenanceConfigurationWork
       SET DueRows=DueRows+@RowsProcessed,LastBatchRows=@RowsProcessed,LastScan=@LastScan,
           LargeBatchGeneration=CASE WHEN @RowsProcessed>=5000 THEN @generation ELSE LargeBatchGeneration END
     WHERE ID=1;
    IF @@ROWCOUNT<>1 THROW 51962,''Configuration maintenance summary missing.'',1;
END;';
-- dbo.usp_MaintenanceDue
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceDue
    @Kind varchar(24), @RequestID uniqueidentifier = NULL, @ImportKS4 bit = 0,
    @FinalDashboard bit = 0, @FinalSummary bit = 0
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @ImportKS4=1 AND @Kind<>''import'' THROW 51962,''KS4 scope requires import maintenance.'',1;
    IF (@FinalDashboard=1 OR @FinalSummary=1) AND (@Kind<>''final_stats'' OR @@TRANCOUNT=0)
        THROW 51962,''Final report demand requires its business transaction.'',1;
    -- Join the business transaction. Never commit or roll back the caller.
    -- The finite row set coalesces work; no per-import queue grows without bound.
    UPDATE dbo.MaintenanceWork WITH (UPDLOCK)
       SET DueGeneration=DueGeneration+1, DueUTC=SYSUTCDATETIME(),
           KS4DueGeneration=CASE WHEN @ImportKS4=1 THEN DueGeneration+1 ELSE KS4DueGeneration END,
           DashboardDueGeneration=CASE WHEN @FinalDashboard=1 THEN DueGeneration+1 ELSE DashboardDueGeneration END,
           SummaryDueGeneration=CASE WHEN @FinalSummary=1 THEN DueGeneration+1 ELSE SummaryDueGeneration END,
           LastRequestID=@RequestID,
           State=CASE WHEN State=''complete'' THEN ''pending'' ELSE State END
     WHERE Kind=@Kind AND (@RequestID IS NULL OR LastRequestID IS NULL
                          OR LastRequestID<>@RequestID);
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork WHERE Kind=@Kind)
        THROW 51962, ''Unknown maintenance kind.'', 1;
END;';
-- dbo.usp_MaintenanceFinalStats
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceFinalStats
    @Dashboard bit, @Summary bit, @Generation bigint, @ClaimID uniqueidentifier
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Direct calls must obey the same session boundary as the worker.
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51962,''Maintenance child requires its own autocommit session.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:TargetPublication:DeltaPreprocessing'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance delta guard required.'',1;
    IF APPLOCK_MODE(''public'',''K98:post-import-stats:v1'',''Session'')<>''Exclusive''
       OR APPLOCK_MODE(''public'',''k98-legacy-output-snapshot'',''Session'')<>''Exclusive''
        THROW 51961, ''Exact maintenance worker ownership required.'', 1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:maintenance-schema:v1'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance schema guard required.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:StatsForUpload:Publish'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance player publication guard required.'',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork WHERE Kind=''final_stats''
        AND State=''running'' AND ClaimID=@ClaimID AND ClaimedGeneration=@Generation)
        THROW 51964,''Exact final maintenance claim required.'',1;
    IF @Dashboard=1 AND OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'',''U'') IS NOT NULL
        UPDATE STATISTICS dbo.EXCEL_FOR_DASHBOARD WITH SAMPLE 25 PERCENT;
    IF @Summary=1
    BEGIN
        UPDATE STATISTICS dbo.ALL_STATS_FOR_DASHBAORD WITH FULLSCAN;
        CHECKPOINT;
    END;
END;';
-- dbo.usp_MaintenanceImport
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceImport @IncludeKS4 bit
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Direct calls must obey the same session boundary as the worker.
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51962,''Maintenance child requires its own autocommit session.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:StatsForUpload:Publish'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance player publication guard required.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:TargetPublication:DeltaPreprocessing'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance delta guard required.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:post-import-stats:v1'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''k98-legacy-output-snapshot'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''K98:maintenance-schema:v1'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Exact maintenance session guards required.'',1;
        -- SMART INDEX MAINTENANCE: Only update stats for KS5 (lightweight)
        -- Full index rebuild happens nightly via maintenance job
        PRINT ''Updating statistics for KingdomScanData5 (quick sample)...'';
        UPDATE STATISTICS dbo.KingdomScanData5 WITH SAMPLE 20 PERCENT;
        PRINT ''KingdomScanData5 statistics refreshed.'';

    IF @IncludeKS4=1
    BEGIN
            ----------------------------------------------------------------
            -- SMART INDEX MAINTENANCE for KS4: Check fragmentation first
            -- Thresholds:
            --   - Skip if < 10% fragmentation
            --   - REORGANIZE if 10-30% fragmentation (online, low impact)
            --   - REBUILD if > 30% fragmentation
            ----------------------------------------------------------------
            PRINT ''Checking KingdomScanData4 index fragmentation...'';

            DECLARE @IndexMaintLog TABLE (
                IndexName NVARCHAR(128),
                FragmentationPercent DECIMAL(5,2),
                Action NVARCHAR(20)
            );

            -- Check fragmentation of critical indexes
            DECLARE @IndexName NVARCHAR(128);
            DECLARE @Fragmentation DECIMAL(5,2);
            DECLARE @SQL NVARCHAR(MAX);

            DECLARE idx_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                    i.name AS IndexName,
                    ips.avg_fragmentation_in_percent AS Fragmentation
                FROM sys.dm_db_index_physical_stats(
                    DB_ID(),
                    OBJECT_ID(''dbo.KingdomScanData4''),
                    NULL, NULL, ''LIMITED''
                ) AS ips
                INNER JOIN sys.indexes AS i
                    ON ips.object_id = i.object_id
                    AND ips.index_id = i.index_id
                WHERE
                    i.name IN (
                        ''CIX_KS4_ScanOrder_Governor'',
                        ''IX_KSD4_Governor_ScanOrder'',
                        ''IX_KS4_Governor_ScanDate'',
                        ''IX_KSD4_Gov_ScanOrder''
                    )
                    AND ips.avg_fragmentation_in_percent IS NOT NULL;

            OPEN idx_cursor;
            FETCH NEXT FROM idx_cursor INTO @IndexName, @Fragmentation;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @Fragmentation < 10
                BEGIN
                    -- Skip - fragmentation is low
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, ''SKIPPED'');
                    PRINT ''  '' + @IndexName + '': '' + CAST(@Fragmentation AS VARCHAR(10)) + ''% - Skipped'';
                END
                ELSE IF @Fragmentation < 30
                BEGIN
                    -- REORGANIZE - medium fragmentation, online operation
                    SET @SQL = N''ALTER INDEX ['' + @IndexName + N''] ON dbo.KingdomScanData4 REORGANIZE;'';
                    EXEC sp_executesql @SQL;
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, ''REORGANIZED'');
                    PRINT ''  '' + @IndexName + '': '' + CAST(@Fragmentation AS VARCHAR(10)) + ''% - Reorganized'';
                END
                ELSE
                BEGIN
                    -- REBUILD - high fragmentation
                    SET @SQL = N''ALTER INDEX ['' + @IndexName + N''] ON dbo.KingdomScanData4 REBUILD WITH (SORT_IN_TEMPDB = ON, MAXDOP = 0);'';
                    EXEC sp_executesql @SQL;
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, ''REBUILT'');
                    PRINT ''  '' + @IndexName + '': '' + CAST(@Fragmentation AS VARCHAR(10)) + ''% - Rebuilt'';
                END

                FETCH NEXT FROM idx_cursor INTO @IndexName, @Fragmentation;
            END

            CLOSE idx_cursor;
            DEALLOCATE idx_cursor;

            -- Always update statistics after any index maintenance
            UPDATE STATISTICS dbo.KingdomScanData4 WITH SAMPLE 25 PERCENT;
            PRINT ''KingdomScanData4 statistics refreshed.'';

			UPDATE STATISTICS dbo.PlayerScanMeta WITH SAMPLE 25 PERCENT;

            -- Log index maintenance actions
            SELECT * FROM @IndexMaintLog;
    END;
END;';
-- dbo.usp_MaintenanceKvkDue
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceKvkDue @KVKNo int
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @KVKNo IS NULL OR @KVKNo<=0 OR @@TRANCOUNT=0
        THROW 51962,''KVK upkeep requires a positive KVK in its publication transaction.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:maintenance-schema:v1'',''Transaction''),''NoLock'') NOT IN (''Shared'',''Exclusive'')
        THROW 51962,''KVK publication schema ownership required.'',1;
    DECLARE @object int,@created datetime,@revision int,@generation bigint;
    SELECT @object=object_id,@created=create_date FROM sys.tables
      WHERE schema_id=SCHEMA_ID(''dbo'') AND name=N''EXCEL_FOR_KVK_''+CONVERT(nvarchar(11),@KVKNo);
    SELECT @revision=Revision FROM dbo.KVKFinalReportHeader
      WHERE KVK_NO=@KVKNo AND State=N''OUTPUT_COMPLETE'';
    IF @object IS NULL OR @revision IS NULL
        THROW 51962,''Canonical KVK output and completion receipt required.'',1;
    EXEC dbo.usp_MaintenanceDue @Kind=''kvk_output'';
    SELECT @generation=DueGeneration FROM dbo.MaintenanceWork WHERE Kind=''kvk_output'';
    -- One coalesced row per canonical output, never one row per import.
    -- Claim fields remain the original attempted identity after newer publication.
    UPDATE dbo.MaintenanceKvkWork WITH (UPDLOCK,HOLDLOCK)
       SET DueGeneration=@generation,DueObjectID=@object,DueObjectCreateDate=@created,
           DueHeaderRevision=@revision,State=CASE WHEN State=''complete'' THEN ''pending'' ELSE State END
     WHERE KVKNo=@KVKNo;
    IF @@ROWCOUNT=0
        INSERT dbo.MaintenanceKvkWork(KVKNo,DueGeneration,DueObjectID,DueObjectCreateDate,DueHeaderRevision)
        VALUES(@KVKNo,@generation,@object,@created,@revision);
END;';
-- dbo.usp_MaintenanceKvkOutput
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceKvkOutput
    @Generation bigint,@ClaimID uniqueidentifier,@AllDone bit OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Direct calls must obey the same session boundary as the worker.
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51962,''Maintenance child requires its own autocommit session.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:post-import-stats:v1'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''k98-legacy-output-snapshot'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''K98:TargetPublication:DeltaPreprocessing'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''K98:StatsForUpload:Publish'',''Session''),''NoLock'')<>''Exclusive''
       OR COALESCE(APPLOCK_MODE(''public'',''K98:maintenance-schema:v1'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Exact KVK maintenance physical ownership required.'',1;
    IF @ClaimID IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork
        WHERE Kind=''kvk_output'' AND ClaimID=@ClaimID AND ClaimedGeneration=@Generation AND State=''running'')
        THROW 51964,''Exact aggregate KVK maintenance claim required.'',1;
    DECLARE @kvk int,@due bigint,@object int,@created datetime,@revision int,
        @table sysname,@full nvarchar(260),@idx sysname,@sql nvarchar(max);
    SET @AllDone=0;
    -- A fixed one-target budget bounds each invocation, including old seasons.
    SELECT TOP(1) @kvk=KVKNo,@due=DueGeneration,@object=DueObjectID,
        @created=DueObjectCreateDate,@revision=DueHeaderRevision
      FROM dbo.MaintenanceKvkWork
      WHERE DueGeneration<=@Generation AND CompletedGeneration<DueGeneration AND State=''pending''
      ORDER BY DueGeneration,KVKNo;
    IF @kvk IS NOT NULL
    BEGIN
        UPDATE dbo.MaintenanceKvkWork SET State=''running'',ClaimID=@ClaimID,
            ClaimedGeneration=@due,ClaimedObjectID=@object,
            ClaimedObjectCreateDate=@created,ClaimedHeaderRevision=@revision
          WHERE KVKNo=@kvk AND DueGeneration=@due AND State=''pending'';
        IF @@ROWCOUNT<>1 THROW 51964,''KVK maintenance scope changed.'',1;
        BEGIN TRY
            SET @table=N''EXCEL_FOR_KVK_''+CONVERT(nvarchar(11),@kvk);
            SET @full=QUOTENAME(N''dbo'')+N''.''+QUOTENAME(@table);
            IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@object
                AND schema_id=SCHEMA_ID(''dbo'') AND name=@table AND create_date=@created)
               OR NOT EXISTS(SELECT 1 FROM dbo.KVKFinalReportHeader
                WHERE KVK_NO=@kvk AND Revision=@revision AND State=N''OUTPUT_COMPLETE'')
                THROW 51968,''KVK maintenance output identity no longer matches its receipt.'',1;
            IF COL_LENGTH(@full,''Gov_ID'') IS NULL OR COL_LENGTH(@full,''KVK_NO'') IS NULL
                THROW 51968,''KVK maintenance output columns are missing.'',1;
            -- Create only absent nonunique output indexes. Never drop a unique
            -- index/constraint or alter required output shape to do upkeep.
            SET @idx=N''IX_''+@table+N''_GovID'';
            IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@object AND name=@idx)
            BEGIN
                SET @sql=N''CREATE NONCLUSTERED INDEX ''+QUOTENAME(@idx)+N'' ON ''+@full+N''([Gov_ID]);'';
                EXEC sys.sp_executesql @sql;
            END;
            SET @idx=N''IX_''+@table+N''_KVK_NO'';
            IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@object AND name=@idx)
            BEGIN
                SET @sql=N''CREATE NONCLUSTERED INDEX ''+QUOTENAME(@idx)+N'' ON ''+@full+N''([KVK_NO]);'';
                EXEC sys.sp_executesql @sql;
            END;
            SET @sql=N''UPDATE STATISTICS ''+@full+N'' WITH FULLSCAN;'';
            EXEC sys.sp_executesql @sql;
            UPDATE dbo.MaintenanceKvkWork SET CompletedGeneration=@due,CompletedUTC=SYSUTCDATETIME(),
                LastErrorNumber=NULL,State=CASE WHEN DueGeneration=@due THEN ''complete'' ELSE ''pending'' END
              WHERE KVKNo=@kvk AND ClaimID=@ClaimID AND ClaimedGeneration=@due AND State=''running'';
            IF @@ROWCOUNT<>1 THROW 51964,''KVK maintenance completion claim changed.'',1;
        END TRY
        BEGIN CATCH
            DECLARE @error int=ERROR_NUMBER();
            BEGIN TRY
                UPDATE dbo.MaintenanceKvkWork SET State=''failed'',LastErrorNumber=@error,
                    FirstErrorNumber=COALESCE(FirstErrorNumber,@error),
                    FirstErrorUTC=COALESCE(FirstErrorUTC,SYSUTCDATETIME())
                  WHERE KVKNo=@kvk AND ClaimID=@ClaimID AND State=''running'';
            END TRY
            BEGIN CATCH
                -- Preserve first failure; running remains uncertain if evidence fails.
            END CATCH;
            THROW;
        END CATCH;
    END;
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceKvkWork
        WHERE DueGeneration<=@Generation AND CompletedGeneration<DueGeneration)
        SET @AllDone=1;
END;';
-- dbo.usp_MaintenancePlayerReport
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenancePlayerReport
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Direct calls must obey the same session boundary as the worker.
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51962,''Maintenance child requires its own autocommit session.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:TargetPublication:DeltaPreprocessing'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance delta guard required.'',1;
    IF APPLOCK_MODE(''public'',''K98:post-import-stats:v1'',''Session'')<>''Exclusive''
       OR APPLOCK_MODE(''public'',''k98-legacy-output-snapshot'',''Session'')<>''Exclusive''
        THROW 51961, ''Exact maintenance worker ownership required.'', 1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:maintenance-schema:v1'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance schema guard required.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:StatsForUpload:Publish'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance player publication guard required.'',1;
    UPDATE STATISTICS dbo.STATS_FOR_UPLOAD WITH FULLSCAN;
END;';
-- dbo.usp_MaintenancePostImport
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_MaintenancePostImport
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Direct calls must obey the same session boundary as the worker.
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51962,''Maintenance child requires its own autocommit session.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:StatsForUpload:Publish'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance player publication guard required.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:TargetPublication:DeltaPreprocessing'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance delta guard required.'',1;
    IF APPLOCK_MODE(''public'',''K98:post-import-stats:v1'',''Session'')<>''Exclusive''
       OR APPLOCK_MODE(''public'',''k98-legacy-output-snapshot'',''Session'')<>''Exclusive''
        THROW 51961, ''Exact maintenance worker ownership required.'', 1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:maintenance-schema:v1'',''Session''),''NoLock'')<>''Exclusive''
        THROW 51962,''Maintenance schema guard required.'',1;
    EXEC sys.sp_updatestats;
END;';
-- dbo.usp_MarkLogBackupTriggerProcessed
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[usp_MarkLogBackupTriggerProcessed]
	@TriggerID [int],
	@ProcessedBy [nvarchar](128),
	@LogUsedPctAfter [decimal](5, 2) = NULL,
	@BackupResult [nvarchar](max) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    -- A drained, coordinated D4 transition preserves the historical queue.
    -- Observe only this fixed identity under dbo; caller metadata DENYs cannot
    -- disguise the new deployment. The queue operation retains caller context.
    DECLARE @P02LedgerPresent bit;
    EXEC dbo.usp_P02LegacyQueueState @LedgerPresent=@P02LedgerPresent OUTPUT;
    IF @P02LedgerPresent IS NULL
        THROW 52942, ''Legacy backup queue deployment state is unavailable; no queue work was performed.'', 1;
    IF @P02LedgerPresent = 1
        THROW 52941, ''Legacy backup queue is held by P02 maintenance; historical rows must be preserved.'', 1;

    
    UPDATE dbo.LogBackupTriggerQueue
    SET 
        Processed = 1,
        ProcessedTime = SYSDATETIME(),
        ProcessedBy = @ProcessedBy,
        LogUsedPctAfter = @LogUsedPctAfter,
        BackupResult = @BackupResult
    WHERE ID = @TriggerID
      AND Processed = 0;
    
    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR(''Trigger ID %d not found or already processed.'', 16, 1, @TriggerID);
        RETURN -1;
    END
    
    RETURN 0;
END';
-- dbo.usp_RunMaintenance
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_RunMaintenance @Kind varchar(24)
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    -- The actual worker owns both guards; no journal-session/age lease can
    -- outlive it or admit another worker while this one still executes.
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2 THROW 51962, ''Maintenance requires its own autocommit session.'', 1;
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork WHERE Kind=@Kind)
        THROW 51962, ''Unknown maintenance kind.'', 1;
    DECLARE @r int, @released int, @claim uniqueidentifier=NEWID(),
            @generation bigint, @ks4due bigint, @ks4done bigint, @includeKS4 bit, @state varchar(12), @log decimal(9,4),
            @resource nvarchar(255)=N''K98:post-import-stats:v1'',
            @snapshot bit=0, @schema bit=0, @delta bit=0, @player bit=0, @owned bit=0,
            @cfgrows bigint,@cfgcompleted bigint,@cfgbatch int,@cfgscan int,
            @cfglarge bigint,@cfglargedone bigint,@pendingRows bigint,@largeDue bit,@kvkDone bit=1,
            @dashdue bigint,@dashdone bigint,@sumdue bigint,@sumdone bigint,@dashboard bit,@summary bit;
    BEGIN TRY
        EXEC @r=sys.sp_getapplock @Resource=@resource,
            @LockMode=''Exclusive'',@LockOwner=''Session'',@LockTimeout=0;
        IF @r<0 RETURN;
        SET @owned=1;
        -- A free exact session guard proves physical absence, not outcome.
        IF @Kind=''kvk_output''
            UPDATE dbo.MaintenanceKvkWork SET State=''unknown'' WHERE State=''running'';
        UPDATE dbo.MaintenanceWork SET State=''unknown''
          WHERE Kind=@Kind AND State=''running'';
        SELECT @generation=DueGeneration,@state=State,@ks4due=KS4DueGeneration,@ks4done=KS4CompletedGeneration,
            @dashdue=DashboardDueGeneration,@dashdone=DashboardCompletedGeneration,
            @sumdue=SummaryDueGeneration,@sumdone=SummaryCompletedGeneration
          FROM dbo.MaintenanceWork WHERE Kind=@Kind;
        IF @state=''pending''
        BEGIN
            EXEC @r=sys.sp_getapplock @Resource=N''k98-legacy-output-snapshot'',
                @LockMode=''Exclusive'',@LockOwner=''Session'',@LockTimeout=0;
            IF @r>=0
            BEGIN
                SET @snapshot=1;
                EXEC @r=sys.sp_getapplock @Resource=N''K98:TargetPublication:DeltaPreprocessing'',
                    @LockMode=''Exclusive'',@LockOwner=''Session'',@LockTimeout=0;
                IF @r>=0 SET @delta=1;
                IF @delta=1
                BEGIN
                    EXEC @r=sys.sp_getapplock @Resource=N''K98:StatsForUpload:Publish'',
                        @LockMode=''Exclusive'',@LockOwner=''Session'',@LockTimeout=0;
                    IF @r>=0 SET @player=1;
                END;
                IF @player=1
                BEGIN
                    EXEC @r=sys.sp_getapplock @Resource=N''K98:maintenance-schema:v1'',
                        @LockMode=''Exclusive'',@LockOwner=''Session'',@LockTimeout=0;
                    IF @r>=0 SET @schema=1;
                END;
                -- Preserve the existing log headroom gate. Missing evidence
                -- defers optional work; it never creates business replay authority.
                SELECT @log=used_log_space_in_percent FROM sys.dm_db_log_space_usage;
                IF @delta=1 AND @schema=1 AND @log IS NOT NULL AND @log<70
                BEGIN
                    IF @Kind=''configuration''
                    BEGIN
                        SELECT @generation=DueGeneration FROM dbo.MaintenanceWork WHERE Kind=@Kind;
                        SELECT @cfgrows=DueRows,@cfgcompleted=CompletedRows,@cfgbatch=LastBatchRows,
                            @cfgscan=LastScan,@cfglarge=LargeBatchGeneration,@cfglargedone=CompletedLargeBatchGeneration
                          FROM dbo.MaintenanceConfigurationWork WHERE ID=1;
                        IF @cfgrows IS NULL THROW 51962,''Configuration summary missing.'',1;
                        SET @pendingRows=@cfgrows-@cfgcompleted;
                        IF @pendingRows<=0 OR @cfgbatch>@pendingRows THROW 51962,''Configuration maintenance summary does not match pending work.'',1;
                        SET @largeDue=CASE WHEN @cfglarge>@cfglargedone THEN 1 ELSE 0 END;
                    END;
                    UPDATE dbo.MaintenanceWork SET State=''running'',ClaimID=@claim,
                        ClaimedGeneration=@generation,StartedUTC=SYSUTCDATETIME()
                      WHERE Kind=@Kind AND State=''pending'';
                    -- Fixed dispatch only. Later D3 slices add their real children.
                    SET @includeKS4=CASE WHEN @ks4due>@ks4done THEN 1 ELSE 0 END;
                    IF @Kind=''import'' EXEC dbo.usp_MaintenanceImport @IncludeKS4=@includeKS4;
                    ELSE IF @Kind=''configuration'' EXEC dbo.usp_MaintenanceConfiguration
                        @RowsProcessed=@pendingRows,@LastBatchRows=@cfgbatch,@NewMaxScan=@cfgscan,
                        @LargeBatchDue=@largeDue,@Generation=@generation;
                    ELSE IF @Kind=''player_report'' EXEC dbo.usp_MaintenancePlayerReport;
                    ELSE IF @Kind=''kvk_output'' EXEC dbo.usp_MaintenanceKvkOutput
                        @Generation=@generation,@ClaimID=@claim,@AllDone=@kvkDone OUTPUT;
                    ELSE IF @Kind=''final_stats''
                    BEGIN
                        SET @dashboard=CASE WHEN @dashdue>@dashdone THEN 1 ELSE 0 END;
                        SET @summary=CASE WHEN @sumdue>@sumdone THEN 1 ELSE 0 END;
                        EXEC dbo.usp_MaintenanceFinalStats @Dashboard=@dashboard,@Summary=@summary,
                            @Generation=@generation,@ClaimID=@claim;
                    END;
                    ELSE IF @Kind=''post_import''  EXEC dbo.usp_MaintenancePostImport;
                    ELSE THROW 51963, ''Maintenance child is not installed.'', 1;
                    IF @Kind=''configuration''
                    BEGIN
                        BEGIN TRANSACTION;
                        UPDATE dbo.MaintenanceConfigurationWork SET CompletedRows=@cfgrows,
                            CompletedLargeBatchGeneration=@cfglarge WHERE ID=1;
                        IF @@ROWCOUNT<>1 THROW 51964,''Configuration summary changed.'',1;
                    END;
                    UPDATE dbo.MaintenanceWork SET CompletedGeneration=CASE WHEN @kvkDone=1 THEN @generation ELSE CompletedGeneration END,
                        KS4CompletedGeneration=@ks4due,
                        DashboardCompletedGeneration=@dashdue,SummaryCompletedGeneration=@sumdue,
                        CompletedUTC=SYSUTCDATETIME(),LastErrorNumber=NULL,
                        State=CASE WHEN DueGeneration=@generation AND @kvkDone=1 THEN ''complete'' ELSE ''pending'' END
                      WHERE Kind=@Kind AND ClaimID=@claim AND State=''running''
                        AND ClaimedGeneration=@generation;
                    IF @@ROWCOUNT<>1 THROW 51964, ''Maintenance claim changed.'', 1;
                    IF @Kind=''configuration'' COMMIT TRANSACTION;
                END;
            END;
        END;
        IF @schema=1
        BEGIN
            EXEC @released=sys.sp_releaseapplock @Resource=N''K98:maintenance-schema:v1'',@LockOwner=''Session'';
            IF @released<0 THROW 51965,''Maintenance schema release not acknowledged.'',1;
            SET @schema=0;
        END;
        IF @player=1
        BEGIN
            EXEC @released=sys.sp_releaseapplock @Resource=N''K98:StatsForUpload:Publish'',@LockOwner=''Session'';
            IF @released<0 THROW 51965,''Maintenance player publication release not acknowledged.'',1;
            SET @player=0;
        END;
        IF @delta=1
        BEGIN
            EXEC @released=sys.sp_releaseapplock @Resource=N''K98:TargetPublication:DeltaPreprocessing'',@LockOwner=''Session'';
            IF @released<0 THROW 51965,''Maintenance delta release not acknowledged.'',1;
            SET @delta=0;
        END;
        IF @snapshot=1
        BEGIN
            EXEC @released=sys.sp_releaseapplock @Resource=N''k98-legacy-output-snapshot'',@LockOwner=''Session'';
            IF @released<0 THROW 51965, ''Maintenance snapshot release not acknowledged.'', 1;
            SET @snapshot=0;
        END;
        EXEC @released=sys.sp_releaseapplock @Resource=@resource,@LockOwner=''Session'';
        IF @released<0 THROW 51965, ''Maintenance release not acknowledged.'', 1;
        SET @owned=0;
    END TRY
    BEGIN CATCH
        DECLARE @error int=ERROR_NUMBER();
        BEGIN TRY
            IF XACT_STATE()<>0 ROLLBACK; -- only the worker-owned short acknowledgement transaction
        END TRY
        BEGIN CATCH
            -- Preserve the first child/acknowledgement failure. The caller must
            -- still establish physical rollback/release before returning a pool handle.
        END CATCH;
        -- Keep the first failure separate from current state. Transport loss can
        -- prevent this update: running then remains unknown until inspected.
        BEGIN TRY
            UPDATE dbo.MaintenanceWork SET State=''failed'',LastErrorNumber=@error,
                FirstErrorNumber=COALESCE(FirstErrorNumber,@error),
                FirstErrorUTC=COALESCE(FirstErrorUTC,SYSUTCDATETIME())
              WHERE Kind=@Kind AND ClaimID=@claim AND State=''running'';
        END TRY
        BEGIN CATCH
            -- Failed evidence persistence leaves the original running claim.
            -- Preserve the child error below; never manufacture completion.
        END CATCH;
        -- The caller must explicitly acknowledge session release before returning
        -- this connection to an ODBC pool; close alone may retain these guards.
        -- Do not mask the original SQL failure with an attempted second release.
        THROW;
    END CATCH;
END;';
-- dbo.usp_S11CompleteStatsReportsCore
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_S11CompleteStatsReportsCore
    @CompletedFileName nvarchar(260),
    @ExportPreparationID uniqueidentifier = NULL,
    @actual_param1 float = NULL,
    @actual_param2 nvarchar(100) = NULL,
    @rowsKS5 int = 0,
    @rowsKS4 int = 0,
    @StartTime datetime = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;
    IF @@TRANCOUNT <> 0 THROW 51961, ''Reporting requires an unowned transaction.'', 1;
    DECLARE @CompletedStage tinyint=0;
    DECLARE @PhaseBStart datetime2=SYSUTCDATETIME(), @StepStart datetime2,
        @StepEnd datetime2, @StepDuration int, @CurrentLogUsedPct decimal(5,2)=NULL;
    DECLARE @CurrentAuditPhase NVARCHAR(64) = N''update_all2_start'';
    DECLARE @UpdateAll2PhaseAudit TABLE (
        SequenceNo INT IDENTITY(1,1) NOT NULL,
        PhaseName NVARCHAR(64) NOT NULL,
        PhaseStatus NVARCHAR(32) NOT NULL,
        StartedAtUtc DATETIME2(3) NOT NULL,
        CompletedAtUtc DATETIME2(3) NULL,
        DurationMs INT NULL,
        RowsIn INT NULL,
        RowsOut INT NULL,
        DetailsJson NVARCHAR(MAX) NULL,
        ErrorType NVARCHAR(128) NULL,
        ErrorText NVARCHAR(2000) NULL
    );

    BEGIN TRY

        BEGIN TRANSACTION;
        EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        IF @ExportPreparationID IS NOT NULL
            SELECT @CompletedStage=CompletedStage, @actual_param1=KingdomRank,
                @actual_param2=KingdomSeed, @rowsKS5=RowsKS5, @rowsKS4=RowsKS4,
                @StartTime=ImportStartedUTC
            FROM dbo.StatsImportReportContinuation WITH (UPDLOCK,HOLDLOCK)
            WHERE PreparationID=@ExportPreparationID;
        COMMIT;
        IF @CompletedStage=3 RETURN;
        -- One display-name list for this report batch; metrics retain original grouping.
        CREATE TABLE #P02ReportNames (
            GovernorID bigint NOT NULL PRIMARY KEY,
            GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS NOT NULL
        );
        INSERT #P02ReportNames SELECT GovernorID,GovernorName FROM dbo.v_ReportGovernorNames;

        SET @StartTime=COALESCE(@StartTime,GETDATE());

        -- *** NEW: Check log space at Phase B start ***
        SET @CurrentLogUsedPct = NULL;
        DECLARE @LogReuse NVARCHAR(60) = NULL;

        BEGIN TRY
            SELECT @CurrentLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC if DMV not available
            BEGIN TRY
                CREATE TABLE #LogSpace (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpace EXEC(''DBCC SQLPERF(LOGSPACE)'');
                SELECT @CurrentLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpace 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpace;
            END TRY
            BEGIN CATCH
                SET @CurrentLogUsedPct = NULL;
            END CATCH
        END CATCH

        BEGIN TRY
            SELECT @LogReuse = log_reuse_wait_desc
            FROM sys.databases
            WHERE name = DB_NAME();
        END TRY
        BEGIN CATCH
            SET @LogReuse = NULL;
        END CATCH

        PRINT ''Phase B Start - Log Usage: '' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), ''unknown'') + 
              ''%, Reuse Wait: '' + ISNULL(@LogReuse, ''unknown'');

        -- If log usage is high (>70%), force checkpoint before continuing
        IF @CurrentLogUsedPct IS NOT NULL AND @CurrentLogUsedPct > 70.0
        BEGIN
            PRINT ''Log usage elevated ('' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                  ''%); executing CHECKPOINT before Phase B operations...'';
            CHECKPOINT;
            
            -- Log this event for monitoring
            INSERT INTO dbo.ErrorAudit (ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo)
            VALUES (
                GETDATE(), ''UPDATE_ALL2'', 0, 
                ''Elevated log usage detected at Phase B start'', 0,
                ''Log usage: '' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                ''%, Reuse wait: '' + ISNULL(@LogReuse, ''unknown'')
            );
        END

        IF @CompletedStage=0
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        -- Step 1: CREATE_THE_AVERAGES
        SET @CurrentAuditPhase = N''update_all2_create_averages'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.CREATE_THE_AVERAGES;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"CREATE_THE_AVERAGES"}'');
        PRINT ''CREATE_THE_AVERAGES: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        -- Step 2: Rebuild EXCEL_FOR_DASHBOARD
        SET @CurrentAuditPhase = N''update_all2_rebuild_excel_dashboard'';
        SET @StepStart = SYSUTCDATETIME();
        IF OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'',''U'') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        EXEC dbo.sp_Rebuild_ExcelForDashboard;
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"sp_Rebuild_ExcelForDashboard","target":"EXCEL_FOR_DASHBOARD"}'');
        PRINT ''sp_Rebuild_ExcelForDashboard: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        -- Step 3: CREATE_DASH2
        SET @CurrentAuditPhase = N''update_all2_create_dash2'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.CREATE_DASH2;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"CREATE_DASH2"}'');
        PRINT ''CREATE_DASH2: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        ----------------------------------------------------------------
        -- Step 4a: Refresh EXCEL_FOR_KVK table FIRST (lifted from SP_Stats_for_Upload)
        ----------------------------------------------------------------
        SET @StepStart = SYSUTCDATETIME();
        
        -- Determine which KVK and Scan to use (same logic as SP_Stats_for_Upload)
        DECLARE @LatestKVK_Upload INT;
        DECLARE @MaxScan_Upload INT = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4);
        DECLARE @MatchmakingScan_Upload INT;
        DECLARE @DraftScan_Upload INT;
        DECLARE @ScanToUse_Upload INT;

        SELECT TOP 1 @LatestKVK_Upload = KVKVersion
        FROM dbo.ProcConfig
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CAST(ConfigValue AS INT) <= @MaxScan_Upload
        ORDER BY KVKVersion DESC;

        IF @LatestKVK_Upload IS NOT NULL
        BEGIN
            SELECT
                @MatchmakingScan_Upload = MAX(CASE WHEN ConfigKey = ''MATCHMAKING_SCAN'' THEN TRY_CAST(ConfigValue AS INT) END),
                @DraftScan_Upload       = MAX(CASE WHEN ConfigKey = ''DRAFTSCAN''        THEN TRY_CAST(ConfigValue AS INT) END)
            FROM dbo.ProcConfig
            WHERE KVKVersion = @LatestKVK_Upload
              AND ConfigKey IN (''MATCHMAKING_SCAN'',''DRAFTSCAN'');

            -- Decide which scan to use
            SET @ScanToUse_Upload = NULL;
            IF @MatchmakingScan_Upload IS NOT NULL AND @MaxScan_Upload >= @MatchmakingScan_Upload
                SET @ScanToUse_Upload = @MatchmakingScan_Upload;
            ELSE IF @DraftScan_Upload IS NOT NULL AND @MaxScan_Upload >= @DraftScan_Upload
                SET @ScanToUse_Upload = @DraftScan_Upload;

            IF @ScanToUse_Upload IS NOT NULL
            BEGIN
                PRINT ''Step 4a: Refreshing EXCEL_FOR_KVK_'' + CAST(@LatestKVK_Upload AS VARCHAR(10)) 
                    + '' with ScanOrder='' + CAST(@ScanToUse_Upload AS VARCHAR(10)) + ''...'';
                
                -- ✅ LIFT: Call sp_ExcelOutput_ByKVK directly here
                SET @CurrentAuditPhase = N''update_all2_excel_for_kvk_refresh'';
                SET @StepStart = SYSUTCDATETIME();
                EXEC dbo.sp_ExcelOutput_ByKVK @KVK = @LatestKVK_Upload, @Scan = @ScanToUse_Upload;
                
                SET @StepEnd = SYSUTCDATETIME();
                SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
                INSERT INTO @UpdateAll2PhaseAudit
                    (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
                VALUES
                    (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
                     N''{"procedure":"sp_ExcelOutput_ByKVK","kvk":'' + CAST(@LatestKVK_Upload AS NVARCHAR(20)) +
                     N'',"scan":'' + CAST(@ScanToUse_Upload AS NVARCHAR(20)) + N''}'');
                PRINT ''sp_ExcelOutput_ByKVK: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

            END
        END

            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=1, ReportKVK=@LatestKVK_Upload, ReportScan=@ScanToUse_Upload,
                    PrefixCompletedUTC=SYSUTCDATETIME(), Version=Version+1
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=0;
                IF @@ROWCOUNT<>1 THROW 51961, ''Reporting prefix receipt changed.'', 1;
            END;
            EXEC dbo.usp_MaintenanceDue @Kind=''final_stats'',@FinalDashboard=1;
            COMMIT;
            SET @CompletedStage=1;
        END;

        IF @CompletedStage=1
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
            IF @ExportPreparationID IS NOT NULL
                SELECT @LatestKVK_Upload=ReportKVK, @ScanToUse_Upload=ReportScan
                FROM dbo.StatsImportReportContinuation WITH (UPDLOCK,HOLDLOCK)
                WHERE PreparationID=@ExportPreparationID;
            SET @CurrentAuditPhase=N''update_all2_stats_for_upload'';
            SET @StepStart=SYSUTCDATETIME();
            IF @LatestKVK_Upload IS NOT NULL AND @ScanToUse_Upload IS NOT NULL
                EXEC dbo.SP_Stats_for_Upload;
            SET @StepEnd=SYSUTCDATETIME();
            INSERT INTO @UpdateAll2PhaseAudit
                (PhaseName,PhaseStatus,StartedAtUtc,CompletedAtUtc,DurationMs,DetailsJson)
            VALUES (@CurrentAuditPhase,
                CASE WHEN @LatestKVK_Upload IS NOT NULL AND @ScanToUse_Upload IS NOT NULL
                    THEN N''completed'' ELSE N''skipped'' END,
                @StepStart,@StepEnd,DATEDIFF(millisecond,@StepStart,@StepEnd),
                N''{"procedure":"SP_Stats_for_Upload"}'');
            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=2, UploadCompletedUTC=SYSUTCDATETIME(), Version=Version+1
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=1;
                IF @@ROWCOUNT<>1 THROW 51961, ''Upload report receipt changed.'', 1;
            END;
            COMMIT;
            SET @CompletedStage=2;
        END;

        IF @CompletedStage=2
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        ----------------------------------------------------------------
        -- ⚡⚡⚡ OPTIMIZED INSERT INTO ALL_STATS_FOR_DASHBAORD ⚡⚡⚡
        ----------------------------------------------------------------
        SET @CurrentAuditPhase = N''update_all2_all_stats_dashboard'';
        SET @StepStart = SYSUTCDATETIME();
        
        TRUNCATE TABLE dbo.ALL_STATS_FOR_DASHBAORD;

        INSERT INTO dbo.ALL_STATS_FOR_DASHBAORD WITH (TABLOCK) (
            [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
            [Starting Power], [Power_Delta], [Civilization], [KvKPlayed],
            [MostKvKKill], [MostKvKDead], [MostKvKHeal],
            [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon],
            [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct],
            [Starting T4&T5_KILLS], [T4_KILLS], [T5_KILLS], [T4&T5_Kills],
            [KILLS_OUTSIDE_KVK], [Kill Target], [% of Kill target],
            [Starting Deads], Deads_Delta, [DEADS_OUTSIDE_KVK],
            [T4_Deads], [T5_Deads], [Dead Target], [% of Dead Target], [% of Dead_Target],
            [Zeroed], [DKP_SCORE], [DKP Target], [% of DKP Target],
            HelpsDelta, RSS_Assist_Delta, RSS_Gathered_Delta,
            [Pass 4 Kills], [Pass 6 Kills], [Pass 7 Kills], [Pass 8 Kills],
            [Pass 4 Deads], [Pass 6 Deads], [Pass 7 Deads], [Pass 8 Deads],
            [Starting HealedTroops], [HealedTroopsDelta],
            [Starting KillPoints], [KillPointsDelta],
            [RangedPoints], [RangedPointsDelta],
            [AutarchTimes],
            [Max_PreKvk_Points], [Max_HonorPoints],
            [PreKvk_Rank], [Honor_Rank], [KVK_NO]
        )
        SELECT
            ed.[Rank], 
            ed.[KVK_RANK], 
            ed.[Gov_ID],
            RTRIM(COALESCE(ed.[Governor_Name], '''')) AS [Governor_Name],
            
            -- Numeric columns with COALESCE (handles NULL efficiently)
            COALESCE(ed.[Starting Power], 0),
            COALESCE(ed.[Power_Delta], 0),
            ed.[Civilization],  -- NULL allowed
            COALESCE(ed.[KvKPlayed], 0),
            
            COALESCE(ed.[MostKvKKill], 0),
            COALESCE(ed.[MostKvKDead], 0),
            COALESCE(ed.[MostKvKHeal], 0),
            COALESCE(ed.[Acclaim], 0),
            COALESCE(ed.[HighestAcclaim], 0),
            COALESCE(ed.[AOOJoined], 0),
            COALESCE(ed.[AOOWon], 0),
            COALESCE(ed.[AOOAvgKill], 0),
            COALESCE(ed.[AOOAvgDead], 0),
            COALESCE(ed.[AOOAvgHeal], 0),
            ed.[Conduct],
            
            COALESCE(ed.[Starting_T4&T5_KILLS], 0),
            COALESCE(ed.[T4_KILLS], 0),
            COALESCE(ed.[T5_KILLS], 0),
            COALESCE(ed.[T4&T5_Kills], 0),
            COALESCE(ed.[KILLS_OUTSIDE_KVK], 0),
            COALESCE(ed.[Kill Target], 0),
            COALESCE(ed.[% of Kill Target], 0),
            
            COALESCE(ed.[Starting_Deads], 0),
            COALESCE(ed.[Deads_Delta], 0),
            COALESCE(ed.[DEADS_OUTSIDE_KVK], 0),
            COALESCE(ed.[T4_Deads], 0),
            COALESCE(ed.[T5_Deads], 0),
            COALESCE(ed.[Dead_Target], 0),
            COALESCE(ed.[% of Dead Target], 0),
            COALESCE(ed.[% of Dead Target], 0),  -- Duplicate column (fix in schema later)
            
            COALESCE(ed.[Zeroed], 0),
            COALESCE(ed.[DKP_SCORE], 0),
            COALESCE(ed.[DKP Target], 0),
            COALESCE(ed.[% of DKP Target], 0),
            
            COALESCE(ed.[HelpsDelta], 0),
            COALESCE(ed.[RSS_Assist_Delta], 0),
            COALESCE(ed.[RSS_Gathered_Delta], 0),
            
            COALESCE(ed.[Pass 4 Kills], 0),
            COALESCE(ed.[Pass 6 Kills], 0),
            COALESCE(ed.[Pass 7 Kills], 0),
            COALESCE(ed.[Pass 8 Kills], 0),
            COALESCE(ed.[Pass 4 Deads], 0),
            COALESCE(ed.[Pass 6 Deads], 0),
            COALESCE(ed.[Pass 7 Deads], 0),
            COALESCE(ed.[Pass 8 Deads], 0),
            
            COALESCE(ed.[Starting_HealedTroops], 0),
            COALESCE(ed.[HealedTroopsDelta], 0),
            COALESCE(ed.[Starting_KillPoints], 0),
            COALESCE(ed.[KillPointsDelta], 0),
            COALESCE(ed.[RangedPoints], 0),
            COALESCE(ed.[RangedPointsDelta], 0),
            COALESCE(ed.[AutarchTimes], 0),
            
            COALESCE(ed.[Max_PreKvk_Points], 0),
            COALESCE(ed.[Max_HonorPoints], 0),
            COALESCE(ed.[PreKvk_Rank], 0),
            COALESCE(ed.[Honor_Rank], 0),
            COALESCE(ed.[KVK_NO], 0)
        FROM dbo.EXCEL_FOR_DASHBOARD AS ed
        WHERE ed.Gov_ID <> 12025033
        OPTION (RECOMPILE);  -- Fresh execution plan with current statistics
        
        DECLARE @RowsInserted INT = @@ROWCOUNT;
        
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"ALL_STATS_FOR_DASHBAORD"}'');
        PRINT ''ALL_STATS_FOR_DASHBAORD insert: '' + CAST(@RowsInserted AS VARCHAR(10)) + '' rows, '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';
        
        ----------------------------------------------------------------
        -- Continue with POWER_BY_MONTH and remaining steps
        ----------------------------------------------------------------
        SET @CurrentAuditPhase = N''update_all2_power_by_month'';
        SET @StepStart = SYSUTCDATETIME();
        
        TRUNCATE TABLE dbo.POWER_BY_MONTH;

        INSERT INTO dbo.POWER_BY_MONTH (
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS], 
            DEADS, [MONTH], HealedTroops, RangedPoints
        )
        SELECT 
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
            DEADS, [MONTH], HealedTroops, RangedPoints
        FROM (
            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.KingdomScanData4
            WHERE GovernorID NOT IN (0, 12025033)
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

            UNION ALL

            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.THE_AVERAGES
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)
        ) AS T
        ORDER BY GovernorID, [MONTH];
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"target":"POWER_BY_MONTH"}'');
        PRINT ''POWER_BY_MONTH: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        SET @CurrentAuditPhase = N''update_all2_refresh_inactive_governors'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.sp_RefreshInactiveGovernors;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"sp_RefreshInactiveGovernors"}'');

        DECLARE @MAXDATE DATETIME = (SELECT TOP 1 ScanDate FROM dbo.KingdomScanData4 ORDER BY ScanDate DESC);

        SET @CurrentAuditPhase = N''update_all2_ks_summary_insert'';
        SET @StepStart = SYSUTCDATETIME();
        INSERT INTO dbo.KS (
            KINGDOM_POWER, Governors, KP, [KILL], [DEAD], [CH25], 
            HealedTroops, RangedPoints, [Last Update], KINGDOM_RANK, KINGDOM_SEED
        )
        SELECT
            SUM(CAST([Power] AS BIGINT)), COUNT(GovernorID), SUM([KillPoints]),
            SUM([TOTAL_KILLS]), SUM([DEADS]),
            CAST(SUM(CASE WHEN [City Hall] = 25 THEN 1 ELSE 0 END) AS INT),
            SUM(ISNULL([HealedTroops], 0)), SUM(ISNULL([RangedPoints], 0)),
            @MAXDATE, @actual_param1, @actual_param2
        FROM dbo.KingdomScanData4
        WHERE ScanDate = @MAXDATE;
        SET @RowsInserted = @@ROWCOUNT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"KS"}'');

        SET @CurrentAuditPhase = N''update_all2_summary_proc'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.SUMMARY_PROC;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"SUMMARY_PROC"}'');

        SET @CurrentAuditPhase = N''update_all2_governor_names'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.GOVERNOR_NAMES_PROC;
        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''CompletedReports'';

        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"GOVERNOR_NAMES_PROC"}'');

        SET @CurrentAuditPhase = N''update_all2_scan_list'';
        SET @StepStart = SYSUTCDATETIME();
        TRUNCATE TABLE dbo.SCAN_LIST;

        INSERT INTO dbo.SCAN_LIST (SCANORDER, ScanDate)
        SELECT SCANORDER, ScanDate
        FROM dbo.KingdomScanData4
        GROUP BY SCANORDER, ScanDate;
        SET @RowsInserted = @@ROWCOUNT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"SCAN_LIST"}'');

        ----------------------------------------------------------------
        -- *** NEW: Phase B Completion - Log Management ***
        ----------------------------------------------------------------
        
        -- Optional upkeep and backup dispatch belong to the owned maintenance path.
        DECLARE @FinalLogUsedPct DECIMAL(5,2) = NULL;
        DECLARE @LogBackupTriggered BIT = 0;

        DECLARE @EndTime DATETIME = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
        DECLARE @PhaseBDuration INT = DATEDIFF(MILLISECOND, @PhaseBStart, SYSUTCDATETIME());

        PRINT ''========================================'';
        PRINT ''Phase B Total: '' + CAST(@PhaseBDuration AS VARCHAR(10)) + ''ms'';
        PRINT ''Log Usage: Initial='' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), ''unknown'') + 
              ''%, Final='' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), ''unknown'') + ''%'';
        PRINT ''Log Backup Triggered: '' + CASE WHEN @LogBackupTriggered = 1 THEN ''Yes'' ELSE ''No (maintenance deferred)'' END;
        PRINT ''========================================'';

        DECLARE @S11CompletionCounters TABLE (LastRunCounter int NOT NULL);
        INSERT INTO dbo.SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
        OUTPUT inserted.LastRunCounter INTO @S11CompletionCounters (LastRunCounter)
        VALUES (
            ''UPDATE_ALL2'', ''Complete'', @EndTime,
            ISNULL((SELECT MAX(LastRunCounter) FROM dbo.SP_TaskStatus WITH (UPDLOCK,HOLDLOCK) WHERE TaskName=''UPDATE_ALL2''), 0) + 1,
            @DurationSeconds
        );

        IF @ExportPreparationID IS NOT NULL
        BEGIN
            UPDATE dbo.StatsImportExecution SET State=''completed'',
                LastRunCounter=(SELECT LastRunCounter FROM @S11CompletionCounters),
                UpdatedUTC=SYSUTCDATETIME(), Version=Version+1
            WHERE PreparationID=@ExportPreparationID AND CompletedFileName=@CompletedFileName AND State IN (''import_committed'',''partial'') AND Resolution IS NULL;
            IF @@ROWCOUNT <> 1 THROW 51960, ''Missing exact Phase B execution receipt.'', 1;
        END;
            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=3, SummaryCompletedUTC=SYSUTCDATETIME(), Version=Version+1,
                    RecoveryState=CASE WHEN RecoveryActionID IS NOT NULL THEN ''completed'' END
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=2;
                IF @@ROWCOUNT<>1 THROW 51961, ''Summary receipt changed.'', 1;
            END;
            INSERT INTO dbo.Update_ALL_Complete (CompletionTime) VALUES (GETDATE());
            EXEC dbo.usp_MaintenanceDue @Kind=''final_stats'',@FinalSummary=1;
            COMMIT;
        END;

        SELECT
            PhaseName,
            PhaseStatus,
            StartedAtUtc,
            CompletedAtUtc,
            DurationMs,
            RowsIn,
            RowsOut,
            DetailsJson,
            ErrorType,
            ErrorText
        FROM @UpdateAll2PhaseAudit
        ORDER BY SequenceNo;

        SELECT 
            @rowsKS5 AS RowsInsertedKS5,
            @rowsKS4 AS RowsInsertedKS4,
            @DurationSeconds AS DurationSeconds,
            @PhaseBDuration AS PhaseBDurationMS,
            @CurrentLogUsedPct AS LogUsedPctBefore,
            @FinalLogUsedPct AS LogUsedPctAfter,
            @LogBackupTriggered AS LogBackupTriggered,
            ''SUCCESS'' AS Status;

    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;';
-- dbo.usp_S11ValidateStatsReportStage
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_S11ValidateStatsReportStage
    @PreparationID uniqueidentifier,
    @CompletedFileName nvarchar(260)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>1 OR XACT_STATE()<>1
        THROW 51961, ''One owned reporting transaction required.'', 1;
    DECLARE @LockResult int;
    EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK @LockTimeout=0,@LockResult=@LockResult OUTPUT;
    IF @LockResult<0 THROW 51961, ''Scan writer is active; reporting remains held.'', 1;
    EXEC @LockResult=sys.sp_getapplock @Resource=N''K98:maintenance-schema:v1'',
        @LockMode=''Shared'',@LockOwner=''Transaction'',@LockTimeout=0;
    IF @LockResult<0 THROW 51966,''Report maintenance is active; reporting remains held.'',1;
    -- The non-coordinated legacy entry point still uses these same business
    -- calculations. It has no durable continuation and cannot adopt one.
    IF @PreparationID IS NULL RETURN;
    DECLARE @Resource nvarchar(255)=N''S11:stats-import:''+LOWER(CONVERT(nvarchar(36),@PreparationID));
    IF COALESCE(APPLOCK_MODE(N''public'',@Resource,N''Session''),N''NoLock'')<>N''Exclusive''
       OR COALESCE(APPLOCK_MODE(N''public'',N''k98-legacy-output-snapshot'',N''Session''),N''NoLock'')<>N''Exclusive''
        THROW 51961, ''Both independent producer session guards are required.'', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.StatsImportExecution e WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.StatsImportReportContinuation c WITH (UPDLOCK,HOLDLOCK) ON c.PreparationID=e.PreparationID
        JOIN dbo.ExportPreparation p WITH (UPDLOCK,HOLDLOCK) ON p.PreparationID=e.PreparationID
        JOIN dbo.ExportResource r WITH (UPDLOCK,HOLDLOCK) ON r.ActivePreparationID=p.PreparationID
        JOIN dbo.KS4_ImportFileClaim f WITH (HOLDLOCK) ON f.CompletedFileName COLLATE Latin1_General_100_BIN2=e.CompletedFileName
        WHERE e.PreparationID=@PreparationID AND e.CompletedFileName=@CompletedFileName
          AND e.Resolution IS NULL AND e.State IN (''import_committed'',''partial'',''completed'')
          AND e.ScanOrder=c.ScanOrder AND c.ContractVersion=1
          AND (e.State<>''completed'' OR c.CompletedStage=3)
          AND (c.CompletedStage<>3 OR e.State=''completed'')
          AND p.ConsumerKind=''scan_data'' AND p.State IN (''writing'',''committed'',''uncertain'')
          AND p.OwnerID=e.OwnerID AND p.Fence=e.Fence
          AND p.JobID IS NULL AND p.SpoolKey IS NULL AND p.GenerationJson IS NULL
          AND r.ResourceKey=''sql_snapshot:legacy_outputs'' AND r.OwnerID=p.OwnerID AND r.Fence=p.Fence
          AND r.ActiveJobID IS NULL AND r.ActiveOutputOperationID IS NULL
          AND f.FileDigest=c.InputDigest AND f.ClaimStatus IN (''imported'',''archived'')
          AND c.LatestScanOrder=(SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4 WITH (HOLDLOCK))
          AND c.ConfigurationJson=(SELECT KVKVersion,ConfigKey,ConfigValue,LastUpdated
              FROM dbo.ProcConfig WITH (HOLDLOCK) ORDER BY KVKVersion,ConfigKey
              FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE Latin1_General_100_BIN2
          AND NOT EXISTS (SELECT 1 FROM dbo.ExportResource other WITH (HOLDLOCK)
              WHERE other.ActivePreparationID=p.PreparationID AND other.ResourceKey<>''sql_snapshot:legacy_outputs'')
    ) THROW 51961, ''Exact committed input, unchanged configuration and retained ownership required.'', 1;
END;';
-- dbo.usp_update_stats
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_update_stats @RequestID uniqueidentifier = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2 THROW 51962, ''Post-import maintenance requires autocommit.'', 1;
    EXEC dbo.usp_MaintenanceDue @Kind=''post_import'',@RequestID=@RequestID;
    EXEC dbo.usp_RunMaintenance @Kind=''import'';
    EXEC dbo.usp_RunMaintenance @Kind=''configuration'';
    EXEC dbo.usp_RunMaintenance @Kind=''player_report'';
    EXEC dbo.usp_RunMaintenance @Kind=''kvk_output'';
    EXEC dbo.usp_RunMaintenance @Kind=''final_stats'';
    EXEC dbo.usp_RunMaintenance @Kind=''post_import'';
    SELECT Kind,DueGeneration,CompletedGeneration,ClaimedGeneration,ClaimID,
        State,FirstErrorNumber,LastErrorNumber
      FROM dbo.MaintenanceWork WHERE Kind IN (''import'',''configuration'',''player_report'',''kvk_output'',''final_stats'',''post_import'');
END;';
IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 52981,'D4 release transaction escaped.',1;
