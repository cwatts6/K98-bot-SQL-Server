/*
MigrationId: 20260929_001_manual_export_registration
Purpose: Append-only manual file registration with existing service-account verification
Author: cwatts
CreatedUtc: 2026-09-29
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact S11 source modules and separately approved target/restore packet
PostValidationQuery: Manual table/transition shape, restricted permissions and no provider mutation
RelatedBotPR:
RelatedSQLPR:
*/
-- AUTHORING ONLY. No execution authorization. Preserve all prior origin rows.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51720,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51720,'Schema busy.',1;
IF OBJECT_ID(N'dbo.ExportManagedFileOrigin',N'U') IS NULL OR DATABASE_PRINCIPAL_ID(N'ExportExecutionAuthority') IS NULL OR DATABASE_PRINCIPAL_ID(N'ExportExecutionReader') IS NULL
 THROW 51720,'S11 prerequisites missing.',1;
IF (CASE WHEN OBJECT_ID(N'dbo.ExportManualFileOrigin') IS NULL THEN 0 ELSE 1 END + CASE WHEN OBJECT_ID(N'dbo.usp_ExportManualOutputEnrollmentTransition') IS NULL THEN 0 ELSE 1 END) NOT IN (0,2)
 THROW 51720,'Partial manual installation; preserve and review.',1;
