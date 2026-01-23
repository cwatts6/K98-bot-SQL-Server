SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Loop_ExcelOutput_ByKVK]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Loop_ExcelOutput_ByKVK] AS' 
END
ALTER PROCEDURE [dbo].[sp_Loop_ExcelOutput_ByKVK]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @KVKVersion INT;

    DECLARE kvk_cursor_loop CURSOR FOR
        SELECT DISTINCT KVKVersion FROM dbo.ProcConfig ORDER BY KVKVersion;

    -- Ensure delta tables exist/are created
    EXEC dbo.CREATE_DELTA_TABLES;

    OPEN kvk_cursor_loop;
    FETCH NEXT FROM kvk_cursor_loop INTO @KVKVersion;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE
            @CURRENTKVK3 INT,
            @KVK_END_SCAN INT,
            @LASTKVKEND INT,
            @MATCHMAKING_SCAN INT,
            @PASS4END INT,
            @PASS6END INT,
            @PASS7END INT,
            @PRE_PASS_4_SCAN INT,
            @MaxAvailableScan INT;

        SELECT
            @CURRENTKVK3      = MAX(CASE WHEN ConfigKey='CURRENTKVK3'      THEN TRY_CAST(ConfigValue AS INT) END),
            @KVK_END_SCAN     = MAX(CASE WHEN ConfigKey='KVK_END_SCAN'     THEN TRY_CAST(ConfigValue AS INT) END),
            @LASTKVKEND       = MAX(CASE WHEN ConfigKey='LASTKVKEND'       THEN TRY_CAST(ConfigValue AS INT) END),
            @MATCHMAKING_SCAN = MAX(CASE WHEN ConfigKey='MATCHMAKING_SCAN' THEN TRY_CAST(ConfigValue AS INT) END),
            @PASS4END         = MAX(CASE WHEN ConfigKey='PASS4END'         THEN TRY_CAST(ConfigValue AS INT) END),
            @PASS6END         = MAX(CASE WHEN ConfigKey='PASS6END'         THEN TRY_CAST(ConfigValue AS INT) END),
            @PASS7END         = MAX(CASE WHEN ConfigKey='PASS7END'         THEN TRY_CAST(ConfigValue AS INT) END),
            @PRE_PASS_4_SCAN  = MAX(CASE WHEN ConfigKey='PRE_PASS_4_SCAN'  THEN TRY_CAST(ConfigValue AS INT) END)
        FROM dbo.ProcConfig
        WHERE KVKVersion = @KVKVersion;

        -- Reset staging
        TRUNCATE TABLE dbo.STAGING_STATS;

        -- Cap to latest available scan to avoid future scans
        SELECT @MaxAvailableScan = MAX(ScanOrder) FROM dbo.KingdomScanData4;
        IF @MATCHMAKING_SCAN > @MaxAvailableScan SET @MATCHMAKING_SCAN = @MaxAvailableScan;

        IF @CURRENTKVK3 IS NOT NULL AND @MATCHMAKING_SCAN IS NOT NULL
        BEGIN
            -- Delegate per-KVK work to canonical proc
            EXEC dbo.sp_ExcelOutput_ByKVK @KVK = @CURRENTKVK3, @Scan = @MATCHMAKING_SCAN;
        END

        FETCH NEXT FROM kvk_cursor_loop INTO @KVKVersion;
    END

    CLOSE kvk_cursor_loop;
    DEALLOCATE kvk_cursor_loop;
END;

