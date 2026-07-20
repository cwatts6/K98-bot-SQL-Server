SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
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
                 CONVERT(decimal(38,8), @KillPoints)
                 / NULLIF(CONVERT(decimal(38,8),
                     CONVERT(decimal(38,0), @HealedTroops) * 20 + @Deads), 0)
                 * 100.0) END AS TankingScore,
        CONVERT(bit, CASE WHEN @KillPoints > 0
                              AND (@T4T5Kills > 0 OR @Deads > 0 OR @HealedTroops > 0)
                         THEN 1 ELSE 0 END) AS IsEngaged
);
