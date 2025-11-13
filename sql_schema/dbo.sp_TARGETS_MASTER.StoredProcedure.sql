SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_TARGETS_MASTER]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_TARGETS_MASTER] AS' 
END
ALTER PROCEDURE [dbo].[sp_TARGETS_MASTER]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE @aw_on bit = 1;  -- marker to restore later
	SET ANSI_WARNINGS OFF;

    BEGIN TRY
        -- Defensive cursor cleanup (handles both local/global)
		IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
		BEGIN
			IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
			DEALLOCATE kvk_cursor_master;
		END
		IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
		BEGIN
			IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
			DEALLOCATE kvk_cursor_master;
		END;

        DECLARE @KVK INT
              , @Now DATETIME = GETDATE()
              , @ConfiguredScan FLOAT
              , @DraftScan FLOAT
              , @MaxAvailableScan FLOAT
              , @Scan FLOAT;

        -- Build the KVK list from ANY of the two keys so we don't miss ones with only DRAFTSCAN
        DECLARE kvk_cursor_master CURSOR LOCAL FAST_FORWARD FOR
			SELECT DISTINCT KVKVersion
			FROM dbo.ProcConfig
			WHERE ConfigKey IN ('MATCHMAKING_SCAN','DRAFTSCAN');

        -- Create delta tables once
        EXEC dbo.CREATE_DELTA_TABLES;

        OPEN kvk_cursor_master;
        FETCH NEXT FROM kvk_cursor_master INTO @KVK;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT 'Processing KVKVersion: ' + CAST(@KVK AS NVARCHAR(20));

            -- Pull config values
            SELECT @ConfiguredScan = NULL, @DraftScan = NULL;

            SELECT @ConfiguredScan = CONVERT(FLOAT, pc.ConfigValue)
            FROM dbo.ProcConfig pc
            WHERE pc.KVKVersion = @KVK AND pc.ConfigKey = 'MATCHMAKING_SCAN';

            SELECT @DraftScan = CONVERT(FLOAT, pc.ConfigValue)
            FROM dbo.ProcConfig pc
            WHERE pc.KVKVersion = @KVK AND pc.ConfigKey = 'DRAFTSCAN';

            -- Current data ceiling
            SELECT @MaxAvailableScan = MAX(CONVERT(FLOAT, ScanOrder))
            FROM dbo.KingdomScanData4;

            IF @MaxAvailableScan IS NULL
            BEGIN
                PRINT '⚠ No scan data in KingdomScanData4; skipping KVK ' + CAST(@KVK AS NVARCHAR(20));
                GOTO NextKVK;
            END

            -- Choose the scan to use:
            -- 1) Prefer MATCHMAKING if it exists and is available
            IF @ConfiguredScan IS NOT NULL AND @ConfiguredScan <= @MaxAvailableScan
            BEGIN
                SET @Scan = @ConfiguredScan;
                PRINT '✅ Using MATCHMAKING_SCAN (' + CAST(@Scan AS VARCHAR(30)) + ') for KVK ' + CAST(@KVK AS NVARCHAR(20));
            END
            ELSE IF @DraftScan IS NOT NULL
            BEGIN
                -- Use draft but never exceed data ceiling
                SET @Scan = CASE WHEN @DraftScan <= @MaxAvailableScan THEN @DraftScan ELSE @MaxAvailableScan END;
                PRINT '📝 Using DRAFTSCAN (' + CAST(@DraftScan AS VARCHAR(30)) + ' → applied ' + CAST(@Scan AS VARCHAR(30)) + ') for KVK ' + CAST(@KVK AS NVARCHAR(20));
            END
            ELSE
            BEGIN
                PRINT '⚠ Neither MATCHMAKING_SCAN (available) nor DRAFTSCAN set; skipping KVK ' + CAST(@KVK AS NVARCHAR(20));
                GOTO NextKVK;
            END

            -- Execute per-KVK pipeline
            PRINT '▶ Processing KVK ' + CAST(@KVK AS VARCHAR(20)) + ' with SCANORDER = ' + CAST(@Scan AS VARCHAR(30));

            EXEC dbo.sp_Prep_TargetTable          @KVK, @Scan;
            EXEC dbo.sp_ExcelOutput_ByKVK         @KVK, @Scan;   -- if this proc is independent of @Scan
            EXEC dbo.sp_Prep_ExcelOutputTable     @KVK, @Scan;
            EXEC dbo.sp_Prep_ExcelExportTable     @KVK;

            NextKVK:
            FETCH NEXT FROM kvk_cursor_master INTO @KVK;
        END

        -- Safe cursor cleanup
        IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
			BEGIN
				IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
				DEALLOCATE kvk_cursor_master;
			END
			IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
			BEGIN
				IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
				DEALLOCATE kvk_cursor_master;
			END

        -------------------------------------------------------------------
        -- Create/refresh v_TARGETS_FOR_UPLOAD pointing at latest KVK export
        -------------------------------------------------------------------
        DECLARE @LatestKVK int;

        ;WITH src AS (
            SELECT kvk = TRY_CAST(REPLACE(t.name, 'EXCEL_EXPORT_KVK_TARGETS_', '') AS int)
            FROM sys.tables AS t
            WHERE t.name LIKE 'EXCEL_EXPORT_KVK_TARGETS[_]%'  -- escape underscore
              AND t.schema_id = SCHEMA_ID('dbo')
        )
        SELECT @LatestKVK = MAX(kvk) FROM src;

        IF @LatestKVK IS NULL
        BEGIN
            PRINT '⚠ No EXCEL_EXPORT_KVK_TARGETS_xx tables found. Skipping v_TARGETS_FOR_UPLOAD refresh.';
        END
        ELSE
        BEGIN
            DECLARE @src sysname = QUOTENAME('dbo') + N'.' + QUOTENAME('EXCEL_EXPORT_KVK_TARGETS_' + CAST(@LatestKVK AS nvarchar(10)));
            DECLARE @sql nvarchar(max);

            -- Drop any existing object named v_TARGETS_FOR_UPLOAD
            IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', 'V') IS NOT NULL
                DROP VIEW dbo.v_TARGETS_FOR_UPLOAD;
            IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', 'U') IS NOT NULL
                DROP TABLE dbo.v_TARGETS_FOR_UPLOAD;

            -- Recreate as a view pointing to the newest KVK export table
            SET @sql = N'CREATE VIEW dbo.v_TARGETS_FOR_UPLOAD AS SELECT * FROM ' + @src + N';';
            EXEC sys.sp_executesql @sql;

            PRINT '✅ v_TARGETS_FOR_UPLOAD now points at ' + @src;
        END
	SET ANSI_WARNINGS ON;
    END TRY
	BEGIN CATCH
        IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
			BEGIN
				IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
				DEALLOCATE kvk_cursor_master;
			END
			IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
			BEGIN
				IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
				DEALLOCATE kvk_cursor_master;
			END

        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR('sp_TARGETS_MASTER failed: %s', 16, 1, @ErrMsg);
    END CATCH
END

