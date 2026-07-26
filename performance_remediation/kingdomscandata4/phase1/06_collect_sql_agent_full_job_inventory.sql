/*
Purpose: Read-only supplement that emits every visible SQL Agent job, step,
         schedule, and last outcome after the targeted Gate 2 collector
         reported five visible jobs but emitted only four.
Safety: No job, schedule, history, data, or schema changes.
Target: ROK_TRACKER on the production SQL Server instance.

The report contains full SQL Agent step commands and may expose operational
paths or other sensitive configuration. Retain the raw .rpt outside Git.
*/

SET NOCOUNT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF DB_NAME() <> N'ROK_TRACKER'
BEGIN
    THROW 51000, 'Run this collector only in the ROK_TRACKER database.', 1;
END;

DECLARE @CollectorRevision nvarchar(30) = N'20260725.1';

BEGIN TRY
    SELECT
        N'sql_agent_full_inventory_context' AS EvidenceSection,
        @CollectorRevision AS CollectorRevision,
        @@SERVERNAME AS ServerName,
        DB_NAME() AS DatabaseName,
        ORIGINAL_LOGIN() AS OriginalLogin,
        IS_SRVROLEMEMBER(N'sysadmin') AS IsSysadmin,
        COUNT_BIG(*) AS VisibleJobCount,
        SYSUTCDATETIME() AS CollectedAtUtc
    FROM msdb.dbo.sysjobs;

    SELECT
        N'sql_agent_all_jobs' AS EvidenceSection,
        j.job_id AS JobId,
        j.name AS JobName,
        j.enabled AS JobEnabled,
        SUSER_SNAME(j.owner_sid) AS OwnerLogin,
        c.name AS CategoryName,
        j.description AS JobDescription,
        j.start_step_id AS StartStepId,
        j.notify_level_eventlog AS NotifyLevelEventLog,
        j.notify_level_email AS NotifyLevelEmail,
        j.notify_level_netsend AS NotifyLevelNetSend,
        j.notify_level_page AS NotifyLevelPage,
        j.delete_level AS DeleteLevel,
        j.date_created AS DateCreated,
        j.date_modified AS DateModified,
        j.version_number AS VersionNumber,
        CASE
            WHEN jsv.last_run_date > 0
                THEN msdb.dbo.agent_datetime(
                    jsv.last_run_date,
                    jsv.last_run_time
                )
            ELSE NULL
        END AS LastRunServerLocal,
        jsv.last_run_outcome AS LastRunOutcomeCode,
        CASE jsv.last_run_outcome
            WHEN 0 THEN N'Failed'
            WHEN 1 THEN N'Succeeded'
            WHEN 2 THEN N'Retry'
            WHEN 3 THEN N'Canceled'
            WHEN 4 THEN N'In progress'
            WHEN 5 THEN N'Unknown'
            ELSE NULL
        END AS LastRunOutcome
    FROM msdb.dbo.sysjobs AS j
    LEFT JOIN msdb.dbo.syscategories AS c
      ON c.category_id = j.category_id
     AND c.category_class = 1
    LEFT JOIN msdb.dbo.sysjobservers AS jsv
      ON jsv.job_id = j.job_id
     AND jsv.server_id = 0
    ORDER BY j.name;

    SELECT
        N'sql_agent_all_job_steps' AS EvidenceSection,
        j.job_id AS JobId,
        j.name AS JobName,
        js.step_id AS StepId,
        js.step_name AS StepName,
        js.subsystem AS Subsystem,
        js.database_name AS DatabaseName,
        js.database_user_name AS DatabaseUserName,
        js.proxy_id AS ProxyId,
        js.command AS CommandText,
        js.output_file_name AS OutputFileName,
        js.retry_attempts AS RetryAttempts,
        js.retry_interval AS RetryIntervalMinutes,
        js.on_success_action AS OnSuccessAction,
        js.on_success_step_id AS OnSuccessStepId,
        js.on_fail_action AS OnFailAction,
        js.on_fail_step_id AS OnFailStepId,
        js.flags AS StepFlags
    FROM msdb.dbo.sysjobs AS j
    JOIN msdb.dbo.sysjobsteps AS js
      ON js.job_id = j.job_id
    ORDER BY j.name, js.step_id;

    SELECT
        N'sql_agent_all_job_schedules' AS EvidenceSection,
        j.job_id AS JobId,
        j.name AS JobName,
        j.enabled AS JobEnabled,
        sc.schedule_id AS ScheduleId,
        sc.schedule_uid AS ScheduleUid,
        sc.name AS ScheduleName,
        sc.enabled AS ScheduleEnabled,
        CASE sc.freq_type
            WHEN 1 THEN N'Once'
            WHEN 4 THEN N'Daily'
            WHEN 8 THEN N'Weekly'
            WHEN 16 THEN N'Monthly'
            WHEN 32 THEN N'Monthly relative'
            WHEN 64 THEN N'At SQL Agent startup'
            WHEN 128 THEN N'When CPUs are idle'
            ELSE CONCAT(N'Unknown(', sc.freq_type, N')')
        END AS FrequencyType,
        sc.freq_interval AS FrequencyInterval,
        sc.freq_subday_type AS FrequencySubdayType,
        sc.freq_subday_interval AS FrequencySubdayInterval,
        sc.freq_relative_interval AS FrequencyRelativeInterval,
        sc.freq_recurrence_factor AS FrequencyRecurrenceFactor,
        sc.active_start_date AS ActiveStartDate,
        sc.active_end_date AS ActiveEndDate,
        sc.active_start_time AS ActiveStartTime,
        sc.active_end_time AS ActiveEndTime,
        CASE
            WHEN jsc.next_run_date > 0
                THEN msdb.dbo.agent_datetime(
                    jsc.next_run_date,
                    jsc.next_run_time
                )
            ELSE NULL
        END AS NextRunServerLocal
    FROM msdb.dbo.sysjobs AS j
    LEFT JOIN msdb.dbo.sysjobschedules AS jsc
      ON jsc.job_id = j.job_id
    LEFT JOIN msdb.dbo.sysschedules AS sc
      ON sc.schedule_id = jsc.schedule_id
    ORDER BY j.name, sc.name;
END TRY
BEGIN CATCH
    SELECT
        N'sql_agent_full_inventory_unavailable' AS EvidenceSection,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_LINE() AS ErrorLine,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;
