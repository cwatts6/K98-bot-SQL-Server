SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PlayerScanMeta]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PlayerScanMeta]  AS 
WITH scan_days AS (
    SELECT DISTINCT CAST(ks.ScanDate AS date) AS ScanDate
    FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
    WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
),
d AS (
    SELECT DISTINCT
        ks.GovernorID,
        CAST(ks.ScanDate AS date) AS ScanDate
    FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
    WHERE ks.GovernorID IS NOT NULL AND ks.GovernorID <> 0
),
ordered AS (
    SELECT
        GovernorID,
        ScanDate,
        LAG(ScanDate) OVER (PARTITION BY GovernorID ORDER BY ScanDate) AS PrevScanDate
    FROM d
),
gaps AS (
    SELECT
        o.GovernorID,
        o.ScanDate,
        o.PrevScanDate,
        -- Count only the days where a scan actually existed between prev and current
        MissedScanDays = CASE
            WHEN o.PrevScanDate IS NULL THEN 0
            ELSE (
                SELECT COUNT(1)
                FROM scan_days sd
                WHERE sd.ScanDate >  o.PrevScanDate
                  AND sd.ScanDate <  o.ScanDate
            )
        END
    FROM ordered o
)
SELECT
    GovernorID,
    MIN(ScanDate) AS FirstScanDate,
    MAX(ScanDate) AS LastScanDate,
    SUM(CASE WHEN MissedScanDays > 30 THEN MissedScanDays ELSE 0 END) AS OfflineDaysOver30
FROM gaps
GROUP BY GovernorID;



'
