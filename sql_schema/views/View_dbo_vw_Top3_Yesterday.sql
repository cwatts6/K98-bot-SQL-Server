SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_Top3_Yesterday]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vw_Top3_Yesterday]  AS 
WITH DeltaWithTime AS (
    SELECT d.GovernorID, d.BuildingDelta, d.TechDonationDelta,
           h.SnapshotTsUtc, h.WeekStartUtc
    FROM dbo.AllianceActivityDelta d
    JOIN dbo.AllianceActivitySnapshotHeader h ON h.SnapshotId = d.SnapshotId
)

SELECT TOP (3)
    dw.GovernorID,
    SUM(dw.TechDonationDelta)    AS TechDonationYesterday,
    SUM(dw.BuildingDelta)        AS BuildingYesterday
FROM DeltaWithTime dw
WHERE CONVERT(date, dw.SnapshotTsUtc AT TIME ZONE ''UTC'') =
      DATEADD(day, -1, CONVERT(date, SYSUTCDATETIME()))
GROUP BY dw.GovernorID
ORDER BY TechDonationYesterday DESC, BuildingYesterday DESC, GovernorID;


'
