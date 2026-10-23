/*
MigrationId: 20261023_001_legacy_export_closeout
Purpose: Allow verified legacy closeout without replacing spreadsheet URLs
Author: cwatts
CreatedUtc: 2026-10-23
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact module preimages and closed protected authority
PostValidationQuery: Exact definitions and authority-only closeout permission
*/
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51740,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int,@Body nvarchar(max);
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51740,'Schema busy.',1;
IF EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WITH(HOLDLOCK) WHERE State<>'closed')
 THROW 51740,'Authority sessions must be closed.',1;

SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition'));
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE') WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE') WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE') ELSE @Body END;
IF @Body IS NULL OR HASHBYTES('SHA2_256',@Body) NOT IN(0x82681de9419221006f49e852705246f3ca2f2bc0721d75275cef486f8df6eab1,0xa510b4cb637a8f833ad068e461914cec120855682630907da6cd0fbb0059b520)
 THROW 51740,'Unreviewed dbo.usp_ExportExecutionStreamTransition preimage.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition'))
 OR EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition') AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
 THROW 51740,'Unexpected execution context or signature.',1;

SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend'));
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE') WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE') WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE') ELSE @Body END;
IF @Body IS NULL OR HASHBYTES('SHA2_256',@Body) NOT IN(0xf66175f143e0f5f10f013a973a3b8d5ed4abbca158f3ba1689df767bce799891,0x9f1ee72f9f683333e1ad2a8449a05f4fdda2a21e503c43048c770dece2b5f7cc)
 THROW 51740,'Unreviewed dbo.usp_ExportProviderRequestEventAppend preimage.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend'))
 OR EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend') AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
 THROW 51740,'Unexpected execution context or signature.',1;

SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue'));
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE') WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE') WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE') ELSE @Body END;
IF @Body IS NULL OR HASHBYTES('SHA2_256',@Body) NOT IN(0x5c2cddf56393a56325544620c4aee097ab9083b00a6bed543a44d32d652cdb36,0x5c2cddf56393a56325544620c4aee097ab9083b00a6bed543a44d32d652cdb36)
 THROW 51740,'Unreviewed dbo.usp_ExportReconciliationProofIssue preimage.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue'))
 OR EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue') AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
 THROW 51740,'Unexpected execution context or signature.',1;

IF OBJECT_ID(N'dbo.ExportLegacyCloseout') IS NULL EXEC sys.sp_executesql N'SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.ExportLegacyCloseout
(
 ActionID uniqueidentifier NOT NULL,
 JobID uniqueidentifier NOT NULL,
 ContainmentID uniqueidentifier NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 OwnerVersion bigint NOT NULL,
 SnapshotHash binary(32) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportLegacyCloseout PRIMARY KEY(ActionID),
 CONSTRAINT UQ_ExportLegacyCloseout_Job UNIQUE(JobID),
 CONSTRAINT FK_ExportLegacyCloseout_Job FOREIGN KEY(JobID) REFERENCES dbo.ExportJob(JobID),
 CONSTRAINT FK_ExportLegacyCloseout_Containment FOREIGN KEY(ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID),
 CONSTRAINT CK_ExportLegacyCloseout_Version CHECK(OwnerVersion>0),
 CONSTRAINT CK_ExportLegacyCloseout_Actor CHECK(Actor=N''recovery:''+LOWER(CONVERT(nvarchar(36),ActionID)) AND LEN(Reason)>0)
);
';

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE #ExpectedLegacyCloseout
(
 ActionID uniqueidentifier NOT NULL,
 JobID uniqueidentifier NOT NULL,
 ContainmentID uniqueidentifier NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 OwnerVersion bigint NOT NULL,
 SnapshotHash binary(32) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 PRIMARY KEY(ActionID),
 UNIQUE(JobID),
 CHECK(OwnerVersion>0),
 CHECK(Actor=N'recovery:'+LOWER(CONVERT(nvarchar(36),ActionID)) AND LEN(Reason)>0)
);

IF EXISTS(SELECT column_id,name COLLATE Latin1_General_100_BIN2 AS name,system_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_nullable,is_identity,is_computed FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') EXCEPT SELECT column_id,name COLLATE Latin1_General_100_BIN2 AS name,system_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_nullable,is_identity,is_computed FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExpectedLegacyCloseout'))
 OR EXISTS(SELECT column_id,name COLLATE Latin1_General_100_BIN2 AS name,system_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_nullable,is_identity,is_computed FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExpectedLegacyCloseout') EXCEPT SELECT column_id,name COLLATE Latin1_General_100_BIN2 AS name,system_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_nullable,is_identity,is_computed FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))
 THROW 51740,'Existing closeout table differs.',1;
IF EXISTS(SELECT definition COLLATE Latin1_General_100_BIN2,is_disabled,is_not_trusted FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout')
 EXCEPT SELECT definition COLLATE Latin1_General_100_BIN2,is_disabled,is_not_trusted FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#ExpectedLegacyCloseout'))
 OR EXISTS(SELECT definition COLLATE Latin1_General_100_BIN2,is_disabled,is_not_trusted FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#ExpectedLegacyCloseout')
 EXCEPT SELECT definition COLLATE Latin1_General_100_BIN2,is_disabled,is_not_trusted FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))
 OR (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))<>2
 THROW 51740,'Existing closeout checks differ.',1;
DROP TABLE #ExpectedLegacyCloseout;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))<>2
 OR NOT EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.index_columns c ON c.object_id=i.object_id AND c.index_id=i.index_id
  WHERE i.object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND i.name=N'PK_ExportLegacyCloseout'
   AND i.is_primary_key=1 AND i.is_unique=1 AND i.is_disabled=0 AND i.has_filter=0
   AND c.key_ordinal=1 AND COL_NAME(c.object_id,c.column_id)=N'ActionID'
   AND (SELECT COUNT(*) FROM sys.index_columns x WHERE x.object_id=i.object_id AND x.index_id=i.index_id)=1)
 OR NOT EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.index_columns c ON c.object_id=i.object_id AND c.index_id=i.index_id
  WHERE i.object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND i.name=N'UQ_ExportLegacyCloseout_Job'
   AND i.is_unique_constraint=1 AND i.is_unique=1 AND i.is_disabled=0 AND i.has_filter=0
   AND c.key_ordinal=1 AND COL_NAME(c.object_id,c.column_id)=N'JobID'
   AND (SELECT COUNT(*) FROM sys.index_columns x WHERE x.object_id=i.object_id AND x.index_id=i.index_id AND x.key_ordinal>0)=1)
 THROW 51740,'Existing closeout keys differ.',1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))<>2
 OR EXISTS(SELECT 1 FROM sys.foreign_keys f WHERE f.parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND
  (f.is_disabled=1 OR f.is_not_trusted=1 OR f.delete_referential_action<>0 OR f.update_referential_action<>0
   OR (SELECT COUNT(*) FROM sys.foreign_key_columns c WHERE c.constraint_object_id=f.object_id)<>1
   OR NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns c WHERE c.constraint_object_id=f.object_id AND
    ((f.name=N'FK_ExportLegacyCloseout_Job' AND COL_NAME(c.parent_object_id,c.parent_column_id)=N'JobID'
      AND c.referenced_object_id=OBJECT_ID(N'dbo.ExportJob') AND COL_NAME(c.referenced_object_id,c.referenced_column_id)=N'JobID')
     OR (f.name=N'FK_ExportLegacyCloseout_Containment' AND COL_NAME(c.parent_object_id,c.parent_column_id)=N'ContainmentID'
      AND c.referenced_object_id=OBJECT_ID(N'dbo.ExportTargetContainment') AND COL_NAME(c.referenced_object_id,c.referenced_column_id)=N'ContainmentID')))))
 THROW 51740,'Existing closeout references differ.',1;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))
 OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))
 OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND (user_type_id<>system_type_id OR encryption_type IS NOT NULL))
 OR EXISTS(SELECT 1 FROM sys.masked_columns WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND is_masked=1)
 THROW 51740,'Unsupported closeout security contract.',1;

