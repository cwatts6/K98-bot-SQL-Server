SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DEADSSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[DEADSSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[DEADSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN



-- Truncate tables
TRUNCATE TABLE DEADSSUMMARY;
TRUNCATE TABLE DALL;
TRUNCATE TABLE D12;
TRUNCATE TABLE D6;
TRUNCATE TABLE D3;
TRUNCATE TABLE LATEST;
TRUNCATE TABLE D3D;
TRUNCATE TABLE D6D;
TRUNCATE TABLE D12D;

-- Define CTEs first

DROP TABLE IF EXISTS #BASEDATA
    
	SELECT 
        GovernorID,
        GovernorName,
        [DEADS],
        ScanDate,
        ScanOrder,
        PowerRank
		INTO #BASEDATA
    FROM KingdomScanData4;

WITH 
RankedAll AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAscALL,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDescALL
    FROM #BaseData
)

INSERT INTO DALL (GovernorID, GovernorName, DEADS, ScanDate, RowAscALL, RowDescALL)
SELECT GovernorID, GovernorName, DEADS, ScanDate, RowAscALL, RowDescALL FROM RankedAll;


WITH RankedD12 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc12,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc12
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -12, GETDATE())
)

INSERT INTO D12 (GovernorID, DEADS, ScanDate, RowAsc12, RowDesc12)
SELECT GovernorID, DEADS, ScanDate, RowAsc12, RowDesc12 FROM RankedD12;

WITH RankedD6 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc6,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc6
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -6, GETDATE())
)

INSERT INTO D6 (GovernorID, DEADS, ScanDate, RowAsc6, RowDesc6)
SELECT GovernorID, DEADS, ScanDate, RowAsc6, RowDesc6 FROM RankedD6;

WITH RankedD3 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc3,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc3
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -3, GETDATE())
) 

INSERT INTO D3 (GovernorID, DEADS, ScanDate, RowAsc3, RowDesc3)
SELECT GovernorID, DEADS, ScanDate, RowAsc3, RowDesc3 FROM RankedD3;

WITH LatestScan AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
    FROM #BASEDATA
)

INSERT INTO LATEST (GovernorID, GovernorName, PowerRank, DEADS)
SELECT GovernorID, GovernorName, PowerRank, DEADS 
FROM LatestScan 
WHERE rn = 1 AND GovernorID <> 0;


-- Dead delta calculations
INSERT INTO D3D (GovernorID, DEADSDelta3Months)
SELECT 
    L.GovernorID,
    MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.DEADS END) - MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.DEADS END)
FROM LATEST L
LEFT JOIN D3 ON L.GovernorID = D3.GovernorID
GROUP BY L.GovernorID;

INSERT INTO D6D (GovernorID, DEADSDelta6Months)
SELECT 
    L.GovernorID,
    MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.DEADS END) - MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.DEADS END)
FROM LATEST L
LEFT JOIN D6 ON L.GovernorID = D6.GovernorID
GROUP BY L.GovernorID;

INSERT INTO D12D (GovernorID, DEADSDelta12Months)
SELECT 
    L.GovernorID,
    MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.DEADS END) - MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.DEADS END)
FROM LATEST L
LEFT JOIN D12 ON L.GovernorID = D12.GovernorID
GROUP BY L.GovernorID;

-- Final aggregation
INSERT INTO DEADSSUMMARY (
    GovernorID, GovernorName, PowerRank, DEADS,
    StartingDEADS, OverallDEADSDelta,
    DEADSDelta12Months, DEADSDelta6Months, DEADSDelta3Months
)
SELECT 
    L.GovernorID, L.GovernorName, L.PowerRank, L.DEADS,
    MAX(CASE WHEN DALL.RowAscALL = 1 THEN DALL.DEADS END) AS StartingDEADS,
    MAX(CASE WHEN DALL.RowDescALL = 1 THEN DALL.DEADS END) - MAX(CASE WHEN DALL.RowAscALL = 1 THEN DALL.DEADS END) AS OverallDEADSDelta,
    ISNULL(D12D.DEADSDelta12Months, 0),
    ISNULL(D6D.DEADSDelta6Months, 0),
    ISNULL(D3D.DEADSDelta3Months, 0)
FROM LATEST L
JOIN DALL ON L.GovernorID = DALL.GovernorID
LEFT JOIN D12D ON L.GovernorID = D12D.GovernorID
LEFT JOIN D6D ON L.GovernorID = D6D.GovernorID
LEFT JOIN D3D ON L.GovernorID = D3D.GovernorID
GROUP BY 
    L.GovernorID, L.GovernorName, L.PowerRank, L.DEADS,
    D12D.DEADSDelta12Months, D6D.DEADSDelta6Months, D3D.DEADSDelta3Months;

-- Aggregates
INSERT INTO DEADSSUMMARY
SELECT 999999997, 'Top50', 50,
       ROUND(AVG(DEADS), 0),
       ROUND(AVG(StartingDEADS), 0),
       ROUND(AVG(OverallDEADSDelta), 0),
       ROUND(AVG(DEADSDelta12Months), 0),
       ROUND(AVG(DEADSDelta6Months), 0),
       ROUND(AVG(DEADSDelta3Months), 0)
FROM DEADSSUMMARY WHERE PowerRank <= 50;

INSERT INTO DEADSSUMMARY
SELECT 999999998, 'Top100', 100,
       ROUND(AVG(DEADS), 0),
       ROUND(AVG(StartingDEADS), 0),
       ROUND(AVG(OverallDEADSDelta), 0),
       ROUND(AVG(DEADSDelta12Months), 0),
       ROUND(AVG(DEADSDelta6Months), 0),
       ROUND(AVG(DEADSDelta3Months), 0)
FROM DEADSSUMMARY WHERE PowerRank <= 100;

INSERT INTO DEADSSUMMARY
SELECT 999999999, 'Kingdom Average', 150,
       ROUND(AVG(DEADS), 0),
       ROUND(AVG(StartingDEADS), 0),
       ROUND(AVG(OverallDEADSDelta), 0),
       ROUND(AVG(DEADSDelta12Months), 0),
       ROUND(AVG(DEADSDelta6Months), 0),
       ROUND(AVG(DEADSDelta3Months), 0)
FROM DEADSSUMMARY WHERE PowerRank <= 150;


END;


