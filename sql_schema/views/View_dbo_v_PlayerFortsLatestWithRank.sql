SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PlayerFortsLatestWithRank]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PlayerFortsLatestWithRank]  AS 
WITH L AS (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SnapshotAt DESC) AS rn
  FROM dbo.PlayerFortsHistory WITH (NOLOCK)
),
C AS (
  SELECT GovernorID, FortsStarted, FortsJoined, FortsTotal, SnapshotAt
  FROM L WHERE rn = 1
)
SELECT
  C.*,
  RANK() OVER (ORDER BY C.FortsTotal DESC) AS FortsRank
FROM C;


'
