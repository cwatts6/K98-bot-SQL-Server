SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PlayerKVK_Last3]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PlayerKVK_Last3]  AS 
WITH last3 AS (
    SELECT TOP (3) KVK_NUMBER
    FROM dbo.PlayerKVKHistory
    GROUP BY KVK_NUMBER
    ORDER BY KVK_NUMBER DESC
)
SELECT
    pkh.GovernorID,
    pkh.KVK_NUMBER,
    pkh.KVK_KILL_RANK,
    -- Convert to numeric in case the source sometimes stores ''xx%'' as text.
    -- If you prefer the raw value, replace the line below with: pkh.KillPercent
    TRY_CONVERT(decimal(9,2), REPLACE(CONVERT(varchar(50), pkh.KillPercent), ''%'','''')) AS KillPercent
FROM dbo.PlayerKVKHistory AS pkh
INNER JOIN last3 AS l
    ON l.KVK_NUMBER = pkh.KVK_NUMBER;


'
