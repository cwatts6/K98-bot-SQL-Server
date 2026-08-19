SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_TARGETS_MASTER]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_TARGETS_MASTER] AS' 
END
ALTER PROCEDURE [dbo].[sp_TARGETS_MASTER]
	@KVK [int] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    PRINT N'DBG: sp_TARGETS_MASTER start';
    SET ANSI_WARNINGS OFF;

    -- Log the mode (full vs incremental)
    IF @KVK IS NULL
        PRINT N'MODE: Full refresh (all KVKs)';
    ELSE
        PRINT CONCAT('MODE: Incremental refresh (KVK ', CAST(@KVK AS NVARCHAR(20)), ' only)');

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

        DECLARE @Now DATETIME = GETDATE()
              , @ConfiguredScan FLOAT
              , @DraftScan FLOAT
              , @MaxAvailableScan FLOAT
              , @Scan FLOAT;

        -- Build the KVK list from ANY of the two keys so we don't miss ones with only DRAFTSCAN
        -- Filter by @KVK parameter if provided
        DECLARE kvk_cursor_master CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT KVKVersion
            FROM dbo.ProcConfig
            WHERE ConfigKey IN ('MATCHMAKING_SCAN','DRAFTSCAN')
              AND (@KVK IS NULL OR KVKVersion = @KVK)  -- Filter by specific KVK if provided
            ORDER BY KVKVersion;

        -- Create delta tables once
		SET ANSI_WARNINGS ON;
        PRINT N'Calling CREATE_DELTA_TABLES';
        EXEC dbo.CREATE_DELTA_TABLES;
		SET ANSI_WARNINGS OFF;

        OPEN kvk_cursor_master;
        FETCH NEXT FROM kvk_cursor_master INTO @KVK;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            PRINT CONCAT('Processing KVKVersion: ', CAST(@KVK AS NVARCHAR(20)));

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
                PRINT CONCAT('WARN: No scan data in KingdomScanData4; skipping KVK ', CAST(@KVK AS NVARCHAR(20)));
                GOTO NextKVK;
            END

            -- Choose the scan to use:
            IF @ConfiguredScan IS NOT NULL AND @ConfiguredScan <= @MaxAvailableScan
            BEGIN
                SET @Scan = @ConfiguredScan;
                PRINT CONCAT('Using MATCHMAKING_SCAN (', CAST(@Scan AS VARCHAR(30)), ') for KVK ', CAST(@KVK AS NVARCHAR(20)));
            END
            ELSE IF @DraftScan IS NOT NULL
            BEGIN
                SET @Scan = CASE WHEN @DraftScan <= @MaxAvailableScan THEN @DraftScan ELSE @MaxAvailableScan END;
                PRINT CONCAT('Using DRAFTSCAN (', CAST(@DraftScan AS VARCHAR(30)), ' -> applied ', CAST(@Scan AS VARCHAR(30)), ') for KVK ', CAST(@KVK AS NVARCHAR(20)));
            END
            ELSE
            BEGIN
                PRINT CONCAT('WARN: Neither MATCHMAKING_SCAN nor DRAFTSCAN set; skipping KVK ', CAST(@KVK AS NVARCHAR(20)));
                GOTO NextKVK;
            END

            PRINT CONCAT('Processing KVK ', CAST(@KVK AS VARCHAR(20)), ' with SCANORDER = ', CAST(@Scan AS VARCHAR(30)));

            -- Per-KVK pipeline (local TRY/CATCHs keep errors informative)
            BEGIN TRY
                EXEC dbo.sp_Prep_TargetTable @KVK, @Scan;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('ERR: sp_Prep_TargetTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                THROW;
            END CATCH

            BEGIN TRY
                EXEC dbo.sp_ExcelOutput_ByKVK @KVK, @Scan;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('ERR: sp_ExcelOutput_ByKVK failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                THROW;
            END CATCH

            BEGIN TRY
                EXEC dbo.sp_Prep_ExcelOutputTable @KVK, @Scan;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('ERR: sp_Prep_ExcelOutputTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                THROW;
            END CATCH

            BEGIN TRY
                EXEC dbo.sp_Prep_ExcelExportTable @KVK;
            END TRY
            BEGIN CATCH
                PRINT CONCAT('ERR: sp_Prep_ExcelExportTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                THROW;
            END CATCH

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

        PRINT CONCAT('LatestKVK = ', ISNULL(CAST(@LatestKVK AS nvarchar(10)), '(null)'));

        IF @LatestKVK IS NULL
        BEGIN
            PRINT N'WARN: No EXCEL_EXPORT_KVK_TARGETS_xx tables found. Skipping v_TARGETS_FOR_UPLOAD refresh.';
        END
        ELSE
        BEGIN
            DECLARE @plainName nvarchar(128) = N'dbo.EXCEL_EXPORT_KVK_TARGETS_' + CAST(@LatestKVK AS nvarchar(10));
            DECLARE @srcQuoted sysname = QUOTENAME('dbo') + N'.' + QUOTENAME('EXCEL_EXPORT_KVK_TARGETS_' + CAST(@LatestKVK AS nvarchar(10)));
            DECLARE @sql nvarchar(max);

            IF OBJECT_ID(@plainName, 'U') IS NULL
            BEGIN
                PRINT CONCAT('WARN: Expected table ', @plainName, ' does not exist. Skipping v_TARGETS_FOR_UPLOAD refresh.');
            END
            ELSE
            BEGIN
                IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', 'V') IS NOT NULL
                    DROP VIEW dbo.v_TARGETS_FOR_UPLOAD;
                IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', 'U') IS NOT NULL
                    DROP TABLE dbo.v_TARGETS_FOR_UPLOAD;

                SET @sql = N'CREATE VIEW dbo.v_TARGETS_FOR_UPLOAD AS SELECT * FROM ' + @srcQuoted + N';';
                PRINT N'About to execute dynamic SQL to create view:';
                PRINT @sql;

                BEGIN TRY
                    EXEC sys.sp_executesql @sql;
                    PRINT CONCAT('v_TARGETS_FOR_UPLOAD now points at ', @srcQuoted);
                END TRY
                BEGIN CATCH
                    DECLARE @dynMsg nvarchar(4000) = ERROR_MESSAGE();
                    DECLARE @dynLine int = ERROR_LINE();
                    DECLARE @fullMsg nvarchar(4000) = N'sp_TARGETS_MASTER: dynamic CREATE VIEW failed for ' + @srcQuoted + N': ' + ISNULL(@dynMsg, N'(no message)');
                    PRINT N'ERROR: ' + @fullMsg + N' (line ' + CAST(ISNULL(@dynLine,0) AS nvarchar(10)) + N')';
                    RAISERROR(@fullMsg, 16, 1);
                END CATCH
            END
        END

        SET ANSI_WARNINGS ON;
        PRINT N'DBG: sp_TARGETS_MASTER complete';
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
        DECLARE @ErrProc SYSNAME = ERROR_PROCEDURE();
        DECLARE @ErrLine INT = ERROR_LINE();

        PRINT CONCAT(N'ERROR in sp_TARGETS_MASTER: ', ISNULL(@ErrProc, N'(no procedure)'), N' line ', CAST(ISNULL(@ErrLine, 0) AS NVARCHAR(10)), N': ', ISNULL(@ErrMsg, N'(no message)'));

        THROW;
    END CATCH
END

