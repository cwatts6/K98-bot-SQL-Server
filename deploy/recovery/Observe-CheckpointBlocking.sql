/* Read-only, bounded diagnostic. Run in a new SSMS window in ROK_TRACKER.
   SQL Server 2022: VIEW SERVER PERFORMANCE STATE is required. No grants are made.
   Start during an already-authorized operation; do not repeat an import to create
   evidence. Save all result sets. No SQL text, parameters or credentials collected.
   No rows means no wait was observed in this sample, never proof of no contention.
   Negative blocking IDs are SQL internal states, not a user session to terminate. */
SET NOCOUNT ON;
IF DB_NAME() <> N'ROK_TRACKER'
    THROW 51490, 'Select ROK_TRACKER before running this read-only diagnostic.', 1;
IF @@TRANCOUNT <> 0
    THROW 51490, 'Use a fresh query window without an open transaction.', 1;
DECLARE @RequestSessionId smallint = NULL; -- Optional exact requester from bot diagnostics.
DECLARE @Started datetime2(3) = SYSUTCDATETIME();
DECLARE @Until datetime2(3) = DATEADD(second, 15, @Started);
DECLARE @Samples int = 0;
DECLARE @Waits TABLE
(
    ObservedUTC datetime2(3), RequestSessionId smallint, RequestId int,
    BlockingSessionId smallint, WaitType nvarchar(60), WaitMilliseconds int,
    WaitResource nvarchar(256), RequestOpenTransactions int,
    BlockerOpenTransactions int, BlockerStatus nvarchar(30), BlockerCommand nvarchar(32)
);
WHILE SYSUTCDATETIME() < @Until AND @Samples < 150
      AND (SELECT COUNT(*) FROM @Waits) < 512
BEGIN
    INSERT @Waits
    SELECT TOP (32) SYSUTCDATETIME(), r.session_id, r.request_id,
        r.blocking_session_id, r.wait_type, r.wait_time, r.wait_resource,
        rs.open_transaction_count, bs.open_transaction_count, bs.status, br.command
    FROM sys.dm_exec_requests AS r
    LEFT JOIN sys.dm_exec_sessions AS rs ON rs.session_id = r.session_id
    LEFT JOIN sys.dm_exec_sessions AS bs ON bs.session_id = r.blocking_session_id
    OUTER APPLY (SELECT TOP (1) command FROM sys.dm_exec_requests
                 WHERE session_id = r.blocking_session_id ORDER BY request_id) AS br
    WHERE r.database_id = DB_ID() AND r.session_id <> @@SPID
      AND (@RequestSessionId IS NULL OR r.session_id = @RequestSessionId)
      AND (r.blocking_session_id <> 0 OR r.wait_type LIKE N'LCK[_]M[_]%')
    ORDER BY r.session_id, r.request_id;
    SET @Samples += 1;
    WAITFOR DELAY '00:00:00.100';
END;
SELECT @Started AS StartedUTC, SYSUTCDATETIME() AS FinishedUTC,
    @Samples AS Samples, (SELECT COUNT(*) FROM @Waits) AS ObservedWaitRows,
    CAST(CASE WHEN (SELECT COUNT(*) FROM @Waits) >= 512 THEN 1 ELSE 0 END AS bit) AS Truncated;
SELECT * FROM @Waits ORDER BY ObservedUTC, RequestSessionId, RequestId;

-- Index inventory explains lookup breadth without generating or executing a plan.
SELECT i.name AS IndexName, i.type_desc, i.has_filter, i.filter_definition,
    c.name AS ColumnName, ic.key_ordinal, ic.is_included_column
FROM sys.indexes AS i
JOIN sys.index_columns AS ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns AS c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE i.object_id = OBJECT_ID(N'dbo.ExportResource')
ORDER BY i.index_id, ic.key_ordinal, ic.index_column_id;
