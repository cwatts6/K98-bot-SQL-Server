SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Prep_ExcelOutputTable]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Prep_ExcelOutputTable] AS' 
END
ALTER PROCEDURE [dbo].[sp_Prep_ExcelOutputTable]
	@KVK [int],
	@Scan [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Prev1 INT = @KVK - 1;
    DECLARE @Prev2 INT = @KVK - 2;
    DECLARE @OutputTable NVARCHAR(128) = QUOTENAME('EXCEL_OUTPUT_KVK_TARGETS_' + CAST(@KVK AS VARCHAR));
    DECLARE @TargetTable NVARCHAR(128) = QUOTENAME('TARGETS_' + CAST(@KVK AS VARCHAR));
    DECLARE @Prev1Table NVARCHAR(128) = QUOTENAME('EXCEL_FOR_KVK_' + CAST(@Prev1 AS VARCHAR));
    DECLARE @Prev2Table NVARCHAR(128) = QUOTENAME('EXCEL_FOR_KVK_' + CAST(@Prev2 AS VARCHAR));

    -- Drop and create the output table structure
    IF OBJECT_ID(N'dbo.' + @OutputTable) IS NOT NULL
    BEGIN
        EXEC('DROP TABLE ' + @OutputTable);
    END

    DECLARE @CreateSQL NVARCHAR(MAX) = '
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
    INTO ' + @OutputTable + '
    ';
    EXEC(@CreateSQL);

    DECLARE @InsertSQL NVARCHAR(MAX);

    IF @KVK = 3
    BEGIN
        SET @InsertSQL = '
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
               0 AS [Kills KVK ' + CAST(@Prev1 AS VARCHAR) + '],
               0 AS [DEADS KVK ' + CAST(@Prev1 AS VARCHAR) + '],
               0 AS [DKP KVK ' + CAST(@Prev1 AS VARCHAR) + '],
               0 AS [% DKP Target KVK ' + CAST(@Prev1 AS VARCHAR) + '],
               0 AS [Kills KVK ' + CAST(@Prev2 AS VARCHAR) + '],
               0 AS [DEADS KVK ' + CAST(@Prev2 AS VARCHAR) + '],
               0 AS [DKP KVK ' + CAST(@Prev2 AS VARCHAR) + '],
               0 AS [% DKP Target KVK ' + CAST(@Prev2 AS VARCHAR) + ']
        FROM (
            SELECT GovernorID, GovernorName, Power, [Troops Power], [City Hall],
                   [Tech Power], [Building Power], [Commander Power],
                   ROW_NUMBER() OVER (ORDER BY Power DESC) AS PowerRank
            FROM KingdomScanData4
            WHERE SCANORDER = ' + CAST(@Scan AS VARCHAR) + '
			              
        ) AS P
        JOIN ' + @TargetTable + ' AS T ON T.GovernorID = P.GovernorID
        ORDER BY RANK2 ASC;';
    END
    ELSE IF @KVK = 4
    BEGIN
        SET @InsertSQL = '
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
               0 AS [Kills KVK ' + CAST(@Prev2 AS VARCHAR) + '],
               0 AS [DEADS KVK ' + CAST(@Prev2 AS VARCHAR) + '],
               0 AS [DKP KVK ' + CAST(@Prev2 AS VARCHAR) + '],
               0 AS [% DKP Target KVK ' + CAST(@Prev2 AS VARCHAR) + ']
        FROM (
            SELECT GovernorID, GovernorName, Power, [Troops Power], [City Hall],
                   [Tech Power], [Building Power], [Commander Power],
                   ROW_NUMBER() OVER (ORDER BY Power DESC) AS PowerRank
            FROM KingdomScanData4
            WHERE SCANORDER = ' + CAST(@Scan AS VARCHAR) + '
              
        ) AS P
        JOIN ' + @TargetTable + ' AS T ON T.GovernorID = P.GovernorID
        LEFT JOIN ' + @Prev1Table + ' AS LK ON LK.Gov_ID = P.GovernorID
        ORDER BY RANK2 ASC;';
    END
    ELSE
    BEGIN
        SET @InsertSQL = '
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
            WHERE SCANORDER = ' + CAST(@Scan AS VARCHAR) + '
              
        ) AS P
        JOIN ' + @TargetTable + ' AS T ON T.GovernorID = P.GovernorID
        LEFT JOIN ' + @Prev1Table + ' AS LK ON LK.Gov_ID = P.GovernorID
        LEFT JOIN ' + @Prev2Table + ' AS JK ON JK.Gov_ID = P.GovernorID
        ORDER BY RANK2 ASC;';
    END

    EXEC(@InsertSQL);
END



