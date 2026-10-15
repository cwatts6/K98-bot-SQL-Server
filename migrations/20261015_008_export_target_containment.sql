/*
MigrationId: 20261015_008_export_target_containment
Purpose: Permanent physical-target isolation with exact atomic owner release
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
PreValidationQuery: Reviewed 007 modules and trusted stream constraint; all new objects absent
PostValidationQuery: Exact module postimages, trusted state constraint and immutable evidence permissions
*/
-- Install before coordinated protected authority/Bot rollout. No existing owner
-- or physical target is released/retired by installation. Retain all history.
-- The migration runner records success; existing/partial new objects are refused.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51726,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51726,'Schema busy.',1;
IF DATABASE_PRINCIPAL_ID(N'ExportExecutionAuthority') IS NULL OR DATABASE_PRINCIPAL_ID(N'ExportExecutionReader') IS NULL
 THROW 51726,'Installed reviewed execution roles required.',1;
IF OBJECT_ID(N'dbo.ExportTargetContainment') IS NOT NULL THROW 51726,'Containment object already exists; verify migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.ExportContainedTarget') IS NOT NULL THROW 51726,'Containment object already exists; verify migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.ExportContainedStream') IS NOT NULL THROW 51726,'Containment object already exists; verify migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.usp_ExportJobContainTargets') IS NOT NULL THROW 51726,'Containment object already exists; verify migration history before forward repair.',1;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Permanent isolation decisions. No expiry, undo or target-reuse transition exists.
CREATE TABLE dbo.ExportTargetContainment
(
 ContainmentID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 JobID uniqueidentifier NULL,
 OutputOperationID uniqueidentifier NULL,
 PreparationID uniqueidentifier NULL,
 OwnerVersion bigint NOT NULL,
 OwnerID uniqueidentifier NOT NULL,
 Fence bigint NOT NULL,
 SnapshotHash binary(32) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportTargetContainment PRIMARY KEY (ContainmentID),
 CONSTRAINT CK_ExportTargetContainment_Owner CHECK ((CASE WHEN JobID IS NULL THEN 0 ELSE 1 END + CASE WHEN OutputOperationID IS NULL THEN 0 ELSE 1 END + CASE WHEN PreparationID IS NULL THEN 0 ELSE 1 END)=1),
 CONSTRAINT CK_ExportTargetContainment_Counters CHECK (OwnerVersion>0 AND Fence>0),
 CONSTRAINT CK_ExportTargetContainment_Text CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=LEN(AccountKey) AND AccountKey NOT LIKE '%[^A-Za-z0-9_.@:-]%' COLLATE Latin1_General_100_BIN2 AND LEN(Actor)>0 AND LEN(Reason)>0),
 CONSTRAINT FK_ExportTargetContainment_Job FOREIGN KEY (JobID) REFERENCES dbo.ExportJob(JobID),
 CONSTRAINT FK_ExportTargetContainment_Operation FOREIGN KEY (OutputOperationID) REFERENCES KVK.SourceOutputOperation(OperationID),
 CONSTRAINT FK_ExportTargetContainment_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID)
);
CREATE INDEX IX_ExportTargetContainment_Account ON dbo.ExportTargetContainment(AccountKey,CreatedUTC,ContainmentID);
CREATE UNIQUE INDEX UX_ExportTargetContainment_Job ON dbo.ExportTargetContainment(JobID) WHERE JobID IS NOT NULL;
CREATE UNIQUE INDEX UX_ExportTargetContainment_Operation ON dbo.ExportTargetContainment(OutputOperationID) WHERE OutputOperationID IS NOT NULL;
CREATE UNIQUE INDEX UX_ExportTargetContainment_Preparation ON dbo.ExportTargetContainment(PreparationID) WHERE PreparationID IS NOT NULL;

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- File identity is global: changing account, job or registration cannot reuse it.
CREATE TABLE dbo.ExportContainedTarget
(
 FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ContainmentID uniqueidentifier NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportContainedTarget PRIMARY KEY (FileID),
 CONSTRAINT UQ_ExportContainedTarget_Decision UNIQUE (ContainmentID,FileID),
 CONSTRAINT CK_ExportContainedTarget_File CHECK (LEN(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT FK_ExportContainedTarget_Decision FOREIGN KEY (ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID)
);

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Original stream version and ledger seal retained separately from logical closure.
CREATE TABLE dbo.ExportContainedStream
(
 StreamID uniqueidentifier NOT NULL,
 ContainmentID uniqueidentifier NOT NULL,
 OriginalVersion bigint NOT NULL,
 LastSequence bigint NOT NULL,
 EventDigest binary(32) NOT NULL,
 CONSTRAINT PK_ExportContainedStream PRIMARY KEY (StreamID),
 CONSTRAINT CK_ExportContainedStream_Counters CHECK (OriginalVersion>0 AND LastSequence>=0),
 CONSTRAINT FK_ExportContainedStream_Decision FOREIGN KEY (ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID),
 CONSTRAINT FK_ExportContainedStream_Stream FOREIGN KEY (StreamID) REFERENCES dbo.ExportExecutionStream(StreamID)
);

CREATE TABLE #K98TargetStateBefore (State varchar(16) COLLATE Latin1_General_100_BIN2,ActiveAccountKey varchar(128) COLLATE Latin1_General_100_BIN2,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2,ClosedUTC datetime2(3),CreatedUTC datetime2(3),
 ClosureHash binary(32),ClosureReference uniqueidentifier,EventDigest binary(32),Purpose varchar(16) COLLATE Latin1_General_100_BIN2,
 PreparationID uniqueidentifier,JobID uniqueidentifier,OutputOperationID uniqueidentifier,NestedToken uniqueidentifier,Epoch bigint, CHECK (DATALENGTH(State)=LEN(State) AND ((State IN ('open','frozen') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR ((State='closed' OR (State='target_contained' AND Purpose IN ('mutation','probe')) OR (State='read_contained' AND Purpose='probe' AND PreparationID IS NOT NULL AND JobID IS NULL AND OutputOperationID IS NULL AND NestedToken IS NULL AND Epoch IS NULL)) AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL))));
CREATE TABLE #K98TargetStateAfter (State varchar(16) COLLATE Latin1_General_100_BIN2,ActiveAccountKey varchar(128) COLLATE Latin1_General_100_BIN2,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2,ClosedUTC datetime2(3),CreatedUTC datetime2(3),
 ClosureHash binary(32),ClosureReference uniqueidentifier,EventDigest binary(32),Purpose varchar(16) COLLATE Latin1_General_100_BIN2,
 PreparationID uniqueidentifier,JobID uniqueidentifier,OutputOperationID uniqueidentifier,NestedToken uniqueidentifier,Epoch bigint, CHECK (DATALENGTH(State)=LEN(State) AND ((State IN ('open','frozen') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR ((State='closed' OR (State='target_contained' AND Purpose IN ('mutation','probe')) OR (State='read_contained' AND Purpose='probe' AND PreparationID IS NOT NULL AND JobID IS NULL AND OutputOperationID IS NULL AND NestedToken IS NULL AND Epoch IS NULL)) AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL))));
DECLARE @Before nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98TargetStateBefore')),
 @After nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98TargetStateAfter'));
DECLARE @Actual nvarchar(max)=(SELECT definition FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.ExportExecutionStream')
 AND name='CK_ExportExecutionStream_State' AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0);
IF @Actual IS NULL OR @Actual COLLATE Latin1_General_100_BIN2 NOT IN (@Before COLLATE Latin1_General_100_BIN2,@After COLLATE Latin1_General_100_BIN2)
 THROW 51726,'Exact trusted stream-state constraint required.',1;
IF @Actual COLLATE Latin1_General_100_BIN2<>@After COLLATE Latin1_General_100_BIN2
BEGIN
 ALTER TABLE dbo.ExportExecutionStream DROP CONSTRAINT CK_ExportExecutionStream_State;
 ALTER TABLE dbo.ExportExecutionStream WITH CHECK ADD CONSTRAINT CK_ExportExecutionStream_State CHECK (DATALENGTH(State)=LEN(State) AND ((State IN ('open','frozen') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR ((State='closed' OR (State='target_contained' AND Purpose IN ('mutation','probe')) OR (State='read_contained' AND Purpose='probe' AND PreparationID IS NOT NULL AND JobID IS NULL AND OutputOperationID IS NULL AND NestedToken IS NULL AND Epoch IS NULL)) AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL)));
END;
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.ExportExecutionStream')
 AND name='CK_ExportExecutionStream_State' AND definition COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2
 AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0)
 THROW 51726,'Trusted containment constraint postimage differs.',1;
DECLARE @ObjectID int,@Installed nvarchar(max),@Apply nvarchar(max);
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xde1a5515900cc47bec4732f406e0592071eb588f6280ec005d02900677a2efae
 THROW 51726,'Exact reviewed target-containment predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID)
 THROW 51726,'Unexpected signature; preserve and review.',1;
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
 OR ISJSON(@ScopeJson)<>1 OR @ScopeJson IS NULL OR DATALENGTH(@ScopeJson)>65536
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xd30aeed2693ab3c551c651c44a3968bea012fd88195e3d02c1b866e4b8dfd0cd
 THROW 51726,'Exact reviewed target-containment postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportExecutionSessionTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x117f0729a5da84252f2bbb41890e7ccaf1a5dd7f3abb2804c8e65fd4ce4450cb
 THROW 51726,'Exact reviewed target-containment predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID)
 THROW 51726,'Unexpected signature; preserve and review.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportExecutionSessionTransition
 @SessionID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @HostIdentity varchar(128)=NULL,
 @BootID uniqueidentifier=NULL,
 @ExecutableHash binary(32)=NULL,
 @ManifestHash binary(32)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,''Evidence transition requires its own short transaction.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
   THROW 51700,''Evidence authority role required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY

 DECLARE @Existing bigint;
 SELECT @Existing=Version FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK) WHERE SessionID=@SessionID;
 IF @Action=''open'' AND DATALENGTH(@Action)=4 AND @ExpectedVersion=0 AND @Existing IS NULL
 BEGIN
  INSERT dbo.ExportExecutionSession VALUES (@SessionID,USER_NAME(),@HostIdentity,@BootID,@ExecutableHash,@ManifestHash,1,''open'',1,SYSUTCDATETIME(),NULL);
 END
 ELSE IF @Action=''close'' AND DATALENGTH(@Action)=5 AND @ExpectedVersion=@Existing
 BEGIN
  IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE SessionID=@SessionID AND State NOT IN (''closed'',''read_contained'',''target_contained''))
    THROW 51700,''Provider stream closure is unproven.'',1;
  IF EXISTS (SELECT 1 FROM dbo.ExportPreparation
    WHERE ConsumerKind=''config'' AND State<>''completed''
     AND JSON_VALUE(RequestJson,''$.purpose'')=''output_enrollment''
     AND TRY_CONVERT(uniqueidentifier,JSON_VALUE(GenerationJson,''$.session_id''))=@SessionID)
    THROW 51700,''Enrollment completion is unproven; retain the open session and claims.'',1;
  UPDATE dbo.ExportExecutionSession SET State=''closed'',Version=Version+1,ClosedUTC=SYSUTCDATETIME()
  WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State=''open'' AND Version=@ExpectedVersion;
  IF @@ROWCOUNT<>1 THROW 51700,''Session CAS lost.'',1;
 END
 ELSE THROW 51700,''Session action/CAS conflict; read exact identity before retry.'',1;
 SELECT * FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportExecutionSessionTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x423b0a865264a87ac0b6b5d1542b02495eb4fd4609ded03963152020c20f14ed
 THROW 51726,'Exact reviewed target-containment postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x27c121ac419001d63e84b532181392581180d2a4bb659ab0016496b9c9f3f361
 THROW 51726,'Exact reviewed target-containment predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID)
 THROW 51726,'Unexpected signature; preserve and review.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportReconciliationProofIssue
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
   WHERE s.State NOT IN (''closed'',''read_contained'') OR s.ActiveAccountKey IS NOT NULL OR s.ClosureHash IS NULL OR s.EventDigest IS NULL
    OR (s.State=''read_contained'' AND (s.Purpose<>''probe'' OR s.PreparationID IS NULL OR s.JobID IS NOT NULL OR s.OutputOperationID IS NOT NULL
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
END;
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x7d830f81912767b1cf95ecf076bc4876a87574bb7030d8829b14218b5946de6e
 THROW 51726,'Exact reviewed target-containment postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x08d485624075ee6424efd6e659d1a33304f3545aa5d57928828405567c2c2c80
 THROW 51726,'Exact reviewed target-containment predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID)
 THROW 51726,'Unexpected signature; preserve and review.',1;
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportProviderRequestEventAppend
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
   IF JSON_VALUE(@EnrollmentPlan,''$.version'') IN (''2'',''3'') AND @State=''prepared'' AND
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
 IF (@State=''prepared'' AND EXISTS(SELECT 1 FROM dbo.ExportContainedTarget WITH (HOLDLOCK) WHERE FileID=@TargetID))
  OR (@State=''dispatch_intent'' AND EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r
   JOIN dbo.ExportContainedTarget t WITH (HOLDLOCK) ON t.FileID=r.TargetID WHERE r.RequestID=@RequestID))
  THROW 51700,''Permanently isolated target: provider dispatch is forbidden.'',1;

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
';
EXEC sys.sp_executesql @Apply;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x0fe8c04e7be2b79c983b9a3eec0b1bad1e38ccb243a89e4115f616606109c757
 THROW 51726,'Exact reviewed target-containment postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportJobContainTargets',N'P');
