/* S11 AUTHORING ONLY. No default target or predecessor fixture execution.
   Operator supplies #S11EvidenceApproval in this same connection, with exactly:
   ServerName nvarchar(128), DatabaseName sysname, RunID uniqueidentifier,
   BackupEvidence nvarchar(1024), ActualRestoreEvidence nvarchar(1024).
   Run under a separately provisioned restricted ExportExecutionAuthority user.
   This fixture retains its synthetic session rows; no cleanup/release/activation.
   Python opt-in cases separately test concurrency and effective Reader rights. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 51701,'S11 fixture requires independent procedure transactions.',1;
IF OBJECT_ID(N'tempdb..#S11EvidenceApproval',N'U') IS NULL
 THROW 51701,'Exact S11 target, operations, backup and actual restore approval required.',1;
IF (SELECT COUNT_BIG(*) FROM #S11EvidenceApproval)<>1 OR EXISTS
 (SELECT 1 FROM #S11EvidenceApproval WHERE ServerName IS NULL OR DatabaseName IS NULL OR RunID IS NULL
 OR ServerName<>CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) OR DatabaseName<>DB_NAME()
 OR DatabaseName NOT LIKE N'K98[_]S11[_]Disposable[_]%'
 OR BackupEvidence IS NULL OR LEN(BackupEvidence)=0 OR ActualRestoreEvidence IS NULL OR LEN(ActualRestoreEvidence)=0)
 THROW 51701,'S11 exact target/evidence mismatch.',1;
IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
 THROW 51701,'Use the approved restricted authority principal.',1;
IF ISNULL(IS_MEMBER(N'db_owner'),-1)<>0 OR ISNULL(IS_SRVROLEMEMBER(N'sysadmin'),-1)<>0
 THROW 51701,'An administrator token cannot prove evidence isolation.',1;
DECLARE @Objects TABLE(Name sysname);
INSERT @Objects VALUES (N'ExportExecutionSession'),(N'ExportExecutionStream'),(N'ExportProviderRequest'),(N'ExportProviderRequestEvent'),(N'ExportReconciliationProof'),(N'ExportManagedFileOrigin');
IF EXISTS(SELECT 1 FROM @Objects WHERE ISNULL(HAS_PERMS_BY_NAME(N'dbo.'+Name,'OBJECT','SELECT'),-1)<>1
 OR ISNULL(HAS_PERMS_BY_NAME(N'dbo.'+Name,'OBJECT','INSERT'),-1)<>0
 OR ISNULL(HAS_PERMS_BY_NAME(N'dbo.'+Name,'OBJECT','UPDATE'),-1)<>0
 OR ISNULL(HAS_PERMS_BY_NAME(N'dbo.'+Name,'OBJECT','DELETE'),-1)<>0
 OR ISNULL(HAS_PERMS_BY_NAME(N'dbo.'+Name,'OBJECT','ALTER'),-1)<>0
 OR ISNULL(HAS_PERMS_BY_NAME(N'dbo.'+Name,'OBJECT','CONTROL'),-1)<>0)
 THROW 51701,'Effective evidence permission boundary differs.',1;
DECLARE @SessionID uniqueidentifier=NEWID(),@BootID uniqueidentifier=NEWID(),@Rejected bit=0;
DECLARE @ExecutableHash binary(32)=HASHBYTES('SHA2_256','S11 synthetic executable'),
 @ManifestHash binary(32)=HASHBYTES('SHA2_256','S11 synthetic manifest');
EXEC dbo.usp_ExportExecutionSessionTransition @SessionID=@SessionID,@Action='open',@ExpectedVersion=0,
 @HostIdentity='s11-transaction-fixture',@BootID=@BootID,@ExecutableHash=@ExecutableHash,@ManifestHash=@ManifestHash;
BEGIN TRY
 EXEC dbo.usp_ExportExecutionSessionTransition @SessionID=@SessionID,@Action='close',@ExpectedVersion=2;
END TRY
BEGIN CATCH
 IF ERROR_NUMBER()<>51700 THROW;
 SET @Rejected=1;
END CATCH;
IF @Rejected<>1 OR NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID AND State='open' AND Version=1)
 THROW 51701,'Stale CAS changed the retained session.',1;
EXEC dbo.usp_ExportExecutionSessionTransition @SessionID=@SessionID,@Action='close',@ExpectedVersion=1;
IF NOT EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID AND State='closed' AND Version=2)
 THROW 51701,'Positive close control failed.',1;
-- This narrow fixture does NOT claim request/stream contention, nested recovery,
-- provider outcomes, process containment or installed production permission proof.
SELECT N'S11 session CAS and restricted authority checks completed' AS Result,@SessionID AS RetainedSessionID;
