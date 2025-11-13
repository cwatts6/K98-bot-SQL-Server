SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PlayerFortsLatest]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PlayerFortsLatest]  AS 
WITH L AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SnapshotAt DESC) AS rn
  FROM dbo.PlayerFortsHistory WITH (NOLOCK)
)
SELECT GovernorID, FortsStarted, FortsJoined, FortsTotal, SnapshotAt
FROM L
WHERE rn = 1;


'
