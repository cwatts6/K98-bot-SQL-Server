SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE dbo.usp_ExportLegacyCloseout
 @ActionID uniqueidentifier,@JobID uniqueidentifier,@AccountKey varchar(128),
 @StorageOwner varchar(128),@ExpectedVersion bigint,@OwnerID uniqueidentifier,@Fence bigint,
 @SnapshotHash binary(32),@ReceiptHash binary(32),@ReceiptReference uniqueidentifier,
 @Actor nvarchar(128),@Reason nvarchar(512)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51740,'Exact outer closeout transaction required.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
  THROW 51740,'Evidence authority role required.',1;
 IF @ActionID IS NULL OR @JobID IS NULL OR @AccountKey IS NULL OR @StorageOwner IS NULL
  OR @OwnerID IS NULL OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion IS NULL OR @ExpectedVersion<=0
  OR @SnapshotHash IS NULL OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL
  OR @Actor IS NULL OR @Actor<>N'recovery:'+LOWER(CONVERT(nvarchar(36),@ActionID))
  OR DATALENGTH(@Actor)<>90 OR @Reason IS NULL OR LEN(@Reason)=0
  THROW 51740,'Complete closeout identity required.',1;
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(136),'account:'+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51740,'Account admission busy.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportJob WITH(UPDLOCK,HOLDLOCK)
  WHERE JobID=@JobID AND AccountKey=@AccountKey AND StorageOwner=@StorageOwner
   AND ConsumerKind IN('scan_data','all_kvk') AND State IN('uncertain','failed')
   AND Version=@ExpectedVersion AND OwnerID=@OwnerID AND Fence=@Fence
   AND ISNULL(JSON_VALUE(ProvenanceJson,'$.safe_retry.requested'),'false')<>'true')
  THROW 51740,'Exact stopped legacy export required.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportLegacyCloseout WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID OR ActionID=@ActionID)
  THROW 51740,'Closeout already recorded; verify its receipt.',1;
 DECLARE @ContainmentID uniqueidentifier;
 SELECT @ContainmentID=ContainmentID FROM dbo.ExportTargetContainment WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID;
 IF @ContainmentID IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.ExportReplacementPlan WITH(UPDLOCK,HOLDLOCK) WHERE ContainmentID=@ContainmentID)
  THROW 51740,'Replacement work must be reconciled before same-file reuse.',1;

 DECLARE @ResourceKey varchar(256);
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR
  SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@JobID ORDER BY ResourceKey;
 OPEN ResourceLocks; FETCH NEXT FROM ResourceLocks INTO @ResourceKey;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@ResourceKey),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @LockResult<0 THROW 51740,'Resource admission busy.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@ResourceKey
   AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL
   AND ((ActiveJobID IS NULL AND OwnerID IS NULL)
    OR (ActiveJobID=@JobID AND OwnerID=@OwnerID AND Fence=@Fence)))
   THROW 51740,'Foreign ownership prevents closeout.',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;
 IF (SELECT COUNT(*) FROM dbo.ExportJobResource WHERE JobID=@JobID) NOT BETWEEN 2 AND 1025
  OR NOT EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey='account:'+@AccountKey)
  OR EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey<>'account:'+@AccountKey AND ResourceKey NOT LIKE 'destination:%')
  OR EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ActiveJobID=@JobID
   AND ResourceKey NOT IN(SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@JobID))
  THROW 51740,'Complete resource membership required.',1;
 IF @ContainmentID IS NOT NULL AND (
  EXISTS(SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID
   EXCEPT SELECT SUBSTRING(ResourceKey,13,128) FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey LIKE 'destination:%')
  OR EXISTS(SELECT SUBSTRING(ResourceKey,13,128) FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey LIKE 'destination:%'
   EXCEPT SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID))
  THROW 51740,'Complete contained target membership required.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportContainedTarget t JOIN dbo.ExportJobResource m ON m.ResourceKey='destination:'+t.FileID
  WHERE m.JobID=@JobID AND (@ContainmentID IS NULL OR t.ContainmentID<>@ContainmentID))
  THROW 51740,'Another containment owns these targets.',1;

 IF (SELECT COUNT(*) FROM dbo.ExportExecutionStream WHERE JobID=@JobID) NOT BETWEEN 1 AND 4096
  OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE ActiveAccountKey=@AccountKey)
  OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s WITH(UPDLOCK,HOLDLOCK)
   JOIN dbo.ExportExecutionSession a ON a.SessionID=s.SessionID WHERE s.JobID=@JobID AND
    (s.State NOT IN('closed','target_contained') OR s.ActiveAccountKey IS NOT NULL
     OR s.OwnerID<>@OwnerID OR s.Fence<>@Fence OR s.AccountKey<>@AccountKey
     OR a.AuthorityPrincipal<>USER_NAME() OR s.ClosureHash IS NULL OR s.ClosureReference IS NULL
     OR (s.State='target_contained' AND @ContainmentID IS NULL)
     OR s.Purpose NOT IN('mutation','probe') OR s.NestedToken IS NOT NULL OR s.Epoch IS NOT NULL))
  THROW 51740,'Every original execution must be sealed by its authority.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s WHERE s.JobID=@JobID AND
  (s.LastSequence<>(SELECT COUNT_BIG(*) FROM dbo.ExportProviderRequest r WHERE r.StreamID=s.StreamID)
   OR s.LastSequence<>ISNULL((SELECT MAX(Sequence) FROM dbo.ExportProviderRequest r WHERE r.StreamID=s.StreamID),0)))
  THROW 51740,'Complete sequential request membership required.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportExecutionStream s ON s.StreamID=r.StreamID
  WHERE s.JobID=@JobID AND (r.Operation='sheets.create'
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey='destination:'+r.TargetID)
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID AND EventSequence=1 AND State='prepared')
   OR NOT ((EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID AND EventSequence=2 AND State='not_sent')
    AND (SELECT COUNT(*) FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID)=2)
    OR (EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID AND EventSequence=2 AND State='dispatch_intent')
     AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID AND EventSequence=3 AND State='succeeded')
     AND (SELECT COUNT(*) FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID)=3))))
  THROW 51740,'Unfinished or unknown requests prevent same-file reuse.',1;

 INSERT dbo.ExportLegacyCloseout(ActionID,JobID,ContainmentID,AccountKey,OwnerVersion,SnapshotHash,ReceiptHash,ReceiptReference,Actor,Reason,CreatedUTC)
 VALUES(@ActionID,@JobID,@ContainmentID,@AccountKey,@ExpectedVersion,@SnapshotHash,@ReceiptHash,@ReceiptReference,@Actor,@Reason,SYSUTCDATETIME());
 DECLARE @Marker nvarchar(max)=(SELECT LOWER(CONVERT(varchar(36),@ReceiptReference)) AS reference,
  LOWER(CONVERT(varchar(64),@ReceiptHash,2)) AS sha256 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 UPDATE dbo.ExportJob SET State='failed',ProvenanceJson=JSON_MODIFY(ProvenanceJson,'$.legacy_export_abandoned',JSON_QUERY(@Marker)),
  Version=Version+1,UpdatedUTC=SYSUTCDATETIME() WHERE JobID=@JobID AND Version=@ExpectedVersion;
 IF @@ROWCOUNT<>1 THROW 51740,'Closeout owner changed.',1;
 UPDATE dbo.ExportResource SET ActiveJobID=NULL,OwnerID=NULL,BlockedReason=NULL,Version=Version+1
  WHERE ActiveJobID=@JobID AND OwnerID=@OwnerID AND Fence=@Fence;
 SELECT * FROM dbo.ExportLegacyCloseout WHERE ActionID=@ActionID;
END;
GO
