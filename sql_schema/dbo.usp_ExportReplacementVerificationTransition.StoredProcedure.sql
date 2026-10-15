SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE dbo.usp_ExportReplacementVerificationTransition
 @VerificationID uniqueidentifier,@ReplacementID uniqueidentifier,@SessionID uniqueidentifier,
 @AccountKey varchar(128),@Action varchar(16),@PlanJson nvarchar(max)=NULL,
 @Actor nvarchar(128)=NULL,@Reason nvarchar(512)=NULL,
 @ReceiptHash binary(32)=NULL,@ReceiptReference uniqueidentifier=NULL,
 @ExpectedVersion bigint=0,@StreamID uniqueidentifier=NULL,@StreamVersion bigint=NULL,
 @LastSequence bigint=NULL,@EventDigest binary(32)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51728,'Exact outer replacement verification transaction required.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
  THROW 51728,'Evidence authority role required.',1;
 IF @Action IS NULL OR @Action NOT IN ('begin','verify','discard') OR DATALENGTH(@Action)<>LEN(@Action)
  OR @VerificationID IS NULL OR @ReplacementID IS NULL OR @SessionID IS NULL
  OR @AccountKey IS NULL OR LEN(@AccountKey)=0 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey)
  OR @AccountKey COLLATE Latin1_General_100_BIN2 LIKE '%[^-A-Za-z0-9_.@:]%'
  THROW 51728,'Canonical replacement verification identity required.',1;
 DECLARE @LockResult int,@LockKey nvarchar(255),@AccountResource varchar(256)='account:'+@AccountKey;
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@AccountResource),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51728,'Replacement verification admission busy.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WITH(UPDLOCK,HOLDLOCK)
  WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State='open')
  THROW 51728,'Current authority session required.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementPlan p WITH(UPDLOCK,HOLDLOCK)
  JOIN dbo.ExportTargetContainment c ON c.ContainmentID=p.ContainmentID
  JOIN dbo.ExportJob j ON j.JobID=c.JobID WHERE p.ReplacementID=@ReplacementID AND p.AccountKey=@AccountKey
   AND c.AccountKey=@AccountKey AND j.AccountKey=@AccountKey AND j.State='uncertain')
  THROW 51728,'Exact isolated job and replacement proposal required.',1;
 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 INSERT @Resources VALUES(@AccountResource);
 INSERT @Resources SELECT 'destination:'+NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID;
 DECLARE @Key varchar(256);
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks; FETCH NEXT FROM ResourceLocks INTO @Key;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@Key),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @LockResult<0 THROW 51728,'Replacement destination busy.',1;
  FETCH NEXT FROM ResourceLocks INTO @Key;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;
 DECLARE @PreparationID uniqueidentifier=@VerificationID,@OwnerID uniqueidentifier=@VerificationID,@Fence bigint,
  @ClaimVersion bigint,@OriginalSession uniqueidentifier,@StoredPlan nvarchar(max),@StoredHash binary(32);
 IF @Action='begin'
 BEGIN
  IF @ExpectedVersion<>0 OR @PlanJson IS NULL OR ISJSON(@PlanJson)<>1 OR DATALENGTH(@PlanJson)>2097152
   OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
   OR EXISTS(SELECT 1 FROM dbo.ExportReplacementVerification WHERE VerificationID=@VerificationID OR (ReplacementID=@ReplacementID AND State='checking'))
   THROW 51728,'New bounded verification action required; inspect any retained attempt.',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@PlanJson))<>13 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@PlanJson))<>13
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN
    ('version','purpose','account','storage_owner','owner_email','editor_email','project_id','credential_profile_sha256','manifest_sha256','file_count','plan_id','replacement_id','files'))
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN ('version','file_count','files') AND (type<>1 OR LEN(value)=0))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]='version' AND type=2 AND value IN (N'4',N'5') AND DATALENGTH(value)=2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]='file_count' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 1 AND 1024 AND value=CONVERT(varchar(4),TRY_CONVERT(int,value)))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]='files' AND type=4)
   OR JSON_VALUE(@PlanJson,'$.plan_id') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),@VerificationID)) COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,'$.plan_id'))<>72
   OR JSON_VALUE(@PlanJson,'$.replacement_id') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),@ReplacementID)) COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,'$.replacement_id'))<>72
   OR DATALENGTH(JSON_VALUE(@PlanJson,'$.purpose'))<>34
   OR DATALENGTH(JSON_VALUE(@PlanJson,'$.storage_owner')) NOT BETWEEN 2 AND 256
   OR JSON_VALUE(@PlanJson,'$.storage_owner') COLLATE Latin1_General_100_BIN2 LIKE '%[^-A-Za-z0-9_.@:]%'
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] IN ('manifest_sha256','credential_profile_sha256')
    AND (DATALENGTH(value)<>128 OR value COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9a-f]%'))
   THROW 51728,'Exact replacement read plan required.',1;
  IF JSON_VALUE(@PlanJson,'$.version') NOT IN ('4','5') OR JSON_VALUE(@PlanJson,'$.purpose')<>'output_enrollment'
   OR JSON_VALUE(@PlanJson,'$.account') COLLATE Latin1_General_100_BIN2<>@AccountKey COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,'$.account'))<>2*DATALENGTH(@AccountKey)
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,'$.plan_id'))<>@VerificationID
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,'$.replacement_id'))<>@ReplacementID
   OR TRY_CONVERT(int,JSON_VALUE(@PlanJson,'$.file_count')) NOT BETWEEN 1 AND 1024
   OR JSON_QUERY(@PlanJson,'$.files') IS NULL OR LEFT(LTRIM(JSON_QUERY(@PlanJson,'$.files')),1)<>'['
   OR (SELECT COUNT(*) FROM OPENJSON(@PlanJson,'$.files'))<>(SELECT COUNT(*) FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID)
   OR (SELECT COUNT(*) FROM OPENJSON(@PlanJson,'$.files'))<>TRY_CONVERT(int,JSON_VALUE(@PlanJson,'$.file_count'))
   OR EXISTS(SELECT NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID
    EXCEPT SELECT JSON_VALUE(value,'$.file_id') FROM OPENJSON(@PlanJson,'$.files'))
   OR EXISTS(SELECT JSON_VALUE(value,'$.file_id') FROM OPENJSON(@PlanJson,'$.files')
    EXCEPT SELECT NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID)
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID
    AND LOWER(CONVERT(varchar(64),ManifestHash,2)) COLLATE Latin1_General_100_BIN2=JSON_VALUE(@PlanJson,'$.manifest_sha256') COLLATE Latin1_General_100_BIN2)
   THROW 51728,'Replacement read plan does not bind the complete proposal and session.',1;
  IF JSON_VALUE(@PlanJson,'$.version')='5' AND EXISTS(
   SELECT 1 FROM OPENJSON(@PlanJson,'$.files') f WHERE f.type<>5
    OR (SELECT COUNT(*) FROM OPENJSON(f.value))<>4
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(f.value))<>4
    OR EXISTS(SELECT 1 FROM OPENJSON(f.value) WHERE [key] NOT IN ('file_id','audience','editors','kind'))
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(f.value) WHERE [key]='kind' AND type=1
     AND ((value COLLATE Latin1_General_100_BIN2=N'output' AND DATALENGTH(value)=12)
      OR (value COLLATE Latin1_General_100_BIN2=N'configuration_output' AND DATALENGTH(value)=40))))
   THROW 51728,'Exact configuration or output verification role required.',1;
  IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
   OR EXISTS(SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN ('pending','preflight','sql_pending','writing','committed','uncertain'))
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey AND State IN ('closing','ready','running','uncertain'))
   OR EXISTS(SELECT 1 FROM dbo.ExportJob j WHERE j.AccountKey=@AccountKey AND j.State IN ('ready','running','uncertain')
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportJobResource m JOIN dbo.ExportContainedTarget t ON m.ResourceKey='destination:'+t.FileID WHERE m.JobID=j.JobID))
   THROW 51728,'Healthy work retains admission priority.',1;
  IF EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t WHERE t.ReplacementID=@ReplacementID AND
   (EXISTS(SELECT 1 FROM dbo.ExportContainedTarget WHERE FileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin WHERE FileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE ResourceKey='destination:'+t.NewFileID)
    OR EXISTS(SELECT 1 FROM dbo.ExportPreparationResource m WHERE m.ResourceKey='destination:'+t.NewFileID AND NOT EXISTS
     (SELECT 1 FROM dbo.ExportReplacementVerification v
      JOIN dbo.ExportReplacementPlan prior ON prior.ReplacementID=v.ReplacementID
      JOIN dbo.ExportReplacementPlan current_plan ON current_plan.ReplacementID=@ReplacementID
      WHERE v.PreparationID=m.PreparationID AND prior.ContainmentID=current_plan.ContainmentID
       AND prior.AccountKey=current_plan.AccountKey AND v.State IN ('verified','discarded')
       AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation a WHERE a.ReplacementID=prior.ReplacementID)))))
   THROW 51728,'Replacement file has unrelated or permanent history.',1;
  IF EXISTS(SELECT 1 FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey
   WHERE r.OwnerID IS NOT NULL OR r.ActiveJobID IS NOT NULL OR r.ActivePreparationID IS NOT NULL OR r.ActiveOutputOperationID IS NOT NULL OR r.BlockedReason IS NOT NULL)
   THROW 51728,'Replacement resources are still owned or blocked.',1;
  INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version)
   SELECT x.ResourceKey,CASE WHEN x.ResourceKey=@AccountResource THEN 'account' ELSE 'destination' END,0,1 FROM @Resources x
   WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=x.ResourceKey);
  SELECT @Fence=Fence+1 FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
  DECLARE @Ticket bigint=(SELECT ISNULL(MAX(Ticket),0)+1 FROM
   (SELECT EnqueueSequence Ticket FROM dbo.ExportJob WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey) q);
  INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,KVK_NO,RequestHash,EnqueueSequence,State,OwnerID,Fence,Version,StorageOwner,RequestJson,GenerationJson,Actor,Reason,CreatedUTC,UpdatedUTC)
   VALUES(@PreparationID,@AccountKey,'config',NULL,HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PlanJson)),@Ticket,'preflight',@OwnerID,@Fence,1,
    JSON_VALUE(@PlanJson,'$.storage_owner'),@PlanJson,
    N'{"session_id":"'+LOWER(CONVERT(nvarchar(36),@SessionID))+N'","phase":"verify","next_ordinal":'+JSON_VALUE(@PlanJson,'$.file_count')+N'}',
    @Actor,@Reason,SYSUTCDATETIME(),SYSUTCDATETIME());
  INSERT dbo.ExportPreparationResource SELECT @PreparationID,ResourceKey FROM @Resources;
  UPDATE r SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=Version+1
   FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey;
  INSERT dbo.ExportReplacementVerification VALUES(@VerificationID,@ReplacementID,@PreparationID,@SessionID,HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PlanJson)),'checking',1,NULL,NULL,@Actor,@Reason,SYSUTCDATETIME(),SYSUTCDATETIME());
 END
 ELSE
 BEGIN
  IF @ExpectedVersion<>1 OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL OR @PlanJson IS NOT NULL
   THROW 51728,'Exact retained verification and private settlement receipt required.',1;
  SELECT @OriginalSession=v.SessionID,@Fence=p.Fence,@ClaimVersion=p.Version,@StoredPlan=p.RequestJson,@StoredHash=p.RequestHash
   FROM dbo.ExportReplacementVerification v WITH(UPDLOCK,HOLDLOCK) JOIN dbo.ExportPreparation p WITH(UPDLOCK,HOLDLOCK) ON p.PreparationID=v.PreparationID
   WHERE v.VerificationID=@VerificationID AND v.ReplacementID=@ReplacementID AND v.State='checking' AND v.Version=@ExpectedVersion
    AND p.PreparationID=@PreparationID AND p.AccountKey=@AccountKey AND p.OwnerID=@OwnerID AND p.State='preflight' AND p.Version=1
    AND p.JobID IS NULL AND p.SpoolKey IS NULL AND p.ConsumerKind='config' AND p.KVK_NO IS NULL AND p.RequestHash=v.PlanHash;
  IF @StoredPlan IS NULL OR @StoredHash<>HASHBYTES('SHA2_256',CONVERT(varbinary(max),@StoredPlan))
   OR JSON_VALUE(@StoredPlan,'$.version') NOT IN ('4','5') OR JSON_VALUE(@StoredPlan,'$.purpose')<>'output_enrollment'
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@OriginalSession AND AuthorityPrincipal=USER_NAME())
   OR EXISTS(SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID)
   OR EXISTS(SELECT 1 FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey WHERE
    r.ActivePreparationID IS NULL OR r.ActivePreparationID<>@PreparationID OR r.OwnerID IS NULL OR r.OwnerID<>@OwnerID OR r.Fence<>@Fence
    OR r.ActiveJobID IS NOT NULL OR r.ActiveOutputOperationID IS NOT NULL OR r.BlockedReason IS NOT NULL)
   THROW 51728,'Verification ownership or typed plan changed.',1;
  DECLARE @Count int=(SELECT COUNT(*) FROM dbo.ExportExecutionStream WHERE PreparationID=@PreparationID);
  IF (@Count=0 AND (@Action<>'discard' OR @StreamID IS NOT NULL)) OR @Count>1
   THROW 51728,'Complete exact verification stream membership required.',1;
  IF @Count=1
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE
    StreamID=@StreamID AND PreparationID=@PreparationID AND SessionID=@OriginalSession AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND ClaimVersion=@ClaimVersion AND Version=@StreamVersion
    AND Purpose='enrollment' AND RegistrationHash=@StoredHash AND SnapshotHash=@StoredHash
    AND NestedToken IS NULL AND JobID IS NULL AND OutputOperationID IS NULL AND Epoch IS NULL
    AND LastSequence=@LastSequence AND State IN ('open','frozen','closed'))
    OR @EventDigest IS NULL OR @LastSequence IS NULL
    OR (SELECT COUNT_BIG(*) FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID)<>@LastSequence
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID AND
     (RequestKind<>'read' OR Operation NOT IN ('drive.files.get','drive.permissions.list','sheets.get','sheets.values.batchGet')
      OR Sequence<1 OR Sequence>@LastSequence OR NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID AND NewFileID=TargetID)))
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID AND
     (NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.EventSequence=1 AND e.State='prepared')
      OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State NOT IN ('prepared','dispatch_intent','succeeded','not_sent','unknown'))))
    THROW 51728,'Complete typed read-only verification ledger required.',1;
   IF @Action='verify'
   BEGIN
    IF @LastSequence<>(SELECT SUM(CASE WHEN JSON_VALUE(@StoredPlan,'$.version')='5'
      AND JSON_VALUE(value,'$.kind')='configuration_output' THEN 19 ELSE 5 END)
      FROM OPENJSON(@StoredPlan,'$.files'))
     OR NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND State='closed' AND ActiveAccountKey IS NULL AND ClosureHash IS NOT NULL AND EventDigest=@EventDigest)
     OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID AND NOT EXISTS
      (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State='succeeded'))
     THROW 51728,'Successful privately verified readback and closed child required.',1;
   END
   ELSE
    -- Explicit discard is a dispatch fence, not an assertion that the child died.
    UPDATE dbo.ExportExecutionStream SET State='read_contained',ActiveAccountKey=NULL,Version=Version+1,
     ClosureHash=@ReceiptHash,ClosureReference=@ReceiptReference,EventDigest=@EventDigest,ClosedUTC=SYSUTCDATETIME()
     WHERE StreamID=@StreamID AND Version=@StreamVersion;
  END;
  UPDATE r SET ActivePreparationID=NULL,OwnerID=NULL,Version=Version+1 FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey;
  UPDATE dbo.ExportPreparation SET State=CASE WHEN @Action='verify' THEN 'completed' ELSE 'unavailable' END,Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PreparationID=@PreparationID AND Version=1;
  UPDATE dbo.ExportReplacementVerification SET State=CASE WHEN @Action='verify' THEN 'verified' ELSE 'discarded' END,
   Version=2,ReceiptHash=@ReceiptHash,ReceiptReference=@ReceiptReference,UpdatedUTC=SYSUTCDATETIME() WHERE VerificationID=@VerificationID AND Version=@ExpectedVersion;
 END;
 SELECT * FROM dbo.ExportReplacementVerification WHERE VerificationID=@VerificationID;
END;
GO
