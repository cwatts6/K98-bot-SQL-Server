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

DECLARE @FIRSTSCAN AS FLOAT = 1

    -- Truncate existing delta tables
    TRUNCATE TABLE T4T5KillDelta;
    TRUNCATE TABLE T4KillDelta;
    TRUNCATE TABLE T5KillDelta;
    TRUNCATE TABLE DeadsDelta;
    TRUNCATE TABLE HelpsDelta;
    TRUNCATE TABLE RSSASSISTDelta;
    TRUNCATE TABLE RSSGatheredDelta;
    TRUNCATE TABLE POWERDelta;

    -- Build temporary base data table
    SELECT 
        GovernorID,
        SCANORDER,
        SUM(T4_Kills) AS T4_Kills,
        SUM(T5_Kills) AS T5_Kills,
        SUM([T4&T5_Kills]) AS T4T5_Kills,
        SUM([Power]) AS Power,
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

		-- HealedTroopsDelta: previous non-NULL lookup
	IF OBJECT_ID('dbo.HealedTroopsDelta','U') IS NOT NULL
	BEGIN
		TRUNCATE TABLE dbo.HealedTroopsDelta;
	END

	INSERT INTO dbo.HealedTroopsDelta (GovernorID, DeltaOrder, HealedTroopsDelta)
	SELECT
		b.GovernorID,
		b.SCANORDER,
		b.HealedTroops - ISNULL(prev.HealedTroops, 0) AS HealedTroopsDelta
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

	-- RangedPointsDelta: same pattern
	IF OBJECT_ID('dbo.RangedPointsDelta','U') IS NOT NULL
	BEGIN
		TRUNCATE TABLE dbo.RangedPointsDelta;
	END

	INSERT INTO dbo.RangedPointsDelta (GovernorID, DeltaOrder, RangedPointsDelta)
	SELECT
		b.GovernorID,
		b.SCANORDER,
		b.RangedPoints - ISNULL(prev.RangedPoints, 0) AS RangedPointsDelta
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

    -- T4 Kill Delta
    INSERT INTO T4KillDelta
    SELECT 
        GovernorID,
        SCANORDER,
        T4_Kills - COALESCE(LAG(T4_Kills) OVER (PARTITION BY GovernorID ORDER BY SCANORDER), 0)
    FROM #BaseData;

    -- T5 Kill Delta
    INSERT INTO T5KillDelta
    SELECT 
        GovernorID,
        SCANORDER,
        T5_Kills - COALESCE(LAG(T5_Kills) OVER (PARTITION BY GovernorID ORDER BY SCANORDER), 0)
    FROM #BaseData;

    -- T4&T5 Kill Delta
    INSERT INTO T4T5KillDelta
    SELECT 
        GovernorID,
        SCANORDER,
        T4T5_Kills - COALESCE(LAG(T4T5_Kills) OVER (PARTITION BY GovernorID ORDER BY SCANORDER), 0)
    FROM #BaseData;

    -- Power Delta
    INSERT INTO POWERDelta
    SELECT 
        GovernorID,
        SCANORDER,
        Power - COALESCE(LAG(Power) OVER (PARTITION BY GovernorID ORDER BY SCANORDER), 0)
    FROM #BaseData;

    -- Deads Delta
    INSERT INTO DeadsDelta
    SELECT 
        GovernorID,
        SCANORDER,
        Deads - COALESCE(LAG(Deads) OVER (PARTITION BY GovernorID ORDER BY SCANORDER), 0)
    FROM #BaseData;

    -- Helps Delta
    INSERT INTO HelpsDelta
    SELECT 
        GovernorID,
        SCANORDER,
        Helps - COALESCE(LAG(Helps) OVER (PARTITION BY GovernorID ORDER BY SCANORDER), 0)
    FROM #BaseData;

    -- RSS Assistance Delta
    INSERT INTO RSSASSISTDelta
    SELECT 
        GovernorID,
        SCANORDER,
        RSSAssist - COALESCE(LAG(RSSAssist) OVER (PARTITION BY GovernorID ORDER BY SCANORDER), 0)
    FROM #BaseData;

    -- RSS Gathered Delta
    INSERT INTO RSSGatheredDelta
    SELECT 
        GovernorID,
        SCANORDER,
        RSSGathered - COALESCE(LAG(RSSGathered) OVER (PARTITION BY GovernorID ORDER BY SCANORDER), 0)
    FROM #BaseData;

    -- Cleanup
    IF OBJECT_ID('tempdb..#BaseData') IS NOT NULL DROP TABLE #BaseData;



END;

