SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Refresh_View_EXCEL_FOR_KVK_All]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Refresh_View_EXCEL_FOR_KVK_All] AS' 
END
ALTER PROCEDURE [dbo].[sp_Refresh_View_EXCEL_FOR_KVK_All]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#kvks') IS NOT NULL DROP TABLE #kvks;
    CREATE TABLE #kvks (
        ord INT IDENTITY(1,1) PRIMARY KEY,
        name SYSNAME NOT NULL,
        kvk_no INT NOT NULL,
        obj_id INT NOT NULL
    );

    INSERT INTO #kvks(name, kvk_no, obj_id)
    SELECT t.name,
           TRY_CONVERT(int, REPLACE(t.name, 'EXCEL_FOR_KVK_', '')) AS kvk_no,
           t.object_id
    FROM sys.tables AS t
    WHERE t.name LIKE 'EXCEL_FOR_KVK[_]%'
      AND TRY_CONVERT(int, REPLACE(t.name, 'EXCEL_FOR_KVK_', '')) IS NOT NULL
    ORDER BY TRY_CONVERT(int, REPLACE(t.name, 'EXCEL_FOR_KVK_', ''));

    IF NOT EXISTS (SELECT 1 FROM #kvks)
    BEGIN
        -- Empty skeleton with legacy & compatibility aliases
        EXEC('
        CREATE OR ALTER VIEW dbo.v_EXCEL_FOR_KVK_All AS
        SELECT CAST(NULL AS int)            AS [Rank],
               CAST(NULL AS int)            AS [KVK_RANK],
               CAST(NULL AS bigint)         AS [Gov_ID],
               CAST(NULL AS nvarchar(200))  AS [Governor_Name],
               CAST(NULL AS bigint)         AS [Starting Power],
               CAST(NULL AS bigint)         AS [Power_Delta],
               CAST(NULL AS bigint)         AS [T4_KILLS],
               CAST(NULL AS bigint)         AS [T5_KILLS],
               CAST(NULL AS bigint)         AS [T4&T5_Kills],
               CAST(NULL AS bigint)         AS [KILLS_OUTSIDE_KVK],
               CAST(NULL AS bigint)         AS [Kill Target],
               CAST(NULL AS decimal(9,2))   AS [% of Kill Target],
               CAST(NULL AS bigint)         AS [Deads],
               CAST(NULL AS bigint)         AS [DEADS_OUTSIDE_KVK],
               CAST(NULL AS bigint)         AS [T4_Deads],
               CAST(NULL AS bigint)         AS [T5_Deads],
               CAST(NULL AS bigint)         AS [Dead_Target],
               CAST(NULL AS decimal(9,2))   AS [% of Dead Target],
               CAST(NULL AS decimal(9,2))   AS [% of Dead_Target],
               CAST(NULL AS bit)            AS [Zeroed],
               CAST(NULL AS bigint)         AS [DKP_SCORE],
               CAST(NULL AS bigint)         AS [DKP Target],
               CAST(NULL AS decimal(9,2))   AS [% of DKP Target],
               CAST(NULL AS bigint)         AS [Helps],
               CAST(NULL AS bigint)         AS [RSS_Assist],
               CAST(NULL AS bigint)         AS [RSS_Gathered],
               CAST(NULL AS bigint)         AS [Pass 4 Kills],
               CAST(NULL AS bigint)         AS [Pass 6 Kills],
               CAST(NULL AS bigint)         AS [Pass 7 Kills],
               CAST(NULL AS bigint)         AS [Pass 8 Kills],
               CAST(NULL AS bigint)         AS [Pass 4 Deads],
               CAST(NULL AS bigint)         AS [Pass 6 Deads],
               CAST(NULL AS bigint)         AS [Pass 7 Deads],
               CAST(NULL AS bigint)         AS [Pass 8 Deads],
               CAST(NULL AS int)            AS [KVK_NO]
        WHERE 1=0;');
        EXEC('CREATE OR ALTER VIEW dbo.v_EXCEL_FOR_KVK_Started AS SELECT * FROM dbo.v_EXCEL_FOR_KVK_All WHERE 1=0;');
        RETURN;
    END

    DECLARE @view NVARCHAR(MAX) = N'CREATE OR ALTER VIEW dbo.v_EXCEL_FOR_KVK_All AS' + CHAR(10);
    DECLARE @first BIT = 1;

    DECLARE
        @name SYSNAME, @obj_id INT,
        @DeadTargetSrc NVARCHAR(200),
        @PctDeadTargetSrc NVARCHAR(200),
        @DKPSrc NVARCHAR(200),
        @PctKillSrc NVARCHAR(200),
        @PctDKPSrc NVARCHAR(200);

    DECLARE c CURSOR FAST_FORWARD FOR
        SELECT name, obj_id FROM #kvks ORDER BY ord;

    OPEN c;
    FETCH NEXT FROM c INTO @name, @obj_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Resolve source columns (prefer new safe names, then legacy)
        SET @PctKillSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Pct_of_Kill_Target')
                    THEN '[Pct_of_Kill_Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of Kill Target')
                    THEN '[% of Kill Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of Kill target')
                    THEN '[% of Kill target]'
                ELSE 'CAST(0.00 AS decimal(9,2))'
            END;

        SET @PctDKPSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Pct_of_DKP_Target')
                    THEN '[Pct_of_DKP_Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of DKP Target')
                    THEN '[% of DKP Target]'
                ELSE 'CAST(0.00 AS decimal(9,2))'
            END;

        SET @DeadTargetSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Dead_Target')
                    THEN '[Dead_Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Dead Target')
                    THEN '[Dead Target]'
                ELSE 'CAST(0 AS bigint)'
            END;

        SET @PctDeadTargetSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='Pct_of_Dead_Target')
                    THEN '[Pct_of_Dead_Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of Dead Target')
                    THEN '[% of Dead Target]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='% of Dead_Target')
                    THEN '[% of Dead_Target]'
                ELSE 'CAST(0.00 AS decimal(9,2))'
            END;

        SET @DKPSrc =
            CASE
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='DKP_SCORE')
                    THEN '[DKP_SCORE]'
                WHEN EXISTS (SELECT 1 FROM sys.columns WHERE object_id=@obj_id AND name='DKP Score')
                    THEN '[DKP Score]'
                ELSE 'CAST(0 AS bigint)'
            END;

        DECLARE @select NVARCHAR(MAX) = N'
SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    ' + @PctKillSrc + '         AS [% of Kill Target],
    [Deads],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    ' + @DeadTargetSrc + '      AS [Dead_Target],
    ' + @PctDeadTargetSrc + '   AS [% of Dead Target],
    ' + @PctDeadTargetSrc + '   AS [% of Dead_Target],
    [Zeroed],
    ' + @DKPSrc + '             AS [DKP_SCORE],
    [DKP Target],
    ' + @PctDKPSrc + '          AS [% of DKP Target],
    [Helps],
    [RSS_Assist],
    [RSS_Gathered],
    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],
    [KVK_NO]
FROM dbo.' + QUOTENAME(@name);

        IF @first = 1
        BEGIN
            SET @view += @select;
            SET @first = 0;
        END
        ELSE
        BEGIN
            SET @view += CHAR(10) + N'UNION ALL' + CHAR(10) + @select;
        END

        FETCH NEXT FROM c INTO @name, @obj_id;
    END
    CLOSE c; DEALLOCATE c;

    EXEC sys.sp_executesql @view;

    DECLARE @sql2 NVARCHAR(MAX) = N'
    CREATE OR ALTER VIEW dbo.v_EXCEL_FOR_KVK_Started AS
    WITH MaxStarted AS (
        SELECT MAX(KVK_NO) AS MaxKVK
        FROM dbo.KVK_Details
        WHERE KVK_START_DATE IS NOT NULL
          AND KVK_START_DATE <= SYSUTCDATETIME()
    )
    SELECT a.*
    FROM dbo.v_EXCEL_FOR_KVK_All AS a
    CROSS JOIN MaxStarted ms
    WHERE a.[KVK_NO] <= ms.MaxKVK;';
    EXEC sys.sp_executesql @sql2;
END

