-- AUTHORING ONLY. Run only in an explicitly approved fresh disposable database.
-- Retain all predecessor databases/files. This fixture rolls back its own rows.
-- Installation/rerun/partial/type-conflict/drift and actual restore are separate operations.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 51422,'Fixture requires its own transaction.',1;
IF OBJECT_ID(N'dbo.ExportPreparation',N'U') IS NULL THROW 51422,'Install approved S10C prerequisites first.',1;
BEGIN TRANSACTION;
BEGIN TRY
 DECLARE @Preparation uniqueidentifier=NEWID();
 DECLARE @Account varchar(128)='s10c-fixture-'+CONVERT(varchar(36),NEWID());
 INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,KVK_NO,RequestHash,EnqueueSequence,State,Fence,Version,StorageOwner,RequestJson,Actor,Reason,CreatedUTC,UpdatedUTC)
 VALUES (@Preparation,@Account,'scan_data',NULL,HASHBYTES('SHA2_256',@Account),1,'pending',0,1,'fixture','{}','fixture','offline-authored fixture',SYSUTCDATETIME(),SYSUTCDATETIME());
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportPreparation WHERE PreparationID=@Preparation AND SpoolKey IS NULL AND JobID IS NULL) THROW 51422,'Pending capture lost.',1;
 DECLARE @Resource varchar(256)='account:'+@Account;
 INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version) VALUES (@Resource,'account',0,1);
 INSERT dbo.ExportPreparationResource(PreparationID,ResourceKey) VALUES (@Preparation,@Resource);
 UPDATE dbo.ExportPreparation SET State='preflight',OwnerID=@Preparation,Fence=1,Version=2 WHERE PreparationID=@Preparation;
 UPDATE dbo.ExportResource SET ActivePreparationID=@Preparation,OwnerID=@Preparation,Fence=1,Version=2 WHERE ResourceKey=@Resource;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ResourceKey=@Resource AND ActiveJobID IS NULL AND ActivePreparationID=@Preparation) THROW 51422,'Preparation membership missing.',1;
 -- Expected constraint failures must leave the admitted row untouched. XACT_ABORT
 -- is disabled only for these deliberate CHECK/FK violations inside this fixture.
 SET XACT_ABORT OFF;
 DECLARE @Rejected bit;
 SET @Rejected=0;
 BEGIN TRY
  UPDATE dbo.ExportPreparation SET State='pending' WHERE PreparationID=@Preparation;
 END TRY BEGIN CATCH
  IF ERROR_NUMBER()<>547 THROW;
  SET @Rejected=1;
 END CATCH;
 IF @Rejected=0 THROW 51422,'Owned preparation accepted pending state.',1;
 IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID('dbo.ExportPreparation') AND name='Actor' AND collation_name='Latin1_General_100_BIN2')
  THROW 51422,'Actor identity collation drifted.',1;

 SET @Rejected=0;
 BEGIN TRY
  UPDATE dbo.ExportPreparation SET KVK_NO=1 WHERE PreparationID=@Preparation;
 END TRY BEGIN CATCH
  IF ERROR_NUMBER()<>547 THROW;
  SET @Rejected=1;
 END CATCH;
 IF @Rejected=0 THROW 51422,'Scan preparation accepted a season.',1;
 SET @Rejected=0;
 BEGIN TRY
  UPDATE dbo.ExportPreparation SET State='captured' WHERE PreparationID=@Preparation;
 END TRY BEGIN CATCH
  IF ERROR_NUMBER()<>547 THROW;
  SET @Rejected=1;
 END CATCH;
 IF @Rejected=0 THROW 51422,'Capture accepted missing spool/generation.',1;
 SET @Rejected=0;
 BEGIN TRY
  UPDATE dbo.ExportPreparation SET Version=0 WHERE PreparationID=@Preparation;
 END TRY BEGIN CATCH
  IF ERROR_NUMBER()<>547 THROW;
  SET @Rejected=1;
 END CATCH;
 IF @Rejected=0 THROW 51422,'Preparation accepted a zero version.',1;
 SET @Rejected=0;
 BEGIN TRY
  UPDATE dbo.ExportResource SET OwnerID=NULL WHERE ResourceKey=@Resource;
 END TRY BEGIN CATCH
  IF ERROR_NUMBER()<>547 THROW;
  SET @Rejected=1;
 END CATCH;
 IF @Rejected=0 THROW 51422,'Owned resource accepted no owner.',1;
 SET @Rejected=0;
 BEGIN TRY
  UPDATE dbo.ExportResource SET ActivePreparationID=NEWID() WHERE ResourceKey=@Resource;
 END TRY BEGIN CATCH
  IF ERROR_NUMBER()<>547 THROW;
  SET @Rejected=1;
 END CATCH;
 IF @Rejected=0 THROW 51422,'Resource accepted missing preparation membership.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ResourceKey=@Resource AND ActivePreparationID=@Preparation AND OwnerID=@Preparation AND Fence=1 AND Version=2)
  THROW 51422,'Rejected changes altered the retained resource.',1;
 SET XACT_ABORT ON;
 ROLLBACK;
 SELECT 'S10C preparation fixture rolled back' AS Outcome;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
