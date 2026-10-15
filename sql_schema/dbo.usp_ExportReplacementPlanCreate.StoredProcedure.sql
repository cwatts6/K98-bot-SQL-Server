SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE PROCEDURE dbo.usp_ExportReplacementPlanCreate
 @ReplacementID uniqueidentifier,@ContainmentID uniqueidentifier,@AccountKey varchar(128),
 @BaseRegistrationHash binary(32),@ProjectedRegistrationHash binary(32),
 @ReceiptHash binary(32),@ReceiptReference uniqueidentifier,@MappingJson nvarchar(max),
 @Actor nvarchar(128),@Reason nvarchar(512)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51727,'Exact outer replacement-plan transaction required.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
  THROW 51727,'Evidence authority role required.',1;
 IF @ReplacementID IS NULL OR @ContainmentID IS NULL OR @AccountKey IS NULL
  OR DATALENGTH(@AccountKey)<>LEN(@AccountKey) OR LEN(@AccountKey)=0
  OR @AccountKey LIKE '%[^-A-Za-z0-9_.@:]%' COLLATE Latin1_General_100_BIN2
  OR @BaseRegistrationHash IS NULL OR @ProjectedRegistrationHash IS NULL
  OR @BaseRegistrationHash=@ProjectedRegistrationHash OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL
  OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
  OR @MappingJson IS NULL OR ISJSON(@MappingJson)<>1 OR DATALENGTH(@MappingJson)>1048576
  THROW 51727,'Complete bounded replacement proposal required.',1;
 IF LEFT(LTRIM(@MappingJson),1)<>'[' OR (SELECT COUNT(*) FROM OPENJSON(@MappingJson)) NOT BETWEEN 1 AND 1024
  OR EXISTS(SELECT 1 FROM OPENJSON(@MappingJson) j WHERE j.type<>5
   OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>2 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>2
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]='old' AND type=1 AND DATALENGTH(value)=2*LEN(value)
    AND LEN(value) BETWEEN 6 AND 128 AND value NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]='new' AND type=1 AND DATALENGTH(value)=2*LEN(value)
    AND LEN(value) BETWEEN 6 AND 128 AND value NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2))
  THROW 51727,'Exact old/new physical file mapping required.',1;
 DECLARE @Mapping TABLE(OldFileID varchar(128) COLLATE Latin1_General_100_BIN2 PRIMARY KEY,
  NewFileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL UNIQUE);
 INSERT @Mapping SELECT OldFileID,NewFileID FROM OPENJSON(@MappingJson)
  WITH(OldFileID varchar(128) '$.old',NewFileID varchar(128) '$.new');
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255),@JobID uniqueidentifier;
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(136),'account:'+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51727,'Account admission busy.',1;
 SELECT @JobID=JobID FROM dbo.ExportTargetContainment WITH(UPDLOCK,HOLDLOCK)
  WHERE ContainmentID=@ContainmentID AND AccountKey=@AccountKey AND JobID IS NOT NULL
   AND PreparationID IS NULL AND OutputOperationID IS NULL;
 IF @JobID IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.ExportJob WITH(UPDLOCK,HOLDLOCK)
   WHERE JobID=@JobID AND AccountKey=@AccountKey AND State='uncertain')
  THROW 51727,'Exact isolated unresolved job required.',1;
 IF EXISTS(SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID EXCEPT SELECT OldFileID FROM @Mapping)
  OR EXISTS(SELECT OldFileID FROM @Mapping EXCEPT SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID)
  THROW 51727,'Every isolated physical target requires a replacement.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ActiveJobID=@JobID)
  THROW 51727,'Original custody has not been released.',1;
 -- Replay is never a second insert. The authority reads and verifies the
 -- original private receipt after any lost commit acknowledgement.
 IF EXISTS(SELECT 1 FROM dbo.ExportReplacementPlan WITH(UPDLOCK,HOLDLOCK) WHERE ReplacementID=@ReplacementID)
  THROW 51727,'Proposal already recorded; verify its original receipt.',1;
 DECLARE @ResourceKey varchar(256);
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR
  SELECT 'destination:'+NewFileID FROM @Mapping ORDER BY NewFileID;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@ResourceKey),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @LockResult<0 THROW 51727,'Replacement destination busy.',1;
  IF EXISTS(SELECT 1 FROM dbo.ExportContainedTarget WHERE FileID=SUBSTRING(@ResourceKey,13,128))
   OR EXISTS(SELECT 1 FROM dbo.ExportResource r WITH(UPDLOCK,HOLDLOCK) WHERE r.ResourceKey=@ResourceKey AND
    (r.OwnerID IS NOT NULL OR r.ActiveJobID IS NOT NULL OR r.ActivePreparationID IS NOT NULL
     OR r.ActiveOutputOperationID IS NOT NULL OR r.BlockedReason IS NOT NULL
     OR NOT EXISTS(SELECT 1 FROM dbo.ExportPreparationResource m
      JOIN dbo.ExportReplacementVerification v ON v.PreparationID=m.PreparationID
      JOIN dbo.ExportReplacementPlan p ON p.ReplacementID=v.ReplacementID
      WHERE m.ResourceKey=r.ResourceKey AND p.ContainmentID=@ContainmentID AND p.AccountKey=@AccountKey
       AND v.State IN ('verified','discarded') AND NOT EXISTS
        (SELECT 1 FROM dbo.ExportReplacementActivation a WHERE a.ReplacementID=p.ReplacementID))))
   OR EXISTS(SELECT 1 FROM dbo.ExportPreparationResource m WHERE m.ResourceKey=@ResourceKey AND NOT EXISTS
    (SELECT 1 FROM dbo.ExportReplacementVerification v JOIN dbo.ExportReplacementPlan p ON p.ReplacementID=v.ReplacementID
     WHERE v.PreparationID=m.PreparationID AND p.ContainmentID=@ContainmentID AND p.AccountKey=@AccountKey
      AND v.State IN ('verified','discarded') AND NOT EXISTS
       (SELECT 1 FROM dbo.ExportReplacementActivation a WHERE a.ReplacementID=p.ReplacementID)))
   OR EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE ResourceKey=@ResourceKey)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperationResource WHERE ResourceKey=@ResourceKey)
   OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE TargetID=SUBSTRING(@ResourceKey,13,128) AND RequestKind<>'read')
   OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=SUBSTRING(@ResourceKey,13,128))
   OR EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin WHERE FileID=SUBSTRING(@ResourceKey,13,128))
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=SUBSTRING(@ResourceKey,13,128))
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=SUBSTRING(@ResourceKey,13,128))
   THROW 51727,'A proposed replacement has existing execution or registration history.',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;
 INSERT dbo.ExportReplacementPlan VALUES(@ReplacementID,@ContainmentID,@AccountKey,@BaseRegistrationHash,
  @ProjectedRegistrationHash,@ReceiptHash,@ReceiptReference,@MappingJson,@Actor,@Reason,SYSUTCDATETIME());
 INSERT dbo.ExportReplacementTarget SELECT @ReplacementID,OldFileID,NewFileID FROM @Mapping;
 -- No resource, job, stream, origin or registration is changed by a proposal.
 SELECT * FROM dbo.ExportReplacementPlan WHERE ReplacementID=@ReplacementID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
