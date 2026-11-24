/*
MigrationId: 20261120_001_p02_catalogue_observer
Purpose: Install generation-bound catalogue observation over the retained D4 release
Author: Codex (local candidate; deployment separately authorised)
CreatedUtc: 2026-11-20
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Required
DataChange: No
DataSafetyPlan: Included
DataSafetyNotes: Release-owned drained transaction; no business rows, queue or publication replay. Precommit failure rolls back. Committed state is not reinstalled.
EstimatedRowsAffected: 0 business rows
*/
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>1 OR XACT_STATE()<>1
    THROW 51973,'Observer installation requires the release-owned transaction.',1;
IF DB_NAME()<>N'ROK_TRACKER'
    THROW 51973,'Exact observer installation database required.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory
    WHERE MigrationId=N'20261111_001_p02_d4_combined' AND Status='Applied'
      AND LOWER(ChecksumSha256)='57944777e50b7dc9200220cfcc2ce767edb22a2e0972e02bc2cd6f04e23e8171')
    THROW 51973,'Exact successful D4 predecessor receipt required.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'20261120_001_p02_catalogue_observer')
    THROW 51973,'Observer history already exists; reconcile without replay.',1;
IF DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') IS NULL
    THROW 51973,'Reviewed application role is missing.',1;

IF NOT EXISTS(SELECT 1 FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id
    JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE o.object_id=OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK','P')
      AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1
      AND m.execute_as_principal_id IS NULL
      AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo'
      AND LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10))),2))='97b4bc47a73277d20049558d33fdc623c84bc8f3a16779128d049d9fad29f918')
    THROW 51973,'Reviewed observer predecessor body differs: dbo.sp_ExcelOutput_ByKVK.',1;

IF NOT EXISTS(SELECT 1 FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id
    JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE o.object_id=OBJECT_ID(N'dbo.usp_RunMaintenance','P')
      AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1
      AND m.execute_as_principal_id IS NULL
      AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo'
      AND LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10))),2))='eb05004d539c1ae5fbb4d83685c6916dc7fefd29428788e5238ea75202327138')
    THROW 51973,'Reviewed observer predecessor body differs: dbo.usp_RunMaintenance.',1;

IF NOT EXISTS(SELECT 1 FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id
    JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE o.object_id=OBJECT_ID(N'dbo.usp_S11ValidateStatsReportStage','P')
      AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1
      AND m.execute_as_principal_id IS NULL
      AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo'
      AND LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10))),2))='8a0b6f7cdad350a08408e40c384771bff43e6a879ca9cc32aa967983e28af18d')
    THROW 51973,'Reviewed observer predecessor body differs: dbo.usp_S11ValidateStatsReportStage.',1;

IF OBJECT_ID(N'dbo.P02ObservationGeneration') IS NOT NULL THROW 51973,'Observer object already exists: dbo.P02ObservationGeneration.',1;

IF OBJECT_ID(N'dbo.usp_P02BeginCatalogueMutation') IS NOT NULL THROW 51973,'Observer object already exists: dbo.usp_P02BeginCatalogueMutation.',1;

IF OBJECT_ID(N'dbo.usp_P02EndCatalogueMutation') IS NOT NULL THROW 51973,'Observer object already exists: dbo.usp_P02EndCatalogueMutation.',1;

IF OBJECT_ID(N'dbo.usp_P02ReadObservationBoundary') IS NOT NULL THROW 51973,'Observer object already exists: dbo.usp_P02ReadObservationBoundary.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02CatalogueObservation') THROW 51973,'Observer trigger already exists: tr_P02CatalogueObservation.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02HeaderObservation') THROW 51973,'Observer trigger already exists: tr_P02HeaderObservation.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02KvkWorkObservation') THROW 51973,'Observer trigger already exists: tr_P02KvkWorkObservation.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02MaintenanceObservation') THROW 51973,'Observer trigger already exists: tr_P02MaintenanceObservation.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.KVKFinalReportHeader') AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER') THROW 51973,'Lifecycle ALTER predecessor differs.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.MaintenanceKvkWork') AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER') THROW 51973,'Lifecycle ALTER predecessor differs.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.MaintenanceWork') AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER') THROW 51973,'Lifecycle ALTER predecessor differs.',1;

