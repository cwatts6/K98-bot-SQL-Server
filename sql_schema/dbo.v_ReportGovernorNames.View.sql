SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.v_ReportGovernorNames
AS
-- One current display name per identity. Alias history remains ALL_GOVS_NAMES.
-- Ignore empty observations; use the newest known name and a binary tie-break.
WITH Names AS (
    SELECT GovernorID, RTRIM(GovernorName) AS GovernorName,
           ROW_NUMBER() OVER (
               PARTITION BY GovernorID
               ORDER BY ScanOrder DESC,
                        RTRIM(GovernorName) COLLATE Latin1_General_100_BIN2 ASC
           ) AS NameOrder
    FROM dbo.KingdomScanData4
    WHERE GovernorID IS NOT NULL AND GovernorID <> 0
      AND GovernorID NOT IN (999999997,999999998,999999999)
      AND NULLIF(LTRIM(RTRIM(GovernorName)),N'') IS NOT NULL
)
SELECT GovernorID, GovernorName FROM Names WHERE NameOrder=1;
