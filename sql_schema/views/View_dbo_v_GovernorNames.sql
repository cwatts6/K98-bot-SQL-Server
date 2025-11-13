SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_GovernorNames]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_GovernorNames]  AS 
WITH Latest AS (
    SELECT
        ks.GovernorID,
        ks.GovernorName,
        ks.Alliance,
        ks.SCANORDER,
        ks.AsOfDate,
        ks.ScanDate,
        ROW_NUMBER() OVER (
            PARTITION BY ks.GovernorID
            ORDER BY ks.SCANORDER DESC,
                     ks.AsOfDate  DESC,
                     ks.ScanDate  DESC
        ) AS rn
    FROM dbo.KingdomScanData4 AS ks WITH (NOLOCK)
),
L AS (
    SELECT *
    FROM Latest
    WHERE rn = 1
)
SELECT
    L.GovernorID,

    -- Name: prefer latest row; if blank/null, fall back to most recent non-empty historically
    COALESCE(
        NULLIF(LTRIM(RTRIM(L.GovernorName)), ''''),
        NF.GovernorName
    ) AS GovernorName,

    -- Alliance: prefer latest row; if blank/null, fall back to most recent non-empty historically
    COALESCE(
        NULLIF(LTRIM(RTRIM(L.Alliance)), ''''),
        AF.Alliance
    ) AS Alliance,

    L.SCANORDER AS LastSeenScanOrder,
    L.AsOfDate  AS LastSeenDateUtc
FROM L
OUTER APPLY (
    SELECT TOP (1)
        LTRIM(RTRIM(k.GovernorName)) AS GovernorName
    FROM dbo.KingdomScanData4 k WITH (NOLOCK)
    WHERE k.GovernorID = L.GovernorID
      AND k.GovernorName IS NOT NULL
      AND LTRIM(RTRIM(k.GovernorName)) <> ''''
    ORDER BY k.SCANORDER DESC, k.AsOfDate DESC, k.ScanDate DESC
) NF
OUTER APPLY (
    SELECT TOP (1)
        LTRIM(RTRIM(k.Alliance)) AS Alliance
    FROM dbo.KingdomScanData4 k WITH (NOLOCK)
    WHERE k.GovernorID = L.GovernorID
      AND k.Alliance IS NOT NULL
      AND LTRIM(RTRIM(k.Alliance)) <> ''''
    ORDER BY k.SCANORDER DESC, k.AsOfDate DESC, k.ScanDate DESC
) AF;


'
