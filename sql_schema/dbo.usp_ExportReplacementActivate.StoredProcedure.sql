SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE dbo.usp_ExportReplacementActivate
 @ActivationID uniqueidentifier,@ReplacementID uniqueidentifier,@VerificationID uniqueidentifier,
 @AccountKey varchar(128),@BaseRegistrationHash binary(32),@RegistrationHash binary(32),
 @RegistrationJson nvarchar(max),@ReceiptHash binary(32),@ReceiptReference uniqueidentifier,
 @Actor nvarchar(128),@Reason nvarchar(512),@OldPoolID uniqueidentifier=NULL,@OldPoolVersion bigint=NULL,
 @PoolRegistrationJson nvarchar(max)=NULL,@PoolRegistrationHash binary(32)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51729,'Exact outer activation transaction required.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
  THROW 51729,'Evidence authority role required.',1;
 IF @ActivationID IS NULL OR @ReplacementID IS NULL OR @VerificationID IS NULL OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL
  OR @BaseRegistrationHash IS NULL OR @RegistrationHash IS NULL OR @BaseRegistrationHash=@RegistrationHash
  OR @RegistrationJson IS NULL OR ISJSON(@RegistrationJson)<>1 OR DATALENGTH(@RegistrationJson)>65536
  OR @AccountKey IS NULL OR LEN(@AccountKey)=0 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey)
  OR @AccountKey COLLATE Latin1_General_100_BIN2 LIKE '%[^-A-Za-z0-9_.@:]%'
  OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
  THROW 51729,'Complete bounded activation receipt and registration required.',1;
 DECLARE @AccountResource varchar(256)='account:'+@AccountKey,@LockKey nvarchar(255),@LockResult int;
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@AccountResource),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51729,'Activation admission busy.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation WITH(UPDLOCK,HOLDLOCK) WHERE
  ActivationID=@ActivationID OR ReplacementID=@ReplacementID OR VerificationID=@VerificationID OR (AccountKey=@AccountKey AND BaseRegistrationHash=@BaseRegistrationHash))
  THROW 51729,'Activation already has a durable receipt; inspect it before another action.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation WHERE AccountKey=@AccountKey)
  AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation a WHERE a.AccountKey=@AccountKey AND a.RegistrationHash=@BaseRegistrationHash
   AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation n WHERE n.AccountKey=a.AccountKey AND n.BaseRegistrationHash=a.RegistrationHash))
  THROW 51729,'Effective registration changed after replacement review.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementPlan p JOIN dbo.ExportTargetContainment c ON c.ContainmentID=p.ContainmentID
  JOIN dbo.ExportReplacementVerification v ON v.ReplacementID=p.ReplacementID
  JOIN dbo.ExportPreparation prep ON prep.PreparationID=v.PreparationID
  WHERE p.ReplacementID=@ReplacementID AND p.AccountKey=@AccountKey AND p.BaseRegistrationHash=@BaseRegistrationHash
   AND c.AccountKey=@AccountKey
   AND (EXISTS(SELECT 1 FROM dbo.ExportJob j WHERE j.JobID=c.JobID AND j.AccountKey=@AccountKey AND j.State='uncertain')
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation o WHERE o.OperationID=c.OutputOperationID AND o.AccountKey=@AccountKey AND o.State='uncertain' AND o.Phase='uncertain' AND o.PoolID=@OldPoolID))
   AND v.VerificationID=@VerificationID AND v.State='verified' AND v.Version=2
   AND v.ReceiptHash IS NOT NULL AND v.ReceiptReference IS NOT NULL AND prep.State='completed' AND prep.RequestHash=v.PlanHash)
  THROW 51729,'Verified replacement observation and original isolated job required.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  OR EXISTS(SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN ('preflight','sql_pending','writing','committed','uncertain'))
  OR EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ResourceKey=@AccountResource AND (OwnerID IS NOT NULL OR ActiveJobID IS NOT NULL OR ActivePreparationID IS NOT NULL OR ActiveOutputOperationID IS NOT NULL OR BlockedReason IS NOT NULL))
  THROW 51729,'Active account work must finish before changing registration.',1;
 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 INSERT @Resources SELECT 'destination:'+NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID;
 INSERT @Resources SELECT 'destination:'+OldFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID;
 DECLARE @Key varchar(256);
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks; FETCH NEXT FROM ResourceLocks INTO @Key;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@Key),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @LockResult<0 THROW 51729,'Replacement target busy.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key AND OwnerID IS NULL
   AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND BlockedReason IS NULL)
   THROW 51729,'Exact unowned replacement and contained targets required.',1;
  FETCH NEXT FROM ResourceLocks INTO @Key;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;
 IF EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t WHERE t.ReplacementID=@ReplacementID AND
  (EXISTS(SELECT 1 FROM dbo.ExportContainedTarget WHERE FileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE ResourceKey='destination:'+t.NewFileID)
   OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin WHERE FileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation a JOIN dbo.ExportReplacementTarget other ON other.ReplacementID=a.ReplacementID WHERE other.NewFileID=t.NewFileID)))
  THROW 51729,'Replacement destination was used or isolated after verification.',1;
 DECLARE @NewPoolID uniqueidentifier=NULL;
 IF @OldPoolID IS NULL
 BEGIN
  IF @OldPoolVersion IS NOT NULL OR @PoolRegistrationJson IS NOT NULL OR @PoolRegistrationHash IS NOT NULL
   OR EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t JOIN KVK.SourceOutputPool p ON p.IndexFileID=t.OldFileID WHERE t.ReplacementID=@ReplacementID)
   OR EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t JOIN KVK.SourceOutputSlot s ON s.FileID=t.OldFileID WHERE t.ReplacementID=@ReplacementID)
   THROW 51729,'Pool replacement requires the exact complete old pool.',1;
 END
 ELSE
 BEGIN
  SET @NewPoolID=@ReplacementID;
  SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(41),'pool:'+LOWER(CONVERT(varchar(36),@OldPoolID)))),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @LockResult<0 THROW 51729,'Old pool busy.',1;
  IF @OldPoolVersion IS NULL OR @PoolRegistrationJson IS NULL OR ISJSON(@PoolRegistrationJson)<>1 OR DATALENGTH(@PoolRegistrationJson)>65536 OR @PoolRegistrationHash IS NULL
   OR NOT EXISTS(SELECT 1 FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK) WHERE PoolID=@OldPoolID AND AccountKey=@AccountKey
    AND Version=@OldPoolVersion AND PoolState='blocked' AND OwnerID IS NULL AND RetiredByReplacementID IS NULL
    AND BlockedReason=N'Targets permanently isolated; verified replacements required')
   THROW 51729,'Exact contained pool version required.',1;
  IF (SELECT COUNT(*) FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID)<>(SELECT COUNT(*)+1 FROM KVK.SourceOutputSlot WHERE PoolID=@OldPoolID)
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t JOIN KVK.SourceOutputPool p ON p.IndexFileID=t.OldFileID WHERE t.ReplacementID=@ReplacementID AND p.PoolID=@OldPoolID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot s WHERE s.PoolID=@OldPoolID AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t WHERE t.ReplacementID=@ReplacementID AND t.OldFileID=s.FileID))
   THROW 51729,'Complete index and ordered slots required.',1;
  IF (SELECT COUNT(*) FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK) WHERE RetiredByReplacementID IS NULL)>8
   THROW 51729,'Active registration capacity differs.',1;
  INSERT KVK.SourceOutputFile(FileID,FileKind,ResourceKey,RegisteredBy,RegisteredUTC,EvidenceHash,EvidenceJson)
   SELECT t.NewFileID,CASE WHEN t.OldFileID=p.IndexFileID THEN 'index' ELSE 'slot' END,'destination:'+t.NewFileID,@Actor,SYSUTCDATETIME(),@PoolRegistrationHash,@PoolRegistrationJson
   FROM dbo.ExportReplacementTarget t CROSS JOIN KVK.SourceOutputPool p WHERE t.ReplacementID=@ReplacementID AND p.PoolID=@OldPoolID;
  UPDATE KVK.SourceOutputPool SET RetiredByReplacementID=@ReplacementID,Version=Version+1,UpdatedUTC=SYSUTCDATETIME() WHERE PoolID=@OldPoolID AND Version=@OldPoolVersion;
  INSERT KVK.SourceOutputPool(PoolID,IndexFileID,IndexFileKind,RegistrationNo,AccountKey,AccountResourceKey,ExpectedOwner,AudienceJson,SourceKey,ActiveKVK,ChoiceID,Epoch,PoolState,OwnerID,Fence,Version,BlockedReason,CreatedUTC,UpdatedUTC,RegistrationHash,RegistrationJson)
   SELECT @NewPoolID,t.NewFileID,'index',p.RegistrationNo,p.AccountKey,p.AccountResourceKey,p.ExpectedOwner,p.AudienceJson,p.SourceKey,p.ActiveKVK,p.ChoiceID,1,'active',NULL,0,1,NULL,SYSUTCDATETIME(),SYSUTCDATETIME(),@PoolRegistrationHash,@PoolRegistrationJson
   FROM KVK.SourceOutputPool p JOIN dbo.ExportReplacementTarget t ON t.OldFileID=p.IndexFileID AND t.ReplacementID=@ReplacementID WHERE p.PoolID=@OldPoolID;
  INSERT KVK.SourceOutputSlot(FileID,FileKind,PoolID,SlotNo,Epoch,State,OwnerID,Fence,Version,CreatedUTC,UpdatedUTC)
   SELECT t.NewFileID,'slot',@NewPoolID,s.SlotNo,1,'free',NULL,0,1,SYSUTCDATETIME(),SYSUTCDATETIME()
   FROM KVK.SourceOutputSlot s JOIN dbo.ExportReplacementTarget t ON t.OldFileID=s.FileID AND t.ReplacementID=@ReplacementID WHERE s.PoolID=@OldPoolID;
 END;
 INSERT dbo.ExportReplacementActivation VALUES(@ActivationID,@ReplacementID,@VerificationID,@AccountKey,@BaseRegistrationHash,@RegistrationHash,@RegistrationJson,
  @ReceiptHash,@ReceiptReference,@OldPoolID,@NewPoolID,@Actor,@Reason,SYSUTCDATETIME());
 SELECT * FROM dbo.ExportReplacementActivation WHERE ActivationID=@ActivationID;
END;
GO
