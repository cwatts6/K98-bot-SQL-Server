/*
MigrationId: 20261016_001_rollover_replacement
Purpose: Guided isolation and replacement of interrupted rollover pools
Author: cwatts
CreatedUtc: 2026-10-16
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact reviewed 010-chain procedure preimages and absent new procedure
PostValidationQuery: Exact reviewed procedure postimages
*/
-- Install after 010, before Bot/authority rollout and protected contract reissue.
-- No execution of recovery, release, provider calls or application-data changes.
-- Mixed, repeated, signed or drifted installations stop without changing data.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51734,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51734,'Schema busy.',1;
IF DATABASE_PRINCIPAL_ID(N'ExportExecutionAuthority') IS NULL
 OR DATABASE_PRINCIPAL_ID(N'ExportExecutionReader') IS NULL
 OR OBJECT_ID(N'dbo.ExportTargetContainment',N'U') IS NULL
 OR OBJECT_ID(N'dbo.ExportReplacementActivation',N'U') IS NULL
 THROW 51734,'Reviewed containment/replacement prerequisites required.',1;
IF OBJECT_ID(N'dbo.usp_ExportRolloverContainTargets') IS NOT NULL
 THROW 51734,'New rollover containment procedure must be absent.',1;
DECLARE @ObjectID int,@Installed nvarchar(max),@Apply nvarchar(max);
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementPlanCreate',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x561518c61b1bbf58fd2326a460d23ab5b760e1e386d84aa7a641f3e242f6d816
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51734,'Unexpected signature; preserve and review.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementVerificationTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x1d1865ee04623d96c730c014b3d900611dcfe552db6cf03492aa33106e34ffea
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51734,'Unexpected signature; preserve and review.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementActivate',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xa9d50e733bae47d77ea1a394514ab4f098c0c80dd9c7e86b587f01a7c6f024ca
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51734,'Unexpected signature; preserve and review.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportManualOutputEnrollmentTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xe968287e1816d157099b85bf031d61347b66526b01d3c908554a08eae332ae6d
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51734,'Unexpected signature; preserve and review.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportOutputEnrollmentTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x8248d1a8c490bac1c1cc13c3ee1bfef0c21fb36465e163c15d994afc7ea8d2ab
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51734,'Unexpected signature; preserve and review.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportReplacementPlanCreate
 @ReplacementID uniqueidentifier,@ContainmentID uniqueidentifier,@AccountKey varchar(128),
 @BaseRegistrationHash binary(32),@ProjectedRegistrationHash binary(32),
 @ReceiptHash binary(32),@ReceiptReference uniqueidentifier,@MappingJson nvarchar(max),
 @Actor nvarchar(128),@Reason nvarchar(512)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51727,''Exact outer replacement-plan transaction required.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51727,''Evidence authority role required.'',1;
 IF @ReplacementID IS NULL OR @ContainmentID IS NULL OR @AccountKey IS NULL
  OR DATALENGTH(@AccountKey)<>LEN(@AccountKey) OR LEN(@AccountKey)=0
  OR @AccountKey LIKE ''%[^-A-Za-z0-9_.@:]%'' COLLATE Latin1_General_100_BIN2
  OR @BaseRegistrationHash IS NULL OR @ProjectedRegistrationHash IS NULL
  OR @BaseRegistrationHash=@ProjectedRegistrationHash OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL
  OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
  OR @MappingJson IS NULL OR ISJSON(@MappingJson)<>1 OR DATALENGTH(@MappingJson)>1048576
  THROW 51727,''Complete bounded replacement proposal required.'',1;
 IF LEFT(LTRIM(@MappingJson),1)<>''['' OR (SELECT COUNT(*) FROM OPENJSON(@MappingJson)) NOT BETWEEN 1 AND 1024
  OR EXISTS(SELECT 1 FROM OPENJSON(@MappingJson) j WHERE j.type<>5
   OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>2 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>2
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''old'' AND type=1 AND DATALENGTH(value)=2*LEN(value)
    AND LEN(value) BETWEEN 6 AND 128 AND value NOT LIKE ''%[^-A-Za-z0-9_]%'' COLLATE Latin1_General_100_BIN2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''new'' AND type=1 AND DATALENGTH(value)=2*LEN(value)
    AND LEN(value) BETWEEN 6 AND 128 AND value NOT LIKE ''%[^-A-Za-z0-9_]%'' COLLATE Latin1_General_100_BIN2))
  THROW 51727,''Exact old/new physical file mapping required.'',1;
 DECLARE @Mapping TABLE(OldFileID varchar(128) COLLATE Latin1_General_100_BIN2 PRIMARY KEY,
  NewFileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL UNIQUE);
 INSERT @Mapping SELECT OldFileID,NewFileID FROM OPENJSON(@MappingJson)
  WITH(OldFileID varchar(128) ''$.old'',NewFileID varchar(128) ''$.new'');
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255),@JobID uniqueidentifier,@OperationID uniqueidentifier;
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51727,''Account admission busy.'',1;
 SELECT @JobID=JobID,@OperationID=OutputOperationID FROM dbo.ExportTargetContainment WITH(UPDLOCK,HOLDLOCK)
  WHERE ContainmentID=@ContainmentID AND AccountKey=@AccountKey AND PreparationID IS NULL;
 IF NOT (EXISTS(SELECT 1 FROM dbo.ExportJob WITH(UPDLOCK,HOLDLOCK)
   WHERE JobID=@JobID AND AccountKey=@AccountKey AND State=''uncertain'')
  OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation WITH(UPDLOCK,HOLDLOCK)
   WHERE OperationID=@OperationID AND AccountKey=@AccountKey AND State=''uncertain'' AND Phase=''uncertain''))
  THROW 51727,''Exact isolated unresolved owner required.'',1;
 IF EXISTS(SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID EXCEPT SELECT OldFileID FROM @Mapping)
  OR EXISTS(SELECT OldFileID FROM @Mapping EXCEPT SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID)
  THROW 51727,''Every isolated physical target requires a replacement.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ActiveJobID=@JobID OR ActiveOutputOperationID=@OperationID)
  THROW 51727,''Original custody has not been released.'',1;
 -- Replay is never a second insert. The authority reads and verifies the
 -- original private receipt after any lost commit acknowledgement.
 IF EXISTS(SELECT 1 FROM dbo.ExportReplacementPlan WITH(UPDLOCK,HOLDLOCK) WHERE ReplacementID=@ReplacementID)
  THROW 51727,''Proposal already recorded; verify its original receipt.'',1;
 DECLARE @ResourceKey varchar(256);
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR
  SELECT ''destination:''+NewFileID FROM @Mapping ORDER BY NewFileID;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51727,''Replacement destination busy.'',1;
  IF EXISTS(SELECT 1 FROM dbo.ExportContainedTarget WHERE FileID=SUBSTRING(@ResourceKey,13,128))
   OR EXISTS(SELECT 1 FROM dbo.ExportResource r WITH(UPDLOCK,HOLDLOCK) WHERE r.ResourceKey=@ResourceKey AND
    (r.OwnerID IS NOT NULL OR r.ActiveJobID IS NOT NULL OR r.ActivePreparationID IS NOT NULL
     OR r.ActiveOutputOperationID IS NOT NULL OR r.BlockedReason IS NOT NULL
     OR NOT EXISTS(SELECT 1 FROM dbo.ExportPreparationResource m
      JOIN dbo.ExportReplacementVerification v ON v.PreparationID=m.PreparationID
      JOIN dbo.ExportReplacementPlan p ON p.ReplacementID=v.ReplacementID
      WHERE m.ResourceKey=r.ResourceKey AND p.ContainmentID=@ContainmentID AND p.AccountKey=@AccountKey
       AND v.State IN (''verified'',''discarded'') AND NOT EXISTS
        (SELECT 1 FROM dbo.ExportReplacementActivation a WHERE a.ReplacementID=p.ReplacementID))))
   OR EXISTS(SELECT 1 FROM dbo.ExportPreparationResource m WHERE m.ResourceKey=@ResourceKey AND NOT EXISTS
    (SELECT 1 FROM dbo.ExportReplacementVerification v JOIN dbo.ExportReplacementPlan p ON p.ReplacementID=v.ReplacementID
     WHERE v.PreparationID=m.PreparationID AND p.ContainmentID=@ContainmentID AND p.AccountKey=@AccountKey
      AND v.State IN (''verified'',''discarded'') AND NOT EXISTS
       (SELECT 1 FROM dbo.ExportReplacementActivation a WHERE a.ReplacementID=p.ReplacementID)))
   OR EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE ResourceKey=@ResourceKey)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperationResource WHERE ResourceKey=@ResourceKey)
   OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE TargetID=SUBSTRING(@ResourceKey,13,128) AND RequestKind<>''read'')
   OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=SUBSTRING(@ResourceKey,13,128))
   OR EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin WHERE FileID=SUBSTRING(@ResourceKey,13,128))
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=SUBSTRING(@ResourceKey,13,128))
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=SUBSTRING(@ResourceKey,13,128))
   THROW 51727,''A proposed replacement has existing execution or registration history.'',1;
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
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementPlanCreate',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xade53ff436cc65de424a04430610a1d6d48ce0647ed99f13a287841080fd9afa
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportReplacementVerificationTransition
 @VerificationID uniqueidentifier,@ReplacementID uniqueidentifier,@SessionID uniqueidentifier,
 @AccountKey varchar(128),@Action varchar(16),@PlanJson nvarchar(max)=NULL,
 @Actor nvarchar(128)=NULL,@Reason nvarchar(512)=NULL,
 @ReceiptHash binary(32)=NULL,@ReceiptReference uniqueidentifier=NULL,
 @ExpectedVersion bigint=0,@StreamID uniqueidentifier=NULL,@StreamVersion bigint=NULL,
 @LastSequence bigint=NULL,@EventDigest binary(32)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51728,''Exact outer replacement verification transaction required.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51728,''Evidence authority role required.'',1;
 IF @Action IS NULL OR @Action NOT IN (''begin'',''verify'',''discard'') OR DATALENGTH(@Action)<>LEN(@Action)
  OR @VerificationID IS NULL OR @ReplacementID IS NULL OR @SessionID IS NULL
  OR @AccountKey IS NULL OR LEN(@AccountKey)=0 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey)
  OR @AccountKey COLLATE Latin1_General_100_BIN2 LIKE ''%[^-A-Za-z0-9_.@:]%''
  THROW 51728,''Canonical replacement verification identity required.'',1;
 DECLARE @LockResult int,@LockKey nvarchar(255),@AccountResource varchar(256)=''account:''+@AccountKey;
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@AccountResource),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51728,''Replacement verification admission busy.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WITH(UPDLOCK,HOLDLOCK)
  WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
  THROW 51728,''Current authority session required.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementPlan p WITH(UPDLOCK,HOLDLOCK)
  JOIN dbo.ExportTargetContainment c ON c.ContainmentID=p.ContainmentID
  WHERE p.ReplacementID=@ReplacementID AND p.AccountKey=@AccountKey AND c.AccountKey=@AccountKey
   AND (EXISTS(SELECT 1 FROM dbo.ExportJob j WHERE j.JobID=c.JobID AND j.AccountKey=@AccountKey AND j.State=''uncertain'')
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation o WHERE o.OperationID=c.OutputOperationID AND o.AccountKey=@AccountKey AND o.State=''uncertain'' AND o.Phase=''uncertain'')))
  THROW 51728,''Exact isolated job and replacement proposal required.'',1;
 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 INSERT @Resources VALUES(@AccountResource);
 INSERT @Resources SELECT ''destination:''+NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID;
 DECLARE @Key varchar(256);
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks; FETCH NEXT FROM ResourceLocks INTO @Key;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@Key),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51728,''Replacement destination busy.'',1;
  FETCH NEXT FROM ResourceLocks INTO @Key;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;
 DECLARE @PreparationID uniqueidentifier=@VerificationID,@OwnerID uniqueidentifier=@VerificationID,@Fence bigint,
  @ClaimVersion bigint,@OriginalSession uniqueidentifier,@StoredPlan nvarchar(max),@StoredHash binary(32);
 IF @Action=''begin''
 BEGIN
  IF @ExpectedVersion<>0 OR @PlanJson IS NULL OR ISJSON(@PlanJson)<>1 OR DATALENGTH(@PlanJson)>2097152
   OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
   OR EXISTS(SELECT 1 FROM dbo.ExportReplacementVerification WHERE VerificationID=@VerificationID OR (ReplacementID=@ReplacementID AND State=''checking''))
   THROW 51728,''New bounded verification action required; inspect any retained attempt.'',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@PlanJson))<>13 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@PlanJson))<>13
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN
    (''version'',''purpose'',''account'',''storage_owner'',''owner_email'',''editor_email'',''project_id'',''credential_profile_sha256'',''manifest_sha256'',''file_count'',''plan_id'',''replacement_id'',''files''))
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''file_count'',''files'') AND (type<>1 OR LEN(value)=0))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''version'' AND type=2 AND value IN (N''4'',N''5'') AND DATALENGTH(value)=2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''file_count'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 1 AND 1024 AND value=CONVERT(varchar(4),TRY_CONVERT(int,value)))
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''files'' AND type=4)
   OR JSON_VALUE(@PlanJson,''$.plan_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),@VerificationID)) COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.plan_id''))<>72
   OR JSON_VALUE(@PlanJson,''$.replacement_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),@ReplacementID)) COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.replacement_id''))<>72
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.purpose''))<>34
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.storage_owner'')) NOT BETWEEN 2 AND 256
   OR JSON_VALUE(@PlanJson,''$.storage_owner'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^-A-Za-z0-9_.@:]%''
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] IN (''manifest_sha256'',''credential_profile_sha256'')
    AND (DATALENGTH(value)<>128 OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''))
   THROW 51728,''Exact replacement read plan required.'',1;
  IF JSON_VALUE(@PlanJson,''$.version'') NOT IN (''4'',''5'') OR JSON_VALUE(@PlanJson,''$.purpose'')<>''output_enrollment''
   OR JSON_VALUE(@PlanJson,''$.account'') COLLATE Latin1_General_100_BIN2<>@AccountKey COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.account''))<>2*DATALENGTH(@AccountKey)
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id''))<>@VerificationID
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.replacement_id''))<>@ReplacementID
   OR TRY_CONVERT(int,JSON_VALUE(@PlanJson,''$.file_count'')) NOT BETWEEN 1 AND 1024
   OR JSON_QUERY(@PlanJson,''$.files'') IS NULL OR LEFT(LTRIM(JSON_QUERY(@PlanJson,''$.files'')),1)<>''[''
   OR (SELECT COUNT(*) FROM OPENJSON(@PlanJson,''$.files''))<>(SELECT COUNT(*) FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID)
   OR (SELECT COUNT(*) FROM OPENJSON(@PlanJson,''$.files''))<>TRY_CONVERT(int,JSON_VALUE(@PlanJson,''$.file_count''))
   OR EXISTS(SELECT NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID
    EXCEPT SELECT JSON_VALUE(value,''$.file_id'') FROM OPENJSON(@PlanJson,''$.files''))
   OR EXISTS(SELECT JSON_VALUE(value,''$.file_id'') FROM OPENJSON(@PlanJson,''$.files'')
    EXCEPT SELECT NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID)
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID
    AND LOWER(CONVERT(varchar(64),ManifestHash,2)) COLLATE Latin1_General_100_BIN2=JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2)
   THROW 51728,''Replacement read plan does not bind the complete proposal and session.'',1;
  IF JSON_VALUE(@PlanJson,''$.version'')=''5'' AND EXISTS(
   SELECT 1 FROM OPENJSON(@PlanJson,''$.files'') f WHERE f.type<>5
    OR (SELECT COUNT(*) FROM OPENJSON(f.value))<>4
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(f.value))<>4
    OR EXISTS(SELECT 1 FROM OPENJSON(f.value) WHERE [key] NOT IN (''file_id'',''audience'',''editors'',''kind''))
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(f.value) WHERE [key]=''kind'' AND type=1
     AND ((value COLLATE Latin1_General_100_BIN2=N''output'' AND DATALENGTH(value)=12)
      OR (value COLLATE Latin1_General_100_BIN2=N''configuration_output'' AND DATALENGTH(value)=40))))
   THROW 51728,''Exact configuration or output verification role required.'',1;
  IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
   OR EXISTS(SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN (''pending'',''preflight'',''sql_pending'',''writing'',''committed'',''uncertain''))
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation o WHERE o.AccountKey=@AccountKey AND o.State IN (''closing'',''ready'',''running'',''uncertain'')
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportTargetContainment c WHERE c.OutputOperationID=o.OperationID AND c.AccountKey=o.AccountKey))
   OR EXISTS(SELECT 1 FROM dbo.ExportJob j WHERE j.AccountKey=@AccountKey AND j.State IN (''ready'',''running'',''uncertain'')
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportJobResource m JOIN dbo.ExportContainedTarget t ON m.ResourceKey=''destination:''+t.FileID WHERE m.JobID=j.JobID))
   THROW 51728,''Healthy work retains admission priority.'',1;
  IF EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t WHERE t.ReplacementID=@ReplacementID AND
   (EXISTS(SELECT 1 FROM dbo.ExportContainedTarget WHERE FileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin WHERE FileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=t.NewFileID)
    OR EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE ResourceKey=''destination:''+t.NewFileID)
    OR EXISTS(SELECT 1 FROM dbo.ExportPreparationResource m WHERE m.ResourceKey=''destination:''+t.NewFileID AND NOT EXISTS
     (SELECT 1 FROM dbo.ExportReplacementVerification v
      JOIN dbo.ExportReplacementPlan prior ON prior.ReplacementID=v.ReplacementID
      JOIN dbo.ExportReplacementPlan current_plan ON current_plan.ReplacementID=@ReplacementID
      WHERE v.PreparationID=m.PreparationID AND prior.ContainmentID=current_plan.ContainmentID
       AND prior.AccountKey=current_plan.AccountKey AND v.State IN (''verified'',''discarded'')
       AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation a WHERE a.ReplacementID=prior.ReplacementID)))))
   THROW 51728,''Replacement file has unrelated or permanent history.'',1;
  IF EXISTS(SELECT 1 FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey
   WHERE r.OwnerID IS NOT NULL OR r.ActiveJobID IS NOT NULL OR r.ActivePreparationID IS NOT NULL OR r.ActiveOutputOperationID IS NOT NULL OR r.BlockedReason IS NOT NULL)
   THROW 51728,''Replacement resources are still owned or blocked.'',1;
  INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version)
   SELECT x.ResourceKey,CASE WHEN x.ResourceKey=@AccountResource THEN ''account'' ELSE ''destination'' END,0,1 FROM @Resources x
   WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=x.ResourceKey);
  SELECT @Fence=Fence+1 FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
  DECLARE @Ticket bigint=(SELECT ISNULL(MAX(Ticket),0)+1 FROM
   (SELECT EnqueueSequence Ticket FROM dbo.ExportJob WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey) q);
  INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,KVK_NO,RequestHash,EnqueueSequence,State,OwnerID,Fence,Version,StorageOwner,RequestJson,GenerationJson,Actor,Reason,CreatedUTC,UpdatedUTC)
   VALUES(@PreparationID,@AccountKey,''config'',NULL,HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson)),@Ticket,''preflight'',@OwnerID,@Fence,1,
    JSON_VALUE(@PlanJson,''$.storage_owner''),@PlanJson,
    N''{"session_id":"''+LOWER(CONVERT(nvarchar(36),@SessionID))+N''","phase":"verify","next_ordinal":''+JSON_VALUE(@PlanJson,''$.file_count'')+N''}'',
    @Actor,@Reason,SYSUTCDATETIME(),SYSUTCDATETIME());
  INSERT dbo.ExportPreparationResource SELECT @PreparationID,ResourceKey FROM @Resources;
  UPDATE r SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=Version+1
   FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey;
  INSERT dbo.ExportReplacementVerification VALUES(@VerificationID,@ReplacementID,@PreparationID,@SessionID,HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson)),''checking'',1,NULL,NULL,@Actor,@Reason,SYSUTCDATETIME(),SYSUTCDATETIME());
 END
 ELSE
 BEGIN
  IF @ExpectedVersion<>1 OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL OR @PlanJson IS NOT NULL
   THROW 51728,''Exact retained verification and private settlement receipt required.'',1;
  SELECT @OriginalSession=v.SessionID,@Fence=p.Fence,@ClaimVersion=p.Version,@StoredPlan=p.RequestJson,@StoredHash=p.RequestHash
   FROM dbo.ExportReplacementVerification v WITH(UPDLOCK,HOLDLOCK) JOIN dbo.ExportPreparation p WITH(UPDLOCK,HOLDLOCK) ON p.PreparationID=v.PreparationID
   WHERE v.VerificationID=@VerificationID AND v.ReplacementID=@ReplacementID AND v.State=''checking'' AND v.Version=@ExpectedVersion
    AND p.PreparationID=@PreparationID AND p.AccountKey=@AccountKey AND p.OwnerID=@OwnerID AND p.State=''preflight'' AND p.Version=1
    AND p.JobID IS NULL AND p.SpoolKey IS NULL AND p.ConsumerKind=''config'' AND p.KVK_NO IS NULL AND p.RequestHash=v.PlanHash;
  IF @StoredPlan IS NULL OR @StoredHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@StoredPlan))
   OR JSON_VALUE(@StoredPlan,''$.version'') NOT IN (''4'',''5'') OR JSON_VALUE(@StoredPlan,''$.purpose'')<>''output_enrollment''
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@OriginalSession AND AuthorityPrincipal=USER_NAME())
   OR EXISTS(SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID)
   OR EXISTS(SELECT 1 FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey WHERE
    r.ActivePreparationID IS NULL OR r.ActivePreparationID<>@PreparationID OR r.OwnerID IS NULL OR r.OwnerID<>@OwnerID OR r.Fence<>@Fence
    OR r.ActiveJobID IS NOT NULL OR r.ActiveOutputOperationID IS NOT NULL OR r.BlockedReason IS NOT NULL)
   THROW 51728,''Verification ownership or typed plan changed.'',1;
  DECLARE @Count int=(SELECT COUNT(*) FROM dbo.ExportExecutionStream WHERE PreparationID=@PreparationID);
  IF (@Count=0 AND (@Action<>''discard'' OR @StreamID IS NOT NULL)) OR @Count>1
   THROW 51728,''Complete exact verification stream membership required.'',1;
  IF @Count=1
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE
    StreamID=@StreamID AND PreparationID=@PreparationID AND SessionID=@OriginalSession AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND ClaimVersion=@ClaimVersion AND Version=@StreamVersion
    AND Purpose=''enrollment'' AND RegistrationHash=@StoredHash AND SnapshotHash=@StoredHash
    AND NestedToken IS NULL AND JobID IS NULL AND OutputOperationID IS NULL AND Epoch IS NULL
    AND LastSequence=@LastSequence AND State IN (''open'',''frozen'',''closed''))
    OR @EventDigest IS NULL OR @LastSequence IS NULL
    OR (SELECT COUNT_BIG(*) FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID)<>@LastSequence
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID AND
     (RequestKind<>''read'' OR Operation NOT IN (''drive.files.get'',''drive.permissions.list'',''sheets.get'',''sheets.values.batchGet'')
      OR Sequence<1 OR Sequence>@LastSequence OR NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID AND NewFileID=TargetID)))
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID AND
     (NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.EventSequence=1 AND e.State=''prepared'')
      OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State NOT IN (''prepared'',''dispatch_intent'',''succeeded'',''not_sent'',''unknown''))))
    THROW 51728,''Complete typed read-only verification ledger required.'',1;
   IF @Action=''verify''
   BEGIN
    IF @LastSequence<>(SELECT SUM(CASE WHEN JSON_VALUE(@StoredPlan,''$.version'')=''5''
      AND JSON_VALUE(value,''$.kind'')=''configuration_output'' THEN 19 ELSE 5 END)
      FROM OPENJSON(@StoredPlan,''$.files''))
     OR NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND State=''closed'' AND ActiveAccountKey IS NULL AND ClosureHash IS NOT NULL AND EventDigest=@EventDigest)
     OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID AND NOT EXISTS
      (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State=''succeeded''))
     THROW 51728,''Successful privately verified readback and closed child required.'',1;
   END
   ELSE
    -- Explicit discard is a dispatch fence, not an assertion that the child died.
    UPDATE dbo.ExportExecutionStream SET State=''read_contained'',ActiveAccountKey=NULL,Version=Version+1,
     ClosureHash=@ReceiptHash,ClosureReference=@ReceiptReference,EventDigest=@EventDigest,ClosedUTC=SYSUTCDATETIME()
     WHERE StreamID=@StreamID AND Version=@StreamVersion;
  END;
  UPDATE r SET ActivePreparationID=NULL,OwnerID=NULL,Version=Version+1 FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey;
  UPDATE dbo.ExportPreparation SET State=CASE WHEN @Action=''verify'' THEN ''completed'' ELSE ''unavailable'' END,Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PreparationID=@PreparationID AND Version=1;
  UPDATE dbo.ExportReplacementVerification SET State=CASE WHEN @Action=''verify'' THEN ''verified'' ELSE ''discarded'' END,
   Version=2,ReceiptHash=@ReceiptHash,ReceiptReference=@ReceiptReference,UpdatedUTC=SYSUTCDATETIME() WHERE VerificationID=@VerificationID AND Version=@ExpectedVersion;
 END;
 SELECT * FROM dbo.ExportReplacementVerification WHERE VerificationID=@VerificationID;
