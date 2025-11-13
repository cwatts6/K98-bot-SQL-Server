SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Rebuild_v_PlayerKVK_Last3]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Rebuild_v_PlayerKVK_Last3] AS' 
END
ALTER PROCEDURE [dbo].[sp_Rebuild_v_PlayerKVK_Last3]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @k1 int, @k2 int, @k3 int;

    ;WITH last3 AS (
        SELECT KVK_NUMBER,
               ROW_NUMBER() OVER (ORDER BY KVK_NUMBER DESC) AS rn
        FROM (SELECT DISTINCT TOP (3) KVK_NUMBER
              FROM dbo.PlayerKVKHistory
              ORDER BY KVK_NUMBER DESC) d
    )
    SELECT
        @k1 = MAX(CASE WHEN rn = 1 THEN KVK_NUMBER END),
        @k2 = MAX(CASE WHEN rn = 2 THEN KVK_NUMBER END),
        @k3 = MAX(CASE WHEN rn = 3 THEN KVK_NUMBER END)
    FROM last3;

    IF @k1 IS NULL OR @k2 IS NULL OR @k3 IS NULL
    BEGIN
        RAISERROR('Not enough distinct KVK_NUMBERs to build view (need 3).', 16, 1);
        RETURN;
    END

    DECLARE @sql nvarchar(max) = N'
CREATE OR ALTER VIEW dbo.v_PlayerKVK_Last3
AS
WITH latest_scan AS (
    SELECT
        g.GovernorID,
        ks0.[GovernorName],
        ks0.[Alliance],
        ks0.[City Hall],
        ks0.[Power],
        ks0.[Troops Power],
        ks0.[TOTAL_KILLS],
        ks0.[Deads],
        ks0.[RSS_Gathered],
        ks0.[Helps]
    FROM (SELECT DISTINCT GovernorID FROM dbo.KingdomScanData4) AS g
    CROSS APPLY (
        SELECT TOP (1) ks.*
        FROM dbo.KingdomScanData4 AS ks
        WHERE ks.GovernorID = g.GovernorID
        ORDER BY ks.[SCANORDER] DESC
    ) AS ks0
    WHERE ks0.[Power] > 40000000
),
pkh AS (
    SELECT
        GovernorID,
        KVK_NUMBER,
        TRY_CONVERT(decimal(9,2), REPLACE(CONVERT(varchar(50), KillPercent), ''%'', '''')) AS KillPercent
        -- , KVK_KILL_RANK  -- uncomment if you want rank too
    FROM dbo.PlayerKVKHistory
    WHERE KVK_NUMBER IN (' + CAST(@k1 as nvarchar(10)) + N',' + CAST(@k2 as nvarchar(10)) + N',' + CAST(@k3 as nvarchar(10)) + N')
),
pivoted AS (
    SELECT
        GovernorID,
        MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k1 as nvarchar(10)) + N' THEN KVK_NUMBER END)   AS [KVK_' + CAST(@k1 as nvarchar(10)) + N'_Number],
        MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k1 as nvarchar(10)) + N' THEN KillPercent END)  AS [KVK_' + CAST(@k1 as nvarchar(10)) + N'_KillPercent],
        MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k2 as nvarchar(10)) + N' THEN KVK_NUMBER END)   AS [KVK_' + CAST(@k2 as nvarchar(10)) + N'_Number],
        MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k2 as nvarchar(10)) + N' THEN KillPercent END)  AS [KVK_' + CAST(@k2 as nvarchar(10)) + N'_KillPercent],
        MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k3 as nvarchar(10)) + N' THEN KVK_NUMBER END)   AS [KVK_' + CAST(@k3 as nvarchar(10)) + N'_Number],
        MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k3 as nvarchar(10)) + N' THEN KillPercent END)  AS [KVK_' + CAST(@k3 as nvarchar(10)) + N'_KillPercent]
        -- , MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k1 as nvarchar(10)) + N' THEN KVK_KILL_RANK END) AS [KVK_' + CAST(@k1 as nvarchar(10)) + N'_KillRank]
        -- , MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k2 as nvarchar(10)) + N' THEN KVK_KILL_RANK END) AS [KVK_' + CAST(@k2 as nvarchar(10)) + N'_KillRank]
        -- , MAX(CASE WHEN KVK_NUMBER = ' + CAST(@k3 as nvarchar(10)) + N' THEN KVK_KILL_RANK END) AS [KVK_' + CAST(@k3 as nvarchar(10)) + N'_KillRank]
    FROM pkh
    GROUP BY GovernorID
)
SELECT
    ls.GovernorID,
    ls.[GovernorName]      AS [Governor_Name],
    ls.[Alliance]          AS [Alliance],
    ls.[City Hall]         AS [CityHallLevel],
    ls.[Power]             AS [Power],
    ls.[Troops Power]      AS [Troop Power],
    ls.[TOTAL_KILLS]       AS [Kills],
    ls.[Deads]             AS [Deads],
    ls.[RSS_Gathered]      AS [RSS_Gathered],
    ls.[Helps]             AS [Helps],
    p.[KVK_' + CAST(@k1 as nvarchar(10)) + N'_Number],
    p.[KVK_' + CAST(@k1 as nvarchar(10)) + N'_KillPercent],
    p.[KVK_' + CAST(@k2 as nvarchar(10)) + N'_Number],
    p.[KVK_' + CAST(@k2 as nvarchar(10)) + N'_KillPercent],
    p.[KVK_' + CAST(@k3 as nvarchar(10)) + N'_Number],
    p.[KVK_' + CAST(@k3 as nvarchar(10)) + N'_KillPercent],
    CONCAT(loc.X, '','', loc.Y) AS [Location]
FROM latest_scan AS ls
LEFT JOIN pivoted AS p
    ON p.GovernorID = ls.GovernorID
OUTER APPLY (
    SELECT TOP (1) pl.X, pl.Y
    FROM dbo.PlayerLocation AS pl
    WHERE pl.GovernorID = ls.GovernorID
      AND pl.X IS NOT NULL AND pl.Y IS NOT NULL
      AND pl.X <> 0 AND pl.Y <> 0
    ORDER BY pl.[LastUpdated] DESC
) AS loc;
';

    EXEC sys.sp_executesql @sql;
END

