/*
MigrationId: 20261015_010_configuration_replacement
Purpose: Bounded read-only verification of shared configuration/output replacements
Author: cwatts
CreatedUtc: 2026-10-15
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact reviewed 009 procedure preimages, no unexpected signatures
PostValidationQuery: Exact reviewed procedure postimages
*/
-- Install before Bot/authority rollout and protected contract reissue.
-- No provider requests, admission release, state changes or new permissions.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51731,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51731,'Schema busy.',1;
DECLARE @ObjectID int,@Installed nvarchar(max),@Apply nvarchar(max);
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementVerificationTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x3f867f51b61190ebf9b3f37fcec3f8a8f342a78b0f3c5507ab0c19fbe163d9eb
 THROW 51731,'Exact reviewed configuration replacement predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51731,'Unexpected signature; preserve and review.',1;
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
  JOIN dbo.ExportJob j ON j.JobID=c.JobID WHERE p.ReplacementID=@ReplacementID AND p.AccountKey=@AccountKey
   AND c.AccountKey=@AccountKey AND j.AccountKey=@AccountKey AND j.State=''uncertain'')
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
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey AND State IN (''closing'',''ready'',''running'',''uncertain''))
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x1d1865ee04623d96c730c014b3d900611dcfe552db6cf03492aa33106e34ffea
 THROW 51731,'Exact reviewed configuration replacement postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x010fcd7e6895faa7888ce20b582f3567163be903cd7b4fbe10faf0640d94e31d
 THROW 51731,'Exact reviewed configuration replacement predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51731,'Unexpected signature; preserve and review.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportExecutionStreamTransition
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
 IF EXISTS (SELECT 1 FROM @Resources r JOIN dbo.ExportContainedTarget t WITH (HOLDLOCK)
  ON r.ResourceKey=(''destination:''+t.FileID) COLLATE Latin1_General_100_BIN2)
  THROW 51700,''A permanently isolated target cannot enter another provider stream.'',1;
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
END;
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x5a1f5e31100bddb1bf66e3072697eeb5d5e601da7455b2b8e8efcbe6d2d274ca
 THROW 51731,'Exact reviewed configuration replacement postimage required.',1;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