SET @Apply=N'CREATE OR ALTER PROCEDURE dbo.usp_ExportJobContainTargets
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
 IF @@TRANCOUNT<>1 THROW 51726,''Exact outer containment transaction required.'',1;
 IF IS_ROLEMEMBER(N''ExportExecutionAuthority'')<>1 OR IS_ROLEMEMBER(N''ExportExecutionAuthority'') IS NULL
  THROW 51726,''Evidence authority role required.'',1;
 IF @ContainmentID IS NULL OR @AccountKey IS NULL OR @JobID IS NULL OR @OwnerID IS NULL
  OR @Fence IS NULL OR @Fence<=0 OR @ExpectedVersion IS NULL OR @ExpectedVersion<=0
  OR @SnapshotHash IS NULL OR @ReceiptHash IS NULL OR @ReceiptReference IS NULL OR @RegistrationHash IS NULL
  OR @Actor IS NULL OR LEN(@Actor)=0 OR @Reason IS NULL OR LEN(@Reason)=0
  OR @ResourcesJson IS NULL OR ISJSON(@ResourcesJson)<>1 OR DATALENGTH(@ResourcesJson)>1048576
  OR @StreamsJson IS NULL OR ISJSON(@StreamsJson)<>1 OR DATALENGTH(@StreamsJson)>1048576
  THROW 51726,''Complete bounded containment identity required.'',1;
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
  THROW 51726,''Exact resource and stream JSON shapes required.'',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51726,''Account admission busy.'',1;

 DECLARE @Resources TABLE(ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 PRIMARY KEY,Version bigint NOT NULL);
 INSERT @Resources SELECT ResourceKey,Version FROM OPENJSON(@ResourcesJson)
  WITH(ResourceKey varchar(256) ''$.key'',Version bigint ''$.version'');
 IF (SELECT COUNT(*) FROM @Resources) NOT BETWEEN 2 AND 1025
  OR NOT EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey=''account:''+@AccountKey)
  OR EXISTS(SELECT 1 FROM @Resources WHERE Version<=0 OR (ResourceKey<>''account:''+@AccountKey AND ResourceKey NOT LIKE ''destination:%''))
  OR EXISTS(SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@JobID EXCEPT SELECT ResourceKey FROM @Resources)
  OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM dbo.ExportJobResource WHERE JobID=@JobID)
  THROW 51726,''Complete exact job resource membership required.'',1;
 DECLARE @ResourceKey varchar(256),@ResourceVersion bigint;
 DECLARE ResourceLocks CURSOR LOCAL FAST_FORWARD FOR SELECT ResourceKey,Version FROM @Resources ORDER BY ResourceKey;
 OPEN ResourceLocks;
 FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',@ResourceKey),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51726,''Resource admission busy.'',1;
  IF NOT EXISTS(SELECT 1 FROM dbo.ExportResource WITH(UPDLOCK,HOLDLOCK)
   WHERE ResourceKey=@ResourceKey AND Version=@ResourceVersion AND ActiveJobID=@JobID
    AND OwnerID=@OwnerID AND Fence=@Fence AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL)
   THROW 51726,''Exact held job resource required.'',1;
  FETCH NEXT FROM ResourceLocks INTO @ResourceKey,@ResourceVersion;
 END;
 CLOSE ResourceLocks; DEALLOCATE ResourceLocks;

 DECLARE @Consumer varchar(32),@JobEpoch bigint,@JobKVK int;
 SELECT @Consumer=ConsumerKind,@JobEpoch=PoolEpoch,@JobKVK=KVK_NO FROM dbo.ExportJob WITH(UPDLOCK,HOLDLOCK)
 WHERE JobID=@JobID AND AccountKey=@AccountKey AND OwnerID=@OwnerID AND Fence=@Fence
  AND Version=@ExpectedVersion AND State IN (''running'',''uncertain'')
  AND ((ConsumerKind=''new_source'' AND StorageOwner IS NULL AND @StorageOwner IS NULL)
   OR (ConsumerKind IN (''scan_data'',''all_kvk'') AND StorageOwner=@StorageOwner));
 IF @Consumer IS NULL THROW 51726,''Exact unfinished job required.'',1;
 IF (@Consumer=''new_source'' AND (@PoolID IS NULL OR @PoolVersion IS NULL OR @PoolVersion<=0))
  OR (@Consumer<>''new_source'' AND (@PoolID IS NOT NULL OR @PoolVersion IS NOT NULL))
  THROW 51726,''Exact consumer pool identity required.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportResource r WITH(UPDLOCK,HOLDLOCK) WHERE r.ActiveJobID=@JobID
  AND NOT EXISTS(SELECT 1 FROM @Resources e WHERE e.ResourceKey=r.ResourceKey))
  THROW 51726,''Unexpected held job resource prevents partial release.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportTargetContainment WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID OR ContainmentID=@ContainmentID)
  THROW 51726,''Containment already recorded; verify its original receipt.'',1;

 DECLARE @Targets TABLE(FileID varchar(128) COLLATE Latin1_General_100_BIN2 PRIMARY KEY);
 IF EXISTS(SELECT 1 FROM @Resources WHERE ResourceKey LIKE ''destination:%'' AND LEN(ResourceKey) NOT BETWEEN 15 AND 140)
  THROW 51726,''Bounded physical target identity required.'',1;
 INSERT @Targets SELECT SUBSTRING(ResourceKey,13,128) FROM @Resources WHERE ResourceKey LIKE ''destination:%'';
 IF EXISTS(SELECT 1 FROM @Targets WHERE DATALENGTH(FileID)<>LEN(FileID) OR FileID LIKE ''%[^A-Za-z0-9_-]%'' COLLATE Latin1_General_100_BIN2)
  OR EXISTS(SELECT 1 FROM @Targets t JOIN dbo.ExportContainedTarget c WITH(UPDLOCK,HOLDLOCK) ON c.FileID=t.FileID)
  THROW 51726,''Target identity differs or is already permanently isolated.'',1;

 DECLARE @Streams TABLE(StreamID uniqueidentifier PRIMARY KEY,Version bigint NOT NULL,LastSequence bigint NOT NULL,EventDigest binary(32) NOT NULL);
 INSERT @Streams SELECT StreamID,Version,LastSequence,CONVERT(binary(32),EventDigest,2)
 FROM OPENJSON(@StreamsJson) WITH(StreamID uniqueidentifier ''$.stream_id'',Version bigint ''$.version'',LastSequence bigint ''$.last_sequence'',EventDigest varchar(64) ''$.event_digest'');
 IF (SELECT COUNT(*) FROM @Streams) NOT BETWEEN 1 AND 4096
  OR EXISTS(SELECT 1 FROM @Streams WHERE Version<=0 OR LastSequence<0)
  OR EXISTS(SELECT StreamID FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID EXCEPT SELECT StreamID FROM @Streams)
  OR EXISTS(SELECT StreamID FROM @Streams EXCEPT SELECT StreamID FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE JobID=@JobID)
  OR EXISTS(SELECT 1 FROM dbo.ExportExecutionStream WITH(UPDLOCK,HOLDLOCK) WHERE ActiveAccountKey=@AccountKey AND (JobID IS NULL OR JobID<>@JobID))
  THROW 51726,''Complete exclusive job stream membership required.'',1;
 IF EXISTS(SELECT 1 FROM @Streams e JOIN dbo.ExportExecutionStream s WITH(UPDLOCK,HOLDLOCK) ON s.StreamID=e.StreamID
  LEFT JOIN dbo.ExportExecutionSession a ON a.SessionID=s.SessionID
  WHERE s.AccountKey<>@AccountKey OR s.OwnerID<>@OwnerID OR s.Fence<>@Fence OR s.Version<>e.Version OR s.LastSequence<>e.LastSequence
   OR s.RegistrationHash IS NULL OR s.RegistrationHash<>@RegistrationHash
   OR s.ClaimVersion>@ExpectedVersion
   OR (s.Epoch IS NULL AND @JobEpoch IS NOT NULL) OR (s.Epoch IS NOT NULL AND @JobEpoch IS NULL) OR s.Epoch<>@JobEpoch
   OR s.PreparationID IS NOT NULL OR s.OutputOperationID IS NOT NULL OR s.Purpose NOT IN (''mutation'',''probe'')
   OR s.State NOT IN (''open'',''frozen'',''closed'') OR a.AuthorityPrincipal IS NULL OR a.AuthorityPrincipal<>USER_NAME()
   OR EXISTS(SELECT ResourceKey FROM OPENJSON(s.ScopeJson,''$.resources'') WITH(ResourceKey varchar(256) ''$.key'') EXCEPT SELECT ResourceKey FROM @Resources)
   OR EXISTS(SELECT ResourceKey FROM @Resources EXCEPT SELECT ResourceKey FROM OPENJSON(s.ScopeJson,''$.resources'') WITH(ResourceKey varchar(256) ''$.key'')))
  THROW 51726,''Exact original stream authority and complete possible targets required.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportProviderRequest r JOIN @Streams s ON s.StreamID=r.StreamID
  WHERE r.Operation=''sheets.create'' OR NOT EXISTS(SELECT 1 FROM @Targets t WHERE t.FileID=r.TargetID))
  THROW 51726,''A recorded request escaped the proposed retired target set.'',1;

 IF @Consumer=''new_source''
 BEGIN
  SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(41),''pool:''+LOWER(CONVERT(varchar(36),@PoolID)))),2));
  EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
  IF @LockResult<0 THROW 51726,''Output pool admission busy.'',1;
  IF NOT EXISTS(SELECT 1 FROM KVK.SourceOutputPool p WITH(UPDLOCK,HOLDLOCK) JOIN @Targets t ON t.FileID=p.IndexFileID
   WHERE p.PoolID=@PoolID AND p.Version=@PoolVersion AND p.Epoch=@JobEpoch AND p.ActiveKVK=@JobKVK
    AND p.RegistrationHash=@RegistrationHash AND p.AccountKey=@AccountKey AND p.PoolState=''active'' AND p.OwnerID IS NULL)
   THROW 51726,''Exact unowned active output pool required.'',1;
  IF (SELECT COUNT(*) FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID) NOT BETWEEN 2 AND 16
   OR EXISTS(SELECT FileID FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID EXCEPT SELECT FileID FROM @Targets)
   OR EXISTS(SELECT FileID FROM @Targets EXCEPT SELECT FileID FROM KVK.SourceOutputSlot WHERE PoolID=@PoolID
    EXCEPT SELECT IndexFileID FROM KVK.SourceOutputPool WHERE PoolID=@PoolID)
   OR EXISTS(SELECT 1 FROM KVK.SourceOutputOperation WHERE PoolID=@PoolID AND State<>''completed'')
   THROW 51726,''Pool membership or unfinished rollover prevents this job decision.'',1;
 END;

 INSERT dbo.ExportTargetContainment
  (ContainmentID,AccountKey,JobID,OwnerVersion,OwnerID,Fence,SnapshotHash,ReceiptHash,ReceiptReference,Actor,Reason,CreatedUTC)
 VALUES(@ContainmentID,@AccountKey,@JobID,@ExpectedVersion,@OwnerID,@Fence,@SnapshotHash,@ReceiptHash,@ReceiptReference,@Actor,@Reason,SYSUTCDATETIME());
 INSERT dbo.ExportContainedTarget SELECT FileID,@ContainmentID,SYSUTCDATETIME() FROM @Targets;
 INSERT dbo.ExportContainedStream SELECT StreamID,@ContainmentID,Version,LastSequence,EventDigest FROM @Streams;
 UPDATE s SET State=''target_contained'',ActiveAccountKey=NULL,Version=s.Version+1,
  ClosureHash=@ReceiptHash,ClosureReference=@ReceiptReference,EventDigest=e.EventDigest,ClosedUTC=SYSUTCDATETIME()
 FROM dbo.ExportExecutionStream s JOIN @Streams e ON e.StreamID=s.StreamID;
 IF @PoolID IS NOT NULL
 BEGIN
  UPDATE KVK.SourceOutputPool SET PoolState=''blocked'',BlockedReason=N''Targets permanently isolated; verified replacements required'',Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
   WHERE PoolID=@PoolID AND PoolState=''active'' AND OwnerID IS NULL AND Version=@PoolVersion;
  IF @@ROWCOUNT<>1 THROW 51726,''Pool containment CAS lost.'',1;
 END;
 UPDATE dbo.ExportJob SET State=''uncertain'',Version=Version+1,UpdatedUTC=SYSUTCDATETIME()
  WHERE JobID=@JobID AND Version=@ExpectedVersion AND OwnerID=@OwnerID AND Fence=@Fence;
 IF @@ROWCOUNT<>1 THROW 51726,''Job containment CAS lost.'',1;
 UPDATE r SET ActiveJobID=NULL,OwnerID=NULL,BlockedReason=NULL,Version=r.Version+1
 FROM dbo.ExportResource r JOIN @Resources e ON e.ResourceKey=r.ResourceKey
 WHERE r.Version=e.Version AND r.ActiveJobID=@JobID AND r.OwnerID=@OwnerID AND r.Fence=@Fence
  AND r.ActivePreparationID IS NULL AND r.ActiveOutputOperationID IS NULL;
 IF @@ROWCOUNT<>(SELECT COUNT(*) FROM @Resources) THROW 51726,''Resource containment CAS lost.'',1;
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
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportJobContainTargets',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xc400afd325c8167a71dff7a71dbda95a6d5cff27ae2a076e1c51350418153301
 THROW 51726,'Exact reviewed target-containment postimage required.',1;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportTargetContainment TO public;
GRANT SELECT ON OBJECT::dbo.ExportTargetContainment TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportTargetContainment TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportTargetContainment TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportTargetContainment TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportContainedTarget TO public;
GRANT SELECT ON OBJECT::dbo.ExportContainedTarget TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportContainedTarget TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportContainedTarget TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportContainedTarget TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportContainedStream TO public;
GRANT SELECT ON OBJECT::dbo.ExportContainedStream TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportContainedStream TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportContainedStream TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportContainedStream TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportJobContainTargets TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportJobContainTargets TO ExportExecutionReader;
DROP TABLE #K98TargetStateBefore;
DROP TABLE #K98TargetStateAfter;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
