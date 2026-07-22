/*
RollbackForMigrationId: 20260722_002_add_leadership_kvk_index_contract
Purpose: Restore the prior Tanking eligibility and leadership KVK result contract
Author: cwatts
CreatedUtc: 2026-07-22
DataChange: No
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER FUNCTION dbo.fn_KvkCombatMetrics
(
    @KillPoints bigint,
    @HealedTroops bigint,
    @Deads bigint,
    @T4T5Kills bigint
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
        CASE WHEN @HealedTroops IS NULL THEN CONVERT(decimal(38,0), NULL)
             ELSE CONVERT(decimal(38,0), @HealedTroops) * 20 END AS KPLoss,
        CASE WHEN @KillPoints IS NULL OR @HealedTroops IS NULL OR @Deads IS NULL
                  OR CONVERT(decimal(38,0), @HealedTroops) * 20 + @Deads <= 0
             THEN CONVERT(decimal(38,8), NULL)
             ELSE CONVERT(decimal(38,8),
                 -- decimal(38,8) division collapses to scale 6 before the final cast.
                 -- These precisions cover BIGINT inputs and retain the required 8 digits.
                 CONVERT(decimal(20,1), @KillPoints)
                 / NULLIF(CONVERT(decimal(22,1),
                     CONVERT(decimal(38,0), @HealedTroops) * 20 + @Deads), 0)
                 * 100.0) END AS TankingScore,
        CONVERT(bit, CASE WHEN @KillPoints > 0
                              AND (@T4T5Kills > 0 OR @Deads > 0 OR @HealedTroops > 0)
                         THEN 1 ELSE 0 END) AS IsEngaged
);
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetLeadershipPlayerKvkHistory
    @GovernorID bigint,
    @CandidateLimit tinyint = 12
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @GovernorID <= 0
        THROW 51521, 'Leadership KVK history requires a positive Governor ID.', 1;
    IF @CandidateLimit < 3 OR @CandidateLimit > 20
        THROW 51522, 'Leadership KVK candidate limit must be between 3 and 20.', 1;

    DECLARE @PersonalCompletedKvkBestAcclaim bigint =
    (
        SELECT MAX(TRY_CONVERT(bigint, history.Acclaim))
        FROM dbo.v_EXCEL_FOR_KVK_All AS history
        JOIN dbo.KVKFinalReportHeader AS final_header
          ON final_header.KVK_NO = TRY_CONVERT(int, history.KVK_NO)
         AND final_header.State = N'OUTPUT_COMPLETE'
        WHERE TRY_CONVERT(bigint, history.Gov_ID) = @GovernorID
    );

    CREATE TABLE #Candidates
    (
        KVK_NO int NOT NULL PRIMARY KEY,
        KVK_NAME nvarchar(100) NULL,
        KVK_REGISTRATION_DATE date NULL,
        KVK_START_DATE date NULL,
        KVK_END_DATE date NULL,
        MATCHMAKING_SCAN int NULL,
        KVK_END_SCAN int NULL,
        MATCHMAKING_START_DATE date NULL,
        FIGHTING_START_DATE date NULL,
        PASS4_START_SCAN int NULL
    );
    INSERT INTO #Candidates
    SELECT TOP (@CandidateLimit)
           KVK_NO, KVK_NAME, KVK_REGISTRATION_DATE, KVK_START_DATE, KVK_END_DATE,
           MATCHMAKING_SCAN, KVK_END_SCAN, MATCHMAKING_START_DATE,
           FIGHTING_START_DATE, PASS4_START_SCAN
    FROM dbo.KVK_Details
    ORDER BY KVK_NO DESC;

    /* Result set 1: resolver inputs plus independent final-output evidence. */
    SELECT candidates.KVK_NO, candidates.KVK_NAME,
           candidates.KVK_REGISTRATION_DATE, candidates.KVK_START_DATE,
           candidates.KVK_END_DATE, candidates.MATCHMAKING_SCAN,
           candidates.KVK_END_SCAN, candidates.MATCHMAKING_START_DATE,
           candidates.FIGHTING_START_DATE, candidates.PASS4_START_SCAN,
           final_header.FinalDataAtUtc, final_header.FinalScanOrder,
           final_header.OutputRowCount, final_header.State AS FinalOutputState,
           final_header.FinalizationBasis
    FROM #Candidates AS candidates
    LEFT JOIN dbo.KVKFinalReportHeader AS final_header
      ON final_header.KVK_NO = candidates.KVK_NO
    ORDER BY candidates.KVK_NO DESC;

    CREATE TABLE #Calculated
    (
        KVK_NO int NOT NULL,
        GovernorID bigint NOT NULL,
        GovernorName nvarchar(255) NULL,
        KVKRank int NULL,
        T4T5Kills bigint NULL,
        KillTarget bigint NULL,
        KillTargetPercent decimal(18,4) NULL,
        KillPoints bigint NULL,
        Deads bigint NULL,
        DeadTarget bigint NULL,
        DeadTargetPercent decimal(18,4) NULL,
        Healed bigint NULL,
        KPLoss decimal(38,0) NULL,
        TankingScore decimal(38,8) NULL,
        Acclaim bigint NULL,
        DKP bigint NULL,
        DKPTarget bigint NULL,
        DKPTargetPercent decimal(18,4) NULL,
        PreKvkPoints bigint NULL,
        PreKvkRank int NULL,
        HonorPoints bigint NULL,
        HonorRank int NULL,
        IsExempt bit NOT NULL,
        IsEngaged bit NOT NULL,
        PRIMARY KEY CLUSTERED (KVK_NO, GovernorID)
    );

    ;WITH SourceRows AS
    (
        SELECT TRY_CONVERT(int, history.KVK_NO) AS KVK_NO,
               TRY_CONVERT(bigint, history.Gov_ID) AS GovernorID,
               CONVERT(nvarchar(255), history.Governor_Name) AS GovernorName,
               TRY_CONVERT(int, history.KVK_RANK) AS KVKRank,
               TRY_CONVERT(bigint, history.[T4&T5_Kills]) AS T4T5Kills,
               TRY_CONVERT(bigint, history.[Kill Target]) AS KillTarget,
               COALESCE(
                   TRY_CONVERT(decimal(18,4), history.[% of Kill Target]),
                   TRY_CONVERT(decimal(18,4),
                       TRY_CONVERT(decimal(38,8), history.[T4&T5_Kills])
                       / NULLIF(TRY_CONVERT(decimal(38,8), history.[Kill Target]), 0)
                       * 100.0)
               ) AS KillTargetPercent,
               TRY_CONVERT(bigint, history.KillPointsDelta) AS KillPoints,
               TRY_CONVERT(bigint, history.Deads_Delta) AS Deads,
               TRY_CONVERT(bigint, history.Dead_Target) AS DeadTarget,
               COALESCE(
                   TRY_CONVERT(decimal(18,4), history.[% of Dead Target]),
                   TRY_CONVERT(decimal(18,4),
                       TRY_CONVERT(decimal(38,8), history.Deads_Delta)
                       / NULLIF(TRY_CONVERT(decimal(38,8), history.Dead_Target), 0)
                       * 100.0)
               ) AS DeadTargetPercent,
               TRY_CONVERT(bigint, history.HealedTroopsDelta) AS Healed,
               TRY_CONVERT(bigint, history.Acclaim) AS Acclaim,
               TRY_CONVERT(bigint, history.DKP_SCORE) AS DKP,
               TRY_CONVERT(bigint, history.[DKP Target]) AS DKPTarget,
               COALESCE(
                   TRY_CONVERT(decimal(18,4), history.[% of DKP Target]),
                   TRY_CONVERT(decimal(18,4),
                       TRY_CONVERT(decimal(38,8), history.DKP_SCORE)
                       / NULLIF(TRY_CONVERT(decimal(38,8), history.[DKP Target]), 0)
                       * 100.0)
               ) AS DKPTargetPercent,
               TRY_CONVERT(bigint, history.Max_PreKvk_Points) AS PreKvkPoints,
               TRY_CONVERT(int, history.PreKvk_Rank) AS PreKvkRank,
               TRY_CONVERT(bigint, history.Max_HonorPoints) AS HonorPoints,
               TRY_CONVERT(int, history.Honor_Rank) AS HonorRank,
               CONVERT(bit, CASE WHEN EXISTS
                    (SELECT 1 FROM dbo.EXEMPT_FROM_STATS AS exemption
                     WHERE TRY_CONVERT(bigint, exemption.GovernorID) = history.Gov_ID
                       AND ISNULL(exemption.Exempt, 1) = 1
                       AND TRY_CONVERT(int, exemption.KVK_NO) IN (0, history.KVK_NO))
                    THEN 1 ELSE 0 END) AS IsExempt
        FROM dbo.v_EXCEL_FOR_KVK_All AS history
        JOIN #Candidates AS candidates ON candidates.KVK_NO = history.KVK_NO
        JOIN dbo.KVKFinalReportHeader AS final_header
          ON final_header.KVK_NO = history.KVK_NO
         AND final_header.State = N'OUTPUT_COMPLETE'
    )
    INSERT INTO #Calculated
    SELECT source.KVK_NO, source.GovernorID, source.GovernorName, source.KVKRank,
           source.T4T5Kills, source.KillTarget, source.KillTargetPercent,
           source.KillPoints, source.Deads, source.DeadTarget, source.DeadTargetPercent,
           source.Healed, combat.KPLoss, combat.TankingScore,
           source.Acclaim, source.DKP, source.DKPTarget, source.DKPTargetPercent,
           source.PreKvkPoints, source.PreKvkRank, source.HonorPoints, source.HonorRank,
           source.IsExempt, combat.IsEngaged
    FROM SourceRows AS source
    CROSS APPLY dbo.fn_KvkCombatMetrics
        (source.KillPoints, source.Healed, source.Deads, source.T4T5Kills) AS combat
    WHERE source.GovernorID > 0;

    CREATE TABLE #EngagedRanks
    (
        KVK_NO int NOT NULL,
        GovernorID bigint NOT NULL,
        HealedRank int NULL,
        TankingRank int NULL,
        EngagedCohortCount int NOT NULL,
        TankingCohortCount int NOT NULL,
        PRIMARY KEY CLUSTERED (KVK_NO, GovernorID)
    );
    ;WITH Ranked AS
    (
        SELECT KVK_NO, GovernorID,
               RANK() OVER (PARTITION BY KVK_NO ORDER BY Healed ASC) AS HealedRank,
               CASE WHEN TankingScore IS NOT NULL
                    THEN RANK() OVER
                        (PARTITION BY KVK_NO, CASE WHEN TankingScore IS NULL THEN 1 ELSE 0 END
                         ORDER BY TankingScore DESC) END AS TankingRank,
               COUNT(*) OVER (PARTITION BY KVK_NO) AS EngagedCohortCount,
               COUNT(TankingScore) OVER (PARTITION BY KVK_NO) AS TankingCohortCount
        FROM #Calculated
        WHERE IsEngaged = 1 AND Healed IS NOT NULL
    )
    INSERT INTO #EngagedRanks
    SELECT KVK_NO, GovernorID, HealedRank, TankingRank,
           EngagedCohortCount, TankingCohortCount
    FROM Ranked;

    /* Result set 2: player final rows and canonical combat ranks. */
    SELECT calculated.KVK_NO, calculated.GovernorID, calculated.GovernorName,
           calculated.KVKRank, calculated.T4T5Kills, calculated.KillTarget,
           calculated.KillTargetPercent, calculated.KillPoints, calculated.Deads,
           calculated.DeadTarget, calculated.DeadTargetPercent, calculated.Healed,
           calculated.KPLoss, calculated.TankingScore, calculated.Acclaim,
           @PersonalCompletedKvkBestAcclaim AS PersonalCompletedKvkBestAcclaim,
           calculated.DKP, calculated.DKPTarget, calculated.DKPTargetPercent,
           calculated.PreKvkPoints, calculated.PreKvkRank,
           calculated.HonorPoints, calculated.HonorRank,
           calculated.IsExempt, calculated.IsEngaged,
           ranks.HealedRank, ranks.TankingRank,
           ranks.EngagedCohortCount, ranks.TankingCohortCount,
           final_header.FinalDataAtUtc, final_header.State AS FinalOutputState,
           final_header.FinalizationBasis
    FROM #Calculated AS calculated
    LEFT JOIN #EngagedRanks AS ranks
      ON ranks.KVK_NO = calculated.KVK_NO AND ranks.GovernorID = calculated.GovernorID
    LEFT JOIN dbo.KVKFinalReportHeader AS final_header
      ON final_header.KVK_NO = calculated.KVK_NO
    WHERE calculated.GovernorID = @GovernorID
    ORDER BY calculated.KVK_NO DESC;
END;
GO
