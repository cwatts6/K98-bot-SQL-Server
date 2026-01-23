SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CREATE_DELTA_TABLES]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CREATE_DELTA_TABLES] AS' 
END
ALTER PROCEDURE [dbo].[CREATE_DELTA_TABLES]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FIRSTSCAN AS FLOAT = 1;

    ----------------------------------------------------------------
    -- Truncate existing delta tables (preserve pattern used originally)
    ----------------------------------------------------------------
    TRUNCATE TABLE T4T5KillDelta;
    TRUNCATE TABLE T4KillDelta;
    TRUNCATE TABLE T5KillDelta;
    TRUNCATE TABLE DeadsDelta;
    TRUNCATE TABLE HelpsDelta;
    TRUNCATE TABLE RSSASSISTDelta;
    TRUNCATE TABLE RSSGatheredDelta;
    TRUNCATE TABLE POWERDelta;

    ----------------------------------------------------------------
    -- Build temporary base data table (include KillPoints)
    ----------------------------------------------------------------
    SELECT 
        GovernorID,
        SCANORDER,
        SUM(T4_Kills) AS T4_Kills,
        SUM(T5_Kills) AS T5_Kills,
        SUM([T4&T5_Kills]) AS T4T5_Kills,
        SUM([Power]) AS Power,
        SUM([KillPoints]) AS KillPoints,              -- NEW
        SUM([Deads]) AS Deads,
        SUM([Helps]) AS Helps,
        SUM([RSSAssistance]) AS RSSAssist,
        SUM([RSS_Gathered]) AS RSSGathered,
        SUM([HealedTroops]) AS HealedTroops,
        SUM([RangedPoints]) AS RangedPoints
    INTO #BaseData
    FROM dbo.kingdomscandata4
    WHERE SCANORDER >= @FIRSTSCAN
    GROUP BY GovernorID, SCANORDER;

    IF OBJECT_ID('tempdb..#BaseData') IS NOT NULL
    BEGIN
        -- create a clustered index if not already present
        -- This helps the OUTER APPLY (previous-row) lookup scale reasonably.
        BEGIN TRY
            CREATE CLUSTERED INDEX IX_BaseData_Gov_Scan ON #BaseData (GovernorID ASC, SCANORDER ASC);
        END TRY
        BEGIN CATCH
            -- ignore if index exists or creation fails
        END CATCH
    END

    ----------------------------------------------------------------
    -- Use OUTER APPLY (previous non-NULL lookup) consistently for deltas
    -- This prevents spurious large deltas when intermediate scans have NULLs
    ----------------------------------------------------------------

    -- HealedTroopsDelta (existing pattern)
    IF OBJECT_ID('dbo.HealedTroopsDelta','U') IS NOT NULL
    BEGIN
        TRUNCATE TABLE dbo.HealedTroopsDelta;
    END

    INSERT INTO dbo.HealedTroopsDelta (GovernorID, DeltaOrder, HealedTroopsDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.HealedTroops - ISNULL(prev.HealedTroops, 0) AS BIGINT) AS HealedTroopsDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.HealedTroops
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.HealedTroops IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.HealedTroops IS NOT NULL;

    -- RangedPointsDelta (existing pattern)
    IF OBJECT_ID('dbo.RangedPointsDelta','U') IS NOT NULL
    BEGIN
        TRUNCATE TABLE dbo.RangedPointsDelta;
    END

    INSERT INTO dbo.RangedPointsDelta (GovernorID, DeltaOrder, RangedPointsDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.RangedPoints - ISNULL(prev.RangedPoints, 0) AS BIGINT) AS RangedPointsDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.RangedPoints
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.RangedPoints IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.RangedPoints IS NOT NULL;

    ----------------------------------------------------------------
    -- T4 Kill Delta (previous non-NULL lookup)
    ----------------------------------------------------------------
    INSERT INTO T4KillDelta (GovernorID, DeltaOrder, T4KILLSDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.T4_Kills - ISNULL(prev.T4_Kills, 0) AS FLOAT) AS T4KILLSDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.T4_Kills
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.T4_Kills IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.T4_Kills IS NOT NULL;

    ----------------------------------------------------------------
    -- T5 Kill Delta
    ----------------------------------------------------------------
    INSERT INTO T5KillDelta (GovernorID, DeltaOrder, T5KILLSDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.T5_Kills - ISNULL(prev.T5_Kills, 0) AS FLOAT) AS T5KILLSDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.T5_Kills
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.T5_Kills IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.T5_Kills IS NOT NULL;

    ----------------------------------------------------------------
    -- T4&T5 Kill Delta
    ----------------------------------------------------------------
    INSERT INTO T4T5KillDelta (GovernorID, DeltaOrder, [T4&T5_KILLSDelta])
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.T4T5_Kills - ISNULL(prev.T4T5_Kills, 0) AS FLOAT) AS T4T5_KillsDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.T4T5_Kills
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.T4T5_Kills IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.T4T5_Kills IS NOT NULL;

    ----------------------------------------------------------------
    -- Power Delta
    ----------------------------------------------------------------
    INSERT INTO POWERDelta (GovernorID, DeltaOrder, [Power_Delta])
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.Power - ISNULL(prev.Power, 0) AS FLOAT) AS PowerDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.Power
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.Power IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.Power IS NOT NULL;

    ----------------------------------------------------------------
    -- Deads Delta
    ----------------------------------------------------------------
    INSERT INTO DeadsDelta (GovernorID, DeltaOrder, DeadsDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.Deads - ISNULL(prev.Deads, 0) AS FLOAT) AS DeadsDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.Deads
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.Deads IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.Deads IS NOT NULL;

    ----------------------------------------------------------------
    -- Helps Delta
    ----------------------------------------------------------------
    INSERT INTO HelpsDelta (GovernorID, DeltaOrder, HelpsDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.Helps - ISNULL(prev.Helps, 0) AS FLOAT) AS HelpsDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.Helps
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.Helps IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.Helps IS NOT NULL;

    ----------------------------------------------------------------
    -- RSS Assistance Delta
    ----------------------------------------------------------------
    INSERT INTO RSSASSISTDelta (GovernorID, DeltaOrder, RSSAssistDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.RSSAssist - ISNULL(prev.RSSAssist, 0) AS FLOAT) AS RSSAssistDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.RSSAssist
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.RSSAssist IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.RSSAssist IS NOT NULL;

    ----------------------------------------------------------------
    -- RSS Gathered Delta
    ----------------------------------------------------------------
    INSERT INTO RSSGatheredDelta (GovernorID, DeltaOrder, RSSGatheredDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.RSSGathered - ISNULL(prev.RSSGathered, 0) AS FLOAT) AS RSSGatheredDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.RSSGathered
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.RSSGathered IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.RSSGathered IS NOT NULL;

    ----------------------------------------------------------------
    -- KillPoints Delta (NEW) - previous non-NULL lookup
    ----------------------------------------------------------------
    IF OBJECT_ID('dbo.KillPointsDelta','U') IS NOT NULL
    BEGIN
        TRUNCATE TABLE dbo.KillPointsDelta;
    END

    INSERT INTO dbo.KillPointsDelta (GovernorID, DeltaOrder, KillPointsDelta)
    SELECT
        b.GovernorID,
        b.SCANORDER,
        CAST(b.KillPoints - ISNULL(prev.KillPoints, 0) AS BIGINT) AS KillPointsDelta
    FROM #BaseData AS b
    OUTER APPLY (
        SELECT TOP (1) b2.KillPoints
        FROM #BaseData AS b2
        WHERE b2.GovernorID = b.GovernorID
          AND b2.SCANORDER < b.SCANORDER
          AND b2.KillPoints IS NOT NULL
        ORDER BY b2.SCANORDER DESC
    ) AS prev
    WHERE b.KillPoints IS NOT NULL;

    ----------------------------------------------------------------
    -- Cleanup
    ----------------------------------------------------------------
    IF OBJECT_ID('tempdb..#BaseData') IS NOT NULL DROP TABLE #BaseData;

    SET NOCOUNT OFF;
END

