SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Create_Excel_For_Kvk_Indexes]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Create_Excel_For_Kvk_Indexes] AS' 
END
ALTER PROCEDURE [dbo].[sp_Create_Excel_For_Kvk_Indexes]
	@FullTableName [nvarchar](260),
	@TableBase [sysname]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF @FullTableName IS NULL OR @TableBase IS NULL
    BEGIN
        RAISERROR('sp_Create_Excel_For_Kvk_Indexes: Missing parameters.',16,1);
        RETURN 1;
    END

    -------------------------------------------------------------------------
    -- Change #1: Parse & safely re-quote schema/table from @FullTableName
    -------------------------------------------------------------------------
    DECLARE @schema sysname = PARSENAME(@FullTableName, 2);
    DECLARE @table  sysname = PARSENAME(@FullTableName, 1);

    IF @schema IS NULL OR @table IS NULL
    BEGIN
        RAISERROR('sp_Create_Excel_For_Kvk_Indexes: @FullTableName must be 2-part (schema.table).',16,1);
        RETURN 1;
    END

    DECLARE @SafeFull nvarchar(260) = QUOTENAME(@schema) + N'.' + QUOTENAME(@table);

    -- Verify the table exists
    IF OBJECT_ID(@SafeFull, 'U') IS NULL
        RETURN 0;

    DECLARE @idxName sysname;
    DECLARE @sql nvarchar(max);

    -------------------------------------------------------------------------
    -- Change #2: Only create indexes if the target columns exist
    -------------------------------------------------------------------------

    -------------------------
    -- Gov_ID index
    -------------------------
    IF COL_LENGTH(@SafeFull, 'Gov_ID') IS NOT NULL
    BEGIN
        SET @idxName = N'IX_' + @TableBase + N'_GovID';

        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(@SafeFull, 'U') AND name = @idxName)
        BEGIN
            SET @sql = N'DROP INDEX ' + QUOTENAME(@idxName) + N' ON ' + @SafeFull + N';';
            EXEC sp_executesql @sql;
        END

        SET @sql = N'CREATE NONCLUSTERED INDEX ' + QUOTENAME(@idxName) + N' ON ' + @SafeFull + N'([Gov_ID]);';
        EXEC sp_executesql @sql;
    END

    -------------------------
    -- KVK_NO index
    -------------------------
    IF COL_LENGTH(@SafeFull, 'KVK_NO') IS NOT NULL
    BEGIN
        SET @idxName = N'IX_' + @TableBase + N'_KVK_NO';

        IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(@SafeFull, 'U') AND name = @idxName)
        BEGIN
            SET @sql = N'DROP INDEX ' + QUOTENAME(@idxName) + N' ON ' + @SafeFull + N';';
            EXEC sp_executesql @sql;
        END

        SET @sql = N'CREATE NONCLUSTERED INDEX ' + QUOTENAME(@idxName) + N' ON ' + @SafeFull + N'([KVK_NO]);';
        EXEC sp_executesql @sql;
    END

    RETURN 0;
END

