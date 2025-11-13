SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KT5SUMMARY_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[KT5SUMMARY_PROC] AS' 
END
ALTER PROCEDURE [dbo].[KT5SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
  
  
-- Truncate tables
TRUNCATE TABLE KILL5SUMMARY;
TRUNCATE TABLE K5ALL;
TRUNCATE TABLE K512;
TRUNCATE TABLE K56;
TRUNCATE TABLE K53;
TRUNCATE TABLE [LATEST_T5_KILLS];
TRUNCATE TABLE K53D;
TRUNCATE TABLE K56D;
TRUNCATE TABLE K512D;

-- Define CTEs first

DROP TABLE IF EXISTS #BASEDATA
    
	SELECT 
        GovernorID,
        GovernorName,
        [T5_KILLS],
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

INSERT INTO K5ALL (GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL)
SELECT GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL 
FROM RankedKALL;


WITH RankedK12 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc12,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc12
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -12, GETDATE())
)

INSERT INTO K512 (GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12)
SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12 
FROM RankedK12;

WITH RankedK6 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc6,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc6
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -6, GETDATE())
)

INSERT INTO K56 (GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6)
SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6 
FROM RankedK6;

WITH RankedK3 AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder ASC) AS RowAsc3,
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS RowDesc3
    FROM #BASEDATA
    WHERE ScanDate >= DATEADD(MONTH, -3, GETDATE())
) 

INSERT INTO K53 (GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3)
SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3 
FROM RankedK3;

WITH LatestScan AS (
    SELECT *, 
        ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn
    FROM #BASEDATA
)

INSERT INTO [LATEST_T5_KILLS] (GovernorID, GovernorName, POWERRank, [T5_KILLS])
SELECT GovernorID, GovernorName, POWERRank, [T5_KILLS]
FROM LatestScan 
WHERE rn = 1 AND GovernorID <> 0;


-- kills delta calculations
INSERT INTO K53D (GovernorID, [T5_KILLSDelta3Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K53.RowDesc3 = 1 THEN K53.[T5_KILLS] END) - MAX(CASE WHEN K53.RowAsc3 = 1 THEN K53.[T5_KILLS] END) as [T5_KILLSDelta3Months]
FROM [LATEST_T5_KILLS] L
LEFT JOIN K53 ON L.GovernorID = K53.GovernorID
GROUP BY L.GovernorID;

INSERT INTO K56D (GovernorID, [T5_KILLSDelta6Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K56.RowDesc6 = 1 THEN K56.[T5_KILLS] END) - MAX(CASE WHEN K56.RowAsc6 = 1 THEN K56.[T5_KILLS] END) AS [T5_KILLSDelta6Months]
	FROM [LATEST_T5_KILLS] L
LEFT JOIN K56 ON L.GovernorID = K56.GovernorID
GROUP BY L.GovernorID;

INSERT INTO K512D (GovernorID, [T5_KILLSDelta12Months])
SELECT 
    L.GovernorID,
    MAX(CASE WHEN K512.RowDesc12 = 1 THEN K512.[T5_KILLS] END) - MAX(CASE WHEN K512.RowAsc12 = 1 THEN K512.[T5_KILLS] END) as [T5_KILLSDelta12Months]
FROM [LATEST_T5_KILLS] L
LEFT JOIN K512 ON L.GovernorID = K512.GovernorID
GROUP BY L.GovernorID;



-- Final aggregation
INSERT INTO KILL5SUMMARY (
    GovernorID, GovernorName, 
	POWERRank, 
	[T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta]
      ,[T5_KILLSDelta12Months]
      ,[T5_KILLSDelta6Months]
      ,[T5_KILLSDelta3Months]
 
)
SELECT 
    L.GovernorID, L.GovernorName, 
	POWERRank, 
	L.[T5_KILLS],
    MAX(CASE WHEN K5ALL.RowAscALL = 1 THEN K5ALL.[T5_KILLS] END) AS [StartingT5_KILLS],
    MAX(CASE WHEN K5ALL.RowDescALL = 1 THEN K5ALL.[T5_KILLS] END) - MAX(CASE WHEN K5ALL.RowAscALL = 1 THEN K5ALL.[T5_KILLS] END) AS [OverallT5_KILLSDelta],
    ISNULL(K512D.[T5_KILLSDelta12Months], 0) as [T5_KILLSDelta12Months] ,
    ISNULL(K56D.[T5_KILLSDelta6Months], 0) as [T5_KILLSDelta6Months],
    ISNULL(K53D.[T5_KILLSDelta3Months], 0) as[T5_KILLSDelta3Months]
	FROM [LATEST_T5_KILLS] L
JOIN K5ALL ON L.GovernorID = K5ALL.GovernorID
LEFT JOIN K512D ON L.GovernorID = K512D.GovernorID
LEFT JOIN K56D ON L.GovernorID = K56D.GovernorID
LEFT JOIN K53D ON L.GovernorID = K53D.GovernorID
GROUP BY 
    L.GovernorID, L.GovernorName, L.POWERRank, L.[T5_KILLS],
    K512D.[T5_KILLSDelta12Months], K56D.[T5_KILLSDelta6Months], K53D.[T5_KILLSDelta3Months];

-- Aggregates
INSERT INTO KILL5SUMMARY
SELECT 999999997, 'Top50', 50,
       ROUND(AVG([T5_KILLS]), 0),
       ROUND(AVG([StartingT5_KILLS]), 0),
       ROUND(AVG([OverallT5_KILLSDelta]), 0),
       ROUND(AVG([T5_KILLSDelta12Months]), 0),
       ROUND(AVG([T5_KILLSDelta6Months]), 0),
       ROUND(AVG([T5_KILLSDelta3Months]), 0)
FROM KILL5SUMMARY WHERE POWERRank <= 50;

INSERT INTO KILL5SUMMARY
SELECT 999999998, 'Top100', 100,
      ROUND(AVG([T5_KILLS]), 0),
       ROUND(AVG([StartingT5_KILLS]), 0),
       ROUND(AVG([OverallT5_KILLSDelta]), 0),
       ROUND(AVG([T5_KILLSDelta12Months]), 0),
       ROUND(AVG([T5_KILLSDelta6Months]), 0),
       ROUND(AVG([T5_KILLSDelta3Months]), 0)
FROM KILL5SUMMARY WHERE POWERRank <= 100;

INSERT INTO KILL5SUMMARY
SELECT 999999999, 'Kingdom Average', 150,
      ROUND(AVG([T5_KILLS]), 0),
       ROUND(AVG([StartingT5_KILLS]), 0),
       ROUND(AVG([OverallT5_KILLSDelta]), 0),
       ROUND(AVG([T5_KILLSDelta12Months]), 0),
       ROUND(AVG([T5_KILLSDelta6Months]), 0),
       ROUND(AVG([T5_KILLSDelta3Months]), 0)
FROM KILL5SUMMARY WHERE POWERRank <= 150;

END;

