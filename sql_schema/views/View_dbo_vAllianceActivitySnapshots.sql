SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vAllianceActivitySnapshots]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vAllianceActivitySnapshots]  AS 
SELECT
    r.GovernorID,
    h.SnapshotId,
    h.SnapshotTsUtc,
    h.WeekStartUtc,                          -- Monday 00:00 UTC
    r.BuildingTotal,                         -- weekly cumulative (resets each week)
    r.TechDonationTotal
FROM dbo.AllianceActivitySnapshotRow  r WITH (NOLOCK)
JOIN dbo.AllianceActivitySnapshotHeader h WITH (NOLOCK)
  ON h.SnapshotId = r.SnapshotId;


'
