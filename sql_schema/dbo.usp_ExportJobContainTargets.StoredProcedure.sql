SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Whole-target retirement, never remote completion or child-termination proof.
GO
CREATE PROCEDURE dbo.usp_ExportJobContainTargets
 @ContainmentID uniqueidentifier,@AccountKey varchar(128),@JobID uniqueidentifier,
 @OwnerID uniqueidentifier,@Fence bigint,@ExpectedVersion bigint,
 @SnapshotHash binary(32),@ReceiptHash binary(32),@ReceiptReference uniqueidentifier,
 @ResourcesJson nvarchar(max),@StreamsJson nvarchar(max),
 @Actor nvarchar(128),@Reason nvarchar(512),
 @RegistrationHash binary(32),@StorageOwner varchar(128)=NULL,
 @PoolID uniqueidentifier=NULL,@PoolVersion bigint=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51726,'Exact outer containment transaction required.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
  THROW 51726,'Evidence authority role required.',1;
 IF @ContainmentID IS NULL OR @AccountKey IS NULL OR @JobID IS NULL OR @OwnerID IS NULL
  OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion IS NULL OR @ExpectedVersion<=0
  OR @SnapshotHash IS NULL OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL OR @RegistrationHash IS NULL
  OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
  OR @ResourcesJson IS NULL OR ISJSON(@ResourcesJson)<>1 OR DATALENGTH(@ResourcesJson)>1048576
  OR @StreamsJson IS NULL OR ISJSON(@StreamsJson)<>1 OR DATALENGTH(@StreamsJson)>1048576
  THROW 51726,'Complete bounded containment identity required.',1;
 -- Validate before typed projection: OPENJSON WITH otherwise truncates strings,
 -- and binary conversion pads short hashes. Neither may change approved evidence.
 IF LEFT(LTRIM(@ResourcesJson),1)<>'[' OR LEFT(LTRIM(@StreamsJson),1)<>'['
  OR EXISTS(SELECT 1 FROM OPENJSON(@ResourcesJson) j WHERE j.type<>5
   OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>2
   OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>2
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]='key' AND type=1
    AND LEN(value) BETWEEN 1 AND 256 AND DATALENGTH(value)=2*LEN(value)
    AND value NOT LIKE '%[^-A-Za-z0-9_.@:]%' COLLATE Latin1_General_100_BIN2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]='version' AND type=2
    AND TRY_CONVERT(bigint,value)>0 AND value NOT LIKE '%[^0-9]%' COLLATE Latin1_General_100_BIN2))
  OR EXISTS(SELECT 1 FROM OPENJSON(@StreamsJson) j WHERE j.type<>5
   OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>4
   OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>4
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]='stream_id' AND type=1
    AND DATALENGTH(value)=72 AND TRY_CONVERT(uniqueidentifier,value) IS NOT NULL)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]='version' AND type=2
    AND TRY_CONVERT(bigint,value)>0 AND value NOT LIKE '%[^0-9]%' COLLATE Latin1_General_100_BIN2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]='last_sequence' AND type=2
    AND TRY_CONVERT(bigint,value)>=0 AND value NOT LIKE '%[^0-9]%' COLLATE Latin1_General_100_BIN2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]='event_digest' AND type=1
    AND DATALENGTH(value)=128 AND value NOT LIKE '%[^0-9a-f]%' COLLATE Latin1_General_100_BIN2))
  THROW 51726,'Exact resource and stream JSON shapes required.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(136),'account:'+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51726,'Account admission busy.',1;

 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 PRIMARY KEY,Version bigint NOT NULL);
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ResourcesJson)
  WITH(ResourceKey varchar(256) '$.key',Version bigint '$.version');
 IF (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 2 AND 1025
  OR NOT EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey='account:'+@AccountKey)
  OR EXISTS(SELECT 1 FROM @Resources WHERE Version<=0 OR (ResourceKey<>'account:'+@AccountKey AND ResourceKey NOT LIKE 'destination:%'))
  OR EXISTS(SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@JobID EXCEPT SELECT ResourceKey FROM @Resources)
  OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@JobID)
  THROW 51726,'Complete exact job resource membership required.',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@ResourceKey),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @LockResult<0 THROW 51726,'Resource admission busy.',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK)
   WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion AND ActiveJobID=@JobID
    AND OwnerID=@OwnerID AND Fence=@Fence AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
   THROW 51726,'Exact held job resource required.',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;

 DECLARE @Consumer varchar(32),@JobEpoch bigint,@JobKVK int;
 SELECT @Consumer=ConsumerKind,@JobEpoch=PoolEpoch,@JobKVK=KVK_NO FROM dbo.ExportJob WITH(UPDLOCK,HOLDLOCK)
 WHERE JobID=@JobID AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence
  AND Version=@ExpectedVersion AND State IN ('running','uncertain')
  AND ((ConsumerKind='new_source' AND StorageOwner IS NULL AND @StorageOwner IS NULL)
   OR (ConsumerKind IN ('scan_data','all_kvk') AND StorageOwner=@StorageOwner));
 IF @Consumer IS NULL THROW 51726,'Exact unfinished job required.',1;
 IF (@Consumer='new_source' AND (@PoolID IS NULL OR @PoolVersion IS NULL OR @PoolVersion<=0))
  OR (@Consumer<>'new_source' AND (@PoolID IS NOT NULL OR @PoolVersion IS NOT NULL))
  THROW 51726,'Exact consumer pool identity required.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportResource r WITH(UPDLOCK,HOLDLOCK) WHERE r.ActiveJobID=@JobID
  AND NOT EXISTS(SELECT 1 FROM @Resources e WHERE e.ResourceKey=r.ResourceKey))
  THROW 51726,'Unexpected held job resource prevents partial release.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportTargetContainment WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID OR ContainmentID=@ContainmentID)
  THROW 51726,'Containment already recorded; verify its original receipt.',1;

 DECLARE @Targets TABLE(FileID varchar(128) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey LIKE 'destination:%' AND LEN(ResourceKey) NOT BETWEEN 15 AND 140)
  THROW 51726,'Bounded physical target identity required.',1;
 INSERT @Targets SELECT SUBSTRING(ResourceKey,13,128) FROM @Resources WHERE ResourceKey LIKE 'destination:%';
 IF EXISTS(SELECT 1 FROM @Targets WHERE DATALENGTH(FileID)<>LEN(FileID) OR FileID LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2)
  OR EXISTS(SELECT 1 FROM @Targets t JOIN dbo.ExportContainedTarget c WITH(UPDLOCK,HOLDLOCK) ON c.FileID=t.FileID)
  THROW 51726,'Target identity differs or is already permanently isolated.',1;

 DECLARE @Streams TABLE(StreamID uniqueidentifier PRIMARY KEY,Version bigint NOT NULL,LastSequence bigint NOT NULL,EventDigest binary(32) NOT NULL);
 INSERT @Streams SELECT StreamID,Version,LastSequence,CONVERT(binary(32),EventDigest,2)
 FROM OPENJSON(@StreamsJson) WITH(StreamID uniqueidentifier '$.stream_id',Version bigint '$.version',LastSequence bigint '$.last_sequence',EventDigest varchar(64) '$.event_digest');
 IF (SELECT COUNT(*) FROM @Streams) NOT BETWEEN 1 AND 4096
  OR EXISTS(SELECT 1 FROM @Streams WHERE Version<=0 OR LastSequence<0)
  OR EXISTS(SELECT StreamID FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID EXCEPT SELECT StreamID FROM @Streams)
  OR EXISTS(SELECT StreamID FROM @Streams EXCEPT SELECT StreamID FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID)
  OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE ActiveAccountKey=@AccountKey AND (JobID IS NULL OR JobID<>@JobID))
  THROW 51726,'Complete exclusive job stream membership required.',1;
 IF EXISTS(SELECT 1 FROM @Streams e JOIN dbo.ExportExecutionStream s WITH(UPDLOCK,HOLDLOCK) ON s.StreamID=e.StreamID
  LEFT JOIN dbo.ExportExecutionSession a ON a.SessionID=s.SessionID
  WHERE s.AccountKey<>@AccountKey OR s.OwnerID<>@OwnerID OR s.Fence<>@Fence OR s.Version<>e.Version OR s.LastSequence<>e.LastSequence
   OR s.RegistrationHash IS NULL OR s.RegistrationHash<>@RegistrationHash
   OR s.ClaimVersion>@ExpectedVersion
   OR (s.Epoch IS NULL AND @JobEpoch IS NOT NULL) OR (s.Epoch IS NOT NULL AND @JobEpoch IS NULL) OR s.Epoch<>@JobEpoch
   OR s.PreparationID IS NOT NULL OR s.OutputOperationID IS NOT NULL OR s.Purpose NOT IN ('mutation','probe')
   OR s.State NOT IN ('open','frozen','closed') OR a.AuthorityPrincipal IS NULL OR a.AuthorityPrincipal<>USER_NAME()
   OR EXISTS(SELECT ResourceKey FROM OPENJSON(s.ScopeJson,'$.resources') WITH(ResourceKey varchar(256) '$.key') EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM OPENJSON(s.ScopeJson,'$.resources') WITH(ResourceKey varchar(256) '$.key')))
  THROW 51726,'Exact original stream authority and complete possible targets required.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r JOIN @Streams s ON s.StreamID=r.StreamID
  WHERE r.Operation='sheets.create' OR NOT EXISTS(SELECT 1 FROM @Targets t WHERE t.FileID=r.TargetID))
  THROW 51726,'A recorded request escaped the proposed retired target set.',1;

 IF @Consumer='new_source'
 BEGIN
  SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(41),'pool:'+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @LockResult<0 THROW 51726,'Output pool admission busy.',1;
  IF NOT EXISTS(SELECT 1 FROM KVK.SourceOutputPool p WITH(UPDLOCK,HOLDLOCK) JOIN @Targets t ON t.FileID=p.IndexFileID
   WHERE p.PoolID=@PoolID AND p.Version=@PoolVersion AND p.Epoch=@JobEpoch AND p.ActiveKVK=@JobKVK
    AND p.RegistrationHash=@RegistrationHash AND p.AccountKey=@AccountKey AND p.PoolState='active' AND p.OwnerID IS NULL)
   THROW 51726,'Exact unowned active output pool required.',1;
  IF (SELECT COUNT(*) FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID) NOT BETWEEN 2 AND 16
   OR EXISTS(SELECT FileID FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID EXCEPT SELECT FileID FROM @Targets)
   OR EXISTS(SELECT FileID FROM @Targets EXCEPT SELECT FileID FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID
    EXCEPT SELECT IndexFileID FROM KVK.SourceOutputPool WHERE PoolID=@PoolID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation WHERE PoolID=@PoolID AND State<>'completed')
   THROW 51726,'Pool membership or unfinished rollover prevents this job decision.',1;
 END;

 INSERT dbo.ExportTargetContainment
  (ContainmentID,AccountKey,JobID,OwnerVersion,OwnerID,Fence,SnapshotHash,ReceiptHash,ReceiptReference,Actor,Reason,CreatedUTC)
 VALUES(@ContainmentID,@AccountKey,@JobID,@ExpectedVersion,@OwnerID,@Fence,@SnapshotHash,@ReceiptHash,@ReceiptReference,@Actor,@Reason,SYSUTCDATETIME());
 INSERT dbo.ExportContainedTarget SELECT FileID,@ContainmentID,SYSUTCDATETIME() FROM @Targets;
 INSERT dbo.ExportContainedStream SELECT StreamID,@ContainmentID,Version,LastSequence,EventDigest FROM @Streams;
 UPDATE s SET State='target_contained',ActiveAccountKey=NULL,Version=s.Version+1,
  ClosureHash=@ReceiptHash,ClosureReference=@ReceiptReference,EventDigest=e.EventDigest,ClosedUTC=SYSUTCDATETIME()
 FROM dbo.ExportExecutionStream s JOIN @Streams e ON e.StreamID=s.StreamID;
 IF @PoolID IS NOT NULL
 BEGIN
  UPDATE KVK.SourceOutputPool SET PoolState='blocked',BlockedReason=N'Targets permanently isolated; verified replacements required',Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PoolID=@PoolID AND PoolState='active' AND OwnerID IS NULL AND Version=@PoolVersion;
  IF @@ROWCOUNT<>1 THROW 51726,'Pool containment CAS lost.',1;
 END;
 UPDATE dbo.ExportJob SET State='uncertain',Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
  WHERE JobID=@JobID AND Version=@ExpectedVersion AND OwnerID=@OwnerID AND Fence=@Fence;
 IF @@ROWCOUNT<>1 THROW 51726,'Job containment CAS lost.',1;
 UPDATE r SET ActiveJobID=NULL,OwnerID=NULL,BlockedReason=NULL,Version=r.Version+1
 FROM dbo.ExportResource r JOIN @Resources e ON e.ResourceKey=r.ResourceKey
 WHERE r.Version=e.Version AND r.ActiveJobID=@JobID AND r.OwnerID=@OwnerID AND r.Fence=@Fence
  AND r.ActivePreparationID IS NULL AND r.ActiveOutputOperationID IS NULL;
 IF @@ROWCOUNT<>(SELECT COUNT(*) FROM @Resources) THROW 51726,'Resource containment CAS lost.',1;
 SELECT * FROM dbo.ExportTargetContainment WHERE ContainmentID=@ContainmentID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO
