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
    SET NOCOUNT ON;

IF @@TRANCOUNT <> 0
    THROW 51833, 'FIX_IMPORT_STAGING refuses caller-owned transactions; execute the public entry point with no active transaction.', 1;

SET XACT_ABORT ON;

DECLARE @DT DATETIME;
DECLARE @ImportLockResult INT;
DECLARE @CurrentMaxScanOrder INT;
DECLARE @NextScanOrder INT;

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
        @LockTimeout = 60000,
        @LockResult = @ImportLockResult OUTPUT;

    IF @ImportLockResult < 0
        THROW 51830, 'FIX_IMPORT_STAGING could not acquire the KingdomScanData4 import mutex within 60000 ms; staging was not changed.', 1;

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


SELECT @CurrentMaxScanOrder = ISNULL(MAX(scan_max.ScanOrder), 0)
FROM
(
    SELECT MAX(SCANORDER) AS ScanOrder
    FROM dbo.KingdomScanData4 WITH (UPDLOCK, HOLDLOCK)

    UNION ALL

    SELECT MAX(SCANORDER)
    FROM dbo.KingdomScanData5 WITH (UPDLOCK, HOLDLOCK)

    UNION ALL

    SELECT MAX(ScanOrder)
    FROM dbo.KS4_ImportFileReceipt WITH (UPDLOCK, HOLDLOCK)
) AS scan_max;

IF @CurrentMaxScanOrder = 2147483647
    THROW 51831, 'Import SCANORDER exhausted the int range; allocation refused.', 1;

SET @NextScanOrder = @CurrentMaxScanOrder + 1;

UPDATE IMPORT_STAGING
SET SCANORDER = @NextScanOrder;

IF EXISTS
(
    SELECT 1
    FROM dbo.IMPORT_STAGING
    GROUP BY SCANORDER, [Governor ID]
    HAVING COUNT_BIG(*) > 1
)
    THROW 51832, 'FIX_IMPORT_STAGING rejected duplicate (SCANORDER, Governor ID) keys.', 1;


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

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
END;