IF OBJECT_ID(N'dbo.ExportActiveContainedTarget') IS NOT NULL
BEGIN
 SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.ExportActiveContainedTarget'));
 SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
 SET @Body=REPLACE(@Body,N'CREATE OR ALTER ',N'CREATE ');
 IF @Body IS NULL OR HASHBYTES('SHA2_256',@Body)<>0x3b1d13c182f9077b0dcc9592bef6449f62266a0280b8266d8fd290fc85b8cf6a THROW 51740,'Existing dbo.ExportActiveContainedTarget differs.',1;
 IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=OBJECT_ID(N'dbo.ExportActiveContainedTarget'))
  OR EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.ExportActiveContainedTarget') AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
  THROW 51740,'Unexpected new module security context.',1;
END;

IF OBJECT_ID(N'dbo.ExportActiveContainedTarget') IS NULL EXEC sys.sp_executesql N'CREATE VIEW dbo.ExportActiveContainedTarget
AS
 SELECT t.FileID,t.ContainmentID,t.CreatedUTC
 FROM dbo.ExportContainedTarget t
 WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportLegacyCloseout c WHERE c.ContainmentID=t.ContainmentID);';

IF OBJECT_ID(N'dbo.usp_ExportLegacyCloseout') IS NOT NULL
BEGIN
 SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportLegacyCloseout'));
 SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
 SET @Body=REPLACE(@Body,N'CREATE OR ALTER ',N'CREATE ');
 IF @Body IS NULL OR HASHBYTES('SHA2_256',@Body)<>0x820d4e94b8973881bbea284d0f2a950ed74e3273853b3746dd29f0b1a9a8d755 THROW 51740,'Existing dbo.usp_ExportLegacyCloseout differs.',1;
 IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_ExportLegacyCloseout'))
  OR EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'dbo.usp_ExportLegacyCloseout') AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
  THROW 51740,'Unexpected new module security context.',1;
END;

