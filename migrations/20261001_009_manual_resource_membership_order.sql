/*
MigrationId: 20261001_009_manual_resource_membership_order
Purpose: Create destination membership before claiming its preparation
Author: cwatts
CreatedUtc: 2026-10-01
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
*/
-- Apply after 007 and 008. No table or receipt changes.
-- Retains account/resource locks, both FKs, and the enclosing atomic transaction.
-- Exact old/new stored body hashes derive from reviewed source, not runtime discovery.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51724,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51724,'Schema busy.',1;
DECLARE @ObjectID int=OBJECT_ID(N'dbo.usp_ExportManualOutputEnrollmentTransition',N'P');
DECLARE @Installed nvarchar(max)=OBJECT_DEFINITION(@ObjectID);
IF @Installed IS NULL OR NOT (
 (DATALENGTH(@Installed)=39360 AND HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))=0x1d583ee11fdf3e96896bd36cdf7e0cdf8deef5fdb9e5473c883a8a58f7490dd2) OR
 (DATALENGTH(@Installed)= 39822 AND HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))=0x3ae857b51e938806feeb09b4639dd99fc61d3222dd061b6f0bdba14185dee60f))
 THROW 51724,'Exact manual module predecessor/postimage required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID)
 THROW 51724,'Unexpected module signature; preserve and review.',1;
IF HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x3ae857b51e938806feeb09b4639dd99fc61d3222dd061b6f0bdba14185dee60f
BEGIN
DECLARE @Apply nvarchar(max)=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportManualOutputEnrollmentTransition
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
END;';
EXEC sys.sp_executesql @Apply;
END;
SET @Installed=OBJECT_DEFINITION(@ObjectID);
IF @Installed IS NULL OR DATALENGTH(@Installed)<>39822 OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x3ae857b51e938806feeb09b4639dd99fc61d3222dd061b6f0bdba14185dee60f
 THROW 51724,'Exact corrected manual module postimage required.',1;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
