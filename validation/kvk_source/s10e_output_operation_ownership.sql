-- S10E authored disposable transaction fixture. NOT EXECUTED by offline checks.
-- Run only after explicit target, installation, backup and actual restore approval.
-- No predecessor execution. No provider/Discord proof. Preserve all retained S6 data.
-- SQLCMD variables are exact operator-reviewed inputs, never production defaults.
SET NOCOUNT ON;
SET XACT_ABORT OFF;
IF N'$(S10E_AUTHORIZED)' <> N'YES' THROW 51601, 'Explicit S10E authorization required.', 1;
IF CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) <> N'$(S10E_SERVER)' OR DB_NAME() <> N'$(S10E_DATABASE)' OR DB_NAME() NOT LIKE N'K98[_]S10E[_]Disposable[_]%' THROW 51601, 'Exact disposable target required.', 1;
IF LEN(N'$(BackupEvidence)') < 8 OR LEN(N'$(RestoreEvidence)') < 8 THROW 51601, 'Backup and actual restore evidence required.', 1;
IF @@TRANCOUNT<>0 THROW 51601, 'Fixture requires independent transaction ownership.', 1;
DECLARE @Pool uniqueidentifier=CONVERT(uniqueidentifier,N'$(S10E_POOL_ID)'), @NextKVK int=CONVERT(int,N'$(S10E_NEXT_KVK)');
DECLARE @Operation uniqueidentifier=NEWID(), @Owner uniqueidentifier=NEWID();
BEGIN TRY
BEGIN TRANSACTION;
-- Seed must be explicit disposable accepted S10D pool; no production-row invention.
INSERT KVK.SourceOutputOperation
(OperationID,PoolID,AccountKey,SourceKey,OldKVK,OldChoiceID,NewKVK,NewChoiceID,OldEpoch,TargetEpoch,PlanHash,PlanJson,ConfirmedBy,GuildID,ChannelID,Reason,ConfirmedUTC,EnqueueSequence,State,ActivePoolID,OwnerID,Fence,Version,Phase,CurrentFileID,ProgressJson,UpdatedUTC)
SELECT @Operation,p.PoolID,p.AccountKey,p.SourceKey,p.ActiveKVK,p.ChoiceID,n.KVK_NO,n.ChoiceID,p.Epoch,p.Epoch+1,HASHBYTES('SHA2_256',N'{}'),N'{}',N's10e-fixture','1','1',N'disposable ownership fixture',SYSUTCDATETIME(),1,'closing',p.PoolID,NULL,0,1,'draining',NULL,N'{}',SYSUTCDATETIME()
FROM KVK.SourceOutputPool p JOIN KVK.SeasonSource n ON n.KVK_NO=@NextKVK AND n.SourceKey=p.SourceKey
WHERE p.PoolID=@Pool AND p.PoolState='active' AND p.ActiveKVK<>@NextKVK;
IF @@ROWCOUNT<>1 THROW 51601, 'Exact fixed-source disposable seed required.', 1;
INSERT KVK.SourceOutputOperationResource (OperationID,PoolID,AccountKey,ResourceKey,ResourceKind,FileID,IndexFileID,SlotFileID)
SELECT @Operation,PoolID,AccountKey,AccountResourceKey,'account',NULL,NULL,NULL FROM KVK.SourceOutputPool WHERE PoolID=@Pool;
-- Third-owner membership is accepted; preexisting job/preparation owners are not released.
UPDATE r SET ActiveOutputOperationID=@Operation,OwnerID=@Owner,Fence=Fence+1,Version=Version+1
FROM dbo.ExportResource r JOIN KVK.SourceOutputPool p ON r.ResourceKey=p.AccountResourceKey
WHERE p.PoolID=@Pool AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL AND BlockedReason IS NULL;
IF @@ROWCOUNT<>1 THROW 51601, 'Fixture requires an unowned disposable account.', 1;
BEGIN TRY
    UPDATE dbo.ExportResource SET OwnerID=NULL WHERE ActiveOutputOperationID=@Operation;
    THROW 51602, 'Ownership constraint failed to reject ownerless operation.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>547 THROW;
END CATCH;
-- Correct owner/fence with stale version must fail; the matching CAS must succeed.
DECLARE @Resource varchar(256), @Version bigint, @Fence bigint;
SELECT @Resource=ResourceKey,@Version=Version,@Fence=Fence FROM dbo.ExportResource WHERE ActiveOutputOperationID=@Operation AND OwnerID=@Owner;
IF @Version IS NULL OR @Fence IS NULL THROW 51601, 'Owned resource snapshot required.', 1;
UPDATE dbo.ExportResource SET Version=Version+1 WHERE ResourceKey=@Resource AND ActiveOutputOperationID=@Operation AND OwnerID=@Owner AND Fence=@Fence AND Version=@Version-1;
IF @@ROWCOUNT<>0 THROW 51601, 'Stale version unexpectedly matched.', 1;
UPDATE dbo.ExportResource SET Version=Version+1 WHERE ResourceKey=@Resource AND ActiveOutputOperationID=@Operation AND OwnerID=@Owner AND Fence=@Fence-1 AND Version=@Version;
IF @@ROWCOUNT<>0 THROW 51601, 'Stale fence unexpectedly matched.', 1;
UPDATE dbo.ExportResource SET Version=Version+1 WHERE ResourceKey=@Resource AND ActiveOutputOperationID=@Operation AND OwnerID=NEWID() AND Fence=@Fence AND Version=@Version;
IF @@ROWCOUNT<>0 THROW 51601, 'Stale owner unexpectedly matched.', 1;
UPDATE dbo.ExportResource SET Version=Version+1 WHERE ResourceKey=@Resource AND ActiveOutputOperationID=@Operation AND OwnerID=@Owner AND Fence=@Fence AND Version=@Version;
IF @@ROWCOUNT<>1 THROW 51601, 'Current owner/fence/version CAS did not match.', 1;
ROLLBACK TRANSACTION;
SELECT 'S10E disposable ownership cases passed; no provider or installation proof' AS Result;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