END;
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementVerificationTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x103b9dbac714945c0caa3125422100a0b113c4e53fe4a637d54b5ea01f721519
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportReplacementActivate
 @ActivationID uniqueidentifier,@ReplacementID uniqueidentifier,@VerificationID uniqueidentifier,
 @AccountKey varchar(128),@BaseRegistrationHash binary(32),@RegistrationHash binary(32),
 @RegistrationJson nvarchar(max),@ReceiptHash binary(32),@ReceiptReference uniqueidentifier,
 @Actor nvarchar(128),@Reason nvarchar(512),@OldPoolID uniqueidentifier=NULL,@OldPoolVersion bigint=NULL,
 @PoolRegistrationJson nvarchar(max)=NULL,@PoolRegistrationHash binary(32)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51729,''Exact outer activation transaction required.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51729,''Evidence authority role required.'',1;
 IF @ActivationID IS NULL OR @ReplacementID IS NULL OR @VerificationID IS NULL OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL
  OR @BaseRegistrationHash IS NULL OR @RegistrationHash IS NULL OR @BaseRegistrationHash=@RegistrationHash
  OR @RegistrationJson IS NULL OR ISJSON(@RegistrationJson)<>1 OR DATALENGTH(@RegistrationJson)>65536
  OR @AccountKey IS NULL OR LEN(@AccountKey)=0 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey)
  OR @AccountKey COLLATE Latin1_General_100_BIN2 LIKE ''%[^-A-Za-z0-9_.@:]%''
  OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
  THROW 51729,''Complete bounded activation receipt and registration required.'',1;
 DECLARE @AccountResource varchar(256)=''account:''+@AccountKey,@LockKey nvarchar(255),@LockResult int;
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@AccountResource),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51729,''Activation admission busy.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation WITH(UPDLOCK,HOLDLOCK) WHERE
  ActivationID=@ActivationID OR ReplacementID=@ReplacementID OR VerificationID=@VerificationID OR (AccountKey=@AccountKey AND BaseRegistrationHash=@BaseRegistrationHash))
  THROW 51729,''Activation already has a durable receipt; inspect it before another action.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation WHERE AccountKey=@AccountKey)
  AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation a WHERE a.AccountKey=@AccountKey AND a.RegistrationHash=@BaseRegistrationHash
   AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation n WHERE n.AccountKey=a.AccountKey AND n.BaseRegistrationHash=a.RegistrationHash))
  THROW 51729,''Effective registration changed after replacement review.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementPlan p JOIN dbo.ExportTargetContainment c ON c.ContainmentID=p.ContainmentID
  JOIN dbo.ExportReplacementVerification v ON v.ReplacementID=p.ReplacementID
  JOIN dbo.ExportPreparation prep ON prep.PreparationID=v.PreparationID
  WHERE p.ReplacementID=@ReplacementID AND p.AccountKey=@AccountKey AND p.BaseRegistrationHash=@BaseRegistrationHash
   AND c.AccountKey=@AccountKey
   AND (EXISTS(SELECT 1 FROM dbo.ExportJob j WHERE j.JobID=c.JobID AND j.AccountKey=@AccountKey AND j.State=''uncertain'')
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation o WHERE o.OperationID=c.OutputOperationID AND o.AccountKey=@AccountKey AND o.State=''uncertain'' AND o.Phase=''uncertain'' AND o.PoolID=@OldPoolID))
   AND v.VerificationID=@VerificationID AND v.State=''verified'' AND v.Version=2
   AND v.ReceiptHash IS NOT NULL AND v.ReceiptReference IS NOT NULL AND prep.State=''completed'' AND prep.RequestHash=v.PlanHash)
  THROW 51729,''Verified replacement observation and original isolated job required.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  OR EXISTS(SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN (''preflight'',''sql_pending'',''writing'',''committed'',''uncertain''))
  OR EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ResourceKey=@AccountResource AND (OwnerID IS NOT NULL OR ActiveJobID IS NOT NULL OR ActivePreparationID IS NOT NULL OR ActiveOutputOperationID IS NOT NULL OR BlockedReason IS NOT NULL))
  THROW 51729,''Active account work must finish before changing registration.'',1;
 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 INSERT @Resources SELECT ''destination:''+NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID;
 INSERT @Resources SELECT ''destination:''+OldFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID;
 DECLARE @Key varchar(256);
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks; FETCH NEXT FROM ResourceLocks INTO @Key;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@Key),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51729,''Replacement target busy.'',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key AND OwnerID IS NULL
   AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND BlockedReason IS NULL)
   THROW 51729,''Exact unowned replacement and contained targets required.'',1;
  FETCH NEXT FROM ResourceLocks INTO @Key;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;
 IF EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t WHERE t.ReplacementID=@ReplacementID AND
  (EXISTS(SELECT 1 FROM dbo.ExportContainedTarget WHERE FileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE ResourceKey=''destination:''+t.NewFileID)
   OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin WHERE FileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=t.NewFileID)
   OR EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation a JOIN dbo.ExportReplacementTarget other ON other.ReplacementID=a.ReplacementID WHERE other.NewFileID=t.NewFileID)))
  THROW 51729,''Replacement destination was used or isolated after verification.'',1;
 DECLARE @NewPoolID uniqueidentifier=NULL;
 IF @OldPoolID IS NULL
 BEGIN
  IF @OldPoolVersion IS NOT NULL OR @PoolRegistrationJson IS NOT NULL OR @PoolRegistrationHash IS NOT NULL
   OR EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t JOIN KVK.SourceOutputPool p ON p.IndexFileID=t.OldFileID WHERE t.ReplacementID=@ReplacementID)
   OR EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t JOIN KVK.SourceOutputSlot s ON s.FileID=t.OldFileID WHERE t.ReplacementID=@ReplacementID)
   THROW 51729,''Pool replacement requires the exact complete old pool.'',1;
 END
 ELSE
 BEGIN
  SET @NewPoolID=@ReplacementID;
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@OldPoolID)))),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51729,''Old pool busy.'',1;
  IF @OldPoolVersion IS NULL OR @PoolRegistrationJson IS NULL OR ISJSON(@PoolRegistrationJson)<>1 OR DATALENGTH(@PoolRegistrationJson)>65536 OR @PoolRegistrationHash IS NULL
   OR NOT EXISTS(SELECT 1 FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK) WHERE PoolID=@OldPoolID AND AccountKey=@AccountKey
    AND Version=@OldPoolVersion AND PoolState=''blocked'' AND OwnerID IS NULL AND RetiredByReplacementID IS NULL
    AND BlockedReason=N''Targets permanently isolated; verified replacements required'')
   THROW 51729,''Exact contained pool version required.'',1;
  IF (SELECT COUNT(*) FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID)<>(SELECT COUNT(*)+1 FROM KVK.SourceOutputSlot WHERE PoolID=@OldPoolID)
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t JOIN KVK.SourceOutputPool p ON p.IndexFileID=t.OldFileID WHERE t.ReplacementID=@ReplacementID AND p.PoolID=@OldPoolID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot s WHERE s.PoolID=@OldPoolID AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t WHERE t.ReplacementID=@ReplacementID AND t.OldFileID=s.FileID))
   THROW 51729,''Complete index and ordered slots required.'',1;
  IF (SELECT COUNT(*) FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK) WHERE RetiredByReplacementID IS NULL)>8
   THROW 51729,''Active registration capacity differs.'',1;
  INSERT KVK.SourceOutputFile(FileID,FileKind,ResourceKey,RegisteredBy,RegisteredUTC,EvidenceHash,EvidenceJson)
   SELECT t.NewFileID,CASE WHEN t.OldFileID=p.IndexFileID THEN ''index'' ELSE ''slot'' END,''destination:''+t.NewFileID,@Actor,SYSUTCDATETIME(),@PoolRegistrationHash,@PoolRegistrationJson
   FROM dbo.ExportReplacementTarget t CROSS JOIN KVK.SourceOutputPool p WHERE t.ReplacementID=@ReplacementID AND p.PoolID=@OldPoolID;
  UPDATE KVK.SourceOutputPool SET RetiredByReplacementID=@ReplacementID,Version=Version+1,UpdatedUTC=SYSUTCDATETIME() WHERE PoolID=@OldPoolID AND Version=@OldPoolVersion;
  INSERT KVK.SourceOutputPool(PoolID,IndexFileID,IndexFileKind,RegistrationNo,AccountKey,AccountResourceKey,ExpectedOwner,AudienceJson,SourceKey,ActiveKVK,ChoiceID,Epoch,PoolState,OwnerID,Fence,Version,BlockedReason,CreatedUTC,UpdatedUTC,RegistrationHash,RegistrationJson)
   SELECT @NewPoolID,t.NewFileID,''index'',p.RegistrationNo,p.AccountKey,p.AccountResourceKey,p.ExpectedOwner,p.AudienceJson,p.SourceKey,p.ActiveKVK,p.ChoiceID,1,''active'',NULL,0,1,NULL,SYSUTCDATETIME(),SYSUTCDATETIME(),@PoolRegistrationHash,@PoolRegistrationJson
   FROM KVK.SourceOutputPool p JOIN dbo.ExportReplacementTarget t ON t.OldFileID=p.IndexFileID AND t.ReplacementID=@ReplacementID WHERE p.PoolID=@OldPoolID;
  INSERT KVK.SourceOutputSlot(FileID,FileKind,PoolID,SlotNo,Epoch,State,OwnerID,Fence,Version,CreatedUTC,UpdatedUTC)
   SELECT t.NewFileID,''slot'',@NewPoolID,s.SlotNo,1,''free'',NULL,0,1,SYSUTCDATETIME(),SYSUTCDATETIME()
   FROM KVK.SourceOutputSlot s JOIN dbo.ExportReplacementTarget t ON t.OldFileID=s.FileID AND t.ReplacementID=@ReplacementID WHERE s.PoolID=@OldPoolID;
 END;
 INSERT dbo.ExportReplacementActivation VALUES(@ActivationID,@ReplacementID,@VerificationID,@AccountKey,@BaseRegistrationHash,@RegistrationHash,@RegistrationJson,
  @ReceiptHash,@ReceiptReference,@OldPoolID,@NewPoolID,@Actor,@Reason,SYSUTCDATETIME());
 SELECT * FROM dbo.ExportReplacementActivation WHERE ActivationID=@ActivationID;
