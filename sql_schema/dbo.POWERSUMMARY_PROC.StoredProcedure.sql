SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[POWERSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[POWERSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[POWERSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
  
 -- Truncate tables
TRUNCATE TABLE POWERSUMMARY;
TRUNCATE TABLE PALL;
TRUNCATE TABLE P12;
TRUNCATE TABLE P6;
TRUNCATE TABLE P3;
TRUNCATE TABLE LATEST_POWER;
TRUNCATE TABLE P3D;
TRUNCATE TABLE P6D;
TRUNCATE TABLE P12D;

-- Define CTEs first

DROP TABLE IF EXISTS #BASEDATA
    
	SELECT 
        GovernorID,
        GovernorName,
        [POWER],
        ScanDate,
        ScanOrder,
        PowerRank
		INTO #BASEDATA
    FROM KingdomScanData4;

WITH 
RankedPALL AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAscALL,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDescALL
    FROM #BaseData
)

INSERT INTO PALL (GovernorID, GovernorName, POWER, ScanDate, RowAscALL, RowDescALL)
SELECT GovernorID, GovernorName, POWER, ScanDate, RowAscALL, RowDescALL 
FROM RankedPALL;


WITH RankedP12 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc12,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc12
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -12, GETDATE())
)

INSERT INTO P12 (GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12)
SELECT GovernorID, POWER, ScanDate, RowAsc12, RowDesc12 
FROM RankedP12;

WITH RankedP6 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc6,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc6
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -6, GETDATE())
)

INSERT INTO P6 (GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6)
SELECT GovernorID, POWER, ScanDate, RowAsc6, RowDesc6 

FROM RankedP6;

WITH RankedP3 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc3,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc3
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -3, GETDATE())
) 

INSERT INTO P3 (GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3)
SELECT GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3 
FROM RankedP3;

WITH LatestScan AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
    FROM #BASEDATA
)

INSERT INTO LATEST_POWER (GovernorID, GovernorName, PowerRank, [POWER])
SELECT GovernorID, GovernorName, PowerRank, [POWER] 
FROM LatestScan 
WHERE rn = 1 AND GovernorID <> 0;


-- Dead delta calculations
INSERT INTO P3D (GovernorID, POWERDelta3Months)
SELECT 
    L.GovernorID,
    MAX(CASE WHEN P3.RowDesc3 = 1 THEN P3.[POWER] END) - MAX(CASE WHEN P3.RowAsc3 = 1 THEN P3.[POWER] END)
FROM LATEST_POWER L
LEFT JOIN P3 ON L.GovernorID = P3.GovernorID
GROUP BY L.GovernorID;

INSERT INTO P6D (GovernorID, POWERDelta6Months)
SELECT 
    L.GovernorID,
    MAX(CASE WHEN P6.RowDesc6 = 1 THEN P6.[POWER] END) - MAX(CASE WHEN P6.RowAsc6 = 1 THEN P6.[POWER] END)
FROM LATEST_POWER L
LEFT JOIN P6 ON L.GovernorID = P6.GovernorID
GROUP BY L.GovernorID;

INSERT INTO P12D (GovernorID, POWERDelta12Months)
SELECT 
    L.GovernorID,
    MAX(CASE WHEN P12.RowDesc12 = 1 THEN P12.[POWER] END) - MAX(CASE WHEN P12.RowAsc12 = 1 THEN P12.[POWER] END)
FROM LATEST_POWER L
LEFT JOIN P12 ON L.GovernorID = P12.GovernorID
GROUP BY L.GovernorID;

-- Final aggregation
INSERT INTO POWERSUMMARY (
    GovernorID, GovernorName, PowerRank, [POWER],
    StartingPOWER, OverallPOWERDelta,
    POWERDelta12Months, POWERDelta6Months, POWERDelta3Months
)
SELECT 
    L.GovernorID, L.GovernorName, L.PowerRank, L.[POWER],
    MAX(CASE WHEN PALL.RowAscALL = 1 THEN PALL.[POWER] END) AS StartingPOWER,
    MAX(CASE WHEN PALL.RowDescALL = 1 THEN PALL.[POWER] END) - MAX(CASE WHEN PALL.RowAscALL = 1 THEN PALL.[POWER] END) AS OverallPOWERDelta,
    ISNULL(P12D.POWERDelta12Months, 0),
    ISNULL(P6D.POWERDelta6Months, 0),
    ISNULL(P3D.POWERDelta3Months, 0)
FROM LATEST_POWER L
JOIN PALL ON L.GovernorID = PALL.GovernorID
LEFT JOIN P12D ON L.GovernorID = P12D.GovernorID
LEFT JOIN P6D ON L.GovernorID = P6D.GovernorID
LEFT JOIN P3D ON L.GovernorID = P3D.GovernorID
GROUP BY 
    L.GovernorID, L.GovernorName, L.PowerRank, L.[POWER],
    P12D.POWERDelta12Months, P6D.POWERDelta6Months, P3D.POWERDelta3Months;

-- Aggregates
INSERT INTO POWERSUMMARY
SELECT 999999997, 'Top50', 50,
       ROUND(AVG([POWER]), 0),
       ROUND(AVG(StartingPOWER), 0),
       ROUND(AVG(OverallPOWERDelta), 0),
       ROUND(AVG(POWERDelta12Months), 0),
       ROUND(AVG(POWERDelta6Months), 0),
       ROUND(AVG(POWERDelta3Months), 0)
FROM POWERSUMMARY WHERE PowerRank <= 50;

INSERT INTO POWERSUMMARY
SELECT 999999998, 'Top100', 100,
       ROUND(AVG([POWER]), 0),
       ROUND(AVG(StartingPOWER), 0),
       ROUND(AVG(OverallPOWERDelta), 0),
       ROUND(AVG(POWERDelta12Months), 0),
       ROUND(AVG(POWERDelta6Months), 0),
       ROUND(AVG(POWERDelta3Months), 0)
FROM POWERSUMMARY WHERE PowerRank <= 100;

INSERT INTO POWERSUMMARY
SELECT 999999999, 'Kingdom Average', 150,
       ROUND(AVG([POWER]), 0),
       ROUND(AVG(StartingPOWER), 0),
       ROUND(AVG(OverallPOWERDelta), 0),
       ROUND(AVG(POWERDelta12Months), 0),
       ROUND(AVG(POWERDelta6Months), 0),
       ROUND(AVG(POWERDelta3Months), 0)
FROM POWERSUMMARY WHERE PowerRank <= 150;

DROP TABLE IF EXISTS #BASEDATA

END;


