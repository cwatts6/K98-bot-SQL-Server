SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CaptureLogHealth]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[CaptureLogHealth] AS' 
END
ALTER PROCEDURE [dbo].[CaptureLogHealth]
WITH EXECUTE AS CALLER
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @db sysname = N'ROK_TRACKER';

  DECLARE @used float =
    (SELECT CAST(used_log_space_in_percent AS float)
     FROM sys.dm_db_log_space_usage
     WHERE DB_NAME(database_id) = @db);

  DECLARE @reuse nvarchar(60) =
    (SELECT log_reuse_wait_desc FROM sys.databases WHERE name = @db);

  DECLARE @recovery nvarchar(60) =
    (SELECT recovery_model_desc FROM sys.databases WHERE name = @db);

  DECLARE @lastFull datetime2(0) =
    (SELECT TOP (1) backup_finish_date
     FROM msdb.dbo.backupset
     WHERE database_name = @db AND type = 'D'
     ORDER BY backup_finish_date DESC);

  DECLARE @lastLog datetime2(0) =
    (SELECT TOP (1) backup_finish_date
     FROM msdb.dbo.backupset
     WHERE database_name = @db AND type = 'L'
     ORDER BY backup_finish_date DESC);

  INSERT dbo.LogHealthSamples (used_percent, reuse_wait_desc, recovery_model, last_full_backup, last_log_backup)
  VALUES (@used, @reuse, @recovery, @lastFull, @lastLog);
END

