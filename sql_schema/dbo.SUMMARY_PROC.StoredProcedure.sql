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

    BEGIN TRY
        -- Step 1: Execute dependent procedures (add healing, ranged, and new killpoints summaries)
        EXEC DEADSSUMMARY_PROC;
        EXEC POWERSUMMARY_PROC;
        EXEC KILLSSUMMARY_PROC;
        EXEC KT4SUMMARY_PROC;
        EXEC KT5SUMMARY_PROC;
        EXEC KILLPOINTSSUMMARY_PROC;   -- NEW: compute KillPoints summary
        EXEC HEALEDSUMMARY_PROC;
        EXEC RANGEDSUMMARY_PROC;

        -- Step 2: Clear export table
        TRUNCATE TABLE SUMMARY_CHANGE_EXPORT;

        -- Step 3: Insert combined summary data including Healed, Ranged, and KillPoints metrics
        INSERT INTO SUMMARY_CHANGE_EXPORT
        SELECT 
            P.GOVERNORID,
            P.GOVERNORNAME,
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
            [T5_Kills],
            [StartingT5_Kills],
            [OverallT5_KillsDelta],
            [T5_KillsDelta12Months],
            [T5_KillsDelta6Months],
            [T5_KillsDelta3Months],
            P.[POWER],
            P.[StartingPower],
            P.[OverallPowerDelta],
            P.[PowerDelta12Months],
            P.[PowerDelta6Months],
            P.[PowerDelta3Months],
            D.[DEADS],
            D.[StartingDEADS],
            D.[OverallDEADSDelta],
            D.[DEADSDelta12Months],
            D.[DEADSDelta6Months],
            D.[DEADSDelta3Months],

            -- Healed summary fields (nullable, fallback 0)
            ISNULL(H.HealedTroops, 0)           AS HealedTroops,
            ISNULL(H.StartingHealed, 0)         AS StartingHealed,
            ISNULL(H.OverallHealedDelta, 0)     AS OverallHealedDelta,
            ISNULL(H.HealedDelta12Months, 0)    AS HealedDelta12Months,
            ISNULL(H.HealedDelta6Months, 0)     AS HealedDelta6Months,
            ISNULL(H.HealedDelta3Months, 0)     AS HealedDelta3Months,

            -- Ranged summary fields
            ISNULL(R.RangedPoints, 0)           AS RangedPoints,
            ISNULL(R.StartingRanged, 0)         AS StartingRanged,
            ISNULL(R.OverallRangedDelta, 0)     AS OverallRangedDelta,
            ISNULL(R.RangedDelta12Months, 0)    AS RangedDelta12Months,
            ISNULL(R.RangedDelta6Months, 0)     AS RangedDelta6Months,
            ISNULL(R.RangedDelta3Months, 0)     AS RangedDelta3Months,

            -- KillPoints summary fields (NEW — nullable/fallbacks)
            ISNULL(KP.KillPoints, 0)            AS KillPoints,
            ISNULL(KP.StartingKillPoints, 0)    AS StartingKillPoints,
            ISNULL(KP.OverallKillPointsDelta, 0) AS OverallKillPointsDelta,
            ISNULL(KP.KillPointsDelta12Months, 0) AS KillPointsDelta12Months,
            ISNULL(KP.KillPointsDelta6Months, 0)  AS KillPointsDelta6Months,
            ISNULL(KP.KillPointsDelta3Months, 0)  AS KillPointsDelta3Months
        FROM POWERSUMMARY AS P
        JOIN KILL4summary AS K4 ON P.GOVERNORID = K4.GOVERNORID
        JOIN KILL5SUMMARY AS K5 ON P.GOVERNORID = K5.GOVERNORID
        JOIN KILLSUMMARY AS K ON P.GOVERNORID = K.GOVERNORID
        JOIN DEADSSUMMARY AS D ON P.GOVERNORID = D.GOVERNORID
        JOIN HEALEDSUMMARY AS H ON P.GOVERNORID = H.GOVERNORID
        JOIN RANGEDSUMMARY AS R ON P.GOVERNORID = R.GOVERNORID
        LEFT JOIN KILLPOINTSSUMMARY AS KP ON P.GOVERNORID = KP.GOVERNORID
        ORDER BY P.GOVERNORNAME;

        -- Step 4: Return result (optional)
        --SELECT * FROM SUMMARY_CHANGE_EXPORT;
    END TRY
    BEGIN CATCH
        -- Error logging and rethrowing
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

