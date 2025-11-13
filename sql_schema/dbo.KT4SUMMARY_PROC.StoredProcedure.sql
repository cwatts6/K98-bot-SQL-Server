SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KT4SUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[KT4SUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[KT4SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
   
   
  -- Truncate tables
TRUNCATE TABLE KILL4SUMMARY;
TRUNCATE TABLE K4ALL;
TRUNCATE TABLE K412;
TRUNCATE TABLE K46;
TRUNCATE TABLE K43;
TRUNCATE TABLE [LATEST_T4_KILLS];
TRUNCATE TABLE K43D;
TRUNCATE TABLE K46D;
TRUNCATE TABLE K412D;

-- Define CTEs first

DROP TABLE IF EXISTS #BASEDATA
    
	SELECT 
        GovernorID,
        GovernorName,
        [T4_KILLS],
        ScanDate,
        ScanOrder,
        PowerRank
		INTO #BASEDATA
    FROM KingdomScanData4;

WITH 
RankedK4ALL AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAscALL,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDescALL
    FROM #BaseData
)

INSERT INTO K4ALL (GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL)
SELECT GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL 
FROM RankedK4ALL;


WITH RankedK12 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc12,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc12
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -12, GETDATE())
)

INSERT INTO K412 (GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12)
SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12 
FROM RankedK12;

WITH RankedK6 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc6,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc6
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -6, GETDATE())
)

INSERT INTO K46 (GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6)
SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6 
FROM RankedK6;

WITH RankedK3 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc3,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc3
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -3, GETDATE())
) 

INSERT INTO K43 (GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3)
SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3 
FROM RankedK3;

WITH LatestScan AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
    FROM #BASEDATA
)

INSERT INTO [LATEST_T4_KILLS] (GovernorID, GovernorName, POWERRank, [T4_KILLS])
SELECT GovernorID, GovernorName, POWERRank, [T4_KILLS]
FROM LatestScan 
WHERE rn = 1 AND GovernorID <> 0;


-- kills delta calculations
INSERT INTO K43D (GovernorID, [T4_KILLSDelta3Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K43.RowDesc3 = 1 THEN K43.[T4_KILLS] END) - MAX(CASE WHEN K43.RowAsc3 = 1 THEN K43.[T4_KILLS] END) as [T4_KILLSDelta3Months]
FROM [LATEST_T4_KILLS] L
LEFT JOIN K43 ON L.GovernorID = K43.GovernorID
GROUP BY L.GovernorID;

INSERT INTO K46D (GovernorID, [T4_KILLSDelta6Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K46.RowDesc6 = 1 THEN K46.[T4_KILLS] END) - MAX(CASE WHEN K46.RowAsc6 = 1 THEN K46.[T4_KILLS] END) AS [T4_KILLSDelta6Months]
	FROM [LATEST_T4_KILLS] L
LEFT JOIN K46 ON L.GovernorID = K46.GovernorID
GROUP BY L.GovernorID;

INSERT INTO K412D (GovernorID, [T4_KILLSDelta12Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K412.RowDesc12 = 1 THEN K412.[T4_KILLS] END) - MAX(CASE WHEN K412.RowAsc12 = 1 THEN K412.[T4_KILLS] END) as [T4_KILLSDelta12Months]
FROM [LATEST_T4_KILLS] L
LEFT JOIN K412 ON L.GovernorID = K412.GovernorID
GROUP BY L.GovernorID;



-- Final aggregation
INSERT INTO KILL4SUMMARY (
    GovernorID, GovernorName, 
	POWERRank, 
	[T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta]
      ,[T4_KILLSDelta12Months]
      ,[T4_KILLSDelta6Months]
      ,[T4_KILLSDelta3Months]
 
)
SELECT 
    L.GovernorID, L.GovernorName, 
	POWERRank, 
	L.[T4_KILLS],
    MAX(CASE WHEN K4ALL.RowAscALL = 1 THEN K4ALL.[T4_KILLS] END) AS [StartingT4_KILLS],
    MAX(CASE WHEN K4ALL.RowDescALL = 1 THEN K4ALL.[T4_KILLS] END) - MAX(CASE WHEN K4ALL.RowAscALL = 1 THEN K4ALL.[T4_KILLS] END) AS [OverallT4_KILLSDelta],
    ISNULL(K412D.[T4_KILLSDelta12Months], 0) as [T4_KILLSDelta12Months] ,
    ISNULL(K46D.[T4_KILLSDelta6Months], 0) as [T4_KILLSDelta6Months],
    ISNULL(K43D.[T4_KILLSDelta3Months], 0) as[T4_KILLSDelta3Months]
	FROM [LATEST_T4_KILLS] L
JOIN K4ALL ON L.GovernorID = K4ALL.GovernorID
LEFT JOIN K412D ON L.GovernorID = K412D.GovernorID
LEFT JOIN K46D ON L.GovernorID = K46D.GovernorID
LEFT JOIN K43D ON L.GovernorID = K43D.GovernorID
GROUP BY 
    L.GovernorID, L.GovernorName, L.POWERRank, L.[T4_KILLS],
    K412D.[T4_KILLSDelta12Months], K46D.[T4_KILLSDelta6Months], K43D.[T4_KILLSDelta3Months];

-- Aggregates
INSERT INTO KILL4SUMMARY
SELECT 999999997, 'Top50', 50,
       ROUND(AVG([T4_KILLS]), 0),
       ROUND(AVG([StartingT4_KILLS]), 0),
       ROUND(AVG([OverallT4_KILLSDelta]), 0),
       ROUND(AVG([T4_KILLSDelta12Months]), 0),
       ROUND(AVG([T4_KILLSDelta6Months]), 0),
       ROUND(AVG([T4_KILLSDelta3Months]), 0)
FROM KILL4SUMMARY WHERE POWERRank <= 50;

INSERT INTO KILL4SUMMARY
SELECT 999999998, 'Top100', 100,
      ROUND(AVG([T4_KILLS]), 0),
       ROUND(AVG([StartingT4_KILLS]), 0),
       ROUND(AVG([OverallT4_KILLSDelta]), 0),
       ROUND(AVG([T4_KILLSDelta12Months]), 0),
       ROUND(AVG([T4_KILLSDelta6Months]), 0),
       ROUND(AVG([T4_KILLSDelta3Months]), 0)
FROM KILL4SUMMARY WHERE POWERRank <= 100;

INSERT INTO KILL4SUMMARY
SELECT 999999999, 'Kingdom Average', 150,
      ROUND(AVG([T4_KILLS]), 0),
       ROUND(AVG([StartingT4_KILLS]), 0),
       ROUND(AVG([OverallT4_KILLSDelta]), 0),
       ROUND(AVG([T4_KILLSDelta12Months]), 0),
       ROUND(AVG([T4_KILLSDelta6Months]), 0),
       ROUND(AVG([T4_KILLSDelta3Months]), 0)
FROM KILL4SUMMARY WHERE POWERRank <= 150;

END;


