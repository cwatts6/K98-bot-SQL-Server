/*
MigrationId: 20260616_001_fix_excel_dashboard_explicit_union
Purpose: Rebuild EXCEL_FOR_DASHBOARD with explicit EXCEL_FOR_KVK column mapping
Author: cwatts
CreatedUtc: 2026-06-16
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: N/A for migration; next UPDATE_ALL2 rebuilds dbo.EXCEL_FOR_DASHBOARD from eligible EXCEL_FOR_KVK tables
PreValidationQuery: SELECT OBJECT_ID(N'dbo.sp_Rebuild_ExcelForDashboard', N'P') AS ObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.sp_Rebuild_ExcelForDashboard', N'P') AS ObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety notes:
- This migration only replaces dbo.sp_Rebuild_ExcelForDashboard; it does not execute the dashboard rebuild.
- The procedure retains the existing rebuild behavior of dropping/recreating dbo.EXCEL_FOR_DASHBOARD when UPDATE_ALL2 runs.
- The runtime rebuild source remains the eligible dbo.EXCEL_FOR_KVK_<n> tables selected by ProcConfig MATCHMAKING_SCAN.
- The change removes SELECT * UNION ALL so differing physical column order cannot corrupt Conduct or other dashboard values.
- Rollback is manual: redeploy the previous procedure body if required, then rerun UPDATE_ALL2 to rebuild dashboard outputs.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Rebuild_ExcelForDashboard]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Rebuild_ExcelForDashboard] AS'
END
GO

ALTER PROCEDURE [dbo].[sp_Rebuild_ExcelForDashboard]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = N'';
    DECLARE @unionSql NVARCHAR(MAX) = N'';
    DECLARE @KVK INT;
    DECLARE @MaxScan FLOAT;
    DECLARE @TableName SYSNAME;

    -- Determine latest scan order for eligibility checks
    SELECT @MaxScan = MAX(SCANORDER) FROM dbo.KingdomScanData4;

    ----------------------------------------------------------------
    -- Build dynamic UNION of EXCEL_FOR_KVK_<KVK> tables that are eligible.
    -- Use explicit column mapping because upgraded databases may have
    -- different physical column order after ALTER TABLE ... ADD.
    ----------------------------------------------------------------
    DECLARE cur CURSOR FOR
    SELECT DISTINCT KVKVersion
    FROM dbo.ProcConfig
    WHERE ConfigKey = 'MATCHMAKING_SCAN'
      AND TRY_CAST(ConfigValue AS FLOAT) < ISNULL(@MaxScan, 0)
    ORDER BY KVKVersion DESC;

    OPEN cur;
    FETCH NEXT FROM cur INTO @KVK;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @TableName = N'EXCEL_FOR_KVK_' + CAST(@KVK AS NVARCHAR(10));

        IF OBJECT_ID(QUOTENAME(N'dbo') + N'.' + QUOTENAME(@TableName), N'U') IS NOT NULL
        BEGIN
            SET @unionSql +=
                CASE
                    WHEN LEN(ISNULL(@unionSql, N'')) = 0
                        THEN N''
                    ELSE N'
            UNION ALL
'
                END
                + N'
            SELECT
                CAST([Rank] AS int) AS [Rank],
                CAST([KVK_RANK] AS int) AS [KVK_RANK],
                CAST([Gov_ID] AS bigint) AS [Gov_ID],
                CAST([Governor_Name] AS nvarchar(255)) AS [Governor_Name],
                CAST([Starting Power] AS bigint) AS [Starting Power],
                CAST([Power_Delta] AS bigint) AS [Power_Delta],
                CAST([Civilization] AS nvarchar(100)) AS [Civilization],
                CAST([KvKPlayed] AS int) AS [KvKPlayed],
                CAST([MostKvKKill] AS bigint) AS [MostKvKKill],
                CAST([MostKvKDead] AS bigint) AS [MostKvKDead],
                CAST([MostKvKHeal] AS bigint) AS [MostKvKHeal],
                CAST([Acclaim] AS bigint) AS [Acclaim],
                CAST([HighestAcclaim] AS bigint) AS [HighestAcclaim],
                CAST([AOOJoined] AS bigint) AS [AOOJoined],
                CAST([AOOWon] AS int) AS [AOOWon],
                CAST([AOOAvgKill] AS bigint) AS [AOOAvgKill],
                CAST([AOOAvgDead] AS bigint) AS [AOOAvgDead],
                CAST([AOOAvgHeal] AS bigint) AS [AOOAvgHeal],
                CAST([Conduct] AS decimal(5,2)) AS [Conduct],
                CAST([Starting_T4&T5_KILLS] AS bigint) AS [Starting_T4&T5_KILLS],
                CAST([T4_KILLS] AS bigint) AS [T4_KILLS],
                CAST([T5_KILLS] AS bigint) AS [T5_KILLS],
                CAST([T4&T5_Kills] AS bigint) AS [T4&T5_Kills],
                CAST([KILLS_OUTSIDE_KVK] AS bigint) AS [KILLS_OUTSIDE_KVK],
                CAST([Kill Target] AS bigint) AS [Kill Target],
                CAST([% of Kill Target] AS decimal(9,2)) AS [% of Kill Target],
                CAST([Starting_Deads] AS bigint) AS [Starting_Deads],
                CAST([Deads_Delta] AS bigint) AS [Deads_Delta],
                CAST([DEADS_OUTSIDE_KVK] AS bigint) AS [DEADS_OUTSIDE_KVK],
                CAST([T4_Deads] AS bigint) AS [T4_Deads],
                CAST([T5_Deads] AS bigint) AS [T5_Deads],
                CAST([Dead_Target] AS bigint) AS [Dead_Target],
                CAST([% of Dead Target] AS decimal(9,2)) AS [% of Dead Target],
                CAST([Zeroed] AS bit) AS [Zeroed],
                CAST([DKP_SCORE] AS bigint) AS [DKP_SCORE],
                CAST([DKP Target] AS bigint) AS [DKP Target],
                CAST([% of DKP Target] AS decimal(9,2)) AS [% of DKP Target],
                CAST([HelpsDelta] AS bigint) AS [HelpsDelta],
                CAST([RSS_Assist_Delta] AS bigint) AS [RSS_Assist_Delta],
                CAST([RSS_Gathered_Delta] AS bigint) AS [RSS_Gathered_Delta],
                CAST([Pass 4 Kills] AS bigint) AS [Pass 4 Kills],
                CAST([Pass 6 Kills] AS bigint) AS [Pass 6 Kills],
                CAST([Pass 7 Kills] AS bigint) AS [Pass 7 Kills],
                CAST([Pass 8 Kills] AS bigint) AS [Pass 8 Kills],
                CAST([Pass 4 Deads] AS bigint) AS [Pass 4 Deads],
                CAST([Pass 6 Deads] AS bigint) AS [Pass 6 Deads],
                CAST([Pass 7 Deads] AS bigint) AS [Pass 7 Deads],
                CAST([Pass 8 Deads] AS bigint) AS [Pass 8 Deads],
                CAST([Starting_HealedTroops] AS bigint) AS [Starting_HealedTroops],
                CAST([HealedTroopsDelta] AS bigint) AS [HealedTroopsDelta],
                CAST([Starting_KillPoints] AS bigint) AS [Starting_KillPoints],
                CAST([KillPointsDelta] AS bigint) AS [KillPointsDelta],
                CAST([RangedPoints] AS bigint) AS [RangedPoints],
                CAST([RangedPointsDelta] AS bigint) AS [RangedPointsDelta],
                CAST([AutarchTimes] AS bigint) AS [AutarchTimes],
                CAST([Max_PreKvk_Points] AS bigint) AS [Max_PreKvk_Points],
                CAST([Max_HonorPoints] AS bigint) AS [Max_HonorPoints],
                CAST([PreKvk_Rank] AS bigint) AS [PreKvk_Rank],
                CAST([Honor_Rank] AS bigint) AS [Honor_Rank],
                CAST([KVK_NO] AS int) AS [KVK_NO]
            FROM dbo.' + QUOTENAME(@TableName);
        END

        FETCH NEXT FROM cur INTO @KVK;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -- If there are eligible KVK tables, build EXCEL_FOR_DASHBOARD as a union of them.
    IF LEN(ISNULL(@unionSql, '')) > 0
    BEGIN
        SET @sql = N'
        IF OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'', ''U'') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        SELECT TOP (50000000)
               T.*,
               T.[% of Dead Target] AS [% of Dead_Target]  -- alias for compatibility
        INTO dbo.EXCEL_FOR_DASHBOARD
        FROM (
            ' + @unionSql + '
        ) AS T
        ORDER BY KVK_NO, [RANK];
        ';

        EXEC sp_executesql @sql;

        PRINT 'Rebuilt EXCEL_FOR_DASHBOARD by unioning per-KVK tables with explicit columns.';
    END
    ELSE
    BEGIN
        PRINT 'No eligible KVK tables found based on MATCHMAKING_SCAN and Max SCANORDER.';
    END
END
GO
