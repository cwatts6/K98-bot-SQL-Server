SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
GO
CREATE PROCEDURE dbo.usp_ExportProviderRequestEventAppend
 @SessionID uniqueidentifier,
 @StreamID uniqueidentifier,
 @AccountKey varchar(128),
 @ExpectedVersion bigint,
 @RequestID uniqueidentifier,
 @EventID uniqueidentifier,
 @State varchar(32),
 @EvidenceHash binary(32),
 @EvidenceReference uniqueidentifier,
 @Operation varchar(64)=NULL,
 @RequestKind varchar(16)=NULL,
 @TargetID varchar(128)=NULL,
 @PayloadHash binary(32)=NULL,
 @PayloadReference uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,'Evidence transition requires its own short transaction.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
   THROW 51700,'Evidence authority role required.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(136),'account:'+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,'Export admission busy.',1;

 DECLARE @OwnerKind varchar(16),@ObjectID uniqueidentifier,@OwnerID uniqueidentifier,@Fence bigint,@ClaimVersion bigint,
 @NestedToken uniqueidentifier,@Epoch bigint,@ScopeJson nvarchar(max),@Purpose varchar(16),@RegistrationHash binary(32),@SnapshotHash binary(32);
 SELECT @OwnerKind=CASE WHEN JobID IS NOT NULL THEN 'job' WHEN PreparationID IS NOT NULL THEN 'preparation' ELSE 'operation' END,
 @ObjectID=COALESCE(JobID,PreparationID,OutputOperationID),@OwnerID=OwnerID,@Fence=Fence,@ClaimVersion=ClaimVersion,
 @NestedToken=NestedToken,@Epoch=Epoch,@ScopeJson=ScopeJson,@Purpose=Purpose,@RegistrationHash=RegistrationHash,@SnapshotHash=SnapshotHash
 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND AccountKey=@AccountKey AND SessionID=@SessionID;

 IF @State IN ('prepared','dispatch_intent')
 BEGIN

 -- Account lock precedes sorted resource locks; stream row is locked last.
 IF @AccountKey IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL OR @ClaimVersion<=0
 OR (@OwnerID IS NULL AND NOT (@OwnerKind='operation' AND @Purpose='probe' AND @Fence=0 AND @NestedToken IS NULL))
 OR (@OwnerID IS NOT NULL AND @Fence<=0)
 OR @OwnerKind NOT IN ('job','preparation','operation') OR @OwnerKind IS NULL
 OR DATALENGTH(@OwnerKind)<>LEN(@OwnerKind) OR @ObjectID IS NULL
 OR @Purpose NOT IN ('mutation','probe','enrollment') OR @Purpose IS NULL OR DATALENGTH(@Purpose)<>LEN(@Purpose)
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>65536
 THROW 51700,'Complete typed stream scope required.',1;
 DECLARE @Resources TABLE (ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF JSON_QUERY(@ScopeJson,'$.resources') IS NULL THROW 51700,'Complete resource membership required.',1;
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ScopeJson,'$.resources')
 WITH (ResourceKey varchar(256) '$.key',Version bigint '$.version');
 IF NOT EXISTS (SELECT 1 FROM @Resources WHERE ResourceKey='account:'+@AccountKey)
 OR (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 1 AND 1025 OR EXISTS (SELECT 1 FROM @Resources WHERE Version<=0)
 THROW 51700,'Invalid resource membership.',1;
 IF @Purpose='probe' AND EXISTS (SELECT 1 FROM dbo.ExportResource r JOIN dbo.ExportPreparation p ON p.PreparationID=r.ActivePreparationID
    WHERE p.AccountKey=@AccountKey AND r.ResourceKind='sql_snapshot' AND r.OwnerID IS NOT NULL)
  THROW 51700,'Owned SQL producer must drain before observational probe.',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint,@ResourceLock nvarchar(255),@ResourceResult int;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @ResourceLock=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@ResourceKey),2));
  EXEC @ResourceResult=sys.sp_getapplock @Resource=@ResourceLock,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @ResourceResult<0 THROW 51700,'Resource admission busy.',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK)
    WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion
    AND (@Purpose='probe' OR BlockedReason IS NULL)
    AND ((@Purpose='probe' AND OwnerID IS NULL AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
     OR (OwnerID=@OwnerID AND Fence=@Fence AND ((@OwnerKind='job' AND ActiveJobID=@ObjectID AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind='preparation' AND ActivePreparationID=@ObjectID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind='operation' AND ActiveOutputOperationID=@ObjectID AND ActiveJobID IS NULL AND ActivePreparationID IS NULL)))))
   THROW 51700,'Resource owner/fence/version conflict.',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;
 IF @Purpose='enrollment' AND @OwnerKind<>'preparation' THROW 51700,'Enrollment requires its preparation owner.',1;
 IF @OwnerKind='job'
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
   AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion
   AND ((@Purpose='mutation' AND State='running') OR (@Purpose='probe' AND State IN ('running','uncertain','confirmed')))
   AND ((PoolEpoch IS NULL AND @Epoch IS NULL) OR PoolEpoch=@Epoch)
   AND ((@NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,'$.retirement_recovery.state') IS NULL)
      OR (@NestedToken IS NOT NULL AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(ProvenanceJson,'$.retirement_recovery.token'))=@NestedToken
       AND JSON_VALUE(ProvenanceJson,'$.retirement_recovery.state')='owned'
       AND (TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,'$.retirement_recovery.version'))=@ClaimVersion
        OR (@Purpose='probe' AND State='uncertain' AND @ClaimVersion>1
         AND TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,'$.retirement_recovery.version'))=@ClaimVersion-1)))
      OR (@Purpose='probe' AND @NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,'$.retirement_recovery.state')='complete')))
   THROW 51700,'Job/nested owner CAS conflict.',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID)
   THROW 51700,'Job membership conflict.',1;
 END
 ELSE IF @OwnerKind='preparation'
 BEGIN
  IF @NestedToken IS NOT NULL OR @Epoch IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion AND (@Purpose='probe' OR State='preflight'))
   THROW 51700,'Preparation CAS conflict.',1;

  DECLARE @EnrollmentPlan nvarchar(max),@EnrollmentProgress nvarchar(max),@EnrollmentHash binary(32);
  SELECT @EnrollmentPlan=RequestJson,@EnrollmentProgress=GenerationJson,@EnrollmentHash=RequestHash
   FROM dbo.ExportPreparation WHERE PreparationID=@ObjectID;
  IF @Purpose='enrollment'
  BEGIN
   IF JSON_VALUE(@EnrollmentPlan,'$.purpose') IS NULL OR JSON_VALUE(@EnrollmentPlan,'$.purpose')<>'output_enrollment'
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,'$.session_id')) IS NULL
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,'$.session_id'))<>@SessionID
    OR @RegistrationHash<>@EnrollmentHash OR @SnapshotHash<>@EnrollmentHash
    OR @EnrollmentHash<>HASHBYTES('SHA2_256',CONVERT(varbinary(max),@EnrollmentPlan))
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson))<>2
    OR JSON_QUERY(@ScopeJson,'$.enrollment') IS NULL
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson,'$.enrollment'))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson,'$.enrollment'))<>2
    OR JSON_VALUE(@ScopeJson,'$.enrollment.phase') IS NULL
    OR JSON_VALUE(@EnrollmentProgress,'$.phase') IS NULL
    OR JSON_VALUE(@ScopeJson,'$.enrollment.phase')<>JSON_VALUE(@EnrollmentProgress,'$.phase')
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,'$.enrollment.ordinal')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,'$.next_ordinal')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,'$.enrollment.ordinal'))<>TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,'$.next_ordinal'))
    OR JSON_VALUE(@EnrollmentProgress,'$.phase') NOT IN ('create','verify')
    THROW 51700,'Exact authority-side enrollment phase required.',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    THROW 51700,'Enrollment phase already has a stream; never replay.',1;
  END
  ELSE IF JSON_VALUE(@EnrollmentPlan,'$.purpose')='output_enrollment'
   THROW 51700,'Enrollment cannot become ordinary configuration authority.',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID)
   THROW 51700,'Preparation membership conflict.',1;
 END
 ELSE
 BEGIN
  -- Pool lock follows resource locks, matching the Bot's operation DAL.
  DECLARE @PoolID uniqueidentifier,@PoolLock nvarchar(255),@PoolLockResult int;
  SELECT @PoolID=PoolID FROM KVK.SourceOutputOperation WHERE OperationID=@ObjectID AND AccountKey=@AccountKey;
  IF @PoolID IS NULL THROW 51700,'Output operation pool is unavailable.',1;
  SET @PoolLock=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(41),'pool:'+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @PoolLockResult=sys.sp_getapplock @Resource=@PoolLock,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @PoolLockResult<0 THROW 51700,'Output operation pool busy.',1;
  IF NOT EXISTS (SELECT 1 FROM KVK.SourceOutputPool WITH (UPDLOCK,HOLDLOCK)
   WHERE PoolID=@PoolID AND AccountKey=@AccountKey AND PoolState='closing'
    AND OwnerID=@ObjectID AND Epoch=@Epoch AND RegistrationHash=@RegistrationHash)
   THROW 51700,'Output operation registration/epoch changed.',1;
  IF @NestedToken IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM KVK.SourceOutputOperation WITH (UPDLOCK,HOLDLOCK) WHERE OperationID=@ObjectID AND AccountKey=@AccountKey
    AND PoolID=@PoolID AND Fence=@Fence AND Version=@ClaimVersion AND OldEpoch=@Epoch
    AND ((OwnerID=@OwnerID AND (@Purpose='probe' OR State='running'))
      OR (@Purpose='probe' AND @OwnerID IS NULL AND OwnerID IS NULL AND Fence=0 AND State='closing' AND Phase='draining')))
   THROW 51700,'Output operation CAS conflict.',1;
  IF EXISTS (SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID)
   THROW 51700,'Output operation membership conflict.',1;
 END;

 END;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State='open')
 THROW 51700,'Exact open authority session required.',1;

 DECLARE @StreamState varchar(16),@LastSequence bigint,@Version bigint;
 SELECT @StreamState=State,@LastSequence=LastSequence,@Version=Version
 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK)
 WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey;
 IF @ExpectedVersion IS NULL OR @Version IS NULL OR @Version<>@ExpectedVersion OR @StreamState='closed'
  THROW 51700,'Request stream CAS lost or closed.',1;
 IF @State IS NULL OR DATALENGTH(@State)<>LEN(@State) THROW 51700,'Canonical event state required.',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE EventID=@EventID)
  THROW 51700,'Event already exists; read immutable event before retry.',1;
 DECLARE @Previous varchar(32),@EventSequence int;
 IF @State='prepared'
 BEGIN
  IF @StreamState<>'open' OR (@Purpose='probe' AND @RequestKind<>'read')
   THROW 51700,'Stream cannot prepare this request.',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID AND NOT EXISTS
    (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN ('succeeded','not_sent','unknown')))
   THROW 51700,'Only one outstanding request per stream.',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
   WHERE r.StreamID=@StreamID AND r.RequestKind='mutation' AND e.State='unknown')
   THROW 51700,'Unknown mutation requires reconciliation.',1;
  IF @Operation='sheets.create'
  BEGIN
   IF @Purpose<>'enrollment' OR @RequestKind<>'mutation' OR @OwnerKind<>'preparation'
    OR JSON_VALUE(@ScopeJson,'$.enrollment.phase')<>'create'
    OR @TargetID<>LOWER(CONVERT(varchar(36),@ObjectID)) OR DATALENGTH(@TargetID)<>36
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID)
    THROW 51700,'Only one fixed create per fresh enrollment phase.',1;
  END
  ELSE
  BEGIN
   IF NOT EXISTS (SELECT 1 FROM OPENJSON(@ScopeJson,'$.resources') WITH (ResourceKey varchar(256) '$.key') WHERE ResourceKey='destination:'+@TargetID)
    THROW 51700,'Request target is outside owned resources.',1;
   IF @Purpose='enrollment' AND (JSON_VALUE(@ScopeJson,'$.enrollment.phase')<>'verify'
    OR @Operation NOT IN ('drive.permissions.create','drive.files.get','drive.permissions.list','sheets.get','sheets.values.batchGet'))
    THROW 51700,'Enrollment permits only Editor grant and fixed readback.',1;
   IF @Purpose='enrollment' AND @Operation='drive.permissions.create'
    AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID AND TargetID=@TargetID AND Operation=@Operation)
    THROW 51700,'Editor grant cannot be replayed.',1;
  END;
  INSERT dbo.ExportProviderRequest VALUES (@RequestID,@StreamID,@LastSequence+1,@Operation,@RequestKind,@TargetID,@PayloadHash,@PayloadReference,SYSUTCDATETIME());
  SET @EventSequence=1;
  UPDATE dbo.ExportExecutionStream SET LastSequence=LastSequence+1 WHERE StreamID=@StreamID;
 END
 ELSE
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequest WHERE RequestID=@RequestID AND StreamID=@StreamID)
   THROW 51700,'Request identity differs.',1;
  IF @State='dispatch_intent' AND @OwnerKind='job'
   AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE RequestID=@RequestID AND RequestKind='mutation')
   AND NOT EXISTS(SELECT 1 FROM dbo.ExportAttempt WHERE JobID=@ObjectID AND OwnerID=@OwnerID AND Fence=@Fence AND Phase IN ('private_started','verified','publication_pending'))
   THROW 51700,'A durable owned attempt must precede mutation dispatch.',1;
  SELECT TOP(1) @Previous=State,@EventSequence=EventSequence+1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=@RequestID ORDER BY EventSequence DESC;
  IF NOT ((@Previous='prepared' AND @State='not_sent') OR (@Previous='prepared' AND @State='dispatch_intent' AND @StreamState='open')
    OR (@Previous='dispatch_intent' AND @State IN ('succeeded','unknown')))
   OR @Previous IS NULL THROW 51700,'Invalid or terminal request transition; never replay.',1;
 END;
 INSERT dbo.ExportProviderRequestEvent VALUES (@EventID,@RequestID,@EventSequence,@State,@EvidenceHash,@EvidenceReference,SYSUTCDATETIME());
 UPDATE dbo.ExportExecutionStream SET Version=Version+1 WHERE StreamID=@StreamID;
 SELECT * FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
