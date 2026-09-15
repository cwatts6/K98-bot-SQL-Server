SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_GetKvkHistorySummaryMetricRanks]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_GetKvkHistorySummaryMetricRanks] AS' 
END
ALTER PROCEDURE [dbo].[usp_GetKvkHistorySummaryMetricRanks]
	@GovernorID [bigint],
	@FinalizedKvkNos [dbo].[IntList] READONLY
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @GovernorID <= 0
        THROW 51531, 'KVK history rank lookup requires a positive Governor ID.', 1;
    IF NOT EXISTS (SELECT 1 FROM @FinalizedKvkNos)
       OR (SELECT COUNT(*) FROM @FinalizedKvkNos) > 20
       OR EXISTS (SELECT 1 FROM @FinalizedKvkNos WHERE ID <= 0)
        THROW 51533, 'KVK history ranks require between 1 and 20 finalized KVK numbers.', 1;

    ;WITH SourceRows AS
    (
        SELECT TRY_CONVERT(bigint, history.[Gov_ID]) AS Gov_ID,
               TRY_CONVERT(int, history.[KVK_NO]) AS KVK_NO,
               TRY_CONVERT(decimal(38,8), history.[Acclaim]) AS Acclaim,
               TRY_CONVERT(decimal(38,8), history.[T4&T5_Kills]) AS Kills,
               TRY_CONVERT(decimal(38,8), history.[KillPointsDelta]) AS KillPoints,
               TRY_CONVERT(decimal(38,8), history.[Deads_Delta]) AS Deads,
               TRY_CONVERT(decimal(38,8), history.[HealedTroopsDelta]) AS Healed,
               TRY_CONVERT(decimal(38,8), history.[DKP_SCORE]) AS DKP,
               TRY_CONVERT(decimal(38,8), history.[Max_PreKvk_Points]) AS PreKvk,
               TRY_CONVERT(decimal(38,8), history.[Max_HonorPoints]) AS Honor,
               combat.TankingScore,
               combat.IsEngaged
        FROM dbo.v_EXCEL_FOR_KVK_All AS history
        JOIN @FinalizedKvkNos AS finalized
          ON finalized.ID = TRY_CONVERT(int, history.KVK_NO)
        JOIN dbo.KVKFinalReportHeader AS final_header
          ON final_header.KVK_NO = history.KVK_NO
         AND final_header.State = N'OUTPUT_COMPLETE'
        CROSS APPLY dbo.fn_KvkCombatMetrics
        (
            TRY_CONVERT(bigint, history.[KillPointsDelta]),
            TRY_CONVERT(bigint, history.[HealedTroopsDelta]),
            TRY_CONVERT(bigint, history.[Deads_Delta]),
            TRY_CONVERT(bigint, history.[T4&T5_Kills])
        ) AS combat
    ),
    MetricRows AS
    (
        SELECT N'Highest Acclaim' AS Metric, Gov_ID, KVK_NO, Acclaim AS MetricValue
        FROM SourceRows WHERE Acclaim > 0
        UNION ALL SELECT N'Most Kills', Gov_ID, KVK_NO, Kills FROM SourceRows WHERE Kills > 0
        UNION ALL SELECT N'Most KillPoints', Gov_ID, KVK_NO, KillPoints
        FROM SourceRows WHERE KillPoints > 0
        UNION ALL SELECT N'Most Deads', Gov_ID, KVK_NO, Deads FROM SourceRows WHERE Deads > 0
        UNION ALL SELECT N'Lowest Healed', Gov_ID, KVK_NO, Healed
        FROM SourceRows WHERE IsEngaged = 1 AND Healed IS NOT NULL
        UNION ALL SELECT N'Most DKP', Gov_ID, KVK_NO, DKP FROM SourceRows WHERE DKP > 0
        UNION ALL
        SELECT N'Highest Tanking Score', Gov_ID, KVK_NO, TankingScore
        FROM SourceRows
        WHERE IsEngaged = 1 AND TankingScore IS NOT NULL
        UNION ALL SELECT N'Most Pre-KVK', Gov_ID, KVK_NO, PreKvk
        FROM SourceRows WHERE PreKvk > 0
        UNION ALL SELECT N'Most Honor', Gov_ID, KVK_NO, Honor FROM SourceRows WHERE Honor > 0
    ),
    Ranked AS
    (
        SELECT Metric, Gov_ID, KVK_NO, MetricValue,
               RANK() OVER
               (
                   PARTITION BY Metric
                   ORDER BY CASE WHEN Metric = N'Lowest Healed' THEN MetricValue END ASC,
                            CASE WHEN Metric <> N'Lowest Healed' THEN MetricValue END DESC
               ) AS Overall_Rank
        FROM MetricRows WHERE MetricValue IS NOT NULL
    )
    SELECT Metric, Gov_ID, KVK_NO, MetricValue, Overall_Rank
    FROM Ranked
    WHERE Gov_ID = @GovernorID
    ORDER BY Metric, KVK_NO;
END;

