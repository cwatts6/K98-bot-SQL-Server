SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILLSSUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[KILLSSUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[KILLSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN

-- Truncate tables
TRUNCATE TABLE KILLSUMMARY;
TRUNCATE TABLE KALL;
TRUNCATE TABLE K12;
TRUNCATE TABLE K6;
TRUNCATE TABLE K3;
TRUNCATE TABLE [LATEST_T4&T5_KILLS];
TRUNCATE TABLE K3D;
TRUNCATE TABLE K6D;
TRUNCATE TABLE K12D;

-- Define CTEs first

DROP TABLE IF EXISTS #BASEDATA
    
	SELECT 
        GovernorID,
        GovernorName,
        [T4&T5_KILLS],
        ScanDate,
        ScanOrder,
        PowerRank
		INTO #BASEDATA
    FROM KingdomScanData4;

WITH 
RankedKALL AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAscALL,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDescALL
    FROM #BaseData
)

INSERT INTO KALL (GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL)
SELECT GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL 
FROM RankedKALL;


WITH RankedK12 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc12,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc12
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -12, GETDATE())
)

INSERT INTO K12 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12)
SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12 
FROM RankedK12;

WITH RankedK6 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc6,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc6
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -6, GETDATE())
)

INSERT INTO K6 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6)
SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6 
FROM RankedK6;

WITH RankedK3 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc3,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc3
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -3, GETDATE())
) 

INSERT INTO K3 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3)
SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3 
FROM RankedK3;

WITH LatestScan AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
    FROM #BASEDATA
)

INSERT INTO [LATEST_T4&T5_KILLS] (GovernorID, GovernorName, POWERRank, [T4&T5_KILLS])
SELECT GovernorID, GovernorName, POWERRank, [T4&T5_KILLS]
FROM LatestScan 
WHERE rn = 1 AND GovernorID <> 0;


-- kills delta calculations
INSERT INTO K3D (GovernorID, [T4&T5_KILLSDelta3Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K3.RowDesc3 = 1 THEN K3.[T4&T5_KILLS] END) - MAX(CASE WHEN K3.RowAsc3 = 1 THEN K3.[T4&T5_KILLS] END)
FROM [LATEST_T4&T5_KILLS] L
LEFT JOIN K3 ON L.GovernorID = K3.GovernorID
GROUP BY L.GovernorID;

INSERT INTO K6D (GovernorID, [T4&T5_KILLSDelta6Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K6.RowDesc6 = 1 THEN K6.[T4&T5_KILLS] END) - MAX(CASE WHEN K6.RowAsc6 = 1 THEN K6.[T4&T5_KILLS] END)
	FROM [LATEST_T4&T5_KILLS] L
LEFT JOIN K6 ON L.GovernorID = K6.GovernorID
GROUP BY L.GovernorID;

INSERT INTO K12D (GovernorID, [T4&T5_KILLSDelta12Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K12.RowDesc12 = 1 THEN K12.[T4&T5_KILLS] END) - MAX(CASE WHEN K12.RowAsc12 = 1 THEN K12.[T4&T5_KILLS] END) as [T4&T5_KILLSDelta12Months]
FROM [LATEST_T4&T5_KILLS] L
LEFT JOIN K12 ON L.GovernorID = K12.GovernorID
GROUP BY L.GovernorID;

-- Final aggregation
INSERT INTO KILLSUMMARY (
    GovernorID, GovernorName, 
	POWERRank, 
	[T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta]
      ,[T4&T5_KILLSDelta12Months]
      ,[T4&T5_KILLSDelta6Months]
      ,[T4&T5_KILLSDelta3Months]
 
)
SELECT 
    L.GovernorID, L.GovernorName, 
	POWERRank, 
	L.[T4&T5_KILLS],
    MAX(CASE WHEN KALL.RowAscALL = 1 THEN KALL.[T4&T5_KILLS] END) AS [StartingT4&T5_KILLS],
    MAX(CASE WHEN KALL.RowDescALL = 1 THEN KALL.[T4&T5_KILLS] END) - MAX(CASE WHEN KALL.RowAscALL = 1 THEN KALL.[T4&T5_KILLS] END) AS [OverallT4&T5_KILLSDelta],
    ISNULL(K12D.[T4&T5_KILLSDelta12Months], 0) as [T4&T5_KILLSDelta12Months] ,
    ISNULL(K6D.[T4&T5_KILLSDelta6Months], 0) as [T4&T5_KILLSDelta6Months],
    ISNULL(K3D.[T4&T5_KILLSDelta3Months], 0) as[T4&T5_KILLSDelta3Months]
	FROM [LATEST_T4&T5_KILLS] L
JOIN KALL ON L.GovernorID = KALL.GovernorID
LEFT JOIN K12D ON L.GovernorID = K12D.GovernorID
LEFT JOIN K6D ON L.GovernorID = K6D.GovernorID
LEFT JOIN K3D ON L.GovernorID = K3D.GovernorID
GROUP BY 
    L.GovernorID, L.GovernorName, L.POWERRank, L.[T4&T5_KILLS],
    K12D.[T4&T5_KILLSDelta12Months], K6D.[T4&T5_KILLSDelta6Months], K3D.[T4&T5_KILLSDelta3Months];

-- Aggregates
INSERT INTO KILLSUMMARY
SELECT 999999997, 'Top50', 50,
       ROUND(AVG([T4&T5_KILLS]), 0),
       ROUND(AVG([StartingT4&T5_KILLS]), 0),
       ROUND(AVG([OverallT4&T5_KILLSDelta]), 0),
       ROUND(AVG([T4&T5_KILLSDelta12Months]), 0),
       ROUND(AVG([T4&T5_KILLSDelta6Months]), 0),
       ROUND(AVG([T4&T5_KILLSDelta3Months]), 0)
FROM KILLSUMMARY WHERE POWERRank <= 50;

INSERT INTO KILLSUMMARY
SELECT 999999998, 'Top100', 100,
      ROUND(AVG([T4&T5_KILLS]), 0),
       ROUND(AVG([StartingT4&T5_KILLS]), 0),
       ROUND(AVG([OverallT4&T5_KILLSDelta]), 0),
       ROUND(AVG([T4&T5_KILLSDelta12Months]), 0),
       ROUND(AVG([T4&T5_KILLSDelta6Months]), 0),
       ROUND(AVG([T4&T5_KILLSDelta3Months]), 0)
FROM KILLSUMMARY WHERE POWERRank <= 100;

INSERT INTO KILLSUMMARY
SELECT 999999999, 'Kingdom Average', 150,
      ROUND(AVG([T4&T5_KILLS]), 0),
       ROUND(AVG([StartingT4&T5_KILLS]), 0),
       ROUND(AVG([OverallT4&T5_KILLSDelta]), 0),
       ROUND(AVG([T4&T5_KILLSDelta12Months]), 0),
       ROUND(AVG([T4&T5_KILLSDelta6Months]), 0),
       ROUND(AVG([T4&T5_KILLSDelta3Months]), 0)
FROM KILLSUMMARY WHERE POWERRank <= 150;

END;


