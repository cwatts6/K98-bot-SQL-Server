SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
GO
CREATE PROCEDURE dbo.usp_ExportExecutionStreamTransition
 @SessionID uniqueidentifier,
 @StreamID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @AccountKey varchar(128),
 @OwnerKind varchar(16)=NULL,
 @ObjectID uniqueidentifier=NULL,
 @OwnerID uniqueidentifier=NULL,
 @Fence bigint=NULL,
 @ClaimVersion bigint=NULL,
 @NestedToken uniqueidentifier=NULL,
 @RegistrationHash binary(32)=NULL,
 @Epoch bigint=NULL,
 @SnapshotHash binary(32)=NULL,
 @ScopeJson nvarchar(max)=NULL,
 @Purpose varchar(16)=NULL,
 @ChildIdentity uniqueidentifier=NULL,
 @ClosureHash binary(32)=NULL,
 @ClosureReference uniqueidentifier=NULL,
 @EventDigest binary(32)=NULL,
 @LastSequence bigint=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF (@Action='contain_read' AND @@TRANCOUNT<>1) OR (@Action<>'contain_read' AND @@TRANCOUNT<>0)
  THROW 51700,'Read containment requires the exact outer recovery transaction; other transitions require their own transaction.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
   THROW 51700,'Evidence authority role required.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(136),'account:'+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,'Export admission busy.',1;

 IF @Action='contain_read' AND DATALENGTH(@Action)=12
 BEGIN
  -- A distinct dispatch fence, never an OS-closure or provider-success assertion.
  -- The authority has sealed the SQL ledger and the outer transaction compares
  -- the complete preparation/resources before calling this protected transition.
  IF @ClosureHash IS NULL OR @ClosureReference IS NULL OR @EventDigest IS NULL
   OR @LastSequence IS NULL OR @ChildIdentity IS NULL OR @ObjectID IS NULL
   OR @OwnerID IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL
   THROW 51700,'Complete read containment binding required.',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
   WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State IN ('open','closed'))
   THROW 51700,'Exact original authority session required.',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK)
   WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence
    AND ConsumerKind='config' AND KVK_NO IS NULL AND JobID IS NULL AND GenerationJson IS NULL
    AND State IN ('preflight','uncertain')
    AND Version=@ClaimVersion+CASE WHEN State='uncertain' THEN 1 ELSE 0 END
    AND ISNULL(JSON_VALUE(RequestJson,'$.purpose'),'')<>'output_enrollment')
   THROW 51700,'Exact unfinished configuration preparation required.',1;
  IF (SELECT COUNT_BIG(*) FROM dbo.ExportProviderRequest WITH (UPDLOCK,HOLDLOCK) WHERE StreamID=@StreamID)<>@LastSequence
   OR EXISTS (SELECT 1 FROM dbo.ExportProviderRequest WITH (UPDLOCK,HOLDLOCK) WHERE StreamID=@StreamID
    AND (Sequence<1 OR Sequence>@LastSequence OR RequestKind<>'read'
     OR Operation NOT IN ('sheets.get','sheets.values.get','sheets.values.batchGet','drive.files.get','drive.permissions.list')))
   THROW 51700,'Only complete typed read membership can be contained.',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID
   AND (NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.EventSequence=1 AND e.State='prepared')
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State NOT IN ('prepared','dispatch_intent','succeeded','not_sent','unknown'))))
   THROW 51700,'Complete read event membership required.',1;
  UPDATE dbo.ExportExecutionStream SET State='read_contained',ActiveAccountKey=NULL,Version=Version+1,
   ClosureHash=@ClosureHash,ClosureReference=@ClosureReference,EventDigest=@EventDigest,ClosedUTC=SYSUTCDATETIME()
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion
    AND PreparationID=@ObjectID AND OwnerID=@OwnerID AND Fence=@Fence AND ClaimVersion=@ClaimVersion
    AND ChildIdentity=@ChildIdentity AND Purpose='probe' AND State IN ('open','frozen','closed')
    AND JobID IS NULL AND OutputOperationID IS NULL AND NestedToken IS NULL AND Epoch IS NULL AND LastSequence=@LastSequence;
  IF @@ROWCOUNT<>1 THROW 51700,'Read containment CAS lost.',1;
 END
 ELSE IF @Action='open' AND DATALENGTH(@Action)=4 AND @ExpectedVersion=0
 BEGIN

 -- Account lock precedes sorted resource locks; stream row is locked last.
 IF @AccountKey IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL OR @ClaimVersion<=0
 OR (@OwnerID IS NULL AND NOT (@OwnerKind='operation' AND @Purpose='probe' AND @Fence=0 AND @NestedToken IS NULL))
 OR (@OwnerID IS NOT NULL AND @Fence<=0)
 OR @OwnerKind NOT IN ('job','preparation','operation') OR @OwnerKind IS NULL
 OR DATALENGTH(@OwnerKind)<>LEN(@OwnerKind) OR @ObjectID IS NULL
 OR @Purpose NOT IN ('mutation','probe','enrollment') OR @Purpose IS NULL OR DATALENGTH(@Purpose)<>LEN(@Purpose)
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>CASE WHEN @Purpose='enrollment' THEN 524288 ELSE 65536 END
 THROW 51700,'Complete typed stream scope required.',1;
 DECLARE @Resources TABLE (ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF JSON_QUERY(@ScopeJson,'$.resources') IS NULL THROW 51700,'Complete resource membership required.',1;
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ScopeJson,'$.resources')
 WITH (ResourceKey varchar(256) '$.key',Version bigint '$.version');
 IF NOT EXISTS (SELECT 1 FROM @Resources WHERE ResourceKey='account:'+@AccountKey)
 OR (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 1 AND 1025 OR EXISTS (SELECT 1 FROM @Resources WHERE Version<=0)
 THROW 51700,'Invalid resource membership.',1;
 IF EXISTS (SELECT 1 FROM @Resources r JOIN dbo.ExportContainedTarget t WITH (HOLDLOCK)
  ON r.ResourceKey=('destination:'+t.FileID) COLLATE Latin1_General_100_BIN2
  WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportLegacyCloseout released WITH (HOLDLOCK)
   WHERE released.ContainmentID=t.ContainmentID AND released.AccountKey=@AccountKey))
  THROW 51700,'A permanently isolated target cannot enter another provider stream.',1;
 -- A legacy closeout releases ordinary exports and configuration reads only.
 -- Managed pools, enrollment and replacement proofs retain permanent isolation.
 IF EXISTS (SELECT 1 FROM @Resources r JOIN dbo.ExportContainedTarget t WITH (HOLDLOCK)
  ON r.ResourceKey=('destination:'+t.FileID) COLLATE Latin1_General_100_BIN2)
  AND NOT (@NestedToken IS NULL AND @Epoch IS NULL AND
   ((@OwnerKind='job' AND @Purpose='mutation' AND EXISTS
     (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
      AND ConsumerKind IN ('scan_data','all_kvk') AND PoolEpoch IS NULL AND SourceKey IS NULL AND IntentID IS NULL))
    OR (@OwnerKind='preparation' AND @Purpose='probe' AND EXISTS
     (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID
      AND ConsumerKind='config' AND KVK_NO IS NULL AND JobID IS NULL AND GenerationJson IS NULL
      AND ISNULL(JSON_VALUE(RequestJson,'$.purpose'),'')<>'output_enrollment'))))
  THROW 51700,'Historical target isolation permits only legacy export or configuration read.',1;
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
   AND ((@Purpose='mutation' AND State='running') OR (@Purpose='probe' AND State IN ('running','uncertain','confirmed','failed')))
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
    OR (DATALENGTH(@ScopeJson)>65536 AND ISNULL(JSON_VALUE(@EnrollmentPlan,'$.version'),'') NOT IN ('4','5'))
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
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State='open')
 THROW 51700,'Exact open authority session required.',1;

  IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK) WHERE StreamID=@StreamID OR ActiveAccountKey=@AccountKey)
   THROW 51700,'Stream/account already registered; no automatic adoption.',1;
  INSERT dbo.ExportExecutionStream VALUES (@StreamID,@SessionID,@AccountKey,@AccountKey,
   CASE WHEN @OwnerKind='job' THEN @ObjectID END,CASE WHEN @OwnerKind='preparation' THEN @ObjectID END,
   CASE WHEN @OwnerKind='operation' THEN @ObjectID END,@OwnerID,@Fence,@ClaimVersion,@NestedToken,@RegistrationHash,
   @Epoch,@SnapshotHash,@ScopeJson,@Purpose,'open',1,0,@ChildIdentity,NULL,NULL,NULL,SYSUTCDATETIME(),NULL);
 END
 ELSE
 BEGIN
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State='open')
 THROW 51700,'Exact open authority session required.',1;

  IF @Action='freeze' AND DATALENGTH(@Action)=6
  BEGIN
   UPDATE dbo.ExportExecutionStream SET State='frozen',Version=Version+1
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion AND State='open';
   IF @@ROWCOUNT<>1 THROW 51700,'Stream freeze CAS lost.',1;
  END
  ELSE IF @Action='close' AND DATALENGTH(@Action)=5 AND @ClosureHash IS NOT NULL AND @ChildIdentity IS NOT NULL
    AND @ClosureReference IS NOT NULL AND @EventDigest IS NOT NULL AND @LastSequence IS NOT NULL
  BEGIN
   -- Preserve complete abandoned read prefixes; closure is not a successful observation.
   -- The trusted parent must still prove exact child termination and seal every event.
   IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID
    AND NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e
     WHERE e.RequestID=r.RequestID AND e.State IN ('succeeded','not_sent','unknown'))
    AND NOT (r.RequestKind='read'
     AND EXISTS (SELECT 1 FROM dbo.ExportExecutionStream s
      WHERE s.StreamID=r.StreamID AND s.Purpose='probe')
     AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e
      WHERE e.RequestID=r.RequestID AND e.State='prepared')
     AND NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e
      WHERE e.RequestID=r.RequestID AND e.State NOT IN ('prepared','dispatch_intent'))))
    THROW 51700,'Nonterminal request evidence prevents stream closure.',1;
   -- Trusted parent supplies OS-handle closure evidence, not a caller Boolean.
   UPDATE dbo.ExportExecutionStream SET State='closed',ActiveAccountKey=NULL,Version=Version+1,ClosureHash=@ClosureHash,ClosureReference=@ClosureReference,EventDigest=@EventDigest,ClosedUTC=SYSUTCDATETIME()
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion
    AND ChildIdentity=@ChildIdentity AND State='frozen' AND LastSequence=@LastSequence;
   IF @@ROWCOUNT<>1 THROW 51700,'Stream close CAS lost.',1;
  END
  ELSE THROW 51700,'Unsupported stream action.',1;
 END;
 SELECT * FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
