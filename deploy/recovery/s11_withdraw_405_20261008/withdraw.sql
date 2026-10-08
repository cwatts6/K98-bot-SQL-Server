-- Exact unclaimed ticket withdrawal. No SQL producer or provider operation.
-- Caller binds @ExpectedServer nvarchar(128), @ExpectedDatabase sysname.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 2000;
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
 THROW 51930,'Existing operator administrator and own transaction required.',1;
IF CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))<>@ExpectedServer OR DB_NAME()<>@ExpectedDatabase
 THROW 51930,'Withdrawal target differs.',1;
IF NOT ((@ExpectedServer=N'mini_AMD' AND @ExpectedDatabase=N'ROK_TRACKER'
 AND SUSER_SID()=0x01050000000000051500000082350CB1D5DFA006BAE7A2E4E9030000)
 OR (@ExpectedServer=N'9SX2VF4\K98DEV' AND @ExpectedDatabase LIKE N'S11_ManualStats_Test_20261008[_]%'))
 THROW 51930,'Target is outside production/local-fixture scope.',1;
DECLARE @ID uniqueidentifier='340b9372-e6ee-44de-927a-d10483eefe1a',
 @Recovery uniqueidentifier='7c137998-16a2-4e4a-9906-10566ed2b3e6',
 @Account varchar(128)='sheets-service@statsupdate.iam.gserviceaccount.com',
 @LockKey nvarchar(255),@LockResult int,@Audit nvarchar(max),@Before nvarchar(max);
BEGIN TRY
 BEGIN TRAN;
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(136),'account:'+@Account)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51931,'Account busy; no withdrawal.',1;
 SELECT @Audit=GenerationJson FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK)
 WHERE PreparationID=@ID AND AccountKey=@Account;
 IF EXISTS(SELECT 1 FROM dbo.ExportPreparation WHERE PreparationID=@ID AND AccountKey=@Account
  AND State='unavailable' AND Version=2 AND Fence=1 AND OwnerID=@Recovery
  AND JSON_VALUE(GenerationJson,'$.operator_reconciliation.recovery_id')=CONVERT(varchar(36),@Recovery))
 BEGIN
  COMMIT;
  SELECT 'ALREADY_WITHDRAWN_NO_CHANGE' AS Status,@Recovery AS RecoveryID,@Audit AS Audit;
  RETURN;
 END;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportPreparation WHERE PreparationID=@ID AND AccountKey=@Account
  AND ConsumerKind='scan_data' AND State='pending' AND OwnerID IS NULL AND Fence=0 AND Version=1
  AND EnqueueSequence=405
  AND RequestHash=0x80718563BB8BCE4CA05CC48638A7CC2EC9DEDCF159D290079B2B44AA6652F52C
  AND CreatedUTC=CONVERT(datetime2(3),'2026-10-08T14:45:24.378')
  AND UpdatedUTC=CreatedUTC AND GenerationJson IS NULL AND JobID IS NULL
  AND SpoolKey IS NULL AND SpoolBytes IS NULL AND SpoolHash IS NULL)
  THROW 51932,'Exact unclaimed preparation differs; no withdrawal.',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK) WHERE ActivePreparationID=@ID)
  OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ID)
  THROW 51932,'Preparation has resource or provider evidence; no withdrawal.',1;
 -- Completed prior recovery must remain recorded, never repeat it.
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportPreparation WITH (HOLDLOCK)
  WHERE PreparationID='c9831a9d-3031-4954-9da9-79815406ec0b'
  AND State='unavailable' AND Version=6 AND Fence=238
  AND UPPER(JSON_VALUE(GenerationJson,'$.operator_reconciliation.recovery_id'))='50A5B6E5-D1D0-49DC-BF04-AB566047E152')
  THROW 51932,'Prior supersession receipt differs.',1;
 SET @Before=(SELECT PreparationID,EnqueueSequence,State,OwnerID,Fence,Version,RequestHash,CreatedUTC,UpdatedUTC
  FROM dbo.ExportPreparation WHERE PreparationID=@ID FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER);
 SET @Audit=(SELECT 1 AS version,JSON_QUERY((SELECT
  'withdraw_exact_unclaimed_preparation' AS kind,CONVERT(varchar(36),@Recovery) AS recovery_id,
  ORIGINAL_LOGIN() AS actor,SYSUTCDATETIME() AS recorded_utc,
  JSON_QUERY(@Before) AS previous_preparation,
  'pending_v1_owner_null_fence_zero' AS basis,
  CAST(0 AS bit) AS producer_replayed,CAST(0 AS bit) AS provider_replayed
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)) AS operator_reconciliation FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 UPDATE dbo.ExportPreparation SET State='unavailable',OwnerID=@Recovery,Fence=1,Version=2,
  GenerationJson=@Audit,UpdatedUTC=SYSUTCDATETIME()
 WHERE PreparationID=@ID AND AccountKey=@Account AND State='pending' AND Version=1 AND OwnerID IS NULL AND Fence=0;
 IF @@ROWCOUNT<>1 THROW 51933,'Unclaimed preparation CAS failed.',1;
 COMMIT;
 SELECT 'WITHDRAWN_UNCLAIMED_PREPARATION' AS Status,@Recovery AS RecoveryID,@Audit AS Audit;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