IF OBJECT_ID(N'dbo.usp_ExportManualOutputEnrollmentTransition') IS NOT NULL AND (OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportManualOutputEnrollmentTransition',N'P')) IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportManualOutputEnrollmentTransition',N'P')) COLLATE Latin1_General_100_BIN2 NOT IN (N'CREATE OR ALTER PROCEDURE dbo.usp_ExportManualOutputEnrollmentTransition
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
 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey) OR @AccountKey LIKE ''%[^A-Za-z0-9_.@:-]%'' COLLATE Latin1_General_100_BIN2
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
 IF @Action=''begin''
 BEGIN
  IF @ExpectedVersion<>0 OR @Fence IS NOT NULL OR @ResourcesJson IS NOT NULL
   OR @PlanJson IS NULL OR ISJSON(@PlanJson)<>1 OR DATALENGTH(@PlanJson)>65536
   OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
   THROW 51700,''Fresh protected enrollment plan required.'',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@PlanJson))<>13 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@PlanJson))<>13
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''purpose'',''account'',''storage_owner'',''owner_email'',''editor_email'',''project_id'',''credential_profile_sha256'',''manifest_sha256'',''file_count'',''plan_id'',''files'',''protected_file_ids''))
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''version'' AND type=2 AND value=''2'')
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''file_count'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 3 AND 17 AND value=CONVERT(varchar(2),TRY_CONVERT(int,value)))
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''file_count'',''files'',''protected_file_ids'') AND (type<>1 OR LEN(value)=0))
   OR JSON_VALUE(@PlanJson,''$.purpose'') COLLATE Latin1_General_100_BIN2<>''output_enrollment''
   OR JSON_VALUE(@PlanJson,''$.account'') COLLATE Latin1_General_100_BIN2<>@AccountKey COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.account''))<>2*DATALENGTH(@AccountKey)
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.purpose''))<>34
   OR JSON_VALUE(@PlanJson,''$.storage_owner'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_.@:-]%''
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
      AND DATALENGTH(value)=2*LEN(value) AND value COLLATE Latin1_General_100_BIN2 NOT LIKE ''%[^A-Za-z0-9_-]%'')
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''sheet_id'' AND type=2 AND TRY_CONVERT(int,value)>=0)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''title'' AND type=1 AND LEN(value) BETWEEN 1 AND 100)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''rows'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 1 AND 10000)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''columns'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 1 AND 10000)
    OR TRY_CONVERT(bigint,JSON_VALUE(j.value,''$.rows''))*TRY_CONVERT(bigint,JSON_VALUE(j.value,''$.columns''))>50000)
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson,''$.protected_file_ids'') WHERE type<>1 OR DATALENGTH(value) NOT BETWEEN 6 AND 256
      OR DATALENGTH(value)<>2*LEN(value) OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_-]%'')
   THROW 51700,''Exact bounded manual file manifest/exclusions required.'',1;
  INSERT @Files SELECT CONVERT(int,j.[key]),JSON_VALUE(j.value,''$.file_id'') FROM OPENJSON(@PlanJson,''$.files'') j;
  IF EXISTS(SELECT 1 FROM @Files f JOIN OPENJSON(@PlanJson,''$.protected_file_ids'') x ON x.value COLLATE Latin1_General_100_BIN2=f.FileID)
   THROW 51700,''Protected manual destination.'',1;
  -- New enrollment never overtakes existing ready work or bypasses uncertainty.
  IF EXISTS (SELECT 1 FROM dbo.ExportJob WHERE AccountKey=@AccountKey AND State IN (''ready'',''running'',''uncertain''))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN (''pending'',''preflight'',''sql_pending'',''writing'',''committed'',''uncertain''))
   OR EXISTS (SELECT 1 FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey AND State IN (''closing'',''ready'',''running'',''uncertain''))
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
  IF (SELECT COUNT_BIG(*) FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK))+
   (SELECT COUNT_BIG(*) FROM dbo.ExportPreparation p WITH(UPDLOCK,HOLDLOCK)
    WHERE JSON_VALUE(p.RequestJson,''$.purpose'')=''output_enrollment''
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
  INSERT dbo.ExportResource(ResourceKey,ResourceKind,ActivePreparationID,OwnerID,Fence,Version)
   SELECT ''destination:''+FileID,''destination'',@PreparationID,@OwnerID,@Fence,2 FROM @Files;
  INSERT dbo.ExportPreparationResource SELECT @PreparationID,''destination:''+FileID FROM @Files;
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
  IF JSON_VALUE(@Plan,''$.version'')<>''2'' OR @Count IS NULL OR @Count NOT BETWEEN 3 AND 17 OR @Next IS NULL
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
   -- Parent verifies private response bytes, exact owner/editor and all blank cells.
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
END;')) THROW 51720,'Module missing or changed; preserve and forward-review.',1;
IF OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend') IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend')) IS NULL OR (OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend',N'P')) COLLATE Latin1_General_100_BIN2 NOT IN (N'CREATE PROCEDURE dbo.usp_ExportProviderRequestEventAppend
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
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'')))
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
 IF @ExpectedVersion IS NULL OR @Version IS NULL OR @Version<>@ExpectedVersion OR @StreamState=''closed''
  THROW 51700,''Request stream CAS lost or closed.'',1;
 IF @State IS NULL OR DATALENGTH(@State)<>LEN(@State) THROW 51700,''Canonical event state required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE EventID=@EventID)
  THROW 51700,''Event already exists; read immutable event before retry.'',1;
 DECLARE @Previous varchar(32),@EventSequence int;
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
END;
',N'CREATE OR ALTER PROCEDURE dbo.usp_ExportProviderRequestEventAppend
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
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'')))
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
   IF JSON_VALUE(@EnrollmentPlan,''$.version'')=''2'' AND @State=''prepared'' AND
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
 IF @ExpectedVersion IS NULL OR @Version IS NULL OR @Version<>@ExpectedVersion OR @StreamState=''closed''
  THROW 51700,''Request stream CAS lost or closed.'',1;
 IF @State IS NULL OR DATALENGTH(@State)<>LEN(@State) THROW 51700,''Canonical event state required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE EventID=@EventID)
  THROW 51700,''Event already exists; read immutable event before retry.'',1;
 DECLARE @Previous varchar(32),@EventSequence int;
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
END;')) THROW 51720,'Module missing or changed; preserve and forward-review.',1;
IF OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue') IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue')) IS NULL OR (OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue',N'P')) COLLATE Latin1_General_100_BIN2 NOT IN (N'CREATE PROCEDURE dbo.usp_ExportReconciliationProofIssue
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
  OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_-]%'')
  THROW 51700,''Bounded exact registered targets required.'',1;
 IF EXISTS (SELECT 1 FROM (SELECT value,LAG(value) OVER (ORDER BY CONVERT(int,[key])) AS Previous
  FROM OPENJSON(@MembershipJson,''$.targets'')) q WHERE Previous COLLATE Latin1_General_100_BIN2>=value COLLATE Latin1_General_100_BIN2)
  THROW 51700,''Targets must be unique and canonically ordered.'',1;
 INSERT @Targets SELECT CONVERT(varchar(128),value) FROM OPENJSON(@MembershipJson,''$.targets'');
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
 IF EXISTS(SELECT 1 FROM @Targets t WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o
   JOIN dbo.ExportPreparation p ON p.PreparationID=o.PreparationID
   WHERE o.FileID=t.FileID AND o.Stage=''eligible'' AND p.AccountKey=@AccountKey AND p.State=''completed''))
  THROW 51700,''Complete authenticated managed-file origins required.'',1;
 DECLARE @Members TABLE (StreamID uniqueidentifier NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 INSERT @Members SELECT s.StreamID,s.Version FROM dbo.ExportExecutionStream s WITH (UPDLOCK,HOLDLOCK)
 WHERE s.AccountKey=@AccountKey AND (EXISTS (SELECT 1 FROM OPENJSON(s.ScopeJson,''$.resources'')
  WITH (ResourceKey varchar(256) ''$.key'') r JOIN @Targets t
  ON r.ResourceKey COLLATE Latin1_General_100_BIN2=(''destination:''+t.FileID) COLLATE Latin1_General_100_BIN2)
 OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o JOIN @Targets t ON t.FileID=o.FileID
  WHERE o.PreparationID=s.PreparationID AND o.Stage=''created''));
 IF NOT EXISTS (SELECT 1 FROM @Members) THROW 51700,''Empty evidence is not proof of historical coverage.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.State<>''closed'' OR s.ActiveAccountKey IS NOT NULL OR s.ClosureHash IS NULL OR s.EventDigest IS NULL)
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
   WHERE s.StreamID=@ProbeID AND s.Version=@ProbeVersion AND s.Purpose=''probe''
   AND s.SnapshotHash=@SnapshotHash AND s.RegistrationHash=@RegistrationHash
   AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
     WHERE r.StreamID=s.StreamID AND r.RequestKind=''read'' AND e.State=''succeeded''))
  THROW 51700,''Fresh snapshot-bound closed probe required.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportProviderRequest r ON r.StreamID=m.StreamID
   WHERE NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'')))
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
END;
',N'CREATE OR ALTER PROCEDURE dbo.usp_ExportReconciliationProofIssue
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
  OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_-]%'')
  THROW 51700,''Bounded exact registered targets required.'',1;
 IF EXISTS (SELECT 1 FROM (SELECT value,LAG(value) OVER (ORDER BY CONVERT(int,[key])) AS Previous
  FROM OPENJSON(@MembershipJson,''$.targets'')) q WHERE Previous COLLATE Latin1_General_100_BIN2>=value COLLATE Latin1_General_100_BIN2)
  THROW 51700,''Targets must be unique and canonically ordered.'',1;
 INSERT @Targets SELECT CONVERT(varchar(128),value) FROM OPENJSON(@MembershipJson,''$.targets'');
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
   WHERE o.FileID=t.FileID AND o.Stage=''eligible'' AND p.AccountKey=@AccountKey AND p.State=''completed''))
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
   WHERE s.State<>''closed'' OR s.ActiveAccountKey IS NOT NULL OR s.ClosureHash IS NULL OR s.EventDigest IS NULL)
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
   WHERE s.StreamID=@ProbeID AND s.Version=@ProbeVersion AND s.Purpose=''probe''
   AND s.SnapshotHash=@SnapshotHash AND s.RegistrationHash=@RegistrationHash
   AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
     WHERE r.StreamID=s.StreamID AND r.RequestKind=''read'' AND e.State=''succeeded''))
  THROW 51700,''Fresh snapshot-bound closed probe required.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportProviderRequest r ON r.StreamID=m.StreamID
   WHERE NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'')))
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
END;')) THROW 51720,'Module missing or changed; preserve and forward-review.',1;
IF OBJECT_ID(N'dbo.ExportManualFileOrigin',N'U') IS NULL EXEC(N'CREATE TABLE dbo.ExportManualFileOrigin
(
 FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Stage varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ParentStage varchar(16) COLLATE Latin1_General_100_BIN2 NULL,
 PreparationID uniqueidentifier NOT NULL,
 Ordinal int NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 PlanHash binary(32) NOT NULL,
 ProfileHash binary(32) NOT NULL,
 VerificationStreamID uniqueidentifier NULL,
 VerificationClosureHash binary(32) NULL,
 EligibilityHash binary(32) NULL,
 EligibilityReference uniqueidentifier NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportManualFileOrigin PRIMARY KEY(FileID,Stage),
 CONSTRAINT UQ_ExportManualFileOrigin_Ordinal UNIQUE(PreparationID,Ordinal,Stage),
 CONSTRAINT FK_ExportManualFileOrigin_Parent FOREIGN KEY(FileID,ParentStage) REFERENCES dbo.ExportManualFileOrigin(FileID,Stage),
 CONSTRAINT FK_ExportManualFileOrigin_Preparation FOREIGN KEY(PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportManualFileOrigin_Session FOREIGN KEY(SessionID) REFERENCES dbo.ExportExecutionSession(SessionID),
 CONSTRAINT FK_ExportManualFileOrigin_Verification FOREIGN KEY(VerificationStreamID,SessionID) REFERENCES dbo.ExportExecutionStream(StreamID,SessionID),
 CONSTRAINT CK_ExportManualFileOrigin_Identity CHECK(DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE ''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16),
 CONSTRAINT CK_ExportManualFileOrigin_Stage CHECK(DATALENGTH(Stage)=LEN(Stage) AND
  ((Stage=''registered'' AND ParentStage IS NULL AND VerificationStreamID IS NULL AND VerificationClosureHash IS NULL AND EligibilityHash IS NULL AND EligibilityReference IS NULL)
   OR (Stage=''eligible'' AND ParentStage IS NOT NULL AND ParentStage=''registered'' AND DATALENGTH(ParentStage)=10 AND VerificationStreamID IS NOT NULL AND VerificationClosureHash IS NOT NULL AND EligibilityHash IS NOT NULL AND EligibilityReference IS NOT NULL)))
);
CREATE INDEX IX_ExportManualFileOrigin_Preparation ON dbo.ExportManualFileOrigin(PreparationID,Stage,Ordinal);
');

CREATE TABLE #ExpectedManual
(
 FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Stage varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ParentStage varchar(16) COLLATE Latin1_General_100_BIN2 NULL,
 PreparationID uniqueidentifier NOT NULL,
 Ordinal int NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 PlanHash binary(32) NOT NULL,
 ProfileHash binary(32) NOT NULL,
 VerificationStreamID uniqueidentifier NULL,
 VerificationClosureHash binary(32) NULL,
 EligibilityHash binary(32) NULL,
 EligibilityReference uniqueidentifier NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportManualFileOrigin PRIMARY KEY(FileID,Stage),
 CONSTRAINT UQ_ExportManualFileOrigin_Ordinal UNIQUE(PreparationID,Ordinal,Stage),
 CONSTRAINT CK_ExportManualFileOrigin_Identity CHECK(DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16),
 CONSTRAINT CK_ExportManualFileOrigin_Stage CHECK(DATALENGTH(Stage)=LEN(Stage) AND
  ((Stage='registered' AND ParentStage IS NULL AND VerificationStreamID IS NULL AND VerificationClosureHash IS NULL AND EligibilityHash IS NULL AND EligibilityReference IS NULL)
   OR (Stage='eligible' AND ParentStage IS NOT NULL AND ParentStage='registered' AND DATALENGTH(ParentStage)=10 AND VerificationStreamID IS NOT NULL AND VerificationClosureHash IS NOT NULL AND EligibilityHash IS NOT NULL AND EligibilityReference IS NOT NULL)))
);
CREATE INDEX IX_ExportManualFileOrigin_Preparation ON #ExpectedManual(PreparationID,Stage,Ordinal);
DECLARE @Actual int=OBJECT_ID(N'dbo.ExportManualFileOrigin'),@Expected int=OBJECT_ID(N'tempdb..#ExpectedManual');
IF EXISTS(SELECT column_id,name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity,is_computed FROM sys.columns WHERE object_id=@Actual EXCEPT SELECT column_id,name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity,is_computed FROM tempdb.sys.columns WHERE object_id=@Expected)
 OR EXISTS(SELECT column_id,name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity,is_computed FROM tempdb.sys.columns WHERE object_id=@Expected EXCEPT SELECT column_id,name,system_type_id,user_type_id,max_length,precision,scale,collation_name,is_nullable,is_identity,is_computed FROM sys.columns WHERE object_id=@Actual)
 THROW 51720,'Manual origin column drift.',1;
IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@Actual)<>2
 OR EXISTS(SELECT definition,is_disabled,is_not_trusted FROM sys.check_constraints WHERE parent_object_id=@Actual EXCEPT SELECT definition,is_disabled,is_not_trusted FROM tempdb.sys.check_constraints WHERE parent_object_id=@Expected)
 OR EXISTS(SELECT definition,is_disabled,is_not_trusted FROM tempdb.sys.check_constraints WHERE parent_object_id=@Expected EXCEPT SELECT definition,is_disabled,is_not_trusted FROM sys.check_constraints WHERE parent_object_id=@Actual)
 THROW 51720,'Manual origin check drift.',1;
IF EXISTS(SELECT type,is_unique,is_primary_key,is_unique_constraint,is_disabled,has_filter,filter_definition FROM sys.indexes WHERE object_id=@Actual EXCEPT SELECT type,is_unique,is_primary_key,is_unique_constraint,is_disabled,has_filter,filter_definition FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@Actual)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR EXISTS(SELECT index_id,column_id,key_ordinal,is_descending_key,is_included_column FROM sys.index_columns WHERE object_id=@Actual EXCEPT SELECT index_id,column_id,key_ordinal,is_descending_key,is_included_column FROM tempdb.sys.index_columns WHERE object_id=@Expected)
 OR EXISTS(SELECT index_id,column_id,key_ordinal,is_descending_key,is_included_column FROM tempdb.sys.index_columns WHERE object_id=@Expected EXCEPT SELECT index_id,column_id,key_ordinal,is_descending_key,is_included_column FROM sys.index_columns WHERE object_id=@Actual)
 THROW 51720,'Manual origin index drift.',1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@Actual)<>4
 OR EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@Actual AND (is_disabled=1 OR is_not_trusted=1 OR delete_referential_action<>0 OR update_referential_action<>0))
 THROW 51720,'Manual origin foreign-key trust drift.',1;