IF OBJECT_ID(N'dbo.usp_ExportLegacyCloseout') IS NULL EXEC sys.sp_executesql N'CREATE PROCEDURE dbo.usp_ExportLegacyCloseout
 @ActionID uniqueidentifier,@JobID uniqueidentifier,@AccountKey varchar(128),
 @StorageOwner varchar(128),@ExpectedVersion bigint,@OwnerID uniqueidentifier,@Fence bigint,
 @SnapshotHash binary(32),@ReceiptHash binary(32),@ReceiptReference uniqueidentifier,
 @Actor nvarchar(128),@Reason nvarchar(512)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>1 THROW 51740,''Exact outer closeout transaction required.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51740,''Evidence authority role required.'',1;
 IF @ActionID IS NULL OR @JobID IS NULL OR @AccountKey IS NULL OR @StorageOwner IS NULL
  OR @OwnerID IS NULL OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion IS NULL OR @ExpectedVersion<=0
  OR @SnapshotHash IS NULL OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL
  OR @Actor IS NULL OR @Actor<>N''recovery:''+LOWER(CONVERT(nvarchar(36),@ActionID))
  OR DATALENGTH(@Actor)<>90 OR @Reason IS NULL OR LEN(@Reason)=0
  THROW 51740,''Complete closeout identity required.'',1;
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51740,''Account admission busy.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.ExportJob WITH(UPDLOCK,HOLDLOCK)
  WHERE JobID=@JobID AND AccountKey=@AccountKey AND StorageOwner=@StorageOwner
   AND ConsumerKind IN(''scan_data'',''all_kvk'') AND State IN(''uncertain'',''failed'')
   AND Version=@ExpectedVersion AND OwnerID=@OwnerID AND Fence=@Fence
   AND ISNULL(JSON_VALUE(ProvenanceJson,''$.safe_retry.requested''),''false'')<>''true'')
  THROW 51740,''Exact stopped legacy export required.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportLegacyCloseout WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID OR ActionID=@ActionID)
  THROW 51740,''Closeout already recorded; verify its receipt.'',1;
 DECLARE @ContainmentID uniqueidentifier;
 SELECT @ContainmentID=ContainmentID FROM dbo.ExportTargetContainment WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID;
 IF @ContainmentID IS NOT NULL AND EXISTS(SELECT 1 FROM dbo.ExportReplacementPlan WITH(UPDLOCK,HOLDLOCK) WHERE ContainmentID=@ContainmentID)
  THROW 51740,''Replacement work must be reconciled before same-file reuse.'',1;

 DECLARE @ResourceKey varchar(256);
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR
  SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@JobID ORDER BY ResourceKey;
 OPEN ResourceLocks; FETCH NEXT FROM ResourceLocks INTO @ResourceKey;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51740,''Resource admission busy.'',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK) WHERE ResourceKey=@ResourceKey
   AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL
   AND ((ActiveJobID IS NULL AND OwnerID IS NULL)
    OR (ActiveJobID=@JobID AND OwnerID=@OwnerID AND Fence=@Fence)))
   THROW 51740,''Foreign ownership prevents closeout.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;
 IF (SELECT COUNT(*) FROM dbo.ExportJobResource WHERE JobID=@JobID) NOT BETWEEN 2 AND 1025
  OR NOT EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey=''account:''+@AccountKey)
  OR EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey<>''account:''+@AccountKey AND ResourceKey NOT LIKE ''destination:%'')
  OR EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ActiveJobID=@JobID
   AND ResourceKey NOT IN(SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@JobID))
  THROW 51740,''Complete resource membership required.'',1;
 IF @ContainmentID IS NOT NULL AND (
  EXISTS(SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID
   EXCEPT SELECT SUBSTRING(ResourceKey,13,128) FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey LIKE ''destination:%'')
  OR EXISTS(SELECT SUBSTRING(ResourceKey,13,128) FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey LIKE ''destination:%''
   EXCEPT SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID))
  THROW 51740,''Complete contained target membership required.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportActiveContainedTarget t JOIN dbo.ExportJobResource m ON m.ResourceKey=''destination:''+t.FileID
  WHERE m.JobID=@JobID AND (@ContainmentID IS NULL OR t.ContainmentID<>@ContainmentID))
  THROW 51740,''Another containment owns these targets.'',1;

 IF (SELECT COUNT(*) FROM dbo.ExportExecutionStream WHERE JobID=@JobID) NOT BETWEEN 1 AND 4096
  OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE ActiveAccountKey=@AccountKey)
  OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s WITH(UPDLOCK,HOLDLOCK)
   JOIN dbo.ExportExecutionSession a ON a.SessionID=s.SessionID WHERE s.JobID=@JobID AND
    (s.State NOT IN(''closed'',''target_contained'') OR s.ActiveAccountKey IS NOT NULL
     OR s.OwnerID<>@OwnerID OR s.Fence<>@Fence OR s.AccountKey<>@AccountKey
     OR a.AuthorityPrincipal<>USER_NAME() OR s.ClosureHash IS NULL OR s.ClosureReference IS NULL
     OR (s.State=''target_contained'' AND @ContainmentID IS NULL)
     OR s.Purpose NOT IN(''mutation'',''probe'') OR s.NestedToken IS NOT NULL OR s.Epoch IS NOT NULL))
  THROW 51740,''Every original execution must be sealed by its authority.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream s WHERE s.JobID=@JobID AND
  (s.LastSequence<>(SELECT COUNT_BIG(*) FROM dbo.ExportProviderRequest r WHERE r.StreamID=s.StreamID)
   OR s.LastSequence<>ISNULL((SELECT MAX(Sequence) FROM dbo.ExportProviderRequest r WHERE r.StreamID=s.StreamID),0)))
  THROW 51740,''Complete sequential request membership required.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportExecutionStream s ON s.StreamID=r.StreamID
  WHERE s.JobID=@JobID AND (r.Operation=''sheets.create''
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportJobResource WHERE JobID=@JobID AND ResourceKey=''destination:''+r.TargetID)
   OR NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID AND EventSequence=1 AND State=''prepared'')
   OR NOT ((EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID AND EventSequence=2 AND State=''not_sent'')
    AND (SELECT COUNT(*) FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID)=2)
    OR (EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID AND EventSequence=2 AND State=''dispatch_intent'')
     AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID AND EventSequence=3 AND State=''succeeded'')
     AND (SELECT COUNT(*) FROM dbo.ExportProviderRequestEvent WHERE RequestID=r.RequestID)=3))))
  THROW 51740,''Unfinished or unknown requests prevent same-file reuse.'',1;

 INSERT dbo.ExportLegacyCloseout(ActionID,JobID,ContainmentID,AccountKey,OwnerVersion,SnapshotHash,ReceiptHash,ReceiptReference,Actor,Reason,CreatedUTC)
 VALUES(@ActionID,@JobID,@ContainmentID,@AccountKey,@ExpectedVersion,@SnapshotHash,@ReceiptHash,@ReceiptReference,@Actor,@Reason,SYSUTCDATETIME());
 DECLARE @Marker nvarchar(max)=(SELECT LOWER(CONVERT(varchar(36),@ReceiptReference)) AS reference,
  LOWER(CONVERT(varchar(64),@ReceiptHash,2)) AS sha256 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 UPDATE dbo.ExportJob SET State=''failed'',ProvenanceJson=JSON_MODIFY(ProvenanceJson,''$.legacy_export_abandoned'',JSON_QUERY(@Marker)),
  Version=Version+1,UpdatedUTC=SYSUTCDATETIME() WHERE JobID=@JobID AND Version=@ExpectedVersion;
 IF @@ROWCOUNT<>1 THROW 51740,''Closeout owner changed.'',1;
 UPDATE dbo.ExportResource SET ActiveJobID=NULL,OwnerID=NULL,BlockedReason=NULL,Version=Version+1
  WHERE ActiveJobID=@JobID AND OwnerID=@OwnerID AND Fence=@Fence;
 SELECT * FROM dbo.ExportLegacyCloseout WHERE ActionID=@ActionID;
END;';

EXEC sys.sp_executesql N'ALTER PROCEDURE dbo.usp_ExportExecutionStreamTransition
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
 IF (@Action=''contain_read'' AND @@TRANCOUNT<>1) OR (@Action<>''contain_read'' AND @@TRANCOUNT<>0)
  THROW 51700,''Read containment requires the exact outer recovery transaction; other transitions require their own transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;

 IF @Action=''contain_read'' AND DATALENGTH(@Action)=12
 BEGIN
  -- A distinct dispatch fence, never an OS-closure or provider-success assertion.
  -- The authority has sealed the SQL ledger and the outer transaction compares
  -- the complete preparation/resources before calling this protected transition.
  IF @ClosureHash IS NULL OR @ClosureReference IS NULL OR @EventDigest IS NULL
   OR @LastSequence IS NULL OR @ChildIdentity IS NULL OR @ObjectID IS NULL
   OR @OwnerID IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL
   THROW 51700,''Complete read containment binding required.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
   WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State IN (''open'',''closed''))
   THROW 51700,''Exact original authority session required.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK)
   WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence
    AND ConsumerKind=''config'' AND KVK_NO IS NULL AND JobID IS NULL AND GenerationJson IS NULL
    AND State IN (''preflight'',''uncertain'')
    AND Version=@ClaimVersion+CASE WHEN State=''uncertain'' THEN 1 ELSE 0 END
    AND ISNULL(JSON_VALUE(RequestJson,''$.purpose''),'''')<>''output_enrollment'')
   THROW 51700,''Exact unfinished configuration preparation required.'',1;
  IF (SELECT COUNT_BIG(*) FROM dbo.ExportProviderRequest WITH (UPDLOCK,HOLDLOCK) WHERE StreamID=@StreamID)<>@LastSequence
   OR EXISTS (SELECT 1 FROM dbo.ExportProviderRequest WITH (UPDLOCK,HOLDLOCK) WHERE StreamID=@StreamID
    AND (Sequence<1 OR Sequence>@LastSequence OR RequestKind<>''read''
     OR Operation NOT IN (''sheets.get'',''sheets.values.get'',''sheets.values.batchGet'',''drive.files.get'',''drive.permissions.list'')))
   THROW 51700,''Only complete typed read membership can be contained.'',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID
   AND (NOT EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.EventSequence=1 AND e.State=''prepared'')
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State NOT IN (''prepared'',''dispatch_intent'',''succeeded'',''not_sent'',''unknown''))))
   THROW 51700,''Complete read event membership required.'',1;
  UPDATE dbo.ExportExecutionStream SET State=''read_contained'',ActiveAccountKey=NULL,Version=Version+1,
   ClosureHash=@ClosureHash,ClosureReference=@ClosureReference,EventDigest=@EventDigest,ClosedUTC=SYSUTCDATETIME()
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion
    AND PreparationID=@ObjectID AND OwnerID=@OwnerID AND Fence=@Fence AND ClaimVersion=@ClaimVersion
    AND ChildIdentity=@ChildIdentity AND Purpose=''probe'' AND State IN (''open'',''frozen'',''closed'')
    AND JobID IS NULL AND OutputOperationID IS NULL AND NestedToken IS NULL AND Epoch IS NULL AND LastSequence=@LastSequence;
  IF @@ROWCOUNT<>1 THROW 51700,''Read containment CAS lost.'',1;
 END
 ELSE IF @Action=''open'' AND DATALENGTH(@Action)=4 AND @ExpectedVersion=0
 BEGIN

 -- Account lock precedes sorted resource locks; stream row is locked last.
 IF @AccountKey IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL OR @ClaimVersion<=0
 OR (@OwnerID IS NULL AND NOT (@OwnerKind=''operation'' AND @Purpose=''probe'' AND @Fence=0 AND @NestedToken IS NULL))
 OR (@OwnerID IS NOT NULL AND @Fence<=0)
 OR @OwnerKind NOT IN (''job'',''preparation'',''operation'') OR @OwnerKind IS NULL
 OR DATALENGTH(@OwnerKind)<>LEN(@OwnerKind) OR @ObjectID IS NULL
 OR @Purpose NOT IN (''mutation'',''probe'',''enrollment'') OR @Purpose IS NULL OR DATALENGTH(@Purpose)<>LEN(@Purpose)
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>CASE WHEN @Purpose=''enrollment'' THEN 524288 ELSE 65536 END
 THROW 51700,''Complete typed stream scope required.'',1;
 DECLARE @Resources TABLE (ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF JSON_QUERY(@ScopeJson,''$.resources'') IS NULL THROW 51700,''Complete resource membership required.'',1;
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ScopeJson,''$.resources'')
 WITH (ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
 IF NOT EXISTS (SELECT 1 FROM @Resources WHERE ResourceKey=''account:''+@AccountKey)
 OR (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 1 AND 1025 OR EXISTS (SELECT 1 FROM @Resources WHERE Version<=0)
 THROW 51700,''Invalid resource membership.'',1;
 IF EXISTS (SELECT 1 FROM @Resources r JOIN dbo.ExportActiveContainedTarget t WITH (HOLDLOCK)
  ON r.ResourceKey=(''destination:''+t.FileID) COLLATE Latin1_General_100_BIN2)
  THROW 51700,''A permanently isolated target cannot enter another provider stream.'',1;
 -- A legacy closeout releases ordinary exports and configuration reads only.
 -- Managed pools, enrollment and replacement proofs retain permanent isolation.
 IF EXISTS (SELECT 1 FROM @Resources r JOIN dbo.ExportContainedTarget t WITH (HOLDLOCK)
  ON r.ResourceKey=(''destination:''+t.FileID) COLLATE Latin1_General_100_BIN2)
  AND NOT (@NestedToken IS NULL AND @Epoch IS NULL AND
   ((@OwnerKind=''job'' AND @Purpose=''mutation'' AND EXISTS
     (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
      AND ConsumerKind IN (''scan_data'',''all_kvk'') AND PoolEpoch IS NULL AND SourceKey IS NULL AND IntentID IS NULL))
    OR (@OwnerKind=''preparation'' AND @Purpose=''probe'' AND EXISTS
     (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID
      AND ConsumerKind=''config'' AND KVK_NO IS NULL AND JobID IS NULL AND GenerationJson IS NULL
      AND ISNULL(JSON_VALUE(RequestJson,''$.purpose''),'''')<>''output_enrollment''))))
  THROW 51700,''Historical target isolation permits only legacy export or configuration read.'',1;
 IF @Purpose=''probe'' AND EXISTS (SELECT 1 FROM dbo.ExportResource r JOIN dbo.ExportPreparation p ON p.PreparationID=r.ActivePreparationID
    WHERE p.AccountKey=@AccountKey AND r.ResourceKind=''sql_snapshot'' AND r.OwnerID IS NOT NULL)
  THROW 51700,''Owned SQL producer must drain before observational probe.'',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint,@ResourceLock nvarchar(255),@ResourceResult int;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @ResourceLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @ResourceResult=sys.sp_getapplock @Resource=@ResourceLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @ResourceResult<0 THROW 51700,''Resource admission busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK)
    WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion
    AND (@Purpose=''probe'' OR BlockedReason IS NULL)
    AND ((@Purpose=''probe'' AND OwnerID IS NULL AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
     OR (OwnerID=@OwnerID AND Fence=@Fence AND ((@OwnerKind=''job'' AND ActiveJobID=@ObjectID AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''preparation'' AND ActivePreparationID=@ObjectID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''operation'' AND ActiveOutputOperationID=@ObjectID AND ActiveJobID IS NULL AND ActivePreparationID IS NULL)))))
   THROW 51700,''Resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;
 IF @Purpose=''enrollment'' AND @OwnerKind<>''preparation'' THROW 51700,''Enrollment requires its preparation owner.'',1;
 IF @OwnerKind=''job''
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
   AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'',''failed'')))
   AND ((PoolEpoch IS NULL AND @Epoch IS NULL) OR PoolEpoch=@Epoch)
   AND ((@NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'') IS NULL)
      OR (@NestedToken IS NOT NULL AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.token''))=@NestedToken
       AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''owned''
       AND (TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion
        OR (@Purpose=''probe'' AND State=''uncertain'' AND @ClaimVersion>1
         AND TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion-1)))
      OR (@Purpose=''probe'' AND @NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''complete'')))
   THROW 51700,''Job/nested owner CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID)
   THROW 51700,''Job membership conflict.'',1;
 END
 ELSE IF @OwnerKind=''preparation''
 BEGIN
  IF @NestedToken IS NOT NULL OR @Epoch IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion AND (@Purpose=''probe'' OR State=''preflight''))
   THROW 51700,''Preparation CAS conflict.'',1;

  DECLARE @EnrollmentPlan nvarchar(max),@EnrollmentProgress nvarchar(max),@EnrollmentHash binary(32);
  SELECT @EnrollmentPlan=RequestJson,@EnrollmentProgress=GenerationJson,@EnrollmentHash=RequestHash
   FROM dbo.ExportPreparation WHERE PreparationID=@ObjectID;
  IF @Purpose=''enrollment''
  BEGIN
   IF JSON_VALUE(@EnrollmentPlan,''$.purpose'') IS NULL OR JSON_VALUE(@EnrollmentPlan,''$.purpose'')<>''output_enrollment''
    OR (DATALENGTH(@ScopeJson)>65536 AND ISNULL(JSON_VALUE(@EnrollmentPlan,''$.version''),'''') NOT IN (''4'',''5''))
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id'')) IS NULL
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id''))<>@SessionID
    OR @RegistrationHash<>@EnrollmentHash OR @SnapshotHash<>@EnrollmentHash
    OR @EnrollmentHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@EnrollmentPlan))
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson))<>2
    OR JSON_QUERY(@ScopeJson,''$.enrollment'') IS NULL
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'') IS NULL
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') IS NULL
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>JSON_VALUE(@EnrollmentProgress,''$.phase'')
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal''))<>TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal''))
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') NOT IN (''create'',''verify'')
    THROW 51700,''Exact authority-side enrollment phase required.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    THROW 51700,''Enrollment phase already has a stream; never replay.'',1;
  END
  ELSE IF JSON_VALUE(@EnrollmentPlan,''$.purpose'')=''output_enrollment''
   THROW 51700,''Enrollment cannot become ordinary configuration authority.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID)
   THROW 51700,''Preparation membership conflict.'',1;
 END
 ELSE
 BEGIN
  -- Pool lock follows resource locks, matching the Bot''s operation DAL.
  DECLARE @PoolID uniqueidentifier,@PoolLock nvarchar(255),@PoolLockResult int;
  SELECT @PoolID=PoolID FROM KVK.SourceOutputOperation WHERE OperationID=@ObjectID AND AccountKey=@AccountKey;
  IF @PoolID IS NULL THROW 51700,''Output operation pool is unavailable.'',1;
  SET @PoolLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @PoolLockResult=sys.sp_getapplock @Resource=@PoolLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @PoolLockResult<0 THROW 51700,''Output operation pool busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM KVK.SourceOutputPool WITH (UPDLOCK,HOLDLOCK)
   WHERE PoolID=@PoolID AND AccountKey=@AccountKey AND PoolState=''closing''
    AND OwnerID=@ObjectID AND Epoch=@Epoch AND RegistrationHash=@RegistrationHash)
   THROW 51700,''Output operation registration/epoch changed.'',1;
  IF @NestedToken IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM KVK.SourceOutputOperation WITH (UPDLOCK,HOLDLOCK) WHERE OperationID=@ObjectID AND AccountKey=@AccountKey
    AND PoolID=@PoolID AND Fence=@Fence AND Version=@ClaimVersion AND OldEpoch=@Epoch
    AND ((OwnerID=@OwnerID AND (@Purpose=''probe'' OR State=''running''))
      OR (@Purpose=''probe'' AND @OwnerID IS NULL AND OwnerID IS NULL AND Fence=0 AND State=''closing'' AND Phase=''draining'')))
   THROW 51700,''Output operation CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID)
   THROW 51700,''Output operation membership conflict.'',1;
 END;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

  IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK) WHERE StreamID=@StreamID OR ActiveAccountKey=@AccountKey)
   THROW 51700,''Stream/account already registered; no automatic adoption.'',1;
  INSERT dbo.ExportExecutionStream VALUES (@StreamID,@SessionID,@AccountKey,@AccountKey,
   CASE WHEN @OwnerKind=''job'' THEN @ObjectID END,CASE WHEN @OwnerKind=''preparation'' THEN @ObjectID END,
   CASE WHEN @OwnerKind=''operation'' THEN @ObjectID END,@OwnerID,@Fence,@ClaimVersion,@NestedToken,@RegistrationHash,
   @Epoch,@SnapshotHash,@ScopeJson,@Purpose,''open'',1,0,@ChildIdentity,NULL,NULL,NULL,SYSUTCDATETIME(),NULL);
 END
 ELSE
 BEGIN
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

  IF @Action=''freeze'' AND DATALENGTH(@Action)=6
  BEGIN
   UPDATE dbo.ExportExecutionStream SET State=''frozen'',Version=Version+1
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion AND State=''open'';
   IF @@ROWCOUNT<>1 THROW 51700,''Stream freeze CAS lost.'',1;
  END
  ELSE IF @Action=''close'' AND DATALENGTH(@Action)=5 AND @ClosureHash IS NOT NULL AND @ChildIdentity IS NOT NULL
    AND @ClosureReference IS NOT NULL AND @EventDigest IS NOT NULL AND @LastSequence IS NOT NULL
  BEGIN
   -- Preserve complete abandoned read prefixes; closure is not a successful observation.
   -- The trusted parent must still prove exact child termination and seal every event.
   IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID
    AND NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e
     WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'',''unknown''))
    AND NOT (r.RequestKind=''read''
     AND EXISTS (SELECT 1 FROM dbo.ExportExecutionStream s
      WHERE s.StreamID=r.StreamID AND s.Purpose=''probe'')
     AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e
      WHERE e.RequestID=r.RequestID AND e.State=''prepared'')
     AND NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e
      WHERE e.RequestID=r.RequestID AND e.State NOT IN (''prepared'',''dispatch_intent''))))
    THROW 51700,''Nonterminal request evidence prevents stream closure.'',1;
   -- Trusted parent supplies OS-handle closure evidence, not a caller Boolean.
   UPDATE dbo.ExportExecutionStream SET State=''closed'',ActiveAccountKey=NULL,Version=Version+1,ClosureHash=@ClosureHash,ClosureReference=@ClosureReference,EventDigest=@EventDigest,ClosedUTC=SYSUTCDATETIME()
   WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey AND Version=@ExpectedVersion
    AND ChildIdentity=@ChildIdentity AND State=''frozen'' AND LastSequence=@LastSequence;
   IF @@ROWCOUNT<>1 THROW 51700,''Stream close CAS lost.'',1;
  END
  ELSE THROW 51700,''Unsupported stream action.'',1;
 END;
 SELECT * FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;';

EXEC sys.sp_executesql N'ALTER PROCEDURE dbo.usp_ExportProviderRequestEventAppend
 @SessionID uniqueidentifier,
 @StreamID uniqueidentifier,
 @AccountKey varchar(128),
 @ExpectedVersion bigint,
 @RequestID uniqueidentifier,
 @EventID uniqueidentifier,
 @State varchar(32),
 @EvidenceHash binary(32),
 @EvidenceReference uniqueidentifier,
 @Operation varchar(64)=NULL,
 @RequestKind varchar(16)=NULL,
 @TargetID varchar(128)=NULL,
 @PayloadHash binary(32)=NULL,
 @PayloadReference uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;

 DECLARE @OwnerKind varchar(16),@ObjectID uniqueidentifier,@OwnerID uniqueidentifier,@Fence bigint,@ClaimVersion bigint,
 @NestedToken uniqueidentifier,@Epoch bigint,@ScopeJson nvarchar(max),@Purpose varchar(16),@RegistrationHash binary(32),@SnapshotHash binary(32);
 SELECT @OwnerKind=CASE WHEN JobID IS NOT NULL THEN ''job'' WHEN PreparationID IS NOT NULL THEN ''preparation'' ELSE ''operation'' END,
 @ObjectID=COALESCE(JobID,PreparationID,OutputOperationID),@OwnerID=OwnerID,@Fence=Fence,@ClaimVersion=ClaimVersion,
 @NestedToken=NestedToken,@Epoch=Epoch,@ScopeJson=ScopeJson,@Purpose=Purpose,@RegistrationHash=RegistrationHash,@SnapshotHash=SnapshotHash
 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND AccountKey=@AccountKey AND SessionID=@SessionID;

 IF @State IN (''prepared'',''dispatch_intent'')
 BEGIN

 -- Account lock precedes sorted resource locks; stream row is locked last.
 IF @AccountKey IS NULL OR @Fence IS NULL OR @ClaimVersion IS NULL OR @ClaimVersion<=0
 OR (@OwnerID IS NULL AND NOT (@OwnerKind=''operation'' AND @Purpose=''probe'' AND @Fence=0 AND @NestedToken IS NULL))
 OR (@OwnerID IS NOT NULL AND @Fence<=0)
 OR @OwnerKind NOT IN (''job'',''preparation'',''operation'') OR @OwnerKind IS NULL
 OR DATALENGTH(@OwnerKind)<>LEN(@OwnerKind) OR @ObjectID IS NULL
 OR @Purpose NOT IN (''mutation'',''probe'',''enrollment'') OR @Purpose IS NULL OR DATALENGTH(@Purpose)<>LEN(@Purpose)
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>65536
 THROW 51700,''Complete typed stream scope required.'',1;
 DECLARE @Resources TABLE (ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 IF JSON_QUERY(@ScopeJson,''$.resources'') IS NULL THROW 51700,''Complete resource membership required.'',1;
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ScopeJson,''$.resources'')
 WITH (ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
 IF NOT EXISTS (SELECT 1 FROM @Resources WHERE ResourceKey=''account:''+@AccountKey)
 OR (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 1 AND 1025 OR EXISTS (SELECT 1 FROM @Resources WHERE Version<=0)
 THROW 51700,''Invalid resource membership.'',1;
 IF @Purpose=''probe'' AND EXISTS (SELECT 1 FROM dbo.ExportResource r JOIN dbo.ExportPreparation p ON p.PreparationID=r.ActivePreparationID
    WHERE p.AccountKey=@AccountKey AND r.ResourceKind=''sql_snapshot'' AND r.OwnerID IS NOT NULL)
  THROW 51700,''Owned SQL producer must drain before observational probe.'',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint,@ResourceLock nvarchar(255),@ResourceResult int;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @ResourceLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @ResourceResult=sys.sp_getapplock @Resource=@ResourceLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @ResourceResult<0 THROW 51700,''Resource admission busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportResource WITH (UPDLOCK,HOLDLOCK)
    WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion
    AND (@Purpose=''probe'' OR BlockedReason IS NULL)
    AND ((@Purpose=''probe'' AND OwnerID IS NULL AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
     OR (OwnerID=@OwnerID AND Fence=@Fence AND ((@OwnerKind=''job'' AND ActiveJobID=@ObjectID AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''preparation'' AND ActivePreparationID=@ObjectID AND ActiveJobID IS NULL AND ActiveOutputOperationID IS NULL)
      OR (@OwnerKind=''operation'' AND ActiveOutputOperationID=@ObjectID AND ActiveJobID IS NULL AND ActivePreparationID IS NULL)))))
   THROW 51700,''Resource owner/fence/version conflict.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks;
 DEALLOCATE ResourceLocks;
 IF @Purpose=''enrollment'' AND @OwnerKind<>''preparation'' THROW 51700,''Enrollment requires its preparation owner.'',1;
 IF @OwnerKind=''job''
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
   AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'',''failed'')))
   AND ((PoolEpoch IS NULL AND @Epoch IS NULL) OR PoolEpoch=@Epoch)
   AND ((@NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'') IS NULL)
      OR (@NestedToken IS NOT NULL AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.token''))=@NestedToken
       AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''owned''
       AND (TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion
        OR (@Purpose=''probe'' AND State=''uncertain'' AND @ClaimVersion>1
         AND TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,''$.retirement_recovery.version''))=@ClaimVersion-1)))
      OR (@Purpose=''probe'' AND @NestedToken IS NULL AND JSON_VALUE(ProvenanceJson,''$.retirement_recovery.state'')=''complete'')))
   THROW 51700,''Job/nested owner CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@ObjectID)
   THROW 51700,''Job membership conflict.'',1;
 END
 ELSE IF @OwnerKind=''preparation''
 BEGIN
  IF @NestedToken IS NOT NULL OR @Epoch IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID AND AccountKey=@AccountKey
    AND OwnerID=@OwnerID AND Fence=@Fence AND Version=@ClaimVersion AND (@Purpose=''probe'' OR State=''preflight''))
   THROW 51700,''Preparation CAS conflict.'',1;

  DECLARE @EnrollmentPlan nvarchar(max),@EnrollmentProgress nvarchar(max),@EnrollmentHash binary(32);
  SELECT @EnrollmentPlan=RequestJson,@EnrollmentProgress=GenerationJson,@EnrollmentHash=RequestHash
   FROM dbo.ExportPreparation WHERE PreparationID=@ObjectID;
  IF @Purpose=''enrollment''
  BEGIN
   IF JSON_VALUE(@EnrollmentPlan,''$.version'') IN (''2'',''3'',''4'') AND @State=''prepared'' AND
      (@RequestKind IS NULL OR @Operation IS NULL OR @RequestKind<>''read'' OR @Operation NOT IN (''drive.files.get'',''drive.permissions.list'',''sheets.get'',''sheets.values.batchGet''))
    THROW 51700,''Manual registration admits read-only provider requests.'',1;
   IF JSON_VALUE(@EnrollmentPlan,''$.purpose'') IS NULL OR JSON_VALUE(@EnrollmentPlan,''$.purpose'')<>''output_enrollment''
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id'')) IS NULL
    OR TRY_CONVERT(uniqueidentifier,JSON_VALUE(@EnrollmentProgress,''$.session_id''))<>@SessionID
    OR @RegistrationHash<>@EnrollmentHash OR @SnapshotHash<>@EnrollmentHash
    OR @EnrollmentHash<>HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@EnrollmentPlan))
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson))<>2
    OR JSON_QUERY(@ScopeJson,''$.enrollment'') IS NULL
    OR (SELECT COUNT(*) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@ScopeJson,''$.enrollment''))<>2
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'') IS NULL
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') IS NULL
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>JSON_VALUE(@EnrollmentProgress,''$.phase'')
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal'')) IS NULL
    OR TRY_CONVERT(int,JSON_VALUE(@ScopeJson,''$.enrollment.ordinal''))<>TRY_CONVERT(int,JSON_VALUE(@EnrollmentProgress,''$.next_ordinal''))
    OR JSON_VALUE(@EnrollmentProgress,''$.phase'') NOT IN (''create'',''verify'')
    THROW 51700,''Exact authority-side enrollment phase required.'',1;
   IF EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    AND NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID AND PreparationID=@ObjectID AND ClaimVersion=@ClaimVersion)
    THROW 51700,''Enrollment phase already has a stream; never replay.'',1;
  END
  ELSE IF JSON_VALUE(@EnrollmentPlan,''$.purpose'')=''output_enrollment''
   THROW 51700,''Enrollment cannot become ordinary configuration authority.'',1;
  IF EXISTS (SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportPreparationResource WHERE PreparationID=@ObjectID)
   THROW 51700,''Preparation membership conflict.'',1;
 END
 ELSE
 BEGIN
  -- Pool lock follows resource locks, matching the Bot''s operation DAL.
  DECLARE @PoolID uniqueidentifier,@PoolLock nvarchar(255),@PoolLockResult int;
  SELECT @PoolID=PoolID FROM KVK.SourceOutputOperation WHERE OperationID=@ObjectID AND AccountKey=@AccountKey;
  IF @PoolID IS NULL THROW 51700,''Output operation pool is unavailable.'',1;
  SET @PoolLock=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @PoolLockResult=sys.sp_getapplock @Resource=@PoolLock,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @PoolLockResult<0 THROW 51700,''Output operation pool busy.'',1;
  IF NOT EXISTS (SELECT 1 FROM KVK.SourceOutputPool WITH (UPDLOCK,HOLDLOCK)
   WHERE PoolID=@PoolID AND AccountKey=@AccountKey AND PoolState=''closing''
    AND OwnerID=@ObjectID AND Epoch=@Epoch AND RegistrationHash=@RegistrationHash)
   THROW 51700,''Output operation registration/epoch changed.'',1;
  IF @NestedToken IS NOT NULL OR NOT EXISTS
   (SELECT 1 FROM KVK.SourceOutputOperation WITH (UPDLOCK,HOLDLOCK) WHERE OperationID=@ObjectID AND AccountKey=@AccountKey
    AND PoolID=@PoolID AND Fence=@Fence AND Version=@ClaimVersion AND OldEpoch=@Epoch
    AND ((OwnerID=@OwnerID AND (@Purpose=''probe'' OR State=''running''))
      OR (@Purpose=''probe'' AND @OwnerID IS NULL AND OwnerID IS NULL AND Fence=0 AND State=''closing'' AND Phase=''draining'')))
   THROW 51700,''Output operation CAS conflict.'',1;
  IF EXISTS (SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS (SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM KVK.SourceOutputOperationResource WHERE OperationID=@ObjectID)
   THROW 51700,''Output operation membership conflict.'',1;
 END;

 END;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

 DECLARE @StreamState varchar(16),@LastSequence bigint,@Version bigint;
 SELECT @StreamState=State,@LastSequence=LastSequence,@Version=Version
 FROM dbo.ExportExecutionStream WITH (UPDLOCK,HOLDLOCK)
 WHERE StreamID=@StreamID AND SessionID=@SessionID AND AccountKey=@AccountKey;
 IF @ExpectedVersion IS NULL OR @Version IS NULL OR @Version<>@ExpectedVersion OR @StreamState NOT IN (''open'',''frozen'')
  THROW 51700,''Request stream CAS lost or closed.'',1;
 IF @State IS NULL OR DATALENGTH(@State)<>LEN(@State) THROW 51700,''Canonical event state required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE EventID=@EventID)
  THROW 51700,''Event already exists; read immutable event before retry.'',1;
 DECLARE @Previous varchar(32),@EventSequence int;
 IF (@State=''prepared'' AND EXISTS(SELECT 1 FROM dbo.ExportActiveContainedTarget WITH (HOLDLOCK) WHERE FileID=@TargetID))
  OR (@State=''dispatch_intent'' AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r
   JOIN dbo.ExportActiveContainedTarget t WITH (HOLDLOCK) ON t.FileID=r.TargetID WHERE r.RequestID=@RequestID))
  THROW 51700,''Permanently isolated target: provider dispatch is forbidden.'',1;
 -- Recheck the persisted stream owner at both preparation and dispatch. A
 -- released legacy target never grants managed-pool or enrollment authority.
 IF ((@State=''prepared'' AND EXISTS(SELECT 1 FROM dbo.ExportContainedTarget WITH (HOLDLOCK) WHERE FileID=@TargetID))
  OR (@State=''dispatch_intent'' AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r
   JOIN dbo.ExportContainedTarget t WITH (HOLDLOCK) ON t.FileID=r.TargetID WHERE r.RequestID=@RequestID)))
  AND NOT (@NestedToken IS NULL AND @Epoch IS NULL AND
   ((@OwnerKind=''job'' AND @Purpose=''mutation'' AND EXISTS
     (SELECT 1 FROM dbo.ExportJob WITH (UPDLOCK,HOLDLOCK) WHERE JobID=@ObjectID
      AND ConsumerKind IN (''scan_data'',''all_kvk'') AND PoolEpoch IS NULL AND SourceKey IS NULL AND IntentID IS NULL))
    OR (@OwnerKind=''preparation'' AND @Purpose=''probe'' AND EXISTS
     (SELECT 1 FROM dbo.ExportPreparation WITH (UPDLOCK,HOLDLOCK) WHERE PreparationID=@ObjectID
      AND ConsumerKind=''config'' AND KVK_NO IS NULL AND JobID IS NULL AND GenerationJson IS NULL
      AND ISNULL(JSON_VALUE(RequestJson,''$.purpose''),'''')<>''output_enrollment''))))
  THROW 51700,''Historical target isolation permits only legacy export or configuration read.'',1;

 IF @State=''prepared''
 BEGIN
  IF @StreamState<>''open'' OR (@Purpose=''probe'' AND @RequestKind<>''read'')
   THROW 51700,''Stream cannot prepare this request.'',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=@StreamID AND NOT EXISTS
    (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'',''unknown'')))
   THROW 51700,''Only one outstanding request per stream.'',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
   WHERE r.StreamID=@StreamID AND r.RequestKind=''mutation'' AND e.State=''unknown'')
   THROW 51700,''Unknown mutation requires reconciliation.'',1;
  IF @Operation=''sheets.create''
  BEGIN
   IF @Purpose<>''enrollment'' OR @RequestKind<>''mutation'' OR @OwnerKind<>''preparation''
    OR JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>''create''
    OR @TargetID<>LOWER(CONVERT(varchar(36),@ObjectID)) OR DATALENGTH(@TargetID)<>36
    OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID)
    THROW 51700,''Only one fixed create per fresh enrollment phase.'',1;
  END
  ELSE
  BEGIN
   IF NOT EXISTS (SELECT 1 FROM OPENJSON(@ScopeJson,''$.resources'') WITH (ResourceKey varchar(256) ''$.key'') WHERE ResourceKey=''destination:''+@TargetID)
    THROW 51700,''Request target is outside owned resources.'',1;
   IF @Purpose=''enrollment'' AND (JSON_VALUE(@ScopeJson,''$.enrollment.phase'')<>''verify''
    OR @Operation NOT IN (''drive.permissions.create'',''drive.files.get'',''drive.permissions.list'',''sheets.get'',''sheets.values.batchGet''))
    THROW 51700,''Enrollment permits only Editor grant and fixed readback.'',1;
   IF @Purpose=''enrollment'' AND @Operation=''drive.permissions.create''
    AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE StreamID=@StreamID AND TargetID=@TargetID AND Operation=@Operation)
    THROW 51700,''Editor grant cannot be replayed.'',1;
  END;
  INSERT dbo.ExportProviderRequest VALUES (@RequestID,@StreamID,@LastSequence+1,@Operation,@RequestKind,@TargetID,@PayloadHash,@PayloadReference,SYSUTCDATETIME());
  SET @EventSequence=1;
  UPDATE dbo.ExportExecutionStream SET LastSequence=LastSequence+1 WHERE StreamID=@StreamID;
 END
 ELSE
 BEGIN
  IF NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequest WHERE RequestID=@RequestID AND StreamID=@StreamID)
   THROW 51700,''Request identity differs.'',1;
  IF @State=''dispatch_intent'' AND @OwnerKind=''job''
   AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest WHERE RequestID=@RequestID AND RequestKind=''mutation'')
   AND NOT EXISTS(SELECT 1 FROM dbo.ExportAttempt WHERE JobID=@ObjectID AND OwnerID=@OwnerID AND Fence=@Fence AND Phase IN (''private_started'',''verified'',''publication_pending''))
   THROW 51700,''A durable owned attempt must precede mutation dispatch.'',1;
  SELECT TOP(1) @Previous=State,@EventSequence=EventSequence+1 FROM dbo.ExportProviderRequestEvent WHERE RequestID=@RequestID ORDER BY EventSequence DESC;
  IF NOT ((@Previous=''prepared'' AND @State=''not_sent'') OR (@Previous=''prepared'' AND @State=''dispatch_intent'' AND @StreamState=''open'')
    OR (@Previous=''dispatch_intent'' AND @State IN (''succeeded'',''unknown'')))
   OR @Previous IS NULL THROW 51700,''Invalid or terminal request transition; never replay.'',1;
 END;
 INSERT dbo.ExportProviderRequestEvent VALUES (@EventID,@RequestID,@EventSequence,@State,@EvidenceHash,@EvidenceReference,SYSUTCDATETIME());
 UPDATE dbo.ExportExecutionStream SET Version=Version+1 WHERE StreamID=@StreamID;
 SELECT * FROM dbo.ExportExecutionStream WHERE StreamID=@StreamID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;';

