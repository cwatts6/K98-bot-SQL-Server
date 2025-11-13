SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Prep_ExcelExportTable]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Prep_ExcelExportTable] AS' 
END
ALTER PROCEDURE [dbo].[sp_Prep_ExcelExportTable]
	@KVK [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Prev1 INT = @KVK - 1;
    DECLARE @Prev2 INT = @KVK - 2;

    -- Fully-qualified, quoted names
    DECLARE @OutputTableName sysname = N'EXCEL_OUTPUT_KVK_TARGETS_' + CAST(@KVK AS nvarchar(10));
    DECLARE @ExportTableName sysname = N'EXCEL_EXPORT_KVK_TARGETS_' + CAST(@KVK AS nvarchar(10));

    DECLARE @OutputTableFull nvarchar(300) = QUOTENAME('dbo') + N'.' + QUOTENAME(@OutputTableName);
    DECLARE @ExportTableFull nvarchar(300) = QUOTENAME('dbo') + N'.' + QUOTENAME(@ExportTableName);
    DECLARE @TemplateFull    nvarchar(300) = QUOTENAME('dbo') + N'.' + QUOTENAME('EXCEL_EXPORT_KVK_TARGETS_TEMPLATE');

    -- Create or truncate export table
    IF OBJECT_ID(@ExportTableFull, 'U') IS NULL
    BEGIN
        DECLARE @createSql nvarchar(max) =
            N'SELECT TOP (0) * INTO ' + @ExportTableFull + N' FROM ' + @TemplateFull + N';';
        EXEC sys.sp_executesql @createSql;
    END
    ELSE
    BEGIN
        DECLARE @truncateSql nvarchar(max) = N'TRUNCATE TABLE ' + @ExportTableFull + N';';
        EXEC sys.sp_executesql @truncateSql;
    END

    -- Insert into export table from output table
    DECLARE @InsertSQL nvarchar(max) = N'
    INSERT INTO ' + @ExportTableFull + N'
    SELECT TOP (350)
           O.[RANK2]                              AS [Rank],
           O.[Gov_ID],
           O.[Governor_Name],
           O.[Power],
           O.[City Hall]                          AS [CH],
           O.[Troops Power],
           O.[Tech Power],
           O.[Building Power],
           O.[Commander Power],
           '' ''                                   AS [BLANK1],
           O.[Kill_Target],
           O.[Minimum_Kill_Target],
           O.[Dead_Target],
           O.[DKP Target],
           '' ''                                   AS [BLANK2],
           O.[Kills KVK ' + CAST(@Prev1 AS nvarchar(10)) + N'],
           O.[DEADS KVK ' + CAST(@Prev1 AS nvarchar(10)) + N'],
           O.[DKP KVK ' + CAST(@Prev1 AS nvarchar(10)) + N'],
           O.[% DKP Target KVK ' + CAST(@Prev1 AS nvarchar(10)) + N'],
           '' ''                                   AS [BLANK3],
           O.[Kills KVK ' + CAST(@Prev2 AS nvarchar(10)) + N'],
           O.[DEADS KVK ' + CAST(@Prev2 AS nvarchar(10)) + N'],
           O.[DKP KVK ' + CAST(@Prev2 AS nvarchar(10)) + N'],
           O.[% DKP Target KVK ' + CAST(@Prev2 AS nvarchar(10)) + N']
    FROM ' + @OutputTableFull + N' AS O
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.EXEMPT_FROM_STATS AS X
        WHERE X.GovernorID = O.[Gov_ID]
          AND X.KVK_NO IN (0, @pKVK)
    )
    ORDER BY O.[RANK2] ASC;';

    EXEC sys.sp_executesql
        @InsertSQL,
        N'@pKVK int',
        @pKVK = @KVK;
END


