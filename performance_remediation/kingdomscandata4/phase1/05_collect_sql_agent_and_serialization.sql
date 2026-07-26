/*
Purpose: Read-only Phase 1 SQL Agent scheduling and overlap evidence for
         the KingdomScanData4 / UPDATE_ALL2 import path.
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

DECLARE @CollectedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @HistorySinceLocal datetime2(0) = DATEADD(day, -90, SYSDATETIME());
DECLARE @CollectorRevision nvarchar(30) = N'20260724.2';

SELECT
    N'sql_agent_collection_context' AS EvidenceSection,
    @CollectorRevision AS CollectorRevision,
    @@SERVERNAME AS ServerName,
    DB_NAME() AS DatabaseName,
    ORIGINAL_LOGIN() AS OriginalLogin,
    IS_SRVROLEMEMBER(N'sysadmin') AS IsSysadmin,
    HAS_PERMS_BY_NAME(NULL, NULL, N'VIEW SERVER STATE') AS HasViewServerState,
    @HistorySinceLocal AS HistorySinceServerLocal,
    @CollectedAtUtc AS CollectedAtUtc;

BEGIN TRY
    SELECT
        N'sql_agent_service' AS EvidenceSection,
        servicename AS ServiceName,
        startup_type_desc AS StartupType,
        status_desc AS ServiceStatus,
        service_account AS ServiceAccount,
        process_id AS ProcessId,
        last_startup_time AS LastStartupTime,
        filename AS ExecutablePath,
        instant_file_initialization_enabled AS InstantFileInitializationEnabled
    FROM sys.dm_server_services
    WHERE servicename LIKE N'SQL Server Agent%';
END TRY
BEGIN CATCH
    SELECT
        N'sql_agent_service_unavailable' AS EvidenceSection,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_MESSAGE() AS ErrorMessage;
END CATCH;

DECLARE @RelevantJobs table
(
    job_id uniqueidentifier NOT NULL PRIMARY KEY,
    MatchReason nvarchar(1000) NOT NULL
);

BEGIN TRY
    INSERT @RelevantJobs (job_id, MatchReason)
    SELECT
        j.job_id,
        CONCAT(
            CASE
                WHEN j.name LIKE N'%scan%'
                  OR j.name LIKE N'%import%'
                  OR j.name LIKE N'%stats%'
                  OR j.name LIKE N'%download%'
                  OR j.name LIKE N'%rok%'
                    THEN N'job-name;'
                ELSE N''
            END,
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM msdb.dbo.sysjobsteps AS jsx
                    WHERE jsx.job_id = j.job_id
                      AND
                      (
                          jsx.command LIKE N'%UPDATE_ALL2%'
                          OR jsx.command LIKE N'%IMPORT_STAGING%'
                          OR jsx.command LIKE N'%KingdomScanData4%'
                          OR jsx.command LIKE N'%stats.csv%'
                      )
                )
                    THEN N'import-command;'
                ELSE N''
            END,
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM msdb.dbo.sysjobsteps AS jsx
                    WHERE jsx.job_id = j.job_id
                      AND
                      (
                          jsx.command LIKE N'%discord_file_downloader%'
                          OR jsx.command LIKE N'%download%'
                          OR jsx.command LIKE N'%Import_Archive%'
                          OR jsx.command LIKE N'%python%'
                      )
                )
                    THEN N'external-or-download-command;'
                ELSE N''
            END,
            CASE
                WHEN EXISTS
                (
                    SELECT 1
                    FROM msdb.dbo.sysjobsteps AS jsx
                    WHERE jsx.job_id = j.job_id
                      AND
                      (
                          jsx.database_name = N'ROK_TRACKER'
                          OR jsx.command LIKE N'%ROK_TRACKER%'
                      )
                )
                    THEN N'rok-tracker-command;'
                ELSE N''
            END
        ) AS MatchReason
    FROM msdb.dbo.sysjobs AS j
    WHERE
        j.name LIKE N'%scan%'
        OR j.name LIKE N'%import%'
        OR j.name LIKE N'%stats%'
        OR j.name LIKE N'%download%'
        OR j.name LIKE N'%rok%'
        OR EXISTS
        (
            SELECT 1
            FROM msdb.dbo.sysjobsteps AS js
            WHERE js.job_id = j.job_id
              AND
              (
                  js.command LIKE N'%UPDATE_ALL2%'
                  OR js.command LIKE N'%IMPORT_STAGING%'
                  OR js.command LIKE N'%KingdomScanData4%'
                  OR js.command LIKE N'%stats.csv%'
                  OR js.command LIKE N'%discord_file_downloader%'
                  OR js.command LIKE N'%download%'
                  OR js.command LIKE N'%Import_Archive%'
                  OR js.command LIKE N'%python%'
                  OR js.database_name = N'ROK_TRACKER'
                  OR js.command LIKE N'%ROK_TRACKER%'
              )
        );

    SELECT
        N'sql_agent_inventory_summary' AS EvidenceSection,
        (SELECT COUNT_BIG(*) FROM msdb.dbo.sysjobs) AS VisibleJobCount,
        (SELECT COUNT_BIG(*) FROM @RelevantJobs) AS RelevantJobCount,
        (
            SELECT COUNT_BIG(*)
            FROM @RelevantJobs AS er
            JOIN msdb.dbo.sysjobs AS ej
              ON ej.job_id = er.job_id
            WHERE ej.enabled = 1
        ) AS EnabledRelevantJobCount,
        (
            SELECT COUNT_BIG(*)
            FROM @RelevantJobs AS esr
            JOIN msdb.dbo.sysjobs AS esj
              ON esj.job_id = esr.job_id
            WHERE esj.enabled = 1
              AND EXISTS
              (
                  SELECT 1
                  FROM msdb.dbo.sysjobschedules AS esjs
                  JOIN msdb.dbo.sysschedules AS ess
                    ON ess.schedule_id = esjs.schedule_id
                  WHERE esjs.job_id = esr.job_id
                    AND ess.enabled = 1
              )
        ) AS EnabledRelevantJobsWithEnabledSchedule,
        @CollectedAtUtc AS CollectedAtUtc
    ;

    SELECT
        N'sql_agent_relevant_jobs' AS EvidenceSection,
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
        r.MatchReason
    FROM @RelevantJobs AS r
    JOIN msdb.dbo.sysjobs AS j
      ON j.job_id = r.job_id
    LEFT JOIN msdb.dbo.syscategories AS c
      ON c.category_id = j.category_id
     AND c.category_class = 1
    ORDER BY j.name;

    SELECT
        N'sql_agent_relevant_job_steps' AS EvidenceSection,
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
        js.flags AS StepFlags,
        r.MatchReason
    FROM @RelevantJobs AS r
    JOIN msdb.dbo.sysjobs AS j
      ON j.job_id = r.job_id
    JOIN msdb.dbo.sysjobsteps AS js
      ON js.job_id = r.job_id
    ORDER BY j.name, js.step_id;

    SELECT
        N'sql_agent_relevant_job_schedules' AS EvidenceSection,
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
                THEN msdb.dbo.agent_datetime(jsc.next_run_date, jsc.next_run_time)
            ELSE NULL
        END AS NextRunServerLocal,
        CASE
            WHEN jsv.last_run_date > 0
                THEN msdb.dbo.agent_datetime(jsv.last_run_date, jsv.last_run_time)
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
    FROM @RelevantJobs AS r
    JOIN msdb.dbo.sysjobs AS j
      ON j.job_id = r.job_id
    LEFT JOIN msdb.dbo.sysjobschedules AS jsc
      ON jsc.job_id = r.job_id
    LEFT JOIN msdb.dbo.sysschedules AS sc
      ON sc.schedule_id = jsc.schedule_id
    LEFT JOIN msdb.dbo.sysjobservers AS jsv
      ON jsv.job_id = r.job_id
     AND jsv.server_id = 0
    ORDER BY j.name, sc.name;

    DECLARE @CurrentAgentSessionId int =
    (
        SELECT MAX(session_id)
        FROM msdb.dbo.syssessions
    );

    SELECT
        N'sql_agent_current_activity' AS EvidenceSection,
        j.job_id AS JobId,
        j.name AS JobName,
        a.run_requested_date AS RunRequestedServerLocal,
        a.queued_date AS QueuedServerLocal,
        a.start_execution_date AS StartedServerLocal,
        a.stop_execution_date AS StoppedServerLocal,
        a.last_executed_step_id AS LastExecutedStepId,
        a.last_executed_step_date AS LastExecutedStepServerLocal,
        a.next_scheduled_run_date AS NextScheduledRunServerLocal,
        CASE
            WHEN a.start_execution_date IS NOT NULL
             AND a.stop_execution_date IS NULL
                THEN 1
            ELSE 0
        END AS IsRunning
    FROM @RelevantJobs AS r
    JOIN msdb.dbo.sysjobs AS j
      ON j.job_id = r.job_id
    LEFT JOIN msdb.dbo.sysjobactivity AS a
      ON a.job_id = r.job_id
     AND a.session_id = @CurrentAgentSessionId
    ORDER BY j.name;

    DECLARE @RecentOutcomes table
    (
        instance_id int NOT NULL PRIMARY KEY,
        job_id uniqueidentifier NOT NULL,
        RunStartedAt datetime NOT NULL,
        DurationSeconds bigint NOT NULL,
        RunFinishedAt datetime NOT NULL,
        run_status int NOT NULL,
        message nvarchar(4000) NULL,
        retries_attempted int NOT NULL,
        operator_id_emailed int NULL,
        operator_id_netsent int NULL,
        operator_id_paged int NULL
    );

    INSERT @RecentOutcomes
    (
        instance_id,
        job_id,
        RunStartedAt,
        DurationSeconds,
        RunFinishedAt,
        run_status,
        message,
        retries_attempted,
        operator_id_emailed,
        operator_id_netsent,
        operator_id_paged
    )
    SELECT
        h.instance_id,
        h.job_id,
        dt.RunStartedAt,
        dur.DurationSeconds,
        DATEADD(second, dur.DurationSeconds, dt.RunStartedAt),
        h.run_status,
        h.message,
        h.retries_attempted,
        h.operator_id_emailed,
        h.operator_id_netsent,
        h.operator_id_paged
    FROM msdb.dbo.sysjobhistory AS h
    JOIN @RelevantJobs AS r
      ON r.job_id = h.job_id
    CROSS APPLY
    (
        SELECT msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunStartedAt
    ) AS dt
    CROSS APPLY
    (
        SELECT CONVERT(bigint, h.run_duration / 10000) * 3600
             + CONVERT(bigint, (h.run_duration % 10000) / 100) * 60
             + CONVERT(bigint, h.run_duration % 100) AS DurationSeconds
    ) AS dur
    WHERE h.step_id = 0
      AND h.run_date > 0
      AND dt.RunStartedAt >= @HistorySinceLocal;

    SELECT
        N'sql_agent_recent_job_outcomes' AS EvidenceSection,
        j.job_id AS JobId,
        j.name AS JobName,
        o.instance_id AS HistoryInstanceId,
        o.RunStartedAt AS RunStartedServerLocal,
        o.RunFinishedAt AS RunFinishedServerLocal,
        o.DurationSeconds,
        o.run_status AS RunStatusCode,
        CASE o.run_status
            WHEN 0 THEN N'Failed'
            WHEN 1 THEN N'Succeeded'
            WHEN 2 THEN N'Retry'
            WHEN 3 THEN N'Canceled'
            WHEN 4 THEN N'In progress'
            ELSE N'Unknown'
        END AS RunStatus,
        o.retries_attempted AS RetriesAttempted,
        o.message AS HistoryMessage,
        o.operator_id_emailed AS OperatorIdEmailed,
        email_operator.name AS OperatorEmailed,
        o.operator_id_netsent AS OperatorIdNetSent,
        netsend_operator.name AS OperatorNetSent,
        o.operator_id_paged AS OperatorIdPaged,
        page_operator.name AS OperatorPaged
    FROM @RecentOutcomes AS o
    JOIN msdb.dbo.sysjobs AS j
      ON j.job_id = o.job_id
    LEFT JOIN msdb.dbo.sysoperators AS email_operator
      ON email_operator.id = o.operator_id_emailed
    LEFT JOIN msdb.dbo.sysoperators AS netsend_operator
      ON netsend_operator.id = o.operator_id_netsent
    LEFT JOIN msdb.dbo.sysoperators AS page_operator
      ON page_operator.id = o.operator_id_paged
    ORDER BY o.RunStartedAt DESC, j.name;

    SELECT
        N'sql_agent_recent_job_summary' AS EvidenceSection,
        j.job_id AS JobId,
        j.name AS JobName,
        COUNT_BIG(o.instance_id) AS RunCount,
        SUM(CASE WHEN o.run_status = 1 THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
            AS SuccessCount,
        SUM(CASE WHEN o.run_status = 0 THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
            AS FailureCount,
        SUM(CASE WHEN o.run_status = 2 THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
            AS RetryCount,
        SUM(CASE WHEN o.run_status = 3 THEN CONVERT(bigint, 1) ELSE CONVERT(bigint, 0) END)
            AS CanceledCount,
        MIN(o.RunStartedAt) AS EarliestRunServerLocal,
        MAX(o.RunStartedAt) AS LatestRunServerLocal,
        CONVERT(decimal(19, 3), AVG(CONVERT(decimal(19, 3), o.DurationSeconds)))
            AS AverageDurationSeconds,
        MAX(o.DurationSeconds) AS MaximumDurationSeconds
    FROM @RelevantJobs AS r
    JOIN msdb.dbo.sysjobs AS j
      ON j.job_id = r.job_id
    LEFT JOIN @RecentOutcomes AS o
      ON o.job_id = r.job_id
    GROUP BY j.job_id, j.name
    ORDER BY j.name;

    SELECT
        N'sql_agent_recent_failure_steps' AS EvidenceSection,
        j.job_id AS JobId,
        j.name AS JobName,
        h.instance_id AS HistoryInstanceId,
        h.step_id AS StepId,
        h.step_name AS StepName,
        msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunStartedServerLocal,
        CONVERT(bigint, h.run_duration / 10000) * 3600
            + CONVERT(bigint, (h.run_duration % 10000) / 100) * 60
            + CONVERT(bigint, h.run_duration % 100) AS DurationSeconds,
        h.run_status AS RunStatusCode,
        CASE h.run_status
            WHEN 0 THEN N'Failed'
            WHEN 2 THEN N'Retry'
            WHEN 3 THEN N'Canceled'
            ELSE N'Other'
        END AS RunStatus,
        h.sql_severity AS SqlSeverity,
        h.sql_message_id AS SqlMessageId,
        h.retries_attempted AS RetriesAttempted,
        h.message AS HistoryMessage
    FROM msdb.dbo.sysjobhistory AS h
    JOIN @RelevantJobs AS r
      ON r.job_id = h.job_id
    JOIN msdb.dbo.sysjobs AS j
      ON j.job_id = h.job_id
    WHERE h.step_id > 0
      AND h.run_status IN (0, 2, 3)
      AND h.run_date > 0
      AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= @HistorySinceLocal
    ORDER BY h.instance_id DESC, h.step_id;

    SELECT
        N'sql_agent_recent_overlaps' AS EvidenceSection,
        ja.name AS JobA,
        a.RunStartedAt AS JobAStartedServerLocal,
        a.RunFinishedAt AS JobAFinishedServerLocal,
        a.DurationSeconds AS JobADurationSeconds,
        jb.name AS JobB,
        b.RunStartedAt AS JobBStartedServerLocal,
        b.RunFinishedAt AS JobBFinishedServerLocal,
        b.DurationSeconds AS JobBDurationSeconds,
        CASE
            WHEN a.RunStartedAt > b.RunStartedAt
                THEN a.RunStartedAt
            ELSE b.RunStartedAt
        END AS OverlapStartedServerLocal,
        CASE
            WHEN a.RunFinishedAt < b.RunFinishedAt
                THEN a.RunFinishedAt
            ELSE b.RunFinishedAt
        END AS OverlapFinishedServerLocal,
        DATEDIFF_BIG
        (
            second,
            CASE
                WHEN a.RunStartedAt > b.RunStartedAt
                    THEN a.RunStartedAt
                ELSE b.RunStartedAt
            END,
            CASE
                WHEN a.RunFinishedAt < b.RunFinishedAt
                    THEN a.RunFinishedAt
                ELSE b.RunFinishedAt
            END
        ) AS OverlapSeconds
    FROM @RecentOutcomes AS a
    JOIN @RecentOutcomes AS b
      ON a.job_id < b.job_id
     AND a.RunStartedAt < b.RunFinishedAt
     AND b.RunStartedAt < a.RunFinishedAt
    JOIN msdb.dbo.sysjobs AS ja
      ON ja.job_id = a.job_id
    JOIN msdb.dbo.sysjobs AS jb
      ON jb.job_id = b.job_id
    ORDER BY OverlapStartedServerLocal DESC, ja.name, jb.name;

    SELECT
        N'sql_agent_scheduler_resolution' AS EvidenceSection,
        (SELECT COUNT_BIG(*) FROM @RelevantJobs) AS RelevantJobCount,
        (
            SELECT COUNT_BIG(*)
            FROM @RelevantJobs AS er
            JOIN msdb.dbo.sysjobs AS ej
              ON ej.job_id = er.job_id
            WHERE ej.enabled = 1
        ) AS EnabledRelevantJobCount,
        (
            SELECT COUNT_BIG(*)
            FROM @RelevantJobs AS esr
            JOIN msdb.dbo.sysjobs AS esj
              ON esj.job_id = esr.job_id
            JOIN msdb.dbo.sysjobschedules AS esjs
              ON esjs.job_id = esr.job_id
            JOIN msdb.dbo.sysschedules AS ess
              ON ess.schedule_id = esjs.schedule_id
            WHERE esj.enabled = 1
              AND ess.enabled = 1
        ) AS EnabledRelevantJobScheduleCount,
        CAST(NULL AS nvarchar(30)) AS AuthoritativeSchedulerVerdict,
        N'Reconcile this SQL Agent inventory with Task Scheduler, service, process, bot singleton, and filesystem-lock evidence.'
            AS RequiredExternalResolution;
END TRY
BEGIN CATCH
    SELECT
        N'sql_agent_inventory_unavailable' AS EvidenceSection,
        ERROR_NUMBER() AS ErrorNumber,
        ERROR_LINE() AS ErrorLine,
        ERROR_MESSAGE() AS ErrorMessage,
        N'The collector requires visibility into msdb SQL Agent metadata. Grant read access or run through an approved operator with sufficient access.'
            AS RequiredResolution;
END CATCH;
