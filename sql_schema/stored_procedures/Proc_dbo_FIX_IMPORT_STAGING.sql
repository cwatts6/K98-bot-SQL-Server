SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FIX_IMPORT_STAGING]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[FIX_IMPORT_STAGING] AS' 
END
ALTER PROCEDURE [dbo].[FIX_IMPORT_STAGING]
WITH EXECUTE AS CALLER
AS
BEGIN
    -- SQL statements go here

DECLARE @DT DATETIME

-- Set the variable using SELECT
SELECT @DT = CONVERT(DATETIME, 
    STUFF(STUFF(SUBSTRING(Updated_on, 1, 7), 3, 0, '-'), 7, 0, '-') + ' ' +
    REPLACE(REPLACE(SUBSTRING(Updated_on, 9, LEN(Updated_on) - 8), 'h', ':'), 'm', '')
)
FROM IMPORT_STAGING;

UPDATE IMPORT_STAGING -- 
--SET SCANDATE = @CurrentDate
SET SCANDATE = @DT

SELECT [Governor ID],
 SUM([T4-Kills] + [T5-Kills]) AS [Kills (T4+)],
 SUM([T1-Kills]+[T2-KILLS]+[T3-KILLS]+[T4-Kills]+[T5-Kills]) AS KILLS
 INTO #Killsum
FROM IMPORT_STAGING
GROUP BY [Governor ID]

UPDATE IMPORT_STAGING
SET IMPORT_STAGING.[Kills (T4+)] = KS.[Kills (T4+)],
 IMPORT_STAGING.KILLS = KS.KILLS
FROM IMPORT_STAGING
JOIN #Killsum AS KS ON  IMPORT_STAGING.[Governor ID] = KS.[Governor ID]

DROP TABLE #killsum


UPDATE IMPORT_STAGING -- SET SCANORDER TO BE NEXT NUMBER
--SET SCANORDER = '148'
SET SCANORDER = (SELECT MAX(SCANORDER) +1 FROM KingdomScanData4) 


UPDATE IMPORT_STAGING -- FIX ALLIANCE SCAN NAME
SET ALLIANCE = '[k98A]SparTanS' 
WHERE ALLIANCE = '[k98A]SparTanS$S'

UPDATE IMPORT_STAGING -- FIX ALLIANCE SCAN NAME
SET ALLIANCE = '[K98B]TrojanS' 
WHERE ALLIANCE = '[K98B]Trojan$S';



---FIX SCAN ISSUES---
-- Step 1: Precompute latest scan data
WITH LatestScan AS (
    SELECT *
    FROM KingdomScanData4
    WHERE SCANORDER = (SELECT MAX(SCANORDER) FROM KingdomScanData4)
)

-- Step 2: Update all fields in one go
UPDATE I
SET 
    [Total Kill Points] = CASE WHEN I.[Total Kill Points] < K.KillPoints THEN K.KillPoints ELSE I.[Total Kill Points] END,
    [Dead Troops] = CASE WHEN I.[Dead Troops] < K.Deads THEN K.Deads ELSE I.[Dead Troops] END,
    [T1-Kills] = CASE WHEN I.[T1-Kills] < K.T1_Kills THEN K.T1_Kills ELSE I.[T1-Kills] END,
    [T2-Kills] = CASE WHEN I.[T2-Kills] < K.T2_Kills THEN K.T2_Kills ELSE I.[T2-Kills] END,
    [T3-Kills] = CASE WHEN I.[T3-Kills] < K.T3_Kills THEN K.T3_Kills ELSE I.[T3-Kills] END,
    [T4-Kills] = CASE WHEN I.[T4-Kills] < K.T4_Kills THEN K.T4_Kills ELSE I.[T4-Kills] END,
    [T5-Kills] = CASE WHEN I.[T5-Kills] < K.T5_Kills THEN K.T5_Kills ELSE I.[T5-Kills] END,
    [Kills (T4+)] = CASE WHEN I.[Kills (T4+)] < K.[T4&T5_KILLS] THEN K.[T4&T5_KILLS] ELSE I.[Kills (T4+)] END,
    [KILLS] = CASE WHEN I.[KILLS] < K.[TOTAL_KILLS] THEN K.[TOTAL_KILLS] ELSE I.[KILLS] END,
    [RSS Gathered] = CASE WHEN I.[RSS Gathered] < K.RSS_Gathered THEN K.RSS_Gathered ELSE I.[RSS Gathered] END,
    [RSS Assistance] = CASE WHEN I.[RSS Assistance] < K.RSSAssistance THEN K.RSSAssistance ELSE I.[RSS Assistance] END,
    [Alliance Helps] = CASE WHEN I.[Alliance Helps] < K.Helps THEN K.Helps ELSE I.[Alliance Helps] END
FROM IMPORT_STAGING AS I
JOIN LatestScan AS K ON I.[Governor ID] = K.GovernorID;


	END;
