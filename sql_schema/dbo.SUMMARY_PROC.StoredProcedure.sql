SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[SUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N'SummaryExport';
    DECLARE @LastProcessed FLOAT = 0;
    DECLARE @MaxScan FLOAT = 0;

    SELECT @LastProcessed = LastScanOrder
    FROM dbo.SUMMARY_PROC_STATE
    WHERE MetricName = @MetricName;

    IF @LastProcessed IS NULL SET @LastProcessed = 0;

    SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
    FROM dbo.KingdomScanData4;

    IF @MaxScan <= @LastProcessed
    BEGIN
        RETURN;
    END

    BEGIN TRY

        BEGIN TRANSACTION;
        -- Step 1: Execute dependent procedures
        EXEC dbo.DEADSSUMMARY_PROC;
        EXEC dbo.POWERSUMMARY_PROC;
        EXEC dbo.KILLSSUMMARY_PROC;
        EXEC dbo.KT4SUMMARY_PROC;
        EXEC dbo.KT5SUMMARY_PROC;
        EXEC dbo.KILLPOINTSSUMMARY_PROC;
        EXEC dbo.HEALEDSUMMARY_PROC;
        EXEC dbo.RANGEDSUMMARY_PROC;

        -- Step 2: Clear export table
        TRUNCATE TABLE dbo.SUMMARY_CHANGE_EXPORT;

        -- Step 3: Insert combined summary data with all metrics
        INSERT INTO dbo.SUMMARY_CHANGE_EXPORT
        (
            GOVERNORID,
            GOVERNORNAME,
            [T4&T5_KILLS],
            [StartingT4&T5_KILLS],
            [OverallT4&T5_KILLSDelta],
            [T4&T5_KILLSDelta12Months],
            [T4&T5_KILLSDelta6Months],
            [T4&T5_KILLSDelta3Months],
            [T4_KILLS],
            [StartingT4_KILLS],
            [OverallT4_KILLSDelta],
            [T4_KILLSDelta12Months],
            [T4_KILLSDelta6Months],
            [T4_KILLSDelta3Months],
            [T5_KILLS],
            [StartingT5_KILLS],
            [OverallT5_KILLSDelta],
            [T5_KILLSDelta12Months],
            [T5_KILLSDelta6Months],
            [T5_KILLSDelta3Months],
            [POWER],
            StartingPower,
            OverallPowerDelta,
            PowerDelta12Months,
            PowerDelta6Months,
            PowerDelta3Months,
            DEADS,
            StartingDEADS,
            OverallDEADSDelta,
            DEADSDelta12Months,
            DEADSDelta6Months,
            DEADSDelta3Months,
            HealedTroops,
            StartingHealed,
            OverallHealedDelta,
            HealedDelta12Months,
            HealedDelta6Months,
            HealedDelta3Months,
            RangedPoints,
            StartingRanged,
            OverallRangedDelta,
            RangedDelta12Months,
            RangedDelta6Months,
            RangedDelta3Months,
            KillPoints,
            StartingKillPoints,
            OverallKillPointsDelta,
            KillPointsDelta12Months,
            KillPointsDelta6Months,
            KillPointsDelta3Months
        )
        SELECT 
            P.GOVERNORID,
            P.GOVERNORNAME,
            K.[T4&T5_KILLS],
            K.[StartingT4&T5_KILLS],
            K.[OverallT4&T5_KILLSDelta],
            K.[T4&T5_KILLSDelta12Months],
            K.[T4&T5_KILLSDelta6Months],
            K.[T4&T5_KILLSDelta3Months],
            K4.[T4_KILLS],
            K4.[StartingT4_KILLS],
            K4.[OverallT4_KILLSDelta],
            K4.[T4_KILLSDelta12Months],
            K4.[T4_KILLSDelta6Months],
            K4.[T4_KILLSDelta3Months],
            K5.[T5_KILLS],
            K5.[StartingT5_KILLS],
            K5.[OverallT5_KILLSDelta],
            K5.[T5_KILLSDelta12Months],
            K5.[T5_KILLSDelta6Months],
            K5.[T5_KILLSDelta3Months],
            P.[POWER],
            P.StartingPower,
            P.OverallPowerDelta,
            P.PowerDelta12Months,
            P.PowerDelta6Months,
            P.PowerDelta3Months,
            D.DEADS,
            D.StartingDEADS,
            D.OverallDEADSDelta,
            D.DEADSDelta12Months,
            D.DEADSDelta6Months,
            D.DEADSDelta3Months,
            ISNULL(H.HealedTroops, 0),
            ISNULL(H.StartingHealed, 0),
            ISNULL(H.OverallHealedDelta, 0),
            ISNULL(H.HealedDelta12Months, 0),
            ISNULL(H.HealedDelta6Months, 0),
            ISNULL(H.HealedDelta3Months, 0),
            ISNULL(R.RangedPoints, 0),
            ISNULL(R.StartingRanged, 0),
            ISNULL(R.OverallRangedDelta, 0),
            ISNULL(R.RangedDelta12Months, 0),
            ISNULL(R.RangedDelta6Months, 0),
            ISNULL(R.RangedDelta3Months, 0),
            ISNULL(KP.KillPoints, 0),
            ISNULL(KP.StartingKillPoints, 0),
            ISNULL(KP.OverallKillPointsDelta, 0),
            ISNULL(KP.KillPointsDelta12Months, 0),
            ISNULL(KP.KillPointsDelta6Months, 0),
            ISNULL(KP.KillPointsDelta3Months, 0)
        FROM dbo.POWERSUMMARY AS P
        INNER JOIN dbo.KILL4SUMMARY AS K4 ON P.GOVERNORID = K4.GOVERNORID
        INNER JOIN dbo.KILL5SUMMARY AS K5 ON P.GOVERNORID = K5.GOVERNORID
        INNER JOIN dbo.KILLSUMMARY AS K ON P.GOVERNORID = K.GOVERNORID
        INNER JOIN dbo.DEADSSUMMARY AS D ON P.GOVERNORID = D.GOVERNORID
        INNER JOIN dbo.HEALEDSUMMARY AS H ON P.GOVERNORID = H.GOVERNORID
        INNER JOIN dbo.RANGEDSUMMARY AS R ON P.GOVERNORID = R.GOVERNORID
        INNER JOIN dbo.KILLPOINTSSUMMARY AS KP ON P.GOVERNORID = KP.GOVERNORID
		ORDER BY P.GOVERNORNAME;

        MERGE dbo.SUMMARY_PROC_STATE AS T
        USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
        ON T.MetricName = S.MetricName
        WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
        WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime) VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        -- Error logging and rethrowing
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE
            @ErrorMessage NVARCHAR(4000),
            @ErrorSeverity INT,
            @ErrorState INT;

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;