-- Author: K98 programme. Candidate protocol; install only in the isolated lab.
CREATE SEQUENCE dbo.P02ObservationGeneration AS bigint
    START WITH 1 INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807
    NO CYCLE NO CACHE;



-- Consume the never-used starting value before an observer can be admitted.
DECLARE @bootstrap bigint=NEXT VALUE FOR dbo.P02ObservationGeneration;
IF @bootstrap<>1 THROW 51970,'Unexpected observation sequence bootstrap.',1;


EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_P02BeginCatalogueMutation
    @Owner varchar(11)=''Transaction''
AS
BEGIN
    SET NOCOUNT ON;
    IF @Owner NOT IN (''Session'',''Transaction'') OR @Owner IS NULL
        THROW 51970,''Unsupported catalogue mutation owner.'',1;
    IF @Owner=''Transaction'' AND (@@TRANCOUNT=0 OR XACT_STATE()<>1)
        THROW 51970,''A committable mutation transaction is required.'',1;
    IF @Owner=''Session'' AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2)
        THROW 51970,''Session mutation requires an owned autocommit worker.'',1;
    DECLARE @mode nvarchar(32)=APPLOCK_MODE(''public'',''K98:catalogue-mutation:v1'',@Owner);
    IF @mode IS NULL OR @mode NOT IN (''NoLock'',''Shared'')
        THROW 51970,''Unexpected catalogue marker ownership.'',1;
    -- Nested helpers inherit the marker; never add an unbalanced reference.
    IF @mode=''NoLock''
    BEGIN
        DECLARE @r int;
        EXEC @r=sys.sp_getapplock @Resource=N''K98:catalogue-mutation:v1'',
            @LockMode=''Shared'',@LockOwner=@Owner,@LockTimeout=0;
        IF @r IS NULL OR @r NOT IN (0,1)
            THROW 51970,''Catalogue mutation marker was not acknowledged.'',1;
    END;
    DECLARE @generation bigint=NEXT VALUE FOR dbo.P02ObservationGeneration;
    IF @generation<=1 THROW 51970,''Observation sequence was not bootstrapped.'',1;
END;
';

EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_P02EndCatalogueMutation
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51970,''Finish physical work before releasing the session marker.'',1;
    IF COALESCE(APPLOCK_MODE(''public'',''K98:catalogue-mutation:v1'',''Session''),''Unknown'')<>''Shared''
        THROW 51970,''Exact session mutation ownership required.'',1;
    DECLARE @r int;
    EXEC @r=sys.sp_releaseapplock @Resource=N''K98:catalogue-mutation:v1'',@LockOwner=''Session'';
    IF @r IS NULL OR @r<>0 OR
        COALESCE(APPLOCK_MODE(''public'',''K98:catalogue-mutation:v1'',''Session''),''Unknown'')<>''NoLock''
        THROW 51970,''Catalogue marker release was not acknowledged.'',1;
END;
';

EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_P02ReadObservationBoundary
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @transactionMode nvarchar(32)=N''NoLock'',@isolation smallint,
        @g1 bigint,@g2 bigint,@object1 int,@object2 int,@created1 datetime,@created2 datetime,
        @modified1 datetime,@modified2 datetime,@grantable smallint,@health nvarchar(max);
    -- APPLOCK_MODE(Transaction) raises 3918 in an actual zero-transaction session.
    IF @@TRANCOUNT>0
        SET @transactionMode=APPLOCK_MODE(''public'',''K98:catalogue-mutation:v1'',''Transaction'');
    SELECT @isolation=transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID;
    IF @@TRANCOUNT>1 OR XACT_STATE() NOT IN (0,1) OR @isolation<>2
       OR COALESCE(@transactionMode,N''Unknown'')<>N''NoLock''
       OR COALESCE(APPLOCK_MODE(''public'',''K98:catalogue-mutation:v1'',''Session''),N''Unknown'')<>N''NoLock''
        THROW 51971,''Observation requires an unmarked READ COMMITTED cursor.'',1;
    -- Check presence before touching module catalogues: an already active DDL
    -- writer must not make its observer wait on the writer''s metadata locks.
    SELECT @g1=CONVERT(bigint,current_value),@object1=object_id,
        @created1=create_date,@modified1=modify_date
      FROM sys.sequences WHERE object_id=OBJECT_ID(N''dbo.P02ObservationGeneration'',''SO'')
        AND system_type_id=127 AND CONVERT(bigint,start_value)=1
        AND CONVERT(bigint,minimum_value)=1 AND CONVERT(bigint,increment)=1
        AND CONVERT(bigint,maximum_value)=9223372036854775807
        AND is_cycling=0 AND is_cached=0 AND is_exhausted=0;
    SET @grantable=APPLOCK_TEST(''public'',''K98:catalogue-mutation:v1'',''Exclusive'',''Session'');
    IF @grantable=1
    BEGIN
    -- The legacy role has schema ALTER. These explicit denials are part of the
    -- invalidation contract: without them TRUNCATE or bulk trigger suppression
    -- can change lifecycle state without advancing the sequence. Recheck on
    -- every quiet boundary; a database-only generation never caches effective
    -- server permissions, which the actual admission cursor checks separately.
    IF (SELECT COUNT_BIG(*) FROM sys.database_permissions
        WHERE grantee_principal_id=DATABASE_PRINCIPAL_ID(N''ExportLegacyEntryReader'')
          AND class=1 AND minor_id=0 AND state=''D'' AND permission_name=N''ALTER''
          AND major_id IN (OBJECT_ID(N''dbo.KVKFinalReportHeader'',''U''),
                           OBJECT_ID(N''dbo.MaintenanceKvkWork'',''U''),
                           OBJECT_ID(N''dbo.MaintenanceWork'',''U'')))<>3
        THROW 51972,''Lifecycle invalidation permissions differ from the reviewed contract.'',1;
    SELECT @health=(
        SELECT o.name,m.definition,m.uses_ansi_nulls,m.uses_quoted_identifier,
            m.execute_as_principal_id,t.is_disabled,t.is_not_for_replication
        FROM sys.sql_modules m
        JOIN (SELECT object_id,name FROM sys.objects UNION ALL
              SELECT object_id,name FROM sys.triggers WHERE parent_class=0) o ON o.object_id=m.object_id
        LEFT JOIN sys.triggers t ON t.object_id=m.object_id
        WHERE o.name IN (''usp_P02BeginCatalogueMutation'',''usp_P02EndCatalogueMutation'',
            ''usp_P02ReadObservationBoundary'',''tr_P02HeaderObservation'',
            ''tr_P02KvkWorkObservation'',''tr_P02MaintenanceObservation'',''tr_P02CatalogueObservation'')
        ORDER BY o.name COLLATE Latin1_General_100_BIN2
        FOR JSON PATH,INCLUDE_NULL_VALUES);
    END;
    SELECT @g2=CONVERT(bigint,current_value),@object2=object_id,
        @created2=create_date,@modified2=modify_date
      FROM sys.sequences WHERE object_id=OBJECT_ID(N''dbo.P02ObservationGeneration'',''SO'');
    SELECT CONVERT(nvarchar(128),SERVERPROPERTY(''ServerName'')) AS ServerName,
        DB_NAME() AS DatabaseName,DB_ID() AS DatabaseID,USER_NAME() AS PrincipalName,
        ORIGINAL_LOGIN() AS OriginalLogin,@@SPID AS SessionID,@@TRANCOUNT AS TransactionCount,
        XACT_STATE() AS TransactionState,@isolation AS IsolationLevel,
        @g1 AS GenerationBefore,@grantable AS WriterAbsent,@g2 AS GenerationAfter,
        @object1 AS SequenceObjectBefore,@created1 AS SequenceCreatedBefore,@modified1 AS SequenceModifiedBefore,
        @object2 AS SequenceObjectAfter,@created2 AS SequenceCreatedAfter,@modified2 AS SequenceModifiedAfter,
        @health AS ContractHealth;
END;
';

