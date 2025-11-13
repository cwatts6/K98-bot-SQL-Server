SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vDaily_AllianceActivity]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vDaily_AllianceActivity]  AS 
/* 1) Pull all snapshots with their day and cumulative totals */
WITH Snap AS (
    SELECT
        CAST(H.SnapshotTsUtc AS date)          AS DeltaDateUtc,
        H.SnapshotTsUtc,
        R.SnapshotId,
        R.GovernorID,
        R.GovernorName,
        R.AllianceTag,
        R.BuildingTotal       AS BuildingCum,
        R.TechDonationTotal   AS TechCum
    FROM dbo.AllianceActivitySnapshotRow AS R
    JOIN dbo.AllianceActivitySnapshotHeader AS H
      ON H.SnapshotId = R.SnapshotId
),
/* 2) Keep the LAST snapshot per (date, governor) */
DayEnd AS (
    SELECT
        DeltaDateUtc,
        GovernorID,
        GovernorName,
        AllianceTag,
        BuildingCum,
        TechCum,
        ROW_NUMBER() OVER (
            PARTITION BY DeltaDateUtc, GovernorID
            ORDER BY SnapshotTsUtc DESC, SnapshotId DESC
        ) AS rn
    FROM Snap
),
DayEndOnly AS (
    SELECT
        DeltaDateUtc,
        GovernorID,
        GovernorName,
        AllianceTag,
        BuildingCum,
        TechCum
    FROM DayEnd
    WHERE rn = 1
),
/* 3) Compare today''s last vs prior day''s last (skipping missing days automatically) */
WithPrev AS (
    SELECT
        DeltaDateUtc,
        GovernorID,
        GovernorName,
        AllianceTag,
        BuildingCum,
        TechCum,
        LAG(BuildingCum) OVER (
            PARTITION BY GovernorID
            ORDER BY DeltaDateUtc
        ) AS PrevBuildingCum,
        LAG(TechCum) OVER (
            PARTITION BY GovernorID
            ORDER BY DeltaDateUtc
        ) AS PrevTechCum
    FROM DayEndOnly
)
SELECT
    DeltaDateUtc,
    GovernorID,
    GovernorName,
    AllianceTag,
    CASE
        WHEN PrevBuildingCum IS NULL THEN BuildingCum
        WHEN BuildingCum >= PrevBuildingCum THEN BuildingCum - PrevBuildingCum
        ELSE BuildingCum        -- counter reset within/between days
    END AS BuildingDelta,
    CASE
        WHEN PrevTechCum IS NULL THEN TechCum
        WHEN TechCum >= PrevTechCum THEN TechCum - PrevTechCum
        ELSE TechCum            -- counter reset within/between days
    END AS TechDonationDelta
FROM WithPrev;


'
