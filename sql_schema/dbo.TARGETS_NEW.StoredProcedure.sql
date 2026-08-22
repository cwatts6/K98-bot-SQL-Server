SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TARGETS_NEW]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[TARGETS_NEW] AS' 
END
ALTER PROCEDURE [dbo].[TARGETS_NEW]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Ensure any previously open cursor is cleaned up
        IF CURSOR_STATUS('global', 'kvk_cursor') >= -1
        BEGIN
            CLOSE kvk_cursor;
            DEALLOCATE kvk_cursor;
        END;

        DECLARE @KVK INT, @ScanOrder FLOAT, @SQL NVARCHAR(MAX);

        DECLARE kvk_cursor CURSOR FOR
            SELECT DISTINCT KVKVersion
            FROM ProcConfig
            WHERE ConfigKey = 'MATHCHMAKING_SCAN';

        OPEN kvk_cursor;
        FETCH NEXT FROM kvk_cursor INTO @KVK;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT @ScanOrder = ConfigValue
            FROM ProcConfig
            WHERE KVKVersion = @KVK AND ConfigKey = 'MATHCHMAKING_SCAN';

            DECLARE @Prev1 INT = @KVK - 1;
            DECLARE @Prev2 INT = @KVK - 2;
            DECLARE @ExportTable NVARCHAR(128) = 'EXCEL_EXPORT_KVK_TARGETS_' + CAST(@KVK AS VARCHAR);
            DECLARE @OutputTable NVARCHAR(128) = 'EXCEL_OUTPUT_KVK_TARGETS_' + CAST(@KVK AS VARCHAR);
            DECLARE @TargetTable NVARCHAR(128) = 'TARGETS_' + CAST(@KVK AS VARCHAR);
            DECLARE @Prev1Table NVARCHAR(128) = 'EXCEL_FOR_KVK_' + CAST(@Prev1 AS VARCHAR);
            DECLARE @Prev2Table NVARCHAR(128) = 'EXCEL_FOR_KVK_' + CAST(@Prev2 AS VARCHAR);
			DECLARE @Blank CHAR(1) = ' ';

            SET @SQL = '

IF OBJECT_ID(N''dbo.' + @TargetTable + ''') IS NULL
BEGIN
    SELECT GovernorID, CAST(0 AS INT) AS Kill_Target, CAST(0 AS INT) AS Minimum_Kill_Target, CAST(0 AS INT) AS Dead_Target
    INTO ' + @TargetTable + '
    FROM KingdomScanData4 WHERE 1 = 0;
END
ELSE
BEGIN
    TRUNCATE TABLE ' + @TargetTable + ';
END;

WITH BandMatch AS (
    SELECT d.GovernorID, d.Power, kb.KillTarget, kb.MinKillTarget, kb.DeadTarget,
           ROW_NUMBER() OVER (PARTITION BY d.GovernorID ORDER BY kb.MinPower DESC) AS rn
    FROM KingdomScanData4 d
    JOIN KVKTargetBands kb ON kb.KVKVersion = ' + CAST(@KVK AS VARCHAR) + ' AND d.Power >= kb.MinPower
    WHERE d.SCANORDER = @Scan
)
INSERT INTO ' + @TargetTable + ' (GovernorID, Kill_Target, Minimum_Kill_Target, Dead_Target)
SELECT GovernorID, KillTarget, MinKillTarget, DeadTarget
FROM BandMatch WHERE rn = 1;

IF OBJECT_ID(N''dbo.' + @OutputTable + ''') IS NOT NULL
BEGIN
    DROP TABLE ' + @OutputTable + ';
END;