EXEC sys.sp_executesql N'ALTER PROCEDURE dbo.usp_ExportReconciliationProofIssue
 @SessionID uniqueidentifier,
 @ProofID uniqueidentifier,
 @AccountKey varchar(128),
 @SnapshotHash binary(32),
 @RegistrationHash binary(32),
 @ProofKind varchar(32),
 @Outcome varchar(16),
 @MembershipJson nvarchar(max),
 @EvidenceJson nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,''Export admission busy.'',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'')
 THROW 51700,''Exact open authority session required.'',1;

 IF @MembershipJson IS NULL OR ISJSON(@MembershipJson)<>1 OR DATALENGTH(@MembershipJson)>65536
 OR @EvidenceJson IS NULL OR ISJSON(@EvidenceJson)<>1 OR DATALENGTH(@EvidenceJson)>65536
  THROW 51700,''Bounded proof evidence required.'',1;
 IF JSON_VALUE(@EvidenceJson,''$.state'') IS NULL OR JSON_VALUE(@EvidenceJson,''$.snapshot_hash'') IS NULL
 OR JSON_VALUE(@EvidenceJson,''$.state'') COLLATE Latin1_General_100_BIN2<>@Outcome COLLATE Latin1_General_100_BIN2
 OR JSON_VALUE(@EvidenceJson,''$.snapshot_hash'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(64),@SnapshotHash,2)) COLLATE Latin1_General_100_BIN2
  THROW 51700,''Proof body differs from immutable outcome/snapshot.'',1;
 -- v2 seals the complete registered-file catalogue without truncating retained
 -- history into a bounded stream-ID list. Parent verifies each private journal.
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson))<>4
 OR EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key] NOT IN (''version'',''targets'',''history'',''probe''))
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson))<>4
 OR JSON_VALUE(@MembershipJson,''$.version'') IS NULL OR JSON_VALUE(@MembershipJson,''$.version'')<>''2''
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''version'' AND type=2)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''targets'' AND type=4)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''history'' AND type=5)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]=''probe'' AND type=5)
  THROW 51700,''Versioned complete catalogue membership required.'',1;
 DECLARE @Targets TABLE (FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY);
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.targets'')) NOT BETWEEN 1 AND 17
 OR EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.targets'') WHERE type<>1 OR DATALENGTH(value) NOT BETWEEN 6 AND 256
  OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^-A-Za-z0-9_]%'')
  THROW 51700,''Bounded exact registered targets required.'',1;
 IF EXISTS (SELECT 1 FROM (SELECT value,LAG(value) OVER (ORDER BY CONVERT(int,[key])) AS Previous
  FROM OPENJSON(@MembershipJson,''$.targets'')) q WHERE Previous COLLATE Latin1_General_100_BIN2>=value COLLATE Latin1_General_100_BIN2)
  THROW 51700,''Targets must be unique and canonically ordered.'',1;
 INSERT @Targets SELECT CONVERT(varchar(128),value) FROM OPENJSON(@MembershipJson,''$.targets'');
 IF EXISTS(SELECT 1 FROM @Targets t JOIN dbo.ExportContainedTarget c WITH (HOLDLOCK) ON c.FileID=t.FileID)
  THROW 51700,''Isolated targets cannot establish current publication or replacement proof.'',1;
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.history''))<>2
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson,''$.history''))<>2
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.history'') WHERE [key]=''count'' AND type=2)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.history'') WHERE [key]=''sha256'' AND type=1)
 OR (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,''$.probe''))<>2
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson,''$.probe''))<>2
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.probe'') WHERE [key]=''stream_id'' AND type=1)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,''$.probe'') WHERE [key]=''version'' AND type=2)
  THROW 51700,''Exact history seal and fresh probe identity required.'',1;
 DECLARE @ExpectedCount bigint=TRY_CONVERT(bigint,JSON_VALUE(@MembershipJson,''$.history.count'')),
  @HistoryHashText nvarchar(4000)=JSON_VALUE(@MembershipJson,''$.history.sha256''),
  @ProbeID uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@MembershipJson,''$.probe.stream_id'')),
  @ProbeVersion bigint=TRY_CONVERT(bigint,JSON_VALUE(@MembershipJson,''$.probe.version''));
 IF @ExpectedCount IS NULL OR @ExpectedCount<0 OR @ProbeID IS NULL OR @ProbeVersion IS NULL OR @ProbeVersion<=0
 OR @HistoryHashText IS NULL OR DATALENGTH(@HistoryHashText)<>128 OR @HistoryHashText COLLATE Latin1_General_100_BIN2 LIKE ''%[^0-9a-f]%''
 OR DATALENGTH(JSON_VALUE(@MembershipJson,''$.probe.stream_id''))<>72
 OR JSON_VALUE(@MembershipJson,''$.probe.stream_id'') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),@ProbeID)) COLLATE Latin1_General_100_BIN2
  THROW 51700,''Canonical historical count/hash and probe identity required.'',1;
 -- A blank current file is not a creation history. Only sealed managed origins
 -- can enter automatic finality. Old/unproven files remain operator reconciliation.
 IF EXISTS(SELECT 1 FROM @Targets t WHERE NOT EXISTS(SELECT 1 FROM (SELECT FileID,Stage,PreparationID FROM dbo.ExportManagedFileOrigin UNION ALL SELECT FileID,Stage,PreparationID FROM dbo.ExportManualFileOrigin) o
   JOIN dbo.ExportPreparation p ON p.PreparationID=o.PreparationID
   WHERE o.FileID=t.FileID AND o.Stage=''eligible'' AND p.AccountKey=@AccountKey AND p.State=''completed'')
   AND NOT EXISTS(SELECT 1 FROM dbo.ExportReplacementActivation a
    JOIN dbo.ExportReplacementTarget replacement ON replacement.ReplacementID=a.ReplacementID
    JOIN dbo.ExportReplacementVerification v ON v.VerificationID=a.VerificationID AND v.ReplacementID=a.ReplacementID
    JOIN dbo.ExportPreparation prep ON prep.PreparationID=v.PreparationID
    WHERE replacement.NewFileID=t.FileID AND a.AccountKey=@AccountKey AND a.NewPoolID IS NOT NULL
     AND v.State=''verified'' AND v.Version=2 AND prep.State=''completed'' AND prep.AccountKey=a.AccountKey AND prep.RequestHash=v.PlanHash))
  THROW 51700,''Complete authenticated managed-file origins required.'',1;
 DECLARE @Members TABLE (StreamID uniqueidentifier NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 INSERT @Members SELECT s.StreamID,s.Version FROM dbo.ExportExecutionStream s WITH (UPDLOCK,HOLDLOCK)
 WHERE s.AccountKey=@AccountKey AND (EXISTS (SELECT 1 FROM OPENJSON(s.ScopeJson,''$.resources'')
  WITH (ResourceKey varchar(256) ''$.key'') r JOIN @Targets t
  ON r.ResourceKey COLLATE Latin1_General_100_BIN2=(''destination:''+t.FileID) COLLATE Latin1_General_100_BIN2)
 OR EXISTS(SELECT 1 FROM (SELECT FileID,Stage,PreparationID FROM dbo.ExportManagedFileOrigin UNION ALL SELECT FileID,Stage,PreparationID FROM dbo.ExportManualFileOrigin) o JOIN @Targets t ON t.FileID=o.FileID
  WHERE o.PreparationID=s.PreparationID AND o.Stage IN (''created'',''registered'')));
 IF NOT EXISTS (SELECT 1 FROM @Members) THROW 51700,''Empty evidence is not proof of historical coverage.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.State NOT IN (''closed'',''read_contained'') OR s.ActiveAccountKey IS NOT NULL OR s.ClosureHash IS NULL OR s.EventDigest IS NULL
    OR (s.State=''read_contained'' AND (s.Purpose NOT IN (''probe'',''enrollment'') OR s.PreparationID IS NULL OR s.JobID IS NOT NULL OR s.OutputOperationID IS NOT NULL
     OR EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r WHERE r.StreamID=s.StreamID AND r.RequestKind<>''read''))))
  THROW 51700,''Exact closed request-stream membership required.'',1;
 DECLARE @CatalogueHash binary(32)=HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),''K98-S11-CATALOGUE-1'')),
  @CatalogueCount bigint=0,@CatalogueID uniqueidentifier,@CatalogueVersion bigint,@CatalogueEvents binary(32);
 DECLARE CatalogueRows CURSOR LOCAL FAST_FORWARD FOR
 SELECT s.StreamID,s.Version,s.EventDigest FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
 WHERE s.StreamID<>@ProbeID ORDER BY LOWER(CONVERT(varchar(36),s.StreamID)) COLLATE Latin1_General_100_BIN2;
 OPEN CatalogueRows;
 FETCH NEXT FROM CatalogueRows INTO @CatalogueID,@CatalogueVersion,@CatalogueEvents;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @CatalogueHash=HASHBYTES(''SHA2_256'',@CatalogueHash+CONVERT(varbinary(max),LOWER(CONVERT(varchar(36),@CatalogueID)))
   +CONVERT(varbinary(max),'':''+CONVERT(varchar(20),@CatalogueVersion)+'':'')+@CatalogueEvents);
  SET @CatalogueCount=@CatalogueCount+1;
  FETCH NEXT FROM CatalogueRows INTO @CatalogueID,@CatalogueVersion,@CatalogueEvents;
 END;
 CLOSE CatalogueRows;
 DEALLOCATE CatalogueRows;
 IF @CatalogueCount<>@ExpectedCount OR @CatalogueHash<>CONVERT(binary(32),@HistoryHashText,2)
  THROW 51700,''Historical writer catalogue changed around the fresh probe.'',1;
 IF NOT EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.StreamID=@ProbeID AND s.Version=@ProbeVersion AND s.Purpose=''probe'' AND s.State=''closed''
   AND s.SnapshotHash=@SnapshotHash AND s.RegistrationHash=@RegistrationHash
   AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
     WHERE r.StreamID=s.StreamID AND r.RequestKind=''read'' AND e.State=''succeeded''))
  THROW 51700,''Fresh snapshot-bound closed probe required.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportProviderRequest r ON r.StreamID=m.StreamID
   JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID
     AND (e.State IN (''succeeded'',''not_sent'') OR
       (s.StreamID<>@ProbeID AND s.Purpose=''probe'' AND r.RequestKind=''read'' AND e.State IN (''prepared'',''dispatch_intent'',''unknown'')))))
  THROW 51700,''Request gaps or unknown outcomes cannot become proof.'',1;
 -- Older successful jobs stay in the complete catalogue, but do not imply that
 -- this publication dispatched a mutation. Cover every stream of its exact job,
 -- including former nested owners, even outside the current registered target set.
 DECLARE @SubjectJob uniqueidentifier=(SELECT JobID FROM dbo.ExportExecutionStream WHERE StreamID=@ProbeID);
 IF @Outcome=''absent'' AND (@ProofKind<>''publication'' OR @SubjectJob IS NULL)
  THROW 51700,''Absence requires an exact publication-job probe.'',1;
 IF @Outcome=''absent'' AND EXISTS (SELECT 1 FROM dbo.ExportExecutionStream s
   JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
   JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
   WHERE s.AccountKey=@AccountKey AND s.JobID=@SubjectJob AND r.RequestKind=''mutation'' AND e.State=''dispatch_intent'')
  THROW 51700,''Dispatched mutation cannot support absence proof.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  THROW 51700,''A live provider writer/probe prevents proof issue.'',1;
 -- Parent authority must attest COMPLETE historical writer coverage and exact
 -- method-specific readback; SQL does not infer provider truth from row presence.
 INSERT dbo.ExportReconciliationProof VALUES (@ProofID,@SessionID,@AccountKey,@SnapshotHash,@RegistrationHash,@ProofKind,@Outcome,
  HASHBYTES(''SHA2_256'',CONVERT(varbinary(max),@MembershipJson)),@MembershipJson,@EvidenceJson,SYSUTCDATETIME());
 SELECT * FROM dbo.ExportReconciliationProof WHERE ProofID=@ProofID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;';

GRANT SELECT ON dbo.ExportLegacyCloseout TO ExportExecutionAuthority,ExportExecutionReader;
GRANT SELECT ON dbo.ExportActiveContainedTarget TO ExportExecutionAuthority,ExportExecutionReader;
DENY INSERT,UPDATE,DELETE,ALTER,TAKE OWNERSHIP ON dbo.ExportLegacyCloseout TO ExportExecutionAuthority,ExportExecutionReader;
DENY INSERT,UPDATE,DELETE,ALTER,TAKE OWNERSHIP ON dbo.ExportActiveContainedTarget TO ExportExecutionAuthority,ExportExecutionReader;
GRANT EXECUTE ON dbo.usp_ExportLegacyCloseout TO ExportExecutionAuthority;
DENY EXECUTE ON dbo.usp_ExportLegacyCloseout TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON dbo.usp_ExportLegacyCloseout TO ExportExecutionAuthority,ExportExecutionReader;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
