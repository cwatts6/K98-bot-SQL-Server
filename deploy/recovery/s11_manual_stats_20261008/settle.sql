/* Parameterized worker for the approved 2026-10-08 manual supersession.
   This does not establish the historical outcome and never runs UPDATE_ALL2.
   Caller binds @ExpectedServer nvarchar(128), @ExpectedDatabase sysname,
   @StatsHash binary(32), @ImportLockHash binary(32). No dynamic SQL. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 2000;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 51900,'Existing operator administrator and own transaction required.',1;
IF CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))<>@ExpectedServer OR DB_NAME()<>@ExpectedDatabase
    THROW 51900,'Recovery target differs.',1;
IF NOT ((@ExpectedServer=N'mini_AMD' AND @ExpectedDatabase=N'ROK_TRACKER'
         AND SUSER_SID()=0x01050000000000051500000082350CB1D5DFA006BAE7A2E4E9030000)
    OR (@ExpectedServer=N'9SX2VF4\K98DEV' AND @ExpectedDatabase LIKE N'S11_ManualStats_Test_20261008[_]%'))
    THROW 51900,'Target is outside the exact production/local-fixture scope.',1;

DECLARE @Recovery uniqueidentifier='50a5b6e5-d1d0-49dc-bf04-ab566047e152',
    @Preparation uniqueidentifier='c9831a9d-3031-4954-9da9-79815406ec0b',
    @Owner uniqueidentifier='d34ee646-7b5b-4b00-8644-22a3b718ce9e',
    @Waiter uniqueidentifier='aab3d39c-1ba6-4902-a8e7-732be9722b1b',
    @WaiterOwner uniqueidentifier='c03c155e-3937-48b5-bd76-9150048ca77b',
    @Session uniqueidentifier='6b3f98d0-b4a7-41cb-9f4f-3ca2f84655bf',
    @Account varchar(128)='sheets-service@statsupdate.iam.gserviceaccount.com',
    @Resource varchar(256)='sql_snapshot:legacy_outputs',
    @AccountResource varchar(256)='account:sheets-service@statsupdate.iam.gserviceaccount.com',
    @LockResult int,@LockKey nvarchar(255),@Audit nvarchar(max),@Before nvarchar(max),
    @Existing nvarchar(max),@Snapshot nvarchar(max),@Rows bigint,@Definition nvarchar(max),
    @KvK int,@MinRefresh datetime2(7),@MaxRefresh datetime2(7);
BEGIN TRY
    BEGIN TRANSACTION;
    SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(256),@AccountResource)),2));
    EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
    IF @LockResult<0 THROW 51901,'Account busy; no recovery action taken.',1;
    SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@Resource),2));
    EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
    IF @LockResult<0 THROW 51901,'Snapshot coordination busy; no recovery action taken.',1;

    SELECT @Existing=GenerationJson FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK)
    WHERE PreparationID=@Preparation AND AccountKey=@Account;
    IF JSON_VALUE(@Existing,'$.operator_reconciliation.recovery_id')=CONVERT(varchar(36),@Recovery)
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE PreparationID=@Preparation
            AND State='unavailable' AND Version=6 AND OwnerID=@Owner AND Fence=238)
            THROW 51902,'Existing recovery receipt has inconsistent subject state.',1;
        COMMIT;
        SELECT 'ALREADY_COMMITTED_NO_REPLAY' AS Status,@Recovery AS RecoveryID,@Existing AS Audit;
        RETURN;
    END;
    IF (SELECT COUNT(*) FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK)
        WHERE PreparationID=@Preparation AND AccountKey=@Account AND ConsumerKind='scan_data'
        AND State='uncertain' AND OwnerID=@Owner AND Fence=238 AND Version=5 AND EnqueueSequence=360
        AND RequestHash=0x278A54D6EE8C14B5A5022C406021F1093C5C1AB977F5C4BBE2A368F9331A9D7B
        AND GenerationJson IS NULL AND SpoolKey IS NULL AND SpoolBytes IS NULL AND SpoolHash IS NULL AND JobID IS NULL)<>1
        THROW 51902,'Held preparation differs; no settlement.',1;
    IF (SELECT COUNT(*) FROM dbo.ExportPreparationResource WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@Preparation)<>2
        OR EXISTS (SELECT 1 FROM dbo.ExportPreparationResource WHERE PreparationID=@Preparation AND ResourceKey NOT IN (@AccountResource,@Resource))
        THROW 51902,'Held resource membership differs.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK) WHERE ResourceKey=@AccountResource
        AND ActivePreparationID IS NULL AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL AND BlockedReason IS NULL)
        THROW 51902,'Account has active or blocked ownership.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Resource
        AND ResourceKind='sql_snapshot' AND ActivePreparationID=@Preparation AND OwnerID=@Owner AND Fence=238 AND Version=18
        AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL AND BlockedReason=N'Preparation requires authoritative reconciliation')
        THROW 51902,'Snapshot ownership differs.',1;
    IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK) WHERE AccountKey=@Account
        AND (State<>'closed' OR PreparationID IN (@Preparation,@Waiter)))
        THROW 51902,'Open or subject-linked provider evidence requires separate reconciliation.',1;
    IF (SELECT COUNT(*) FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
        WHERE HostIdentity='mini_AMD' COLLATE Latin1_General_100_CI_AS AND State='open')<>1
        OR NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@Session
            AND State='open' AND Version=1 AND AuthorityPrincipal=N'S11_ExportApplication'
            AND ManifestHash=0x287A049603B361510E0745E94300645D9516C347AAC00368B415D03D039AE73E)
        THROW 51902,'Verified successor SQL session differs.',1;
    IF NOT EXISTS (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK)
        WHERE PreparationID=@Waiter AND AccountKey=@Account AND ConsumerKind='scan_data' AND State='sql_pending'
        AND OwnerID=@WaiterOwner AND Fence=238 AND Version=3 AND EnqueueSequence=401
        AND CreatedUTC=CONVERT(datetime2(3),'2026-10-08T14:39:30.904')
        AND UpdatedUTC=CONVERT(datetime2(3),'2026-10-08T14:39:31.191')
        AND GenerationJson IS NULL AND SpoolKey IS NULL AND SpoolBytes IS NULL AND SpoolHash IS NULL AND JobID IS NULL)
        OR EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK) WHERE ActivePreparationID=@Waiter)
        THROW 51902,'Known unstarted waiter differs or owns resources.',1;
    -- A further old ticket must be reviewed, not silently withdrawn by age.
    IF EXISTS (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE AccountKey=@Account
        AND State IN ('pending','sql_pending') AND EnqueueSequence<=401 AND PreparationID<>@Waiter)
        THROW 51902,'Another old queue item requires review.',1;
    EXEC @LockResult=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
    IF @LockResult<0 THROW 51901,'A live SQL producer still owns the session guard.',1;

    -- Exact reviewed procedure bodies, normalized only for DDL verb and CRLF.
    SET @Definition=REPLACE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.SP_Stats_for_Upload')),NCHAR(13)+NCHAR(10),NCHAR(10));
    SET @Definition=SUBSTRING(@Definition,CHARINDEX(N'PROCEDURE',UPPER(@Definition)),LEN(@Definition));
    SET @Definition=TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM @Definition);
    IF @Definition IS NULL OR @StatsHash IS NULL OR HASHBYTES('SHA2_256',@Definition)<>@StatsHash
        THROW 51903,'Reviewed stats procedure differs; no refresh.',1;
    SET @Definition=REPLACE(OBJECT_DEFINITION(OBJECT_ID(N'dbo.ACQUIRE_KS4_IMPORT_LOCK')),NCHAR(13)+NCHAR(10),NCHAR(10));
    SET @Definition=SUBSTRING(@Definition,CHARINDEX(N'PROCEDURE',UPPER(@Definition)),LEN(@Definition));
    SET @Definition=TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM @Definition);
    IF @Definition IS NULL OR @ImportLockHash IS NULL OR HASHBYTES('SHA2_256',@Definition)<>@ImportLockHash
        THROW 51903,'Reviewed import-lock helper differs.',1;
    IF EXISTS (SELECT 1 FROM sys.triggers WHERE parent_id=OBJECT_ID(N'dbo.STATS_FOR_UPLOAD') AND is_disabled=0)
        THROW 51903,'Unreviewed stats-table trigger.',1;
    SET @Before=(SELECT PreparationID,State,OwnerID,Fence,Version,EnqueueSequence,RequestHash,Reason,CreatedUTC,UpdatedUTC
        FROM dbo.ExportPreparation WHERE PreparationID IN (@Preparation,@Waiter) ORDER BY EnqueueSequence FOR JSON PATH);
    EXEC dbo.SP_Stats_for_Upload;
    IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 51904,'Refresh did not retain the recovery transaction.',1;
    SELECT @Rows=COUNT_BIG(*),@KvK=MIN(KVK_NO),@MinRefresh=MIN(LAST_REFRESH),@MaxRefresh=MAX(LAST_REFRESH)
        FROM dbo.STATS_FOR_UPLOAD;
    IF @Rows NOT BETWEEN 1 AND 100000 OR @KvK IS NULL OR @KvK<=0 OR @MinRefresh IS NULL OR @MinRefresh<>@MaxRefresh
        OR EXISTS (SELECT 1 FROM dbo.STATS_FOR_UPLOAD WHERE KVK_NO IS NULL OR KVK_NO<>@KvK OR Gov_ID IS NULL OR Gov_ID<=0 OR LAST_REFRESH IS NULL)
        OR EXISTS (SELECT 1 FROM dbo.STATS_FOR_UPLOAD GROUP BY Gov_ID HAVING COUNT_BIG(*)>1)
        THROW 51904,'Refreshed stats baseline is invalid.',1;
    SET @Snapshot=(SELECT * FROM dbo.STATS_FOR_UPLOAD ORDER BY Gov_ID FOR JSON PATH,INCLUDE_NULL_VALUES);
    IF DATALENGTH(@Snapshot)>16777216 THROW 51904,'Baseline audit exceeds bound.',1;
    SET @Audit=(SELECT 1 AS version,JSON_QUERY((SELECT
        'manual_derived_stats_supersession' AS kind,CONVERT(varchar(36),@Recovery) AS recovery_id,
        'unknown' AS historical_sql_outcome,'operator_approved_2026-10-08' AS [authorization],
        ORIGINAL_LOGIN() AS actor,CONVERT(varchar(33),SYSUTCDATETIME(),127)+'Z' AS recorded_utc,
        CONVERT(varchar(36),@Session) AS session_id,JSON_QUERY(@Before) AS previous_preparations,
        @Rows AS baseline_rows,@KvK AS baseline_kvk,@MinRefresh AS source_scan_date,
        CONVERT(varchar(64),HASHBYTES('SHA2_256',@Snapshot),2) AS baseline_sha256,
        CONVERT(varchar(64),@StatsHash,2) AS stats_procedure_sha256,
        CAST(0 AS bit) AS historical_commit_proven,CAST(0 AS bit) AS provider_delivery_proven
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS operator_reconciliation FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    IF ISJSON(@Audit)<>1 OR DATALENGTH(@Audit)>65536 THROW 51904,'Invalid recovery audit.',1;
    UPDATE dbo.ExportPreparation SET State='unavailable',GenerationJson=@Audit,Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
        WHERE PreparationID=@Preparation AND State='uncertain' AND OwnerID=@Owner AND Fence=238 AND Version=5;
    IF @@ROWCOUNT<>1 THROW 51905,'Held preparation CAS failed.',1;
    UPDATE dbo.ExportPreparation SET State='unavailable',GenerationJson=@Audit,Fence=Fence+1,Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
        WHERE PreparationID=@Waiter AND State='sql_pending' AND OwnerID=@WaiterOwner AND Fence=238 AND Version=3;
    IF @@ROWCOUNT<>1 THROW 51905,'Waiter CAS failed.',1;
    UPDATE dbo.ExportResource SET ActivePreparationID=NULL,OwnerID=NULL,BlockedReason=NULL,Version=Version+1
        WHERE ResourceKey=@Resource AND ActivePreparationID=@Preparation AND OwnerID=@Owner AND Fence=238 AND Version=18
        AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL;
    IF @@ROWCOUNT<>1 THROW 51905,'Snapshot release CAS failed.',1;
    COMMIT;
    SELECT 'COMMITTED_MANUAL_SUPERSESSION' AS Status,@Recovery AS RecoveryID,@Audit AS Audit;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
