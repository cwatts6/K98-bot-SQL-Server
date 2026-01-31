SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_Stats_for_Upload]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[SP_Stats_for_Upload] AS' 
END
ALTER PROCEDURE [dbo].[SP_Stats_for_Upload]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE 
        @LatestKVK       INT,
        @MaxScan         INT,
        @TableName       NVARCHAR(128),
        @TableNameFull   NVARCHAR(260),
        @sql             NVARCHAR(MAX);



    ------------------------------------------------------------
    -- Step 1: Get max scan available
    ------------------------------------------------------------
    SELECT @MaxScan = MAX(SCANORDER)
    FROM dbo.KingdomScanData4;

    IF @MaxScan IS NULL
    BEGIN
        RAISERROR('SP_Stats_for_Upload: No scan data available.',16,1);
        RETURN;
    END

    ------------------------------------------------------------
    -- Step 2: Get latest eligible KVKVersion
    ------------------------------------------------------------
    SELECT TOP 1 @LatestKVK = KVKVersion
    FROM dbo.ProcConfig
    WHERE ConfigKey = 'MATCHMAKING_SCAN'
      AND TRY_CAST(ConfigValue AS INT) <= @MaxScan
    ORDER BY KVKVersion DESC;

    IF @LatestKVK IS NULL
    BEGIN
        RAISERROR('SP_Stats_for_Upload: no eligible KVK found (MATCHMAKING_SCAN <= max scan).',16,1);
        RETURN;
    END

    ------------------------------------------------------------
    -- FIX: Ensure transaction commits are fully visible
    ------------------------------------------------------------
    PRINT 'SP_Stats_for_Upload: Forcing commit flush via CHECKPOINT...';
    CHECKPOINT;
    
    -- Small safety delay to ensure data visibility
    WAITFOR DELAY '00:00:00.100';  -- 100ms delay

	PRINT 'SP_Stats_for_Upload: Populating STATS_FOR_UPLOAD from EXCEL_FOR_KVK_' + CAST(@LatestKVK AS VARCHAR(10));
    
    ------------------------------------------------------------
    -- Step 5b: Verify statistics on source table
    ------------------------------------------------------------
    SET @TableName = 'EXCEL_FOR_KVK_' + CAST(@LatestKVK AS NVARCHAR(10));
    SET @TableNameFull = QUOTENAME('dbo') + N'.' + QUOTENAME(@TableName);

    -- Check if statistics exist; if not, create them
    IF NOT EXISTS (
        SELECT 1 
        FROM sys.stats s
        INNER JOIN sys.tables t ON s.object_id = t.object_id
        WHERE t.name = @TableName
          AND s.name LIKE '_WA_Sys%' -- Auto-created stats
           OR s.name LIKE 'IX_%'      -- Index stats
    )
    BEGIN
        PRINT 'SP_Stats_for_Upload: No statistics found on ' + @TableName + ', creating...';
        SET @sql = N'UPDATE STATISTICS ' + @TableNameFull + N' WITH FULLSCAN;';
        EXEC sp_executesql @sql;
    END
    ELSE
    BEGIN
        PRINT 'SP_Stats_for_Upload: Statistics already exist on ' + @TableName;
    END

    PRINT 'SP_Stats_for_Upload: Beginning STATS_FOR_UPLOAD population...';

    ------------------------------------------------------------
    -- Step 6: Build table name dynamically
    ------------------------------------------------------------
    -- Already set above in @TableNameFull


    ------------------------------------------------------------
    -- Step 7: Truncate + insert from refreshed table
    ------------------------------------------------------------
    SET @sql = N'TRUNCATE TABLE dbo.STATS_FOR_UPLOAD;';

    SET @sql += N'
    DECLARE @MAXDATE DATETIME = (SELECT MAX(ScanDate) FROM dbo.KingdomScanData4);

    DECLARE @X_KVK INT = (
        SELECT TOP 1 TRY_CAST(KVKVersion AS INT)
        FROM dbo.ProcConfig 
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CAST(ConfigValue AS INT) <= (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)
        ORDER BY KVKVersion DESC
    );

    INSERT INTO dbo.STATS_FOR_UPLOAD
    (
        [Rank],[KVK_RANK],[Gov_ID],[Governor_Name],
        [Starting Power],[Power_Delta],
        [Civilization],[KvKPlayed],[MostKvKKill],[MostKvKDead],[MostKvKHeal],
        [Acclaim],[HighestAcclaim],[AOOJoined],[AOOWon],[AOOAvgKill],[AOOAvgDead],[AOOAvgHeal],
        [Starting_T4&T5_KILLS],[T4_KILLS],[T5_KILLS],[T4&T5_Kills],[KILLS_OUTSIDE_KVK],[Kill Target],[% of Kill Target],
        [Starting_Deads],[Deads_Delta],[DEADS_OUTSIDE_KVK],[T4_Deads],[T5_Deads],[Dead_Target],[% of Dead Target],
        [Zeroed],
        [DKP_SCORE],[DKP Target],[% of DKP Target],
        [HelpsDelta],[RSS_Assist_Delta],[RSS_Gathered_Delta],
        [Pass 4 Kills],[Pass 6 Kills],[Pass 7 Kills],[Pass 8 Kills],
        [Pass 4 Deads],[Pass 6 Deads],[Pass 7 Deads],[Pass 8 Deads],
        [Starting_HealedTroops],[HealedTroopsDelta],
        [Starting_KillPoints],[KillPointsDelta],
        [RangedPoints],[RangedPointsDelta],
        [AutarchTimes],
        [Max_PreKvk_Points],[Max_HonorPoints],[PreKvk_Rank],[Honor_Rank],
        [KVK_NO],
        [LAST_REFRESH],[STATUS]
    )
    SELECT
        [Rank],
        [KVK_RANK],
        CAST([Gov_ID] AS bigint) AS [Gov_ID],
        RTRIM([Governor_Name]) AS [Governor_Name],
		[Starting Power],
        ISNULL([Power_Delta],0),
		[Civilization],
        ISNULL([KvKPlayed],0),
        ISNULL([MostKvKKill],0),
        ISNULL([MostKvKDead],0),
        ISNULL([MostKvKHeal],0),
		ISNULL([Acclaim],0),
        ISNULL([HighestAcclaim],0),
        ISNULL([AOOJoined],0),
        ISNULL([AOOWon],0),
        ISNULL([AOOAvgKill],0),
        ISNULL([AOOAvgDead],0),
        ISNULL([AOOAvgHeal],0),
		ISNULL([Starting_T4&T5_KILLS],0),
        ISNULL([T4_KILLS],0),
        ISNULL([T5_KILLS],0),
        ISNULL([T4&T5_Kills],0),
        ISNULL([KILLS_OUTSIDE_KVK],0),
        ISNULL([Kill Target],0),
        ISNULL([% of Kill Target],0),
		ISNULL([Starting_Deads],0),
        ISNULL([Deads_Delta],0),
        ISNULL([DEADS_OUTSIDE_KVK],0),
        ISNULL([T4_Deads],0),
        ISNULL([T5_Deads],0),
        ISNULL([Dead_Target],0),
        ISNULL([% of Dead Target],0),
		ISNULL([Zeroed],0),
		ISNULL([DKP_SCORE],0),
        ISNULL([DKP Target],0),
        ISNULL([% of DKP Target],0),
		ISNULL([HelpsDelta],0),
        ISNULL([RSS_Assist_Delta],0),
        ISNULL([RSS_Gathered_Delta],0),
        ISNULL([Pass 4 Kills],0),
        ISNULL([Pass 6 Kills],0),
        ISNULL([Pass 7 Kills],0),
        ISNULL([Pass 8 Kills],0),
        ISNULL([Pass 4 Deads],0),
        ISNULL([Pass 6 Deads],0),
        ISNULL([Pass 7 Deads],0),
        ISNULL([Pass 8 Deads],0),
        ISNULL([Starting_HealedTroops],0),
        ISNULL([HealedTroopsDelta],0),
        ISNULL([Starting_KillPoints],0),
        ISNULL([KillPointsDelta],0),
        ISNULL([RangedPoints],0),
        ISNULL([RangedPointsDelta],0),
        ISNULL([AutarchTimes],0),
        ISNULL([Max_PreKvk_Points],0),
        ISNULL([Max_HonorPoints],0),
        ISNULL([PreKvk_Rank],0),
        ISNULL([Honor_Rank],0),
        [KVK_NO],
        CAST(@MAXDATE AS date) AS [LAST_REFRESH],
        CASE 
            WHEN CAST([Gov_ID] AS bigint) IN (
                SELECT GovernorID 
                FROM dbo.EXEMPT_FROM_STATS
                WHERE KVK_NO IN (0, @X_KVK)
            ) THEN ''EXEMPT''
            ELSE ''INCLUDED''
        END AS [STATUS]
    FROM ' + @TableNameFull + N';';

    EXEC sp_executesql @sql;

    ------------------------------------------------------------
    -- Step 8: Rebuild/reorganize indexes for optimal performance
    ------------------------------------------------------------
    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.STATS_FOR_UPLOAD') AND name = N'IX_STATS_FOR_UPLOAD_GovID')
    BEGIN
        ALTER INDEX [IX_STATS_FOR_UPLOAD_GovID] ON dbo.STATS_FOR_UPLOAD REBUILD WITH (ONLINE = OFF);
        PRINT 'SP_Stats_for_Upload: Rebuilt index IX_STATS_FOR_UPLOAD_GovID';
    END

    IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.STATS_FOR_UPLOAD') AND name = N'IX_STATS_FOR_UPLOAD_KVK_NO')
    BEGIN
        ALTER INDEX [IX_STATS_FOR_UPLOAD_KVK_NO] ON dbo.STATS_FOR_UPLOAD REBUILD WITH (ONLINE = OFF);
        PRINT 'SP_Stats_for_Upload: Rebuilt index IX_STATS_FOR_UPLOAD_KVK_NO';
    END

    UPDATE STATISTICS dbo.STATS_FOR_UPLOAD WITH FULLSCAN;
    PRINT 'SP_Stats_for_Upload: Updated statistics on STATS_FOR_UPLOAD';

    PRINT 'SP_Stats_for_Upload: Completed successfully for KVK ' + CAST(@LatestKVK AS VARCHAR(10)) 
        + ' using scan ' + CAST(@MaxScan AS VARCHAR(10)) 
        + ' at ' + CONVERT(VARCHAR, GETDATE(), 120);
END

