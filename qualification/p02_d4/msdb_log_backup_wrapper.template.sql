
CREATE PROCEDURE dbo.usp_start_rok_tracker_log_backup
WITH EXECUTE AS OWNER
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @job_id UNIQUEIDENTIFIER = '__K98_LOG_BACKUP_JOB_ID__';

  EXEC msdb.dbo.sp_start_job @job_id = @job_id;
END;