IF EXISTS(SELECT COL_NAME(f.parent_object_id,f.parent_column_id),OBJECT_SCHEMA_NAME(f.referenced_object_id)+'.'+OBJECT_NAME(f.referenced_object_id),COL_NAME(f.referenced_object_id,f.referenced_column_id)
 FROM sys.foreign_key_columns f WHERE f.parent_object_id=@Actual EXCEPT
 SELECT * FROM (VALUES('FileID','dbo.ExportManualFileOrigin','FileID'),('ParentStage','dbo.ExportManualFileOrigin','Stage'),('PreparationID','dbo.ExportPreparation','PreparationID'),('SessionID','dbo.ExportExecutionSession','SessionID'),('VerificationStreamID','dbo.ExportExecutionStream','StreamID'),('SessionID','dbo.ExportExecutionStream','SessionID')) expected(a,b,c))
 OR (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE parent_object_id=@Actual)<>6
 THROW 51720,'Manual origin foreign-key membership drift.',1;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@Actual) THROW 51720,'Unexpected origin trigger.',1;
DROP TABLE #ExpectedManual;
EXEC(N'CREATE OR ALTER PROCEDURE dbo.usp_ExportManualOutputEnrollmentTransition
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
 OR DATALENGTH(@AccountKey)<>LEN(@AccountKey) OR @AccountKey LIKE ''%[^A-Za-z0-9_.@:-]%'' COLLATE Latin1_General_100_BIN2
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
 IF @Action=''begin''
 BEGIN
  IF @ExpectedVersion<>0 OR @Fence IS NOT NULL OR @ResourcesJson IS NOT NULL
   OR @PlanJson IS NULL OR ISJSON(@PlanJson)<>1 OR DATALENGTH(@PlanJson)>65536
   OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
   THROW 51700,''Fresh protected enrollment plan required.'',1;
  IF (SELECT COUNT(*) FROM OPENJSON(@PlanJson))<>13 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@PlanJson))<>13
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''purpose'',''account'',''storage_owner'',''owner_email'',''editor_email'',''project_id'',''credential_profile_sha256'',''manifest_sha256'',''file_count'',''plan_id'',''files'',''protected_file_ids''))
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''version'' AND type=2 AND value=''2'')
   OR NOT EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''file_count'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 3 AND 17 AND value=CONVERT(varchar(2),TRY_CONVERT(int,value)))
   OR EXISTS (SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key] NOT IN (''version'',''file_count'',''files'',''protected_file_ids'') AND (type<>1 OR LEN(value)=0))
   OR JSON_VALUE(@PlanJson,''$.purpose'') COLLATE Latin1_General_100_BIN2<>''output_enrollment''
   OR JSON_VALUE(@PlanJson,''$.account'') COLLATE Latin1_General_100_BIN2<>@AccountKey COLLATE Latin1_General_100_BIN2
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.account''))<>2*DATALENGTH(@AccountKey)
   OR DATALENGTH(JSON_VALUE(@PlanJson,''$.purpose''))<>34
   OR JSON_VALUE(@PlanJson,''$.storage_owner'') COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_.@:-]%''
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
      AND DATALENGTH(value)=2*LEN(value) AND value COLLATE Latin1_General_100_BIN2 NOT LIKE ''%[^A-Za-z0-9_-]%'')
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''sheet_id'' AND type=2 AND TRY_CONVERT(int,value)>=0)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''title'' AND type=1 AND LEN(value) BETWEEN 1 AND 100)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''rows'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 1 AND 10000)
    OR NOT EXISTS(SELECT 1 FROM OPENJSON(j.value) WHERE [key]=''columns'' AND type=2 AND TRY_CONVERT(int,value) BETWEEN 1 AND 10000)
    OR TRY_CONVERT(bigint,JSON_VALUE(j.value,''$.rows''))*TRY_CONVERT(bigint,JSON_VALUE(j.value,''$.columns''))>50000)
   OR EXISTS(SELECT 1 FROM OPENJSON(@PlanJson,''$.protected_file_ids'') WHERE type<>1 OR DATALENGTH(value) NOT BETWEEN 6 AND 256
      OR DATALENGTH(value)<>2*LEN(value) OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_-]%'')
   THROW 51700,''Exact bounded manual file manifest/exclusions required.'',1;
  INSERT @Files SELECT CONVERT(int,j.[key]),JSON_VALUE(j.value,''$.file_id'') FROM OPENJSON(@PlanJson,''$.files'') j;
  IF EXISTS(SELECT 1 FROM @Files f JOIN OPENJSON(@PlanJson,''$.protected_file_ids'') x ON x.value COLLATE Latin1_General_100_BIN2=f.FileID)
   THROW 51700,''Protected manual destination.'',1;
  -- New enrollment never overtakes existing ready work or bypasses uncertainty.
  IF EXISTS (SELECT 1 FROM dbo.ExportJob WHERE AccountKey=@AccountKey AND State IN (''ready'',''running'',''uncertain''))
   OR EXISTS (SELECT 1 FROM dbo.ExportPreparation WHERE AccountKey=@AccountKey AND State IN (''pending'',''preflight'',''sql_pending'',''writing'',''committed'',''uncertain''))
   OR EXISTS (SELECT 1 FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey AND State IN (''closing'',''ready'',''running'',''uncertain''))
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
  IF (SELECT COUNT_BIG(*) FROM KVK.SourceOutputPool WITH(UPDLOCK,HOLDLOCK))+
   (SELECT COUNT_BIG(*) FROM dbo.ExportPreparation p WITH(UPDLOCK,HOLDLOCK)
    WHERE JSON_VALUE(p.RequestJson,''$.purpose'')=''output_enrollment''
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
  INSERT dbo.ExportResource(ResourceKey,ResourceKind,ActivePreparationID,OwnerID,Fence,Version)
   SELECT ''destination:''+FileID,''destination'',@PreparationID,@OwnerID,@Fence,2 FROM @Files;
  INSERT dbo.ExportPreparationResource SELECT @PreparationID,''destination:''+FileID FROM @Files;
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
  IF JSON_VALUE(@Plan,''$.version'')<>''2'' OR @Count IS NULL OR @Count NOT BETWEEN 3 AND 17 OR @Next IS NULL
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
   -- Parent verifies private response bytes, exact owner/editor and all blank cells.
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
END;');
EXEC(N'CREATE OR ALTER PROCEDURE dbo.usp_ExportProviderRequestEventAppend
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
   AND ((@Purpose=''mutation'' AND State=''running'') OR (@Purpose=''probe'' AND State IN (''running'',''uncertain'',''confirmed'')))
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
   IF JSON_VALUE(@EnrollmentPlan,''$.version'')=''2'' AND @State=''prepared'' AND
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
 IF @ExpectedVersion IS NULL OR @Version IS NULL OR @Version<>@ExpectedVersion OR @StreamState=''closed''
  THROW 51700,''Request stream CAS lost or closed.'',1;
 IF @State IS NULL OR DATALENGTH(@State)<>LEN(@State) THROW 51700,''Canonical event state required.'',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent WHERE EventID=@EventID)
  THROW 51700,''Event already exists; read immutable event before retry.'',1;
 DECLARE @Previous varchar(32),@EventSequence int;
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
END;');
EXEC(N'CREATE OR ALTER PROCEDURE dbo.usp_ExportReconciliationProofIssue
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
  OR value COLLATE Latin1_General_100_BIN2 LIKE ''%[^A-Za-z0-9_-]%'')
  THROW 51700,''Bounded exact registered targets required.'',1;
 IF EXISTS (SELECT 1 FROM (SELECT value,LAG(value) OVER (ORDER BY CONVERT(int,[key])) AS Previous
  FROM OPENJSON(@MembershipJson,''$.targets'')) q WHERE Previous COLLATE Latin1_General_100_BIN2>=value COLLATE Latin1_General_100_BIN2)
  THROW 51700,''Targets must be unique and canonically ordered.'',1;
 INSERT @Targets SELECT CONVERT(varchar(128),value) FROM OPENJSON(@MembershipJson,''$.targets'');
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
   WHERE o.FileID=t.FileID AND o.Stage=''eligible'' AND p.AccountKey=@AccountKey AND p.State=''completed''))
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
   WHERE s.State<>''closed'' OR s.ActiveAccountKey IS NOT NULL OR s.ClosureHash IS NULL OR s.EventDigest IS NULL)
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
   WHERE s.StreamID=@ProbeID AND s.Version=@ProbeVersion AND s.Purpose=''probe''
   AND s.SnapshotHash=@SnapshotHash AND s.RegistrationHash=@RegistrationHash
   AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
     WHERE r.StreamID=s.StreamID AND r.RequestKind=''read'' AND e.State=''succeeded''))
  THROW 51700,''Fresh snapshot-bound closed probe required.'',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportProviderRequest r ON r.StreamID=m.StreamID
   WHERE NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN (''succeeded'',''not_sent'')))
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
END;');
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportManualFileOrigin TO public;
GRANT SELECT ON OBJECT::dbo.ExportManualFileOrigin TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportManualFileOrigin TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportManualFileOrigin TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportManualFileOrigin TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportManualOutputEnrollmentTransition TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportManualOutputEnrollmentTransition TO ExportExecutionReader;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
