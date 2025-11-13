SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Maintain_PlayerKVKHistory]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Maintain_PlayerKVKHistory] AS' 
END
ALTER PROCEDURE [dbo].[sp_Maintain_PlayerKVKHistory]
	@KVK_NO [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @tbl sysname = CONCAT('EXCEL_FOR_KVK_', @KVK_NO);

    IF OBJECT_ID(@tbl,'U') IS NULL
    BEGIN
        RAISERROR('Expected table %s not found.', 16, 1, @tbl);
        RETURN;
    END;

    DECLARE @sql nvarchar(max) = N'
        WITH src AS (
            SELECT
                CAST([Gov_ID] AS bigint)          AS GovernorID,
                CAST(@KVK_NO AS int)              AS KVK_NUMBER,
                CAST([KVK_KILL_RANK] AS int)           AS KVK_KILL_RANK,
                CAST(
                    COALESCE([% of Kill target],
                             CASE WHEN [Kill Target] IS NOT NULL AND [Kill Target] <> 0
                                  THEN ([T4&T5_Kills] / [Kill Target]) * 100.0
                             ELSE NULL END
                    ) 
                AS decimal(6,2))                  AS KillPercent
            FROM dbo.' + QUOTENAME(@tbl) + N'
            WHERE [Gov_ID] IS NOT NULL
        )
        MERGE dbo.PlayerKVKHistory AS tgt
        USING src AS s
          ON  tgt.GovernorID = s.GovernorID
          AND tgt.KVK_NUMBER = s.KVK_NUMBER
        WHEN MATCHED THEN
          UPDATE SET 
              tgt.KVK_KILL_RANK = s.KVK_KILL_RANK,
              tgt.KillPercent   = s.KillPercent
        WHEN NOT MATCHED BY TARGET THEN
          INSERT (GovernorID, KVK_NUMBER, KVK_KILL_RANK, KillPercent)
          VALUES (s.GovernorID, s.KVK_NUMBER, s.KVK_KILL_RANK, s.KillPercent);';

    EXEC sp_executesql @sql, N'@KVK_NO int', @KVK_NO = @KVK_NO;
END

