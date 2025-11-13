SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Prep_TargetTable]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Prep_TargetTable] AS' 
END
ALTER PROCEDURE [dbo].[sp_Prep_TargetTable]
	@KVK [int],
	@Scan [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @TargetTableName  sysname = N'TARGETS_' + CAST(@KVK AS nvarchar(10));
    DECLARE @TargetTableFull  nvarchar(300) = QUOTENAME('dbo') + N'.' + QUOTENAME(@TargetTableName);

    -- Create or truncate the target table
    IF OBJECT_ID(@TargetTableFull, 'U') IS NULL
    BEGIN
        DECLARE @createSql nvarchar(max) =
            N'SELECT TOP (0)
                  d.GovernorID
                , CAST(0 AS int) AS Kill_Target
                , CAST(0 AS int) AS Minimum_Kill_Target
                , CAST(0 AS int) AS Dead_Target
              INTO ' + @TargetTableFull + N'
              FROM dbo.KingdomScanData4 AS d;';
        EXEC sys.sp_executesql @createSql;
    END
    ELSE
    BEGIN
        DECLARE @truncateSql nvarchar(max) = N'TRUNCATE TABLE ' + @TargetTableFull + N';';
        EXEC sys.sp_executesql @truncateSql;
    END

    /* Insert data from band match
       - Parameterized @KVK and @Scan
       - NOT EXISTS instead of NOT IN (SELECT ...)
    */
    DECLARE @InsertSQL nvarchar(max) = N'
    ;WITH BandMatch AS (
        SELECT
            d.GovernorID,
            d.[Power],
            kb.KillTarget,
            kb.MinKillTarget,
            kb.DeadTarget,
            ROW_NUMBER() OVER (PARTITION BY d.GovernorID ORDER BY kb.MinPower DESC) AS rn
        FROM dbo.KingdomScanData4 AS d
        JOIN dbo.KVKTargetBands  AS kb
              ON kb.KVKVersion = @KVK
             AND d.[Power]    >= kb.MinPower
        WHERE d.SCANORDER = @Scan
    )
    INSERT INTO ' + @TargetTableFull + N' (GovernorID, Kill_Target, Minimum_Kill_Target, Dead_Target)
    SELECT bm.GovernorID, bm.KillTarget, bm.MinKillTarget, bm.DeadTarget
    FROM BandMatch AS bm
    WHERE bm.rn = 1
      AND NOT EXISTS (
            SELECT 1
            FROM dbo.EXEMPT_FROM_STATS AS x
            WHERE x.GovernorID = bm.GovernorID
              AND x.KVK_NO IN (0, @KVK)
      );';

    EXEC sys.sp_executesql
         @InsertSQL,
         N'@KVK int, @Scan int',
         @KVK = @KVK, @Scan = @Scan;
END

