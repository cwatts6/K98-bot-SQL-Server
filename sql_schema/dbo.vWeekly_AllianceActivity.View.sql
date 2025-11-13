SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vWeekly_AllianceActivity]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vWeekly_AllianceActivity]  AS 
/* Snapshots joined with their header (gives us WeekStartUtc + timestamp) */
WITH Snap AS (
    SELECT
        H.WeekStartUtc,
        H.SnapshotTsUtc,
        R.SnapshotId,
        R.GovernorID,
        R.GovernorName,
        R.AllianceTag,
        /* cumulative values from the uploaded workbook */
        R.BuildingTotal        AS BuildingCum,
        R.TechDonationTotal    AS TechCum
    FROM dbo.AllianceActivitySnapshotRow AS R
    JOIN dbo.AllianceActivitySnapshotHeader AS H
      ON H.SnapshotId = R.SnapshotId
),
/* Per-(week, governor) sequence, get previous cum values for step deltas */
StepDelta AS (
    SELECT
        WeekStartUtc,
        SnapshotTsUtc,
        SnapshotId,
        GovernorID,
        GovernorName,
        AllianceTag,
        BuildingCum,
        TechCum,
        LAG(BuildingCum) OVER (
            PARTITION BY WeekStartUtc, GovernorID
            ORDER BY SnapshotTsUtc, SnapshotId
        ) AS PrevBuildingCum,
        LAG(TechCum) OVER (
            PARTITION BY WeekStartUtc, GovernorID
            ORDER BY SnapshotTsUtc, SnapshotId
        ) AS PrevTechCum,
        ROW_NUMBER() OVER (
            PARTITION BY WeekStartUtc, GovernorID
            ORDER BY SnapshotTsUtc DESC, SnapshotId DESC
        ) AS rn_latest_meta
    FROM Snap
),
/* Turn cumulative streams into step deltas; guard for mid-week resets */
Deltas AS (
    SELECT
        WeekStartUtc,
        GovernorID,
        CASE
            WHEN PrevBuildingCum IS NULL THEN BuildingCum
            WHEN BuildingCum >= PrevBuildingCum THEN BuildingCum - PrevBuildingCum
            ELSE BuildingCum               -- counter reset within the week
        END AS BuildingDelta,
        CASE
            WHEN PrevTechCum IS NULL THEN TechCum
            WHEN TechCum >= PrevTechCum THEN TechCum - PrevTechCum
            ELSE TechCum                   -- counter reset within the week
        END AS TechDonationDelta,
        CASE WHEN rn_latest_meta = 1 THEN GovernorName END AS GovernorNameLatest,
        CASE WHEN rn_latest_meta = 1 THEN AllianceTag  END AS AllianceTagLatest
    FROM StepDelta
),
/* Aggregate weekly totals and keep latest name/tag for display */
Agg AS (
    SELECT
        WeekStartUtc,
        GovernorID,
        SUM(BuildingDelta)        AS BuildingDelta,
        SUM(TechDonationDelta)    AS TechDonationDelta,
        MAX(GovernorNameLatest)   AS GovernorName,
        MAX(AllianceTagLatest)    AS AllianceTag
    FROM Deltas
    GROUP BY WeekStartUtc, GovernorID
)
SELECT
    WeekStartUtc,
    GovernorID,
    BuildingDelta,
    TechDonationDelta,
    GovernorName,
    AllianceTag
FROM Agg;


'