EXEC sys.sp_executesql N'ALTER PROCEDURE [dbo].[sp_ExcelOutput_ByKVK]
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
        EXEC dbo.usp_P02BeginCatalogueMutation @Owner=''Transaction'';

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
END

';

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
        -- Cover early unknown-state repair, every child, and failure recording.
        -- On failure the existing caller retains physical ownership; it must
        -- acknowledge this marker too before pooling/reusing the connection.
        EXEC dbo.usp_P02BeginCatalogueMutation @Owner=''Session'';
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
        EXEC dbo.usp_P02EndCatalogueMutation;
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
END;
';

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
    EXEC dbo.usp_P02BeginCatalogueMutation @Owner=''Transaction'';
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
END;
';

EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER dbo.tr_P02HeaderObservation ON dbo.KVKFinalReportHeader
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted) OR EXISTS(SELECT 1 FROM deleted)
    BEGIN
        BEGIN TRANSACTION;
        EXEC dbo.usp_P02BeginCatalogueMutation @Owner=''Transaction'';
        COMMIT TRANSACTION;
    END;
END;
';

EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER dbo.tr_P02KvkWorkObservation ON dbo.MaintenanceKvkWork
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted) OR EXISTS(SELECT 1 FROM deleted)
    BEGIN
        BEGIN TRANSACTION;
        EXEC dbo.usp_P02BeginCatalogueMutation @Owner=''Transaction'';
        COMMIT TRANSACTION;
    END;
END;
';

EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER dbo.tr_P02MaintenanceObservation ON dbo.MaintenanceWork
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted WHERE Kind=''kvk_output'')
       OR EXISTS(SELECT 1 FROM deleted WHERE Kind=''kvk_output'')
    BEGIN
        BEGIN TRANSACTION;
        EXEC dbo.usp_P02BeginCatalogueMutation @Owner=''Transaction'';
        COMMIT TRANSACTION;
    END;
END;
';

GRANT EXECUTE ON OBJECT::dbo.usp_P02BeginCatalogueMutation TO ExportLegacyEntryReader;

GRANT EXECUTE ON OBJECT::dbo.usp_P02EndCatalogueMutation TO ExportLegacyEntryReader;

GRANT EXECUTE ON OBJECT::dbo.usp_P02ReadObservationBoundary TO ExportLegacyEntryReader;

DENY ALTER ON OBJECT::dbo.KVKFinalReportHeader TO ExportLegacyEntryReader;

DENY ALTER ON OBJECT::dbo.MaintenanceKvkWork TO ExportLegacyEntryReader;

DENY ALTER ON OBJECT::dbo.MaintenanceWork TO ExportLegacyEntryReader;

EXEC sys.sp_executesql N'CREATE OR ALTER TRIGGER tr_P02CatalogueObservation ON DATABASE
FOR DDL_DATABASE_LEVEL_EVENTS
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @event xml=EVENTDATA();
    -- Never permit reset/replacement of an admitted counter. A drained migration
    -- must explicitly remove this protection and create a new contract identity.
    IF @event.value(''(/EVENT_INSTANCE/SchemaName)[1]'',''sysname'')=''dbo''
       AND @event.value(''(/EVENT_INSTANCE/ObjectName)[1]'',''sysname'')=''P02ObservationGeneration''
        THROW 51970,''Observation sequence changes require a drained contract migration.'',1;
    -- Autocommit DDL trigger context can have a nesting count without a user
    -- transaction usable by APPLOCK_MODE (native SQL3918). Explicitly nest;
    -- the enclosing statement/transaction must retain the marker to completion.
    -- Qualification includes a later-trigger barrier to prove that lifetime.
    BEGIN TRANSACTION;
    EXEC dbo.usp_P02BeginCatalogueMutation @Owner=''Transaction'';
    COMMIT TRANSACTION;
END;
';

IF @@TRANCOUNT<>1 OR XACT_STATE()<>1
    THROW 51973,'Observer installation changed the release transaction.',1;
-- The coordinator commits its ordinary receipt before issuing a protected
-- installation binding from an acknowledged postcommit identity read.
