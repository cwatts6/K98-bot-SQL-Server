SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Rebuild_ExcelForDashboard]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Rebuild_ExcelForDashboard] AS' 
END
ALTER PROCEDURE [dbo].[sp_Rebuild_ExcelForDashboard]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = N'';
    DECLARE @unionSql NVARCHAR(MAX) = N'';
    DECLARE @KVK INT;
    DECLARE @MaxScan FLOAT;

    -- Determine latest scan order for eligibility checks
    SELECT @MaxScan = MAX(SCANORDER) FROM dbo.KingdomScanData4;

    ----------------------------------------------------------------
    -- Build dynamic UNION of EXCEL_FOR_KVK_<KVK> tables that are eligible
    -- Eligible KVK versions are those with a MATCHMAKING_SCAN value in ProcConfig
    -- smaller than the current max scanorder.
    ----------------------------------------------------------------
    DECLARE cur CURSOR FOR
    SELECT DISTINCT KVKVersion
    FROM dbo.ProcConfig
    WHERE ConfigKey = 'MATCHMAKING_SCAN'
      AND TRY_CAST(ConfigValue AS FLOAT) < ISNULL(@MaxScan, 0)
    ORDER BY KVKVersion DESC;

    OPEN cur;
    FETCH NEXT FROM cur INTO @KVK;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @unionSql += 
            CASE 
                WHEN LEN(ISNULL(@unionSql,'')) = 0 
                    THEN 'SELECT * FROM EXCEL_FOR_KVK_' + CAST(@KVK AS NVARCHAR(10))
                ELSE ' UNION ALL SELECT * FROM EXCEL_FOR_KVK_' + CAST(@KVK AS NVARCHAR(10))
            END;

        FETCH NEXT FROM cur INTO @KVK;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -- If there are eligible KVK tables, build the EXCEL_FOR_DASHBOARD as a union of them
    IF LEN(ISNULL(@unionSql, '')) > 0
    BEGIN
        SET @sql = N'
        IF OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'', ''U'') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        SELECT TOP (5000000)
               T.*,
               T.[% of Dead Target] AS [% of Dead_Target]  -- alias for compatibility
        INTO dbo.EXCEL_FOR_DASHBOARD
        FROM (
            ' + @unionSql + '
        ) AS T
        ORDER BY KVK_NO, [RANK];
        ';

        EXEC sp_executesql @sql;

        PRINT 'Rebuilt EXCEL_FOR_DASHBOARD by unioning per-KVK tables.';
    END
    ELSE
    BEGIN
        PRINT 'No eligible KVK tables found based on MATCHMAKING_SCAN and Max SCANORDER.';
    END
END