SELECT TOP 0
    CAST(NULL AS INT) AS Rank,
    CAST(NULL AS INT) AS RANK2,
    CAST(NULL AS BIGINT) AS Gov_ID,
    CAST(NULL AS NVARCHAR(100)) AS Governor_Name,
    CAST(NULL AS NVARCHAR(100)) AS Power,
    CAST(NULL AS INT) AS [City Hall],
    CAST(NULL AS NVARCHAR(100)) AS [Troops Power],
    CAST(NULL AS NVARCHAR(100)) AS [Tech Power],
    CAST(NULL AS NVARCHAR(100)) AS [Building Power],
    CAST(NULL AS NVARCHAR(100)) AS [Commander Power],
    CAST(NULL AS INT) AS Kill_Target,
    CAST(NULL AS INT) AS Minimum_Kill_Target,
    CAST(NULL AS INT) AS Dead_Target,
    CAST(NULL AS INT) AS [DKP Target],
    CAST(NULL AS INT) AS [Kills KVK ' + CAST(@Prev1 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [DEADS KVK ' + CAST(@Prev1 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [DKP KVK ' + CAST(@Prev1 AS VARCHAR) + '],
    CAST(NULL AS FLOAT) AS [% DKP Target KVK ' + CAST(@Prev1 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [Kills KVK ' + CAST(@Prev2 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [DEADS KVK ' + CAST(@Prev2 AS VARCHAR) + '],
    CAST(NULL AS INT) AS [DKP KVK ' + CAST(@Prev2 AS VARCHAR) + '],
    CAST(NULL AS FLOAT) AS [% DKP Target KVK ' + CAST(@Prev2 AS VARCHAR) + ']
INTO ' + @OutputTable + ';

IF OBJECT_ID(N''dbo.' + @ExportTable + ''') IS NULL
BEGIN
    SELECT * INTO ' + @ExportTable + ' FROM EXCEL_EXPORT_KVK_TARGETS_TEMPLATE WHERE 1 = 0;
END
ELSE
BEGIN
    TRUNCATE TABLE ' + @ExportTable + ';
END;

INSERT INTO ' + @OutputTable + '
SELECT TOP 5000
       P.PowerRank AS Rank,
       ROW_NUMBER() OVER (ORDER BY P.Power DESC) AS RANK2,
       P.GovernorID AS Gov_ID,
       RTRIM(P.GovernorName) AS Governor_Name,
       FORMAT(P.Power, ''#,###'') AS Power,
       P.[City Hall],
       FORMAT(P.[Troops Power], ''#,###'') AS [Troops Power],
       FORMAT(P.[Tech Power], ''#,###'') AS [Tech Power],
       FORMAT(P.[Building Power], ''#,###'') AS [Building Power],
       FORMAT(P.[Commander Power], ''#,###'') AS [Commander Power],
       T.Kill_Target,
       T.Minimum_Kill_Target,
       T.Dead_Target,
       (T.Kill_Target * 3 + T.Dead_Target * 8) AS [DKP Target],
       LK.[t4&t5_kills] AS [Kills KVK ' + CAST(@Prev1 AS VARCHAR) + '],
	   LK.deads AS [DEADS KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       LK.dkp_score AS [DKP KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       LK.[% of DKP Target] AS [% DKP Target KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       JK.[t4&t5_kills] AS [Kills KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       JK.deads AS [DEADS KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       JK.dkp_score AS [DKP KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       JK.[% of DKP Target] AS [% DKP Target KVK ' + CAST(@Prev2 AS VARCHAR) + ']
FROM (
    SELECT GovernorID, GovernorName, Power, [Troops Power], [City Hall],
           [Tech Power], [Building Power], [Commander Power],
           ROW_NUMBER() OVER (ORDER BY Power DESC) AS PowerRank
    FROM KingdomScanData4
    WHERE SCANORDER = @Scan
      AND GovernorID NOT IN (22345012, 46718337, 2510418, 83724180, 17868677, 12025033)
) AS P
JOIN ' + @TargetTable + ' AS T ON T.GovernorID = P.GovernorID
LEFT JOIN ' + @Prev1Table + ' AS LK ON LK.Gov_ID = P.GovernorID
LEFT JOIN ' + @Prev2Table + ' AS JK ON JK.Gov_ID = P.GovernorID
ORDER BY RANK2 ASC;

INSERT INTO ' + @ExportTable + '
SELECT TOP 350
       RANK2 AS [Rank],
       Gov_ID,
       Governor_Name,
       [Power],
       [City Hall],
       [Troops Power],
       [Tech Power],
       [Building Power],
       [Commander Power],
       @Blank AS [BLANK1],
       [Kill Target],
       [Minimum Kill Target],
       [Dead Target],
       [DKP Target],
       @Blank AS [BLANK2],
       [Kills KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       [DEADS KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       [DKP KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       [% DKP Target KVK ' + CAST(@Prev1 AS VARCHAR) + '],
       @Blank AS [BLANK3],
       [Kills KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       [DEADS KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       [DKP KVK ' + CAST(@Prev2 AS VARCHAR) + '],
       [% DKP Target KVK ' + CAST(@Prev2 AS VARCHAR) + ']
FROM ' + @OutputTable + '
ORDER BY RANK2 ASC;
';

    DECLARE @Params NVARCHAR(MAX) = N'@Scan FLOAT';
	PRINT @SQL
EXEC sp_executesql @SQL, @Params, @Scan = @ScanOrder;
            FETCH NEXT FROM kvk_cursor INTO @KVK;
        END

        CLOSE kvk_cursor;
        DEALLOCATE kvk_cursor;

    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'kvk_cursor') >= -1
        BEGIN
            CLOSE kvk_cursor;
            DEALLOCATE kvk_cursor;
        END;
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR('TARGETS procedure failed: %s', 16, 1, @ErrMsg);
    END CATCH
END

