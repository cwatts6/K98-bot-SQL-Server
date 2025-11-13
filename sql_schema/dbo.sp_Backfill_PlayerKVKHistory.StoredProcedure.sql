SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Backfill_PlayerKVKHistory]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Backfill_PlayerKVKHistory] AS' 
END
ALTER PROCEDURE [dbo].[sp_Backfill_PlayerKVKHistory]
WITH EXECUTE AS CALLER
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @kvk int;

  -- Build the list strictly from existing tables to avoid invalid-object errors
  DECLARE c CURSOR FAST_FORWARD FOR
    SELECT TRY_CAST(REPLACE(name,'EXCEL_FOR_KVK_','') AS int) AS kvk
    FROM sys.tables
    WHERE name LIKE 'EXCEL_FOR_KVK[_]%'
      AND TRY_CAST(REPLACE(name,'EXCEL_FOR_KVK_','') AS int) IS NOT NULL
    ORDER BY TRY_CAST(REPLACE(name,'EXCEL_FOR_KVK_','') AS int);

  OPEN c;
  FETCH NEXT FROM c INTO @kvk;

  WHILE @@FETCH_STATUS = 0
  BEGIN
    BEGIN TRY
      EXEC dbo.sp_Maintain_PlayerKVKHistory @KVK_NO = @kvk;
      PRINT CONCAT('Backfill done for KVK ', @kvk);
    END TRY
    BEGIN CATCH
      PRINT CONCAT('Backfill skipped for KVK ', @kvk, ': ', ERROR_MESSAGE());
    END CATCH;

    FETCH NEXT FROM c INTO @kvk;
  END

  CLOSE c;
  DEALLOCATE c;
END

