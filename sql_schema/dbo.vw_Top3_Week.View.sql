SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_Top3_Week]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vw_Top3_Week]  AS 
WITH DeltaWithTime AS (
    SELECT d.GovernorID, d.BuildingDelta, d.TechDonationDelta,
           h.SnapshotTsUtc, h.WeekStartUtc
    FROM dbo.AllianceActivityDelta d
    JOIN dbo.AllianceActivitySnapshotHeader h ON h.SnapshotId = d.SnapshotId
)

SELECT TOP (3)
    dw.GovernorID,
    SUM(dw.TechDonationDelta)    AS TechDonationWeek,
    SUM(dw.BuildingDelta)        AS BuildingWeek
FROM DeltaWithTime dw
WHERE dw.WeekStartUtc =
      DATEADD(day, 1 - DATEPART(weekday, SYSUTCDATETIME() AT TIME ZONE ''UTC''),
              CONVERT(date, SYSUTCDATETIME())) -- computed Monday 00:00 UTC
GROUP BY dw.GovernorID
ORDER BY TechDonationWeek DESC, BuildingWeek DESC, GovernorID;


'
