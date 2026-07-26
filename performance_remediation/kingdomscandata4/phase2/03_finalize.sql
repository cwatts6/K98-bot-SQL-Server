/*
Purpose:
    Irreversible Phase 2 finalization after accepted verification and before
    application/import restart.

Safety:
    - Confirmation variables default to refusal.
    - Requires the exact run ID and a verification completed in the last five minutes.
    - Requires no conflicting user session and an exclusive migration application lock.
    - Locks all canonical and retained tables, then recomputes exact normalized
      row counts and digests inside the same transaction that drops the originals.
    - Drops only the three retained *_Phase2_Old tables.
    - Never drops the guarded pristine database snapshot.

After this succeeds, metadata-swap rollback is no longer available. Use a
forward fix or the backup/log recovery branch.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;

DECLARE @ScriptRevision varchar(20) = '20260726.1';
DECLARE @ConfirmRunId uniqueidentifier = NULL;
DECLARE @ConfirmIrreversibleFinalize bit = 0;
DECLARE @RunId uniqueidentifier;
DECLARE @ProductionApproved bit;
DECLARE @ApplicationLockResult int;
DECLARE @ExpectedKs4Rows bigint;
DECLARE @ExpectedKs5Rows bigint;
DECLARE @ExpectedStagingRows bigint;
DECLARE @BaselineKs4Digest varbinary(32);
DECLARE @BaselineKs5Digest varbinary(32);
DECLARE @BaselineStagingDigest varbinary(32);
DECLARE @ForwardKs4Digest varbinary(32);
DECLARE @ForwardKs5Digest varbinary(32);
DECLARE @ForwardStagingDigest varbinary(32);
DECLARE @ExpectedKs5PrimaryKeyName sysname;
DECLARE @Sql nvarchar(max);

IF @ConfirmRunId IS NULL OR @ConfirmIrreversibleFinalize <> 1
    THROW 51660, 'Safety stop: confirm the exact run ID and irreversible finalize action.', 1;

IF OBJECT_ID(N'dbo.KS4_Phase2_PreflightState', N'U') IS NULL
    THROW 51661, 'Phase 2 migration state is absent.', 1;

SELECT
    @RunId = RunId,
    @ProductionApproved = ProductionApproved,
    @ExpectedKs4Rows = Ks4Rows,
    @ExpectedKs5Rows = Ks5Rows,
    @ExpectedStagingRows = StagingRows,
    @BaselineKs4Digest = BaselineKs4Digest,
    @BaselineKs5Digest = BaselineKs5Digest,
    @BaselineStagingDigest = BaselineStagingDigest,
    @ForwardKs4Digest = ForwardKs4Digest,
    @ForwardKs5Digest = ForwardKs5Digest,
    @ForwardStagingDigest = ForwardStagingDigest
FROM dbo.KS4_Phase2_PreflightState
WHERE RunId = @ConfirmRunId
  AND DatabaseName = DB_NAME()
  AND ServerName = @@SERVERNAME
  AND Status = 'VERIFIED'
  AND VerifiedAtUtc >= DATEADD(minute, -5, SYSUTCDATETIME())
  AND RollbackCompletedAtUtc IS NULL
  AND FinalizedAtUtc IS NULL;

IF @RunId IS NULL
    THROW 51662, 'No matching verification from the last five minutes exists; rerun 02_verify.sql.', 1;

IF @ExpectedKs4Rows IS NULL
   OR @ExpectedKs5Rows IS NULL
   OR @ExpectedStagingRows IS NULL
   OR @BaselineKs4Digest IS NULL
   OR @BaselineKs5Digest IS NULL
   OR @BaselineStagingDigest IS NULL
   OR @ForwardKs4Digest IS NULL
   OR @ForwardKs5Digest IS NULL
   OR @ForwardStagingDigest IS NULL
    THROW 51671, 'The verified run is missing an exact row-count or digest receipt.', 1;

IF DB_NAME() = N'ROK_TRACKER' AND @ProductionApproved <> 1
    THROW 51663, 'The run did not record separate production approval.', 1;

IF @@TRANCOUNT <> 0
    THROW 51664, 'Run finalization with no existing user transaction.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NULL
    THROW 51665, 'The exact retained-original set is incomplete.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Failed', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Failed', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Failed', N'U') IS NOT NULL
    THROW 51666, 'Failed-copy artifacts indicate a rollback branch; finalization is forbidden.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    EXEC @ApplicationLockResult = sys.sp_getapplock
        @Resource = N'K98:KingdomScanData4:Migration',
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = 0,
        @DbPrincipal = N'public';

    IF @ApplicationLockResult < 0
        THROW 51667, 'Could not acquire the Phase 2 migration application lock.', 1;

    /*
    Lock the accepted state row through commit and revalidate it after the
    application lock is held. This prevents a stale or concurrently changed
    receipt from authorizing irreversible cleanup.
    */
    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_PreflightState WITH (UPDLOCK, HOLDLOCK)
        WHERE RunId = @RunId
          AND DatabaseName = DB_NAME()
          AND ServerName = @@SERVERNAME
          AND Status = 'VERIFIED'
          AND VerifiedAtUtc >= DATEADD(minute, -5, SYSUTCDATETIME())
          AND RollbackCompletedAtUtc IS NULL
          AND FinalizedAtUtc IS NULL
          AND Ks4Rows = @ExpectedKs4Rows
          AND Ks5Rows = @ExpectedKs5Rows
          AND StagingRows = @ExpectedStagingRows
          AND BaselineKs4Digest = @BaselineKs4Digest
          AND BaselineKs5Digest = @BaselineKs5Digest
          AND BaselineStagingDigest = @BaselineStagingDigest
          AND ForwardKs4Digest = @ForwardKs4Digest
          AND ForwardKs5Digest = @ForwardKs5Digest
          AND ForwardStagingDigest = @ForwardStagingDigest
    )
        THROW 51672, 'The verified run receipt changed or expired before finalization.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.dm_exec_sessions AS session_info
        LEFT JOIN sys.dm_exec_requests AS request_info
          ON request_info.session_id = session_info.session_id
        WHERE session_info.is_user_process = 1
          AND session_info.session_id <> @@SPID
          AND COALESCE(request_info.database_id, session_info.database_id) = DB_ID()
          AND NOT
          (
              session_info.program_name LIKE N'Microsoft SQL Server Management Studio%IntelliSense%'
              AND request_info.session_id IS NULL
              AND session_info.open_transaction_count = 0
              AND session_info.status = N'sleeping'
          )
    )
        THROW 51668, 'Conflicting user sessions are connected.', 1;

    SELECT @ExpectedKs5PrimaryKeyName = IndexName
    FROM dbo.KS4_Phase2_IndexInventory WITH (HOLDLOCK)
    WHERE RunId = @RunId
      AND ObjectName = N'KingdomScanData5'
      AND IsPrimaryKey = 1;

    IF @ExpectedKs5PrimaryKeyName IS NULL
       OR
       (
           SELECT COUNT(*)
           FROM dbo.KS4_Phase2_IndexInventory WITH (HOLDLOCK)
           WHERE RunId = @RunId
             AND ObjectName = N'KingdomScanData5'
             AND IsPrimaryKey = 1
       ) <> 1
       OR OBJECT_ID(N'dbo.DF_KS4_Phase2_New_SCAN_UNO', N'D') IS NULL
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.key_constraints
           WHERE parent_object_id = OBJECT_ID(N'dbo.KingdomScanData5', N'U')
             AND [type] = 'PK'
             AND name = @ExpectedKs5PrimaryKeyName
       )
        THROW 51669, 'Expected pre-finalize canonical constraint names are absent.', 1;

    DECLARE @BigintMap table
    (
        LogicalName sysname NOT NULL,
        ColumnName sysname NOT NULL,
        PRIMARY KEY (LogicalName, ColumnName)
    );
    DECLARE @IntMap table
    (
        LogicalName sysname NOT NULL,
        ColumnName sysname NOT NULL,
        PRIMARY KEY (LogicalName, ColumnName)
    );
    DECLARE @StringMap table
    (
        LogicalName sysname NOT NULL,
        ColumnName sysname NOT NULL,
        TargetLength int NOT NULL,
        TrimRight bit NOT NULL,
        PRIMARY KEY (LogicalName, ColumnName)
    );

    INSERT @BigintMap
    VALUES
        (N'KS4', N'GovernorID'), (N'KS4', N'Power'),
        (N'KS4', N'KillPoints'), (N'KS4', N'Deads'),
        (N'KS4', N'T1_Kills'), (N'KS4', N'T2_Kills'),
        (N'KS4', N'T3_Kills'), (N'KS4', N'T4_Kills'),
        (N'KS4', N'T5_Kills'), (N'KS4', N'T4&T5_KILLS'),
        (N'KS4', N'TOTAL_KILLS'), (N'KS4', N'RSS_Gathered'),
        (N'KS4', N'RSSAssistance'), (N'KS4', N'Helps'),
        (N'KS5', N'GovernorID'), (N'KS5', N'Power'),
        (N'KS5', N'KillPoints'), (N'KS5', N'Deads'),
        (N'KS5', N'T1_Kills'), (N'KS5', N'T2_Kills'),
        (N'KS5', N'T3_Kills'), (N'KS5', N'T4_Kills'),
        (N'KS5', N'T5_Kills'), (N'KS5', N'T4&T5_KILLS'),
        (N'KS5', N'TOTAL_KILLS'), (N'KS5', N'RSS_Gathered'),
        (N'KS5', N'RSSAssistance'), (N'KS5', N'Helps'),
        (N'STAGING', N'Governor ID'), (N'STAGING', N'Power'),
        (N'STAGING', N'Total Kill Points'), (N'STAGING', N'Dead Troops'),
        (N'STAGING', N'T1-Kills'), (N'STAGING', N'T2-Kills'),
        (N'STAGING', N'T3-Kills'), (N'STAGING', N'T4-Kills'),
        (N'STAGING', N'T5-Kills'), (N'STAGING', N'Kills (T4+)'),
        (N'STAGING', N'KILLS'), (N'STAGING', N'RSS Gathered'),
        (N'STAGING', N'RSS Assistance'), (N'STAGING', N'Alliance Helps');

    INSERT @IntMap
    VALUES
        (N'KS4', N'PowerRank'), (N'KS4', N'SCANORDER'),
        (N'KS5', N'PowerRank'), (N'KS5', N'SCANORDER'),
        (N'STAGING', N'SCANORDER');

    INSERT @StringMap
    VALUES
        (N'KS4', N'GovernorName', 200, 1),
        (N'KS4', N'Alliance', 100, 1),
        (N'KS5', N'GovernorName', 200, 1),
        (N'KS5', N'Alliance', 100, 1),
        (N'STAGING', N'Name', 200, 1),
        (N'STAGING', N'Alliance', 100, 1),
        (N'STAGING', N'Updated_on', 200, 0);

    DECLARE @DigestWork table
    (
        LogicalName sysname NOT NULL,
        PhysicalName sysname NOT NULL,
        DigestKind varchar(12) NOT NULL,
        ExpectedRows bigint NOT NULL,
        ExpectedDigest varbinary(32) NOT NULL,
        PRIMARY KEY (LogicalName, DigestKind)
    );
    DECLARE @Digests table
    (
        LogicalName sysname NOT NULL,
        DigestKind varchar(12) NOT NULL,
        [RowCount] bigint NOT NULL,
        Digest varbinary(32) NOT NULL,
        PRIMARY KEY (LogicalName, DigestKind)
    );

    INSERT @DigestWork
    VALUES
        (N'KS4', N'KingdomScanData4', 'CURRENT',
         @ExpectedKs4Rows, @ForwardKs4Digest),
        (N'KS5', N'KingdomScanData5', 'CURRENT',
         @ExpectedKs5Rows, @ForwardKs5Digest),
        (N'STAGING', N'IMPORT_STAGING', 'CURRENT',
         @ExpectedStagingRows, @ForwardStagingDigest),
        (N'KS4', N'KingdomScanData4_Phase2_Old', 'RETAINED',
         @ExpectedKs4Rows, @BaselineKs4Digest),
        (N'KS5', N'KingdomScanData5_Phase2_Old', 'RETAINED',
         @ExpectedKs5Rows, @BaselineKs5Digest),
        (N'STAGING', N'IMPORT_STAGING_Phase2_Old', 'RETAINED',
         @ExpectedStagingRows, @BaselineStagingDigest);

    DECLARE
        @LogicalName sysname,
        @PhysicalName sysname,
        @DigestKind varchar(12),
        @ExpectedRows bigint,
        @ExpectedDigest varbinary(32),
        @Projection nvarchar(max),
        @CanonicalRows nvarchar(max),
        @Digest varbinary(32),
        @DigestRows bigint,
        @DigestStartedAtUtc datetime2(7) = SYSUTCDATETIME(),
        @DigestFinishedAtUtc datetime2(7);

    /*
    Runtime writers do not yet share the migration application lock. Hold
    exclusive locks on both canonical and retained tables from the final
    digest check through the irreversible drop.
    */
    DECLARE @LockWitness bigint;
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData5 WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData4 WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.IMPORT_STAGING_Phase2_Old WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData5_Phase2_Old WITH (TABLOCKX, HOLDLOCK);
    SELECT @LockWitness = COUNT_BIG(*)
    FROM dbo.KingdomScanData4_Phase2_Old WITH (TABLOCKX, HOLDLOCK);

    DECLARE digest_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT LogicalName, PhysicalName, DigestKind, ExpectedRows, ExpectedDigest
    FROM @DigestWork
    ORDER BY
        CASE PhysicalName
            WHEN N'IMPORT_STAGING' THEN 1
            WHEN N'KingdomScanData5' THEN 2
            WHEN N'KingdomScanData4' THEN 3
            WHEN N'IMPORT_STAGING_Phase2_Old' THEN 4
            WHEN N'KingdomScanData5_Phase2_Old' THEN 5
            WHEN N'KingdomScanData4_Phase2_Old' THEN 6
        END;

    OPEN digest_cursor;
    FETCH NEXT FROM digest_cursor
    INTO @LogicalName, @PhysicalName, @DigestKind,
         @ExpectedRows, @ExpectedDigest;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @Projection =
            STRING_AGG(
                CONVERT(nvarchar(max),
                    CASE
                        WHEN bigint_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(bigint, source.' + QUOTENAME(column_info.name)
                                 + N') AS ' + QUOTENAME(column_info.name)
                        WHEN int_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(int, source.' + QUOTENAME(column_info.name)
                                 + N') AS ' + QUOTENAME(column_info.name)
                        WHEN string_map.ColumnName IS NOT NULL
                            THEN N'CONVERT(nvarchar('
                                 + CONVERT(nvarchar(10), string_map.TargetLength)
                                 + N'), '
                                 + CASE WHEN string_map.TrimRight = 1
                                        THEN N'RTRIM(source.' + QUOTENAME(column_info.name) + N')'
                                        ELSE N'source.' + QUOTENAME(column_info.name) END
                                 + N') COLLATE Latin1_General_CI_AS AS '
                                 + QUOTENAME(column_info.name)
                        WHEN @LogicalName = N'KS4' AND column_info.name = N'AsOfDate'
                            THEN N'CONVERT(date, source.[ScanDate]) AS [AsOfDate]'
                        ELSE N'source.' + QUOTENAME(column_info.name)
                             + N' AS ' + QUOTENAME(column_info.name)
                    END),
                N',') WITHIN GROUP (ORDER BY column_info.column_id)
        FROM sys.columns AS column_info
        LEFT JOIN @BigintMap AS bigint_map
          ON bigint_map.LogicalName = @LogicalName
         AND bigint_map.ColumnName = column_info.name
        LEFT JOIN @IntMap AS int_map
          ON int_map.LogicalName = @LogicalName
         AND int_map.ColumnName = column_info.name
        LEFT JOIN @StringMap AS string_map
          ON string_map.LogicalName = @LogicalName
         AND string_map.ColumnName = column_info.name
        WHERE column_info.object_id = OBJECT_ID(N'dbo.' + @PhysicalName);

        IF @Projection IS NULL
            THROW 51673, 'Could not build a final normalized digest projection.', 1;

        SET @Sql = N'
            SELECT @Rows = COUNT_BIG(*) FROM dbo.' + QUOTENAME(@PhysicalName) + N';
            SELECT @Canonical =
            (
                SELECT row_hashes.RowDigest
                FROM
                (
                    SELECT CONVERT(char(64),
                        HASHBYTES(''SHA2_256'',
                            (SELECT ' + @Projection + N'
                             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER,
                                 INCLUDE_NULL_VALUES)), 2) AS RowDigest
                    FROM dbo.' + QUOTENAME(@PhysicalName) + N' AS source
                ) AS row_hashes
                ORDER BY row_hashes.RowDigest
                FOR JSON PATH
            );
            SET @OutputDigest =
                HASHBYTES(''SHA2_256'', COALESCE(@Canonical, N''[]''));';

        EXEC sys.sp_executesql
            @Sql,
            N'@Rows bigint OUTPUT, @Canonical nvarchar(max) OUTPUT,
              @OutputDigest varbinary(32) OUTPUT',
            @Rows = @DigestRows OUTPUT,
            @Canonical = @CanonicalRows OUTPUT,
            @OutputDigest = @Digest OUTPUT;

        IF @DigestRows <> @ExpectedRows
           OR @Digest IS NULL
           OR @Digest <> @ExpectedDigest
            THROW 51674, 'Finalization digest guard failed; canonical or retained data changed after verification.', 1;

        INSERT @Digests
            (LogicalName, DigestKind, [RowCount], Digest)
        VALUES
            (@LogicalName, @DigestKind, @DigestRows, @Digest);

        FETCH NEXT FROM digest_cursor
        INTO @LogicalName, @PhysicalName, @DigestKind,
             @ExpectedRows, @ExpectedDigest;
    END;

    CLOSE digest_cursor;
    DEALLOCATE digest_cursor;

    SET @DigestFinishedAtUtc = SYSUTCDATETIME();

    INSERT dbo.KS4_Phase2_MigrationReceipt
        (RunId, Direction, StepName, StartedAtUtc, FinishedAtUtc,
         DurationMs, RowsAffected, Notes)
    VALUES
        (@RunId, 'FINALIZE', N'pre_finalize_digest_guard',
         @DigestStartedAtUtc, @DigestFinishedAtUtc,
         DATEDIFF_BIG(microsecond, @DigestStartedAtUtc, @DigestFinishedAtUtc) / 1000.0,
         2 * (@ExpectedKs4Rows + @ExpectedKs5Rows + @ExpectedStagingRows),
         N'Canonical data still matches forward and retained originals still match baseline under exclusive locks.');

    /*
    A session may have connected while the exact digest check ran. It cannot
    write through the held table locks, but finalization still refuses the
    operationally invalid connected state before dropping retained tables.
    */
    IF EXISTS
    (
        SELECT 1
        FROM sys.dm_exec_sessions AS session_info
        LEFT JOIN sys.dm_exec_requests AS request_info
          ON request_info.session_id = session_info.session_id
        WHERE session_info.is_user_process = 1
          AND session_info.session_id <> @@SPID
          AND COALESCE(request_info.database_id, session_info.database_id) = DB_ID()
          AND NOT
          (
              session_info.program_name LIKE N'Microsoft SQL Server Management Studio%IntelliSense%'
              AND request_info.session_id IS NULL
              AND session_info.open_transaction_count = 0
              AND session_info.status = N'sleeping'
          )
    )
        THROW 51675, 'A conflicting user session connected during finalization verification.', 1;

    DROP TABLE dbo.IMPORT_STAGING_Phase2_Old;
    DROP TABLE dbo.KingdomScanData5_Phase2_Old;
    DROP TABLE dbo.KingdomScanData4_Phase2_Old;

    EXEC sys.sp_rename
        N'dbo.DF_KS4_Phase2_New_SCAN_UNO',
        N'DF_KS4_SCAN_UNO',
        N'OBJECT';

    IF OBJECT_ID(N'dbo.DF_KS4_SCAN_UNO', N'D') IS NULL
       OR NOT EXISTS
       (
           SELECT 1
           FROM sys.key_constraints
           WHERE parent_object_id = OBJECT_ID(N'dbo.KingdomScanData5', N'U')
             AND [type] = 'PK'
             AND name = @ExpectedKs5PrimaryKeyName
       )
       OR (SELECT COUNT(*) FROM sys.indexes
           WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
             AND index_id > 0) <> 10
        THROW 51670, 'Post-finalize constraint or index assertion failed.', 1;

    UPDATE dbo.KS4_Phase2_PreflightState
    SET FinalizedAtUtc = SYSUTCDATETIME(),
        Status = 'FINALIZED'
    WHERE RunId = @RunId;

    COMMIT TRANSACTION;

    SELECT
        N'phase2_finalize_digest_guard' AS EvidenceSection,
        LogicalName,
        DigestKind,
        [RowCount],
        CONVERT(varchar(64), Digest, 2) AS DigestSha256
    FROM @Digests
    ORDER BY LogicalName, DigestKind;

    SELECT
        N'phase2_finalize_completion' AS EvidenceSection,
        @ScriptRevision AS ScriptRevision,
        @RunId AS RunId,
        DB_NAME() AS DatabaseName,
        N'PASS' AS FinalizeStatus,
        N'Metadata-swap rollback is no longer available.' AS RecoveryState,
        SYSUTCDATETIME() AS CompletedAtUtc;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