END;
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementActivate',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x44f66f4c188fdb53f205998f99ac348febe801e49eeb7d8e36673b161e451cbe
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportManualOutputEnrollmentTransition
 @SessionID uniqueidentifier,
 @PreparationID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @AccountKey varchar(128),
 @OwnerID uniqueidentifier,
 @Fence bigint=NULL,
 @ResourcesJson nvarchar(max)=NULL,
 @PlanJson nvarchar(max)=NULL,
 @Actor nvarchar(128)=NULL,
 @Reason nvarchar(1024)=NULL,
 @VerificationStreamID uniqueidentifier=NULL,
 @EligibilityHash binary(32)=NULL,
 @EligibilityReference uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Enrollment requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51700,''Evidence authority role required.'',1;
 IF @AccountKey IS NULL OR DATALENGTH(@AccountKey) NOT BETWEEN 1 AND 128
 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey) OR @AccountKey LIKE ''%[^-A-Za-z0-9_.@:]%'' COLLATE Latin1_General_100_BIN2
 OR @OwnerID IS NULL OR @PreparationID IS NULL OR @ExpectedVersion IS NULL
 OR @Action IS NULL OR DATALENGTH(@Action)<>LEN(@Action) OR @Action NOT IN (''begin'',''complete'')
  THROW 51700,''Canonical enrollment identity required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255),@AccountResource varchar(256)=''account:''+@AccountKey;
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@AccountResource),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK) WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
  THROW 51700,''Exact open authority session required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  THROW 51700,''Enrollment requires closed owned children.'',1;

 DECLARE @Files TABLE(Ordinal int PRIMARY KEY,FileID varchar(128) COLLATE Latin1_General_100_BIN2 UNIQUE NOT NULL);
 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 DECLARE @ReplacementID uniqueidentifier=NULL,@ReplacementPoolID uniqueidentifier=NULL;
 IF @Action=''begin''
 BEGIN
  IF @ExpectedVersion<>0 OR @Fence IS NOT NULL OR @ResourcesJson IS NOT NULL
   OR @PlanJson IS NULL OR ISJSON(@PlanJson)<>1 OR DATALENGTH(@PlanJson)>65536
   OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
   THROW 51700,''Fresh protected enrollment plan required.'',1;
  DECLARE @PlanVersion int=TRY_CONVERT(int,JSON_VALUE(@PlanJson,''$.version''));
  DECLARE @PlanKeys int=CASE @PlanVersion WHEN 2 THEN 13 WHEN 3 THEN 14 ELSE -1 END;
  IF (SELECT COUNT(*) FROM OPENJSON(@PlanJson))<>@PlanKeys OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@PlanJson))<>@PlanKeys
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''purpose'',''account'',''storage_owner'',''owner_email'',''editor_email'',''project_id'',''credential_profile_sha256'',''manifest_sha256'',''file_count'',''plan_id'',''files'',''protected_file_ids'',''access_policy''))
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''version'' AND type=2 AND value IN (''2'',''3'') AND DATALENGTH(value)=2)
   OR (@PlanVersion=2 AND EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''access_policy''))
   OR (@PlanVersion=3 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''access_policy'' AND type=1
      AND value COLLATE Latin1_General_100_BIN2=N''public_viewer_link_v1'' AND DATALENGTH(value)=42))
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''file_count'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 3 AND 17 AND value=CONVERT(varchar(2),TRY_CONVERT(int,value)))
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''file_count'',''files'',''protected_file_ids'') AND (type<>1 OR LEN(value)=0))
   OR JSON_VALUE(@PlanJson,''$.purpose'') COLLATE Latin1_General_100_BIN2<>''output_enrollment''
   OR JSON_VALUE(@PlanJson,''$.account'') COLLATE Latin1_General_100_BIN2<>@AccountKey COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.account''))<>2*DATALENGTH(@AccountKey)
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.purpose''))<>34
   OR JSON_VALUE(@PlanJson,''$.storage_owner'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^-A-Za-z0-9_.@:]%''
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.storage_owner'')) NOT BETWEEN 2 AND 256
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id'')) IS NULL
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.plan_id''))<>72
   OR JSON_VALUE(@PlanJson,''$.plan_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id'')))) COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.credential_profile_sha256''))<>128
   OR JSON_VALUE(@PlanJson,''$.credential_profile_sha256'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.manifest_sha256''))<>128
   OR JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
   OR NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID AND LOWER(CONVERT(varchar(64),ManifestHash,2)) COLLATE Latin1_General_100_BIN2=JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2)
   THROW 51700,''Exact typed enrollment plan differs.'',1;
  IF LEFT(LTRIM(JSON_QUERY(@PlanJson,''$.files'')),1)<>''['' OR JSON_QUERY(@PlanJson,''$.files'') IS NULL
   OR LEFT(LTRIM(JSON_QUERY(@PlanJson,''$.protected_file_ids'')),1)<>''['' OR JSON_QUERY(@PlanJson,''$.protected_file_ids'') IS NULL
   OR (SELECT COUNT(*) FROM OPENJSON(@PlanJson,''$.files''))<>TRY_CONVERT(int,JSON_VALUE(@PlanJson,''$.file_count''))
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson,''$.files'') j WHERE j.type<>5
    OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>5 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>5
    OR EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key] NOT IN (''file_id'',''sheet_id'',''title'',''rows'',''columns''))
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''file_id'' AND type=1 AND DATALENGTH(value) BETWEEN 6 AND 256
      AND DATALENGTH(value)=2*LEN(value) AND value COLLATE Latin1_General_100_BIN2 NOT LIKE ''%[^-A-Za-z0-9_]%'')
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''sheet_id'' AND type=2 AND TRY_CONVERT(int,value)>=0)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''title'' AND type=1 AND LEN(value) BETWEEN 1 AND 100)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''rows'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 1 AND 10000)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''columns'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 1 AND 10000)
    OR TRY_CONVERT(bigint,JSON_VALUE(j.value,''$.rows''))*TRY_CONVERT(bigint,JSON_VALUE(j.value,''$.columns''))>50000)
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson,''$.protected_file_ids'') WHERE type<>1 OR DATALENGTH(value) NOT BETWEEN 6 AND 256
      OR DATALENGTH(value)<>2*LEN(value) OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^-A-Za-z0-9_]%'')
   THROW 51700,''Exact bounded manual file manifest/exclusions required.'',1;
  INSERT @Files SELECT CONVERT(int,j.[key]),JSON_VALUE(j.value,''$.file_id'') FROM OPENJSON(@PlanJson,''$.files'') j;
  IF EXISTS(SELECT 1 FROM @Files f JOIN OPENJSON(@PlanJson,''$.protected_file_ids'') x ON x.value COLLATE Latin1_General_100_BIN2=f.FileID)
   THROW 51700,''Protected manual destination.'',1;
  -- A sealed replacement proposal may verify fresh files for one already
  -- isolated pool. It never adopts the old files or releases any owner.
  SELECT @ReplacementID=p.ReplacementID FROM dbo.ExportReplacementPlan p
   JOIN dbo.ExportTargetContainment c ON c.ContainmentID=p.ContainmentID
   WHERE p.ReplacementID=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id''))
    AND p.AccountKey=@AccountKey AND c.AccountKey=@AccountKey AND c.JobID IS NOT NULL;
  IF @ReplacementID IS NOT NULL
  BEGIN
   SELECT @ReplacementPoolID=p.PoolID FROM KVK.SourceOutputPool p
    JOIN dbo.ExportReplacementTarget t ON t.OldFileID=p.IndexFileID AND t.ReplacementID=@ReplacementID
    WHERE p.AccountKey=@AccountKey AND p.PoolState=''blocked'' AND p.OwnerID IS NULL
     AND p.BlockedReason=N''Targets permanently isolated; verified replacements required''
     AND p.ExpectedOwner=JSON_VALUE(@PlanJson,''$.owner_email'') COLLATE Latin1_General_100_BIN2
     AND DATALENGTH(p.ExpectedOwner)=DATALENGTH(JSON_VALUE(@PlanJson,''$.owner_email''))
     AND ISNULL(JSON_VALUE(p.RegistrationJson,''$.audience''),''private'')=
      CASE WHEN @PlanVersion=3 THEN ''public_viewer'' ELSE ''private'' END;
   IF @ReplacementPoolID IS NULL
    OR EXISTS(SELECT NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID EXCEPT SELECT FileID FROM @Files)
    OR EXISTS(SELECT FileID FROM @Files EXCEPT SELECT NewFileID FROM dbo.ExportReplacementTarget WHERE ReplacementID=@ReplacementID)
    OR NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementTarget t JOIN KVK.SourceOutputPool p ON p.IndexFileID=t.OldFileID
     JOIN @Files f ON f.FileID=t.NewFileID AND f.Ordinal=0 WHERE t.ReplacementID=@ReplacementID AND p.PoolID=@ReplacementPoolID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot s WHERE s.PoolID=@ReplacementPoolID AND NOT EXISTS
     (SELECT 1 FROM dbo.ExportReplacementTarget t JOIN @Files f ON f.FileID=t.NewFileID AND f.Ordinal=s.SlotNo
      WHERE t.ReplacementID=@ReplacementID AND t.OldFileID=s.FileID))
    OR (SELECT COUNT(*) FROM KVK.SourceOutputSlot WHERE PoolID=@ReplacementPoolID)+1<>(SELECT COUNT(*) FROM @Files)
    THROW 51727,''Exact isolated pool, slot order, owner and audience required for replacement verification.'',1;
  END;
  -- Preserve healthy queue priority. Only this explicit replacement path may
  -- ignore jobs whose permanently isolated targets prohibit further admission.
  IF EXISTS (SELECT 1 FROM dbo.ExportJob j WHERE AccountKey=@AccountKey AND State IN (''ready'',''running'',''uncertain'')
   AND (@ReplacementID IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.ExportJobResource m
    JOIN dbo.ExportContainedTarget t ON m.ResourceKey=''destination:''+t.FileID WHERE m.JobID=j.JobID)))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN (''pending'',''preflight'',''sql_pending'',''writing'',''committed'',''uncertain''))
   OR EXISTS (SELECT 1 FROM KVK.SourceOutputOperation o WHERE o.AccountKey=@AccountKey AND o.State IN (''closing'',''ready'',''running'',''uncertain'')
    AND NOT EXISTS (SELECT 1 FROM dbo.ExportTargetContainment c WHERE c.OutputOperationID=o.OperationID AND c.AccountKey=o.AccountKey))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE PreparationID=@PreparationID OR (AccountKey=@AccountKey AND RequestHash=HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson))))
   THROW 51700,''Existing work or enrollment prevents fresh admission.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK) WHERE ResourceKey=@AccountResource)
   INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version) VALUES(@AccountResource,''account'',0,1);
  INSERT @Resources SELECT ResourceKey,Version FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
  INSERT @Resources SELECT ''destination:''+FileID,0 FROM @Files;
 END
 ELSE
 BEGIN
  IF @PlanJson IS NOT NULL OR @ResourcesJson IS NULL OR ISJSON(@ResourcesJson)<>1 OR DATALENGTH(@ResourcesJson)>65536
   OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion<=0
   THROW 51700,''Exact enrollment CAS resources required.'',1;
  IF LEFT(LTRIM(@ResourcesJson),1)<>''['' OR (SELECT COUNT(*) FROM OPENJSON(@ResourcesJson)) NOT BETWEEN 1 AND 18
   OR EXISTS(SELECT 1 FROM OPENJSON(@ResourcesJson) j WHERE j.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>2
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''key'' AND type=1)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''version'' AND type=2))
   THROW 51700,''Exact resource-version list required.'',1;
  INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ResourcesJson) WITH(ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
  IF EXISTS(SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID)
   OR NOT EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey=@AccountResource)
   THROW 51700,''Enrollment resource membership changed.'',1;
 END;
 DECLARE @Key varchar(256),@ResourceVersion bigint;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @Key,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@Key),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51700,''Enrollment resource busy.'',1;
  IF @ResourceVersion=0
  BEGIN
   IF EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key)
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=SUBSTRING(@Key,13,128))
    OR EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin WHERE FileID=SUBSTRING(@Key,13,128))
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=SUBSTRING(@Key,13,128))
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=SUBSTRING(@Key,13,128))
    THROW 51700,''Returned identity has existing history; never adopt.'',1;
  END
  ELSE IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key AND Version=@ResourceVersion AND BlockedReason IS NULL
   AND ((@Action=''begin'' AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL)
    OR (@Action<>''begin'' AND ActivePreparationID=@PreparationID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID=@OwnerID AND Fence=@Fence)))
   THROW 51700,''Enrollment resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @Key,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;

 DECLARE @Plan nvarchar(max),@Progress nvarchar(max),@PlanHash binary(32),@Count int,@Next int;
 IF @Action=''begin''
 BEGIN
  -- Count registered pools and still-unregistered enrollment plans once each.
  -- Range locks prevent concurrent enrollment/registration from overbooking eight.
  IF @ReplacementID IS NULL AND (SELECT COUNT_BIG(*) FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK) WHERE RetiredByReplacementID IS NULL)+
   (SELECT COUNT_BIG(*) FROM dbo.ExportPreparation p WITH(UPDLOCK,HOLDLOCK)
    WHERE JSON_VALUE(p.RequestJson,''$.purpose'')=''output_enrollment''
     AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementVerification v WHERE v.PreparationID=p.PreparationID AND v.PlanHash=p.RequestHash)
     AND NOT EXISTS(SELECT 1 FROM (SELECT FileID,PreparationID,Stage,Ordinal FROM dbo.ExportManagedFileOrigin UNION ALL SELECT FileID,PreparationID,Stage,Ordinal FROM dbo.ExportManualFileOrigin) o JOIN KVK.SourceOutputPool pool ON pool.IndexFileID=o.FileID
      WHERE o.PreparationID=p.PreparationID AND o.Stage=''eligible'' AND o.Ordinal=0))>=8
   THROW 51700,''Eight-pool enrollment capacity is exhausted.'',1;
  SELECT @Fence=Fence+1 FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
  DECLARE @Ticket bigint=(SELECT ISNULL(MAX(Ticket),0)+1 FROM
   (SELECT EnqueueSequence Ticket FROM dbo.ExportJob WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey) q);
  SET @Progress=N''{"session_id":"''+LOWER(CONVERT(nvarchar(36),@SessionID))+N''","phase":"verify","next_ordinal":''+JSON_VALUE(@PlanJson,''$.file_count'')+N''}'';
  INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,KVK_NO,RequestHash,EnqueueSequence,State,OwnerID,Fence,Version,StorageOwner,RequestJson,GenerationJson,Actor,Reason,CreatedUTC,UpdatedUTC)
   VALUES(@PreparationID,@AccountKey,''config'',NULL,HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson)),@Ticket,''preflight'',@OwnerID,@Fence,1,JSON_VALUE(@PlanJson,''$.storage_owner''),@PlanJson,@Progress,@Actor,@Reason,SYSUTCDATETIME(),SYSUTCDATETIME());
  INSERT dbo.ExportPreparationResource VALUES(@PreparationID,@AccountResource);
  UPDATE dbo.ExportResource SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=Version+1 WHERE ResourceKey=@AccountResource;
  -- Both ownership FKs remain enabled: create, attach membership, then claim.
  INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version)
   SELECT ''destination:''+FileID,''destination'',0,1 FROM @Files;
  INSERT dbo.ExportPreparationResource(PreparationID,ResourceKey)
   SELECT @PreparationID,''destination:''+FileID FROM @Files;
  UPDATE r SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=2
   FROM dbo.ExportResource r JOIN @Files f ON r.ResourceKey=''destination:''+f.FileID;
  INSERT dbo.ExportManualFileOrigin(FileID,Stage,PreparationID,Ordinal,SessionID,PlanHash,ProfileHash,CreatedUTC)
   SELECT FileID,''registered'',@PreparationID,Ordinal,@SessionID,HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson)),
    CONVERT(binary(32),JSON_VALUE(@PlanJson,''$.credential_profile_sha256''),2),SYSUTCDATETIME() FROM @Files;

 END
 ELSE
 BEGIN
  SELECT @Plan=RequestJson,@PlanHash=RequestHash,@Progress=GenerationJson FROM dbo.ExportPreparation WITH(UPDLOCK,HOLDLOCK)
   WHERE PreparationID=@PreparationID AND AccountKey=@AccountKey AND ConsumerKind=''config'' AND State=''preflight''
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ExpectedVersion AND JobID IS NULL AND SpoolKey IS NULL
    AND JSON_VALUE(RequestJson,''$.purpose'')=''output_enrollment''
    AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(GenerationJson,''$.session_id''))=@SessionID;
  IF @Plan IS NULL OR @PlanHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@Plan))
   THROW 51700,''Enrollment preparation identity/CAS differs; no adoption.'',1;
  SET @Count=TRY_CONVERT(int,JSON_VALUE(@Plan,''$.file_count''));
  SET @Next=TRY_CONVERT(int,JSON_VALUE(@Progress,''$.next_ordinal''));
  IF JSON_VALUE(@Plan,''$.version'') IS NULL OR JSON_VALUE(@Plan,''$.version'') NOT IN (''2'',''3'') OR @Count IS NULL OR @Count NOT BETWEEN 3 AND 17 OR @Next IS NULL
   THROW 51700,''Enrollment plan/progress differs.'',1;
  BEGIN
   IF @Next<>@Count OR JSON_VALUE(@Progress,''$.phase'')<>''verify'' OR @EligibilityHash IS NULL OR @EligibilityReference IS NULL
    OR (SELECT COUNT(*) FROM dbo.ExportManualFileOrigin WHERE PreparationID=@PreparationID AND Stage=''registered'')<>@Count
    OR EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin WHERE PreparationID=@PreparationID AND Stage=''eligible'')
    THROW 51700,''Complete unsealed origin set required.'',1;
   DECLARE @VerificationClosure binary(32);
   SELECT @VerificationClosure=ClosureHash FROM dbo.ExportExecutionStream
    WHERE StreamID=@VerificationStreamID AND SessionID=@SessionID AND PreparationID=@PreparationID
     AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND ClaimVersion=@ExpectedVersion
     AND Purpose=''enrollment'' AND State=''closed'' AND ActiveAccountKey IS NULL AND EventDigest IS NOT NULL
     AND RegistrationHash=@PlanHash AND SnapshotHash=@PlanHash AND LastSequence=4*@Count AND JSON_VALUE(ScopeJson,''$.enrollment.phase'')=''verify'';
   IF EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@VerificationStreamID AND (RequestKind<>''read'' OR Operation NOT IN (''drive.files.get'',''drive.permissions.list'',''sheets.get'',''sheets.values.batchGet''))) THROW 51700,''Manual registration cannot mutate provider state.'',1;
   IF @VerificationClosure IS NULL OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s
     WHERE s.PreparationID=@PreparationID AND (s.State<>''closed'' OR s.ClosureHash IS NULL OR s.EventDigest IS NULL))
    OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
     WHERE s.PreparationID=@PreparationID AND NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State=''succeeded''))
    THROW 51700,''Enrollment history contains unclosed or uncertain requests.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportManualFileOrigin o CROSS JOIN
     (VALUES(''drive.files.get''),(''drive.permissions.list''),(''sheets.get''),(''sheets.values.batchGet'')) m(Operation)
     WHERE o.PreparationID=@PreparationID AND o.Stage=''registered'' AND NOT EXISTS
      (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@VerificationStreamID AND r.TargetID=o.FileID AND r.Operation=m.Operation))
    THROW 51700,''Every manual file requires complete read-only verification.'',1;
   -- Parent verifies protected response bytes, versioned access policy and all blank cells.
   -- SQL seals that receipt only after the complete request history has terminated.
   INSERT dbo.ExportManualFileOrigin
    SELECT FileID,''eligible'',''registered'',PreparationID,Ordinal,SessionID,PlanHash,ProfileHash,
      @VerificationStreamID,@VerificationClosure,@EligibilityHash,@EligibilityReference,SYSUTCDATETIME()
    FROM dbo.ExportManualFileOrigin WHERE PreparationID=@PreparationID AND Stage=''registered'';
   SET @Progress=JSON_MODIFY(@Progress,''$.phase'',''complete'');
   UPDATE r SET ActivePreparationID=NULL,OwnerID=NULL,Version=r.Version+1
    FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey;
  END;
  UPDATE dbo.ExportPreparation SET GenerationJson=@Progress,State=CASE WHEN @Action=''complete'' THEN ''completed'' ELSE ''preflight'' END,Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PreparationID=@PreparationID AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ExpectedVersion;
  IF @@ROWCOUNT<>1 THROW 51700,''Enrollment preparation CAS lost.'',1;
 END;
 SELECT p.*,(SELECT r.ResourceKey AS [key],r.Version AS [version] FROM dbo.ExportPreparationResource m
  JOIN dbo.ExportResource r ON r.ResourceKey=m.ResourceKey WHERE m.PreparationID=p.PreparationID ORDER BY r.ResourceKey FOR JSON PATH) AS ResourcesJson
 FROM dbo.ExportPreparation p WHERE p.PreparationID=@PreparationID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportManualOutputEnrollmentTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xa0fe4309f3214e80a7c543dee78231a4b08f88b22d87d611e4a188a74888f501
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportOutputEnrollmentTransition
 @SessionID uniqueidentifier,
 @PreparationID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @AccountKey varchar(128),
 @OwnerID uniqueidentifier,
 @Fence bigint=NULL,
 @ResourcesJson nvarchar(max)=NULL,
 @PlanJson nvarchar(max)=NULL,
 @Actor nvarchar(128)=NULL,
 @Reason nvarchar(1024)=NULL,
 @Ordinal int=NULL,
 @FileID varchar(128)=NULL,
 @CreationStreamID uniqueidentifier=NULL,
 @CreationRequestID uniqueidentifier=NULL,
 @ResponseEventID uniqueidentifier=NULL,
 @OriginHash binary(32)=NULL,
 @OriginReference uniqueidentifier=NULL,
 @VerificationStreamID uniqueidentifier=NULL,
 @EligibilityHash binary(32)=NULL,
 @EligibilityReference uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Enrollment requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51700,''Evidence authority role required.'',1;
 IF @AccountKey IS NULL OR DATALENGTH(@AccountKey) NOT BETWEEN 1 AND 128
 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey) OR @AccountKey LIKE ''%[^A-Za-z0-9_.@:-]%'' COLLATE Latin1_General_100_BIN2
 OR @OwnerID IS NULL OR @PreparationID IS NULL OR @ExpectedVersion IS NULL
 OR @Action IS NULL OR DATALENGTH(@Action)<>LEN(@Action) OR @Action NOT IN (''begin'',''bind'',''complete'')
  THROW 51700,''Canonical enrollment identity required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255),@AccountResource varchar(256)=''account:''+@AccountKey;
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@AccountResource),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK) WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
  THROW 51700,''Exact open authority session required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  THROW 51700,''Enrollment requires closed owned children.'',1;

 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF @Action=''begin''
 BEGIN
  IF @ExpectedVersion<>0 OR @Fence IS NOT NULL OR @ResourcesJson IS NOT NULL
   OR @PlanJson IS NULL OR ISJSON(@PlanJson)<>1 OR DATALENGTH(@PlanJson)>65536
   OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
   THROW 51700,''Fresh protected enrollment plan required.'',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@PlanJson))<>11 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@PlanJson))<>11
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''purpose'',''account'',''storage_owner'',''owner_email'',''editor_email'',''project_id'',''credential_profile_sha256'',''manifest_sha256'',''file_count'',''plan_id''))
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''version'' AND type=2 AND value=''1'')
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''file_count'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 3 AND 17 AND value=CONVERT(varchar(2),TRY_CONVERT(int,value)))
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''file_count'') AND (type<>1 OR LEN(value)=0))
   OR JSON_VALUE(@PlanJson,''$.purpose'') COLLATE Latin1_General_100_BIN2<>''output_enrollment''
   OR JSON_VALUE(@PlanJson,''$.account'') COLLATE Latin1_General_100_BIN2<>@AccountKey COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.account''))<>2*DATALENGTH(@AccountKey)
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.purpose''))<>34
   OR JSON_VALUE(@PlanJson,''$.storage_owner'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^-A-Za-z0-9_.@:]%''
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.storage_owner'')) NOT BETWEEN 2 AND 256
   OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id'')) IS NULL
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.plan_id''))<>72
   OR JSON_VALUE(@PlanJson,''$.plan_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,''$.plan_id'')))) COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.credential_profile_sha256''))<>128
   OR JSON_VALUE(@PlanJson,''$.credential_profile_sha256'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.manifest_sha256''))<>128
   OR JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
   OR NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID AND LOWER(CONVERT(varchar(64),ManifestHash,2)) COLLATE Latin1_General_100_BIN2=JSON_VALUE(@PlanJson,''$.manifest_sha256'') COLLATE Latin1_General_100_BIN2)
   THROW 51700,''Exact typed enrollment plan differs.'',1;
  -- New enrollment never overtakes existing ready work or bypasses uncertainty.
  IF EXISTS (SELECT 1 FROM dbo.ExportJob WHERE AccountKey=@AccountKey AND State IN (''ready'',''running'',''uncertain''))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN (''pending'',''preflight'',''sql_pending'',''writing'',''committed'',''uncertain''))
   OR EXISTS (SELECT 1 FROM KVK.SourceOutputOperation o WHERE o.AccountKey=@AccountKey AND o.State IN (''closing'',''ready'',''running'',''uncertain'')
    AND NOT EXISTS (SELECT 1 FROM dbo.ExportTargetContainment c WHERE c.OutputOperationID=o.OperationID AND c.AccountKey=o.AccountKey))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE PreparationID=@PreparationID OR (AccountKey=@AccountKey AND RequestHash=HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson))))
   THROW 51700,''Existing work or enrollment prevents fresh admission.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK) WHERE ResourceKey=@AccountResource)
   INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version) VALUES(@AccountResource,''account'',0,1);
  INSERT @Resources SELECT ResourceKey,Version FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
 END
 ELSE
 BEGIN
  IF @PlanJson IS NOT NULL OR @ResourcesJson IS NULL OR ISJSON(@ResourcesJson)<>1 OR DATALENGTH(@ResourcesJson)>65536
   OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion<=0
   THROW 51700,''Exact enrollment CAS resources required.'',1;
  IF LEFT(LTRIM(@ResourcesJson),1)<>''['' OR (SELECT COUNT(*) FROM OPENJSON(@ResourcesJson)) NOT BETWEEN 1 AND 18
   OR EXISTS(SELECT 1 FROM OPENJSON(@ResourcesJson) j WHERE j.type<>5 OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>2
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''key'' AND type=1)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''version'' AND type=2))
   THROW 51700,''Exact resource-version list required.'',1;
  INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ResourcesJson) WITH(ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
  IF EXISTS(SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@PreparationID)
   OR NOT EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey=@AccountResource)
   THROW 51700,''Enrollment resource membership changed.'',1;
 END;
 -- A newly returned identity must have no resource/origin/registration history.
 IF @Action=''bind''
 BEGIN
  IF @FileID IS NULL OR DATALENGTH(@FileID) NOT BETWEEN 3 AND 128 OR DATALENGTH(@FileID)<>LEN(@FileID)
   OR @FileID LIKE ''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2
   OR @Ordinal IS NULL OR @Ordinal NOT BETWEEN 0 AND 16 OR @OriginHash IS NULL OR @OriginReference IS NULL
   THROW 51700,''Exact newly returned file and origin receipt required.'',1;
  INSERT @Resources VALUES(''destination:''+@FileID,0);
 END;
 DECLARE @Key varchar(256),@ResourceVersion bigint;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @Key,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@Key),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51700,''Enrollment resource busy.'',1;
  IF @ResourceVersion=0
  BEGIN
   IF EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key)
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE FileID=@FileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputPool WHERE IndexFileID=@FileID)
    OR EXISTS(SELECT 1 FROM KVK.SourceOutputSlot WHERE FileID=@FileID)
    THROW 51700,''Returned identity has existing history; never adopt.'',1;
  END
  ELSE IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@Key AND Version=@ResourceVersion AND BlockedReason IS NULL
   AND ((@Action=''begin'' AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID IS NULL)
    OR (@Action<>''begin'' AND ActivePreparationID=@PreparationID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL AND OwnerID=@OwnerID AND Fence=@Fence)))
   THROW 51700,''Enrollment resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @Key,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;

 DECLARE @Plan nvarchar(max),@Progress nvarchar(max),@PlanHash binary(32),@Count int,@Next int;
 IF @Action=''begin''
 BEGIN
  -- Count registered pools and still-unregistered enrollment plans once each.
  -- Range locks prevent concurrent enrollment/registration from overbooking eight.
  IF (SELECT COUNT_BIG(*) FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK) WHERE RetiredByReplacementID IS NULL)+
   (SELECT COUNT_BIG(*) FROM dbo.ExportPreparation p WITH(UPDLOCK,HOLDLOCK)
    WHERE JSON_VALUE(p.RequestJson,''$.purpose'')=''output_enrollment''
     AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementVerification v WHERE v.PreparationID=p.PreparationID AND v.PlanHash=p.RequestHash)
     AND NOT EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o JOIN KVK.SourceOutputPool pool ON pool.IndexFileID=o.FileID
      WHERE o.PreparationID=p.PreparationID AND o.Stage=''eligible'' AND o.Ordinal=0))>=8
   THROW 51700,''Eight-pool enrollment capacity is exhausted.'',1;
  SELECT @Fence=Fence+1 FROM dbo.ExportResource WHERE ResourceKey=@AccountResource;
  DECLARE @Ticket bigint=(SELECT ISNULL(MAX(Ticket),0)+1 FROM
   (SELECT EnqueueSequence Ticket FROM dbo.ExportJob WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey UNION ALL
    SELECT EnqueueSequence FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey) q);
  SET @Progress=N''{"session_id":"''+LOWER(CONVERT(nvarchar(36),@SessionID))+N''","phase":"create","next_ordinal":0}'';
  INSERT dbo.ExportPreparation(PreparationID,AccountKey,ConsumerKind,KVK_NO,RequestHash,EnqueueSequence,State,OwnerID,Fence,Version,StorageOwner,RequestJson,GenerationJson,Actor,Reason,CreatedUTC,UpdatedUTC)
   VALUES(@PreparationID,@AccountKey,''config'',NULL,HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@PlanJson)),@Ticket,''preflight'',@OwnerID,@Fence,1,JSON_VALUE(@PlanJson,''$.storage_owner''),@PlanJson,@Progress,@Actor,@Reason,SYSUTCDATETIME(),SYSUTCDATETIME());
  INSERT dbo.ExportPreparationResource VALUES(@PreparationID,@AccountResource);
  UPDATE dbo.ExportResource SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=Version+1 WHERE ResourceKey=@AccountResource;
 END
 ELSE
 BEGIN
  SELECT @Plan=RequestJson,@PlanHash=RequestHash,@Progress=GenerationJson FROM dbo.ExportPreparation WITH(UPDLOCK,HOLDLOCK)
   WHERE PreparationID=@PreparationID AND AccountKey=@AccountKey AND ConsumerKind=''config'' AND State=''preflight''
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ExpectedVersion AND JobID IS NULL AND SpoolKey IS NULL
    AND JSON_VALUE(RequestJson,''$.purpose'')=''output_enrollment''
    AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(GenerationJson,''$.session_id''))=@SessionID;
  IF @Plan IS NULL OR @PlanHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@Plan))
   THROW 51700,''Enrollment preparation identity/CAS differs; no adoption.'',1;
  SET @Count=TRY_CONVERT(int,JSON_VALUE(@Plan,''$.file_count''));
  SET @Next=TRY_CONVERT(int,JSON_VALUE(@Progress,''$.next_ordinal''));
  IF @Count IS NULL OR @Count NOT BETWEEN 3 AND 17 OR @Next IS NULL
   THROW 51700,''Enrollment plan/progress differs.'',1;
  IF @Action=''bind''
  BEGIN
   IF @Next<>@Ordinal OR @Next>=@Count OR JSON_VALUE(@Progress,''$.phase'')<>''create''
    OR (SELECT COUNT(*) FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'')<>@Ordinal
    THROW 51700,''Creation ordinal is not the next fresh identity.'',1;
   DECLARE @ResponseHash binary(32),@ClosureHash binary(32);
   SELECT @ResponseHash=e.EvidenceHash,@ClosureHash=s.ClosureHash
    FROM dbo.ExportExecutionStream s JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
    JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
    WHERE s.StreamID=@CreationStreamID AND s.SessionID=@SessionID AND s.PreparationID=@PreparationID
     AND s.AccountKey=@AccountKey AND s.OwnerID=@OwnerID AND s.Fence=@Fence AND s.ClaimVersion=@ExpectedVersion
     AND s.Purpose=''enrollment'' AND s.State=''closed'' AND s.ActiveAccountKey IS NULL AND s.LastSequence=1
     AND s.RegistrationHash=@PlanHash AND s.SnapshotHash=@PlanHash AND s.EventDigest IS NOT NULL
     AND JSON_VALUE(s.ScopeJson,''$.enrollment.phase'')=''create''
     AND TRY_CONVERT(int,JSON_VALUE(s.ScopeJson,''$.enrollment.ordinal''))=@Ordinal
     AND r.RequestID=@CreationRequestID AND r.Sequence=1 AND r.Operation=''sheets.create'' AND r.RequestKind=''mutation''
     AND r.TargetID=LOWER(CONVERT(varchar(36),@PreparationID))
     AND e.EventID=@ResponseEventID AND e.State=''succeeded'' AND e.EventSequence=3;
   IF @ResponseHash IS NULL OR @ClosureHash IS NULL THROW 51700,''Exact successful closed creation required.'',1;
   INSERT dbo.ExportManagedFileOrigin(FileID,Stage,PreparationID,Ordinal,SessionID,CreationStreamID,CreationRequestID,ResponseEventID,PlanHash,ProfileHash,ResponseHash,CreationClosureHash,OriginHash,OriginReference,CreatedUTC)
    VALUES(@FileID,''created'',@PreparationID,@Ordinal,@SessionID,@CreationStreamID,@CreationRequestID,@ResponseEventID,@PlanHash,CONVERT(binary(32),JSON_VALUE(@Plan,''$.credential_profile_sha256''),2),@ResponseHash,@ClosureHash,@OriginHash,@OriginReference,SYSUTCDATETIME());
   INSERT dbo.ExportResource(ResourceKey,ResourceKind,Fence,Version) VALUES(''destination:''+@FileID,''destination'',0,1);
   INSERT dbo.ExportPreparationResource VALUES(@PreparationID,''destination:''+@FileID);
   UPDATE dbo.ExportResource SET ActivePreparationID=@PreparationID,OwnerID=@OwnerID,Fence=@Fence,Version=2 WHERE ResourceKey=''destination:''+@FileID;
   SET @Progress=JSON_MODIFY(JSON_MODIFY(@Progress,''$.next_ordinal'',@Next+1),''$.phase'',CASE WHEN @Next+1=@Count THEN ''verify'' ELSE ''create'' END);
  END
  ELSE
  BEGIN
   IF @Next<>@Count OR JSON_VALUE(@Progress,''$.phase'')<>''verify'' OR @EligibilityHash IS NULL OR @EligibilityReference IS NULL
    OR (SELECT COUNT(*) FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'')<>@Count
    OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''eligible'')
    THROW 51700,''Complete unsealed origin set required.'',1;
   DECLARE @VerificationClosure binary(32);
   SELECT @VerificationClosure=ClosureHash FROM dbo.ExportExecutionStream
    WHERE StreamID=@VerificationStreamID AND SessionID=@SessionID AND PreparationID=@PreparationID
     AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND ClaimVersion=@ExpectedVersion
     AND Purpose=''enrollment'' AND State=''closed'' AND ActiveAccountKey IS NULL AND EventDigest IS NOT NULL
     AND RegistrationHash=@PlanHash AND SnapshotHash=@PlanHash AND JSON_VALUE(ScopeJson,''$.enrollment.phase'')=''verify'';
   IF @VerificationClosure IS NULL OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s
     WHERE s.PreparationID=@PreparationID AND (s.State<>''closed'' OR s.ClosureHash IS NULL OR s.EventDigest IS NULL))
    OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
     WHERE s.PreparationID=@PreparationID AND NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State=''succeeded''))
    THROW 51700,''Enrollment history contains unclosed or uncertain requests.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o CROSS JOIN
     (VALUES(''drive.permissions.create''),(''drive.files.get''),(''drive.permissions.list''),(''sheets.get''),(''sheets.values.batchGet'')) m(Operation)
     WHERE o.PreparationID=@PreparationID AND o.Stage=''created'' AND NOT EXISTS
      (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@VerificationStreamID AND r.TargetID=o.FileID AND r.Operation=m.Operation))
    THROW 51700,''Every origin requires grant and complete fixed readback.'',1;
   -- Parent verifies private response bytes, exact owner/editor and all blank cells.
   -- SQL seals that receipt only after the complete request history has terminated.
   INSERT dbo.ExportManagedFileOrigin
    SELECT FileID,''eligible'',''created'',PreparationID,Ordinal,SessionID,CreationStreamID,CreationRequestID,ResponseEventID,PlanHash,ProfileHash,ResponseHash,CreationClosureHash,OriginHash,OriginReference,@VerificationStreamID,@VerificationClosure,@EligibilityHash,@EligibilityReference,SYSUTCDATETIME()
    FROM dbo.ExportManagedFileOrigin WHERE PreparationID=@PreparationID AND Stage=''created'';
   SET @Progress=JSON_MODIFY(@Progress,''$.phase'',''complete'');
   UPDATE r SET ActivePreparationID=NULL,OwnerID=NULL,Version=r.Version+1
    FROM dbo.ExportResource r JOIN @Resources x ON x.ResourceKey=r.ResourceKey;
  END;
  UPDATE dbo.ExportPreparation SET GenerationJson=@Progress,State=CASE WHEN @Action=''complete'' THEN ''completed'' ELSE ''preflight'' END,Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PreparationID=@PreparationID AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ExpectedVersion;
  IF @@ROWCOUNT<>1 THROW 51700,''Enrollment preparation CAS lost.'',1;
 END;
 SELECT p.*,(SELECT r.ResourceKey AS [key],r.Version AS [version] FROM dbo.ExportPreparationResource m
  JOIN dbo.ExportResource r ON r.ResourceKey=m.ResourceKey WHERE m.PreparationID=p.PreparationID ORDER BY r.ResourceKey FOR JSON PATH) AS ResourcesJson
 FROM dbo.ExportPreparation p WHERE p.PreparationID=@PreparationID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportOutputEnrollmentTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x610e4146c04e87532f96fc0aa7510bdcfdc3165fb3d6a237863e4b799ebcf0b0
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportRolloverContainTargets
 @ContainmentID uniqueidentifier,@AccountKey varchar(128),@OperationID uniqueidentifier,
 @OwnerID uniqueidentifier,@Fence bigint,@ExpectedVersion bigint,
 @SnapshotHash binary(32),@ReceiptHash binary(32),@ReceiptReference uniqueidentifier,
 @ResourcesJson nvarchar(max),@StreamsJson nvarchar(max),
 @Actor nvarchar(128),@Reason nvarchar(512),
 @RegistrationHash binary(32),@PoolID uniqueidentifier,@PoolVersion bigint
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51733,''Exact outer containment transaction required.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51733,''Evidence authority role required.'',1;
 IF @ContainmentID IS NULL OR @AccountKey IS NULL OR @OperationID IS NULL OR @OwnerID IS NULL
  OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion IS NULL OR @ExpectedVersion<=0
  OR @SnapshotHash IS NULL OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL OR @RegistrationHash IS NULL
  OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
  OR @ResourcesJson IS NULL OR ISJSON(@ResourcesJson)<>1 OR DATALENGTH(@ResourcesJson)>1048576
  OR @StreamsJson IS NULL OR ISJSON(@StreamsJson)<>1 OR DATALENGTH(@StreamsJson)>1048576
  THROW 51733,''Complete bounded containment identity required.'',1;
 -- Validate before typed projection: OPENJSON WITH otherwise truncates strings,
 -- and binary conversion pads short hashes. Neither may change approved evidence.
 IF LEFT(LTRIM(@ResourcesJson),1)<>''['' OR LEFT(LTRIM(@StreamsJson),1)<>''[''
  OR EXISTS(SELECT 1 FROM OPENJSON(@ResourcesJson) j WHERE j.type<>5
   OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>2
   OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>2
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''key'' AND type=1
    AND LEN(value) BETWEEN 1 AND 256 AND DATALENGTH(value)=2*LEN(value)
    AND value NOT LIKE ''%[^-A-Za-z0-9_.@:]%'' COLLATE Latin1_General_100_BIN2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''version'' AND type=2
    AND TRY_CONVERT(bigint,value)>0 AND value NOT LIKE ''%[^0-9]%'' COLLATE Latin1_General_100_BIN2))
  OR EXISTS(SELECT 1 FROM OPENJSON(@StreamsJson) j WHERE j.type<>5
   OR (SELECT COUNT(*) FROM OPENJSON(j.value))<>4
   OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(j.value))<>4
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''stream_id'' AND type=1
    AND DATALENGTH(value)=72 AND TRY_CONVERT(uniqueidentifier,value) IS NOT NULL)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''version'' AND type=2
    AND TRY_CONVERT(bigint,value)>0 AND value NOT LIKE ''%[^0-9]%'' COLLATE Latin1_General_100_BIN2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''last_sequence'' AND type=2
    AND TRY_CONVERT(bigint,value)>=0 AND value NOT LIKE ''%[^0-9]%'' COLLATE Latin1_General_100_BIN2)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''event_digest'' AND type=1
    AND DATALENGTH(value)=128 AND value NOT LIKE ''%[^0-9a-f]%'' COLLATE Latin1_General_100_BIN2))
  THROW 51733,''Exact resource and stream JSON shapes required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51733,''Account admission busy.'',1;

 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 PRIMARY KEY,Version bigint NOT NULL);
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ResourcesJson)
  WITH(ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
 IF (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 4 AND 18
  OR NOT EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey=''account:''+@AccountKey)
  OR EXISTS(SELECT 1 FROM @Resources WHERE Version<=0 OR (ResourceKey<>''account:''+@AccountKey AND ResourceKey NOT LIKE ''destination:%''))
  OR EXISTS(SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@OperationID EXCEPT SELECT ResourceKey FROM @Resources)
  OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@OperationID)
  THROW 51733,''Complete exact rollover resource membership required.'',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51733,''Resource admission busy.'',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK)
   WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion AND ActiveOutputOperationID=@OperationID
    AND OwnerID=@OwnerID AND Fence=@Fence AND ActivePreparationID IS NULL AND ActiveJobID IS NULL)
   THROW 51733,''Exact held rollover resource required.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;

 DECLARE @OldEpoch bigint,@OldKVK int;
 SELECT @OldEpoch=OldEpoch,@OldKVK=OldKVK
 FROM KVK.SourceOutputOperation WITH(UPDLOCK,HOLDLOCK)
 WHERE OperationID=@OperationID AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence
  AND Version=@ExpectedVersion AND State IN (''running'',''uncertain'') AND PoolID=@PoolID;
 IF @OldEpoch IS NULL OR @PoolID IS NULL OR @PoolVersion IS NULL OR @PoolVersion<=0
  THROW 51733,''Exact unfinished rollover and pool required.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportResource r WITH(UPDLOCK,HOLDLOCK) WHERE r.ActiveOutputOperationID=@OperationID
  AND NOT EXISTS(SELECT 1 FROM @Resources e WHERE e.ResourceKey=r.ResourceKey))
  THROW 51733,''Unexpected held rollover resource prevents partial release.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportTargetContainment WITH(UPDLOCK,HOLDLOCK) WHERE OutputOperationID=@OperationID OR ContainmentID=@ContainmentID)
  THROW 51733,''Containment already recorded; verify its original receipt.'',1;

 DECLARE @Targets TABLE(FileID varchar(128) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey LIKE ''destination:%'' AND LEN(ResourceKey) NOT BETWEEN 15 AND 140)
  THROW 51733,''Bounded physical target identity required.'',1;
 INSERT @Targets SELECT SUBSTRING(ResourceKey,13,128) FROM @Resources WHERE ResourceKey LIKE ''destination:%'';
 IF EXISTS(SELECT 1 FROM @Targets WHERE DATALENGTH(FileID)<>LEN(FileID) OR FileID LIKE ''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2)
  OR EXISTS(SELECT 1 FROM @Targets t JOIN dbo.ExportContainedTarget c WITH(UPDLOCK,HOLDLOCK) ON c.FileID=t.FileID)
  THROW 51733,''Target identity differs or is already permanently isolated.'',1;

 DECLARE @Streams TABLE(StreamID uniqueidentifier PRIMARY KEY,Version bigint NOT NULL,LastSequence bigint NOT NULL,EventDigest binary(32) NOT NULL);
 INSERT @Streams SELECT StreamID,Version,LastSequence,CONVERT(binary(32),EventDigest,2)
 FROM OPENJSON(@StreamsJson) WITH(StreamID uniqueidentifier ''$.stream_id'',Version bigint ''$.version'',LastSequence bigint ''$.last_sequence'',EventDigest varchar(64) ''$.event_digest'');
 IF (SELECT COUNT(*) FROM @Streams) NOT BETWEEN 0 AND 4096
  OR EXISTS(SELECT 1 FROM @Streams WHERE Version<=0 OR LastSequence<0)
  OR EXISTS(SELECT StreamID FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE OutputOperationID=@OperationID EXCEPT SELECT StreamID FROM @Streams)
  OR EXISTS(SELECT StreamID FROM @Streams EXCEPT SELECT StreamID FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE OutputOperationID=@OperationID)
  OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE ActiveAccountKey=@AccountKey AND (OutputOperationID IS NULL OR OutputOperationID<>@OperationID))
  THROW 51733,''Complete exclusive rollover stream membership required.'',1;
 IF EXISTS(SELECT 1 FROM @Streams e JOIN dbo.ExportExecutionStream s WITH(UPDLOCK,HOLDLOCK) ON s.StreamID=e.StreamID
  LEFT JOIN dbo.ExportExecutionSession a ON a.SessionID=s.SessionID
  WHERE s.AccountKey<>@AccountKey OR s.Version<>e.Version OR s.LastSequence<>e.LastSequence
   OR NOT ((s.OwnerID=@OwnerID AND s.Fence=@Fence)
    OR (s.OwnerID IS NULL AND s.Purpose=''probe'' AND s.State=''closed'' AND s.ClaimVersion=1 AND s.Fence=0))
   OR (s.OwnerID IS NULL AND NOT (s.Purpose=''probe'' AND s.State=''closed'' AND s.ClaimVersion=1 AND s.Fence=0))
   OR s.RegistrationHash IS NULL OR s.RegistrationHash<>@RegistrationHash
   OR s.ClaimVersion>@ExpectedVersion
   OR (s.Epoch IS NULL AND @OldEpoch IS NOT NULL) OR (s.Epoch IS NOT NULL AND @OldEpoch IS NULL) OR s.Epoch<>@OldEpoch
   OR s.PreparationID IS NOT NULL OR s.JobID IS NOT NULL OR s.NestedToken IS NOT NULL OR s.Purpose NOT IN (''mutation'',''probe'')
   OR s.State NOT IN (''open'',''frozen'',''closed'') OR a.AuthorityPrincipal IS NULL OR a.AuthorityPrincipal<>USER_NAME()
   OR EXISTS(SELECT ResourceKey FROM OPENJSON(s.ScopeJson,''$.resources'') WITH(ResourceKey varchar(256) ''$.key'') EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM OPENJSON(s.ScopeJson,''$.resources'') WITH(ResourceKey varchar(256) ''$.key'')))
  THROW 51733,''Exact original stream authority and complete possible targets required.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r JOIN @Streams s ON s.StreamID=r.StreamID
  WHERE r.Operation=''sheets.create'' OR NOT EXISTS(SELECT 1 FROM @Targets t WHERE t.FileID=r.TargetID))
  THROW 51733,''A recorded request escaped the proposed retired target set.'',1;

 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51733,''Output pool admission busy.'',1;
  IF NOT EXISTS(SELECT 1 FROM KVK.SourceOutputPool p WITH(UPDLOCK,HOLDLOCK) JOIN @Targets t ON t.FileID=p.IndexFileID
   WHERE p.PoolID=@PoolID AND p.Version=@PoolVersion AND p.Epoch=@OldEpoch AND p.ActiveKVK=@OldKVK
    AND p.RegistrationHash=@RegistrationHash AND p.AccountKey=@AccountKey AND p.PoolState=''closing'' AND p.OwnerID=@OperationID AND p.Fence=@Fence)
   THROW 51733,''Exact owned closing output pool required.'',1;
  IF (SELECT COUNT(*) FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID) NOT BETWEEN 2 AND 16
   OR EXISTS(SELECT FileID FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID EXCEPT SELECT FileID FROM @Targets)
   OR EXISTS(SELECT FileID FROM @Targets EXCEPT SELECT FileID FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID
    EXCEPT SELECT IndexFileID FROM KVK.SourceOutputPool WHERE PoolID=@PoolID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation WHERE PoolID=@PoolID AND OperationID<>@OperationID AND State<>''completed'')
   THROW 51733,''Pool membership or unfinished rollover prevents this rollover decision.'',1;
 END;

 INSERT dbo.ExportTargetContainment
  (ContainmentID,AccountKey,OutputOperationID,OwnerVersion,OwnerID,Fence,SnapshotHash,ReceiptHash,ReceiptReference,Actor,Reason,CreatedUTC)
 VALUES(@ContainmentID,@AccountKey,@OperationID,@ExpectedVersion,@OwnerID,@Fence,@SnapshotHash,@ReceiptHash,@ReceiptReference,@Actor,@Reason,SYSUTCDATETIME());
 INSERT dbo.ExportContainedTarget SELECT FileID,@ContainmentID,SYSUTCDATETIME() FROM @Targets;
 INSERT dbo.ExportContainedStream SELECT StreamID,@ContainmentID,Version,LastSequence,EventDigest FROM @Streams;
 UPDATE s SET State=''target_contained'',ActiveAccountKey=NULL,Version=s.Version+1,
  ClosureHash=@ReceiptHash,ClosureReference=@ReceiptReference,EventDigest=e.EventDigest,ClosedUTC=SYSUTCDATETIME()
 FROM dbo.ExportExecutionStream s JOIN @Streams e ON e.StreamID=s.StreamID;
 IF @PoolID IS NOT NULL
 BEGIN
  UPDATE KVK.SourceOutputPool SET PoolState=''blocked'',OwnerID=NULL,BlockedReason=N''Targets permanently isolated; verified replacements required'',Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PoolID=@PoolID AND PoolState=''closing'' AND OwnerID=@OperationID AND Fence=@Fence AND Version=@PoolVersion;
  IF @@ROWCOUNT<>1 THROW 51733,''Pool containment CAS lost.'',1;
 END;
 UPDATE KVK.SourceOutputOperation SET State=''uncertain'',Phase=''uncertain'',Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
  WHERE OperationID=@OperationID AND Version=@ExpectedVersion AND OwnerID=@OwnerID AND Fence=@Fence;
 IF @@ROWCOUNT<>1 THROW 51733,''Rollover containment CAS lost.'',1;
 UPDATE r SET ActiveOutputOperationID=NULL,OwnerID=NULL,BlockedReason=NULL,Version=r.Version+1
 FROM dbo.ExportResource r JOIN @Resources e ON e.ResourceKey=r.ResourceKey
 WHERE r.Version=e.Version AND r.ActiveOutputOperationID=@OperationID AND r.OwnerID=@OwnerID AND r.Fence=@Fence
  AND r.ActivePreparationID IS NULL AND r.ActiveJobID IS NULL;
 IF @@ROWCOUNT<>(SELECT COUNT(*) FROM @Resources) THROW 51733,''Resource containment CAS lost.'',1;
 SELECT * FROM dbo.ExportTargetContainment WHERE ContainmentID=@ContainmentID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportRolloverContainTargets',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xee3f2f05615b5a4970e5d7c35ec69ef4b6d7fbbfa1de7e5f7d9106e3f6056f86
 THROW 51734,'Exact reviewed rollover replacement definition required.',1;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportRolloverContainTargets TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportRolloverContainTargets TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.usp_ExportRolloverContainTargets TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.usp_ExportRolloverContainTargets TO ExportExecutionReader;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
