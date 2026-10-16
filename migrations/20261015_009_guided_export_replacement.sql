/*
MigrationId: 20261015_009_guided_export_replacement
Purpose: Verified fresh output replacement, durable admin forms and retained-input delivery
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
PreValidationQuery: Exact reviewed 008 module preimages, trusted state constraint, new objects absent
PostValidationQuery: Exact module postimages, trusted constraints, current registration uniqueness and evidence permissions
*/
-- Install before coordinated protected authority/Bot rollout and contract reissue.
-- Installation changes no owner, output registration or existing delivery state.
-- It neither releases old writes nor performs provider operations.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51730,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51730,'Schema busy.',1;
IF DATABASE_PRINCIPAL_ID(N'ExportExecutionAuthority') IS NULL OR DATABASE_PRINCIPAL_ID(N'ExportExecutionReader') IS NULL
 THROW 51730,'Installed reviewed execution roles required.',1;
IF OBJECT_ID(N'dbo.ExportReplacementPlan') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.ExportReplacementTarget') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.ExportReplacementVerification') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.ExportReplacementActivation') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.ExportReplacementDelivery') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.RecoveryInputDraft') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.usp_ExportReplacementPlanCreate') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.usp_ExportReplacementVerificationTransition') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;
IF OBJECT_ID(N'dbo.usp_ExportReplacementActivate') IS NOT NULL THROW 51730,'Replacement object already exists; inspect migration history before forward repair.',1;

IF COL_LENGTH(N'KVK.SourceOutputPool',N'RetiredByReplacementID') IS NOT NULL
 OR COL_LENGTH(N'dbo.RecoveryAction',N'InputJson') IS NOT NULL
 THROW 51730,'Replacement columns already exist; inspect migration history.',1;
IF NOT EXISTS(SELECT 1 FROM sys.key_constraints k JOIN sys.index_columns ic
 ON ic.object_id=k.parent_object_id AND ic.index_id=k.unique_index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
 WHERE k.parent_object_id=OBJECT_ID(N'KVK.SourceOutputPool')
 AND k.name=N'UQ_SourceOutputPool_Registration' AND k.type='UQ' AND c.name=N'RegistrationNo'
 AND ic.key_ordinal=1 AND NOT EXISTS(SELECT 1 FROM sys.index_columns extra
 WHERE extra.object_id=ic.object_id AND extra.index_id=ic.index_id AND extra.key_ordinal>1))
 THROW 51730,'Exact original registration uniqueness required.',1;
ALTER TABLE KVK.SourceOutputPool ADD RetiredByReplacementID uniqueidentifier NULL;
ALTER TABLE KVK.SourceOutputPool WITH CHECK ADD CONSTRAINT CK_SourceOutputPool_RetiredReplacement
 CHECK(RetiredByReplacementID IS NULL OR (PoolState='blocked' AND OwnerID IS NULL AND BlockedReason=N'Targets permanently isolated; verified replacements required'));
ALTER TABLE KVK.SourceOutputPool DROP CONSTRAINT UQ_SourceOutputPool_Registration;
CREATE UNIQUE INDEX UX_SourceOutputPool_CurrentRegistration ON KVK.SourceOutputPool(RegistrationNo) WHERE RetiredByReplacementID IS NULL;
ALTER TABLE dbo.RecoveryAction ADD InputJson nvarchar(max) NULL;
ALTER TABLE dbo.RecoveryAction WITH CHECK ADD CONSTRAINT CK_RecoveryAction_Input
 CHECK(InputJson IS NULL OR (ISJSON(InputJson)=1 AND DATALENGTH(InputJson)<=1048576));
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Immutable proposal only. A plan does not admit provider work or activate files.
CREATE TABLE dbo.ExportReplacementPlan
(
 ReplacementID uniqueidentifier NOT NULL,
 ContainmentID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 BaseRegistrationHash binary(32) NOT NULL,
 ProjectedRegistrationHash binary(32) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 MappingJson nvarchar(max) NOT NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportReplacementPlan PRIMARY KEY (ReplacementID),
 CONSTRAINT FK_ExportReplacementPlan_Containment FOREIGN KEY (ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID),
 CONSTRAINT CK_ExportReplacementPlan_Account CHECK (DATALENGTH(AccountKey)=LEN(AccountKey) AND LEN(AccountKey)>0 AND AccountKey NOT LIKE '%[^-A-Za-z0-9_.@:]%' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportReplacementPlan_Hashes CHECK (BaseRegistrationHash<>ProjectedRegistrationHash),
 CONSTRAINT CK_ExportReplacementPlan_Mapping CHECK (ISJSON(MappingJson)=1 AND DATALENGTH(MappingJson)<=1048576),
 CONSTRAINT CK_ExportReplacementPlan_Text CHECK (LEN(Actor)>0 AND LEN(Reason)>0)
);
CREATE INDEX IX_ExportReplacementPlan_Containment ON dbo.ExportReplacementPlan(ContainmentID,CreatedUTC,ReplacementID);

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Preserve every proposal, including rejected files; this is not activation.
CREATE TABLE dbo.ExportReplacementTarget
(
 ReplacementID uniqueidentifier NOT NULL,
 OldFileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 NewFileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT PK_ExportReplacementTarget PRIMARY KEY (ReplacementID,OldFileID),
 CONSTRAINT UQ_ExportReplacementTarget_New UNIQUE (ReplacementID,NewFileID),
 CONSTRAINT FK_ExportReplacementTarget_Plan FOREIGN KEY (ReplacementID) REFERENCES dbo.ExportReplacementPlan(ReplacementID),
 CONSTRAINT FK_ExportReplacementTarget_Contained FOREIGN KEY (OldFileID) REFERENCES dbo.ExportContainedTarget(FileID),
 CONSTRAINT CK_ExportReplacementTarget_Identity CHECK (OldFileID<>NewFileID AND DATALENGTH(OldFileID)=LEN(OldFileID) AND DATALENGTH(NewFileID)=LEN(NewFileID) AND LEN(OldFileID) BETWEEN 6 AND 128 AND LEN(NewFileID) BETWEEN 6 AND 128 AND OldFileID NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2 AND NewFileID NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2)
);

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Each explicit verification is a new read-only attempt. Old attempts remain auditable.
CREATE TABLE dbo.ExportReplacementVerification
(
 VerificationID uniqueidentifier NOT NULL,
 ReplacementID uniqueidentifier NOT NULL,
 PreparationID uniqueidentifier NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 PlanHash binary(32) NOT NULL,
 State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 ReceiptHash binary(32) NULL,
 ReceiptReference uniqueidentifier NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 UpdatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportReplacementVerification PRIMARY KEY(VerificationID),
 CONSTRAINT UQ_ExportReplacementVerification_Preparation UNIQUE(PreparationID),
 CONSTRAINT FK_ExportReplacementVerification_Plan FOREIGN KEY(ReplacementID) REFERENCES dbo.ExportReplacementPlan(ReplacementID),
 CONSTRAINT FK_ExportReplacementVerification_Preparation FOREIGN KEY(PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportReplacementVerification_Session FOREIGN KEY(SessionID) REFERENCES dbo.ExportExecutionSession(SessionID),
 CONSTRAINT CK_ExportReplacementVerification_State CHECK(DATALENGTH(State)=LEN(State) AND
  ((State='checking' AND Version=1 AND ReceiptHash IS NULL AND ReceiptReference IS NULL)
   OR (State IN ('verified','discarded') AND Version=2 AND ReceiptHash IS NOT NULL AND ReceiptReference IS NOT NULL))),
 CONSTRAINT CK_ExportReplacementVerification_Text CHECK(LEN(Actor)>0 AND LEN(Reason)>0 AND UpdatedUTC>=CreatedUTC)
);
CREATE UNIQUE INDEX UX_ExportReplacementVerification_Checking ON dbo.ExportReplacementVerification(ReplacementID) WHERE State='checking';
CREATE INDEX IX_ExportReplacementVerification_Plan ON dbo.ExportReplacementVerification(ReplacementID,CreatedUTC,VerificationID);

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Append-only effective-registration chain. A new binding never erases the old one.
CREATE TABLE dbo.ExportReplacementActivation
(
 ActivationID uniqueidentifier NOT NULL,
 ReplacementID uniqueidentifier NOT NULL,
 VerificationID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 BaseRegistrationHash binary(32) NOT NULL,
 RegistrationHash binary(32) NOT NULL,
 RegistrationJson nvarchar(max) NOT NULL,
 ReceiptHash binary(32) NOT NULL,
 ReceiptReference uniqueidentifier NOT NULL,
 OldPoolID uniqueidentifier NULL,
 NewPoolID uniqueidentifier NULL,
 Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportReplacementActivation PRIMARY KEY(ActivationID),
 CONSTRAINT UQ_ExportReplacementActivation_Plan UNIQUE(ReplacementID),
 CONSTRAINT UQ_ExportReplacementActivation_Read UNIQUE(VerificationID),
 CONSTRAINT UQ_ExportReplacementActivation_Base UNIQUE(AccountKey,BaseRegistrationHash),
 CONSTRAINT UQ_ExportReplacementActivation_Result UNIQUE(AccountKey,RegistrationHash),
 CONSTRAINT FK_ExportReplacementActivation_Plan FOREIGN KEY(ReplacementID) REFERENCES dbo.ExportReplacementPlan(ReplacementID),
 CONSTRAINT FK_ExportReplacementActivation_Read FOREIGN KEY(VerificationID) REFERENCES dbo.ExportReplacementVerification(VerificationID),
 CONSTRAINT CK_ExportReplacementActivation_Json CHECK(ISJSON(RegistrationJson)=1 AND DATALENGTH(RegistrationJson)<=65536),
 CONSTRAINT CK_ExportReplacementActivation_Hash CHECK(BaseRegistrationHash<>RegistrationHash),
 CONSTRAINT CK_ExportReplacementActivation_Pool CHECK((OldPoolID IS NULL AND NewPoolID IS NULL) OR (OldPoolID IS NOT NULL AND NewPoolID IS NOT NULL AND OldPoolID<>NewPoolID)),
 CONSTRAINT CK_ExportReplacementActivation_Text CHECK(LEN(Actor)>0 AND LEN(Reason)>0 AND LEN(AccountKey)>0)
);
CREATE UNIQUE INDEX UX_ExportReplacementActivation_OldPool ON dbo.ExportReplacementActivation(OldPoolID) WHERE OldPoolID IS NOT NULL;
CREATE UNIQUE INDEX UX_ExportReplacementActivation_NewPool ON dbo.ExportReplacementActivation(NewPoolID) WHERE NewPoolID IS NOT NULL;

CREATE TABLE dbo.ExportReplacementDelivery (
 ActionID uniqueidentifier NOT NULL CONSTRAINT PK_ExportReplacementDelivery PRIMARY KEY,
 OriginalJobID uniqueidentifier NOT NULL,
 ActivationID uniqueidentifier NOT NULL,
 ReplacementJobID uniqueidentifier NOT NULL,
 AccountKey varchar(128) NOT NULL,
 OriginalInputHash binary(32) NOT NULL,
 ReplacementInputHash binary(32) NOT NULL,
 Actor nvarchar(128) NOT NULL,
 Reason nvarchar(512) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT UQ_ExportReplacementDelivery_Original UNIQUE(OriginalJobID,ActivationID),
 CONSTRAINT UQ_ExportReplacementDelivery_Job UNIQUE(ReplacementJobID),
 CONSTRAINT CK_ExportReplacementDelivery_Distinct CHECK(OriginalJobID<>ReplacementJobID),
 CONSTRAINT FK_ExportReplacementDelivery_Original FOREIGN KEY(OriginalJobID) REFERENCES dbo.ExportJob(JobID),
 CONSTRAINT FK_ExportReplacementDelivery_Activation FOREIGN KEY(ActivationID) REFERENCES dbo.ExportReplacementActivation(ActivationID),
 CONSTRAINT FK_ExportReplacementDelivery_Replacement FOREIGN KEY(ReplacementJobID) REFERENCES dbo.ExportJob(JobID)
);

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.RecoveryInputDraft
(
 IncidentID uniqueidentifier NOT NULL,
 IncidentRevision bigint NOT NULL,
 ActionKind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
 EvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 InputJson nvarchar(max) NOT NULL,
 Actor nvarchar(128) NOT NULL,
 UpdatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_RecoveryInputDraft PRIMARY KEY(IncidentID,IncidentRevision,ActionKind),
 CONSTRAINT FK_RecoveryInputDraft_Incident FOREIGN KEY(IncidentID) REFERENCES dbo.RecoveryIncident(IncidentID),
 CONSTRAINT CK_RecoveryInputDraft_Json CHECK(ISJSON(InputJson)=1 AND DATALENGTH(InputJson)<=1048576),
 CONSTRAINT CK_RecoveryInputDraft_Version CHECK(Version>0 AND IncidentRevision>0 AND LEN(Actor)>0)
);

CREATE TABLE #K98TargetStateBefore (State varchar(16) COLLATE Latin1_General_100_BIN2,ActiveAccountKey varchar(128) COLLATE Latin1_General_100_BIN2,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2,ClosedUTC datetime2(3),CreatedUTC datetime2(3),
 ClosureHash binary(32),ClosureReference uniqueidentifier,EventDigest binary(32),Purpose varchar(16) COLLATE Latin1_General_100_BIN2,
 PreparationID uniqueidentifier,JobID uniqueidentifier,OutputOperationID uniqueidentifier,NestedToken uniqueidentifier,Epoch bigint, CHECK (DATALENGTH(State)=LEN(State) AND ((State IN ('open','frozen') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR ((State='closed' OR (State='target_contained' AND Purpose IN ('mutation','probe')) OR (State='read_contained' AND Purpose='probe' AND PreparationID IS NOT NULL AND JobID IS NULL AND OutputOperationID IS NULL AND NestedToken IS NULL AND Epoch IS NULL)) AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL))));
CREATE TABLE #K98TargetStateAfter (State varchar(16) COLLATE Latin1_General_100_BIN2,ActiveAccountKey varchar(128) COLLATE Latin1_General_100_BIN2,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2,ClosedUTC datetime2(3),CreatedUTC datetime2(3),
 ClosureHash binary(32),ClosureReference uniqueidentifier,EventDigest binary(32),Purpose varchar(16) COLLATE Latin1_General_100_BIN2,
 PreparationID uniqueidentifier,JobID uniqueidentifier,OutputOperationID uniqueidentifier,NestedToken uniqueidentifier,Epoch bigint, CHECK (DATALENGTH(State)=LEN(State) AND ((State IN ('open','frozen') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR ((State='closed' OR (State='target_contained' AND Purpose IN ('mutation','probe')) OR (State='read_contained' AND Purpose IN ('probe','enrollment') AND PreparationID IS NOT NULL AND JobID IS NULL AND OutputOperationID IS NULL AND NestedToken IS NULL AND Epoch IS NULL)) AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL))));
DECLARE @Before nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98TargetStateBefore')),
 @After nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98TargetStateAfter'));
DECLARE @Actual nvarchar(max)=(SELECT definition FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.ExportExecutionStream')
 AND name='CK_ExportExecutionStream_State' AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0);
IF @Actual IS NULL OR @Actual COLLATE Latin1_General_100_BIN2 NOT IN (@Before COLLATE Latin1_General_100_BIN2,@After COLLATE Latin1_General_100_BIN2)
 THROW 51730,'Exact trusted stream-state constraint required.',1;
IF @Actual COLLATE Latin1_General_100_BIN2<>@After COLLATE Latin1_General_100_BIN2
BEGIN
 ALTER TABLE dbo.ExportExecutionStream DROP CONSTRAINT CK_ExportExecutionStream_State;
 ALTER TABLE dbo.ExportExecutionStream WITH CHECK ADD CONSTRAINT CK_ExportExecutionStream_State CHECK (DATALENGTH(State)=LEN(State) AND ((State IN ('open','frozen') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR ((State='closed' OR (State='target_contained' AND Purpose IN ('mutation','probe')) OR (State='read_contained' AND Purpose IN ('probe','enrollment') AND PreparationID IS NOT NULL AND JobID IS NULL AND OutputOperationID IS NULL AND NestedToken IS NULL AND Epoch IS NULL)) AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL)));
END;
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('dbo.ExportExecutionStream')
 AND name='CK_ExportExecutionStream_State' AND definition COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2
 AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0)
 THROW 51730,'Trusted containment constraint postimage differs.',1;

CREATE TABLE #K98RequestBoundBefore(RequestJson nvarchar(max),ConsumerKind varchar(32), CHECK (ISJSON(RequestJson)=1 AND DATALENGTH(RequestJson)<=65536));
CREATE TABLE #K98RequestBoundAfter(RequestJson nvarchar(max),ConsumerKind varchar(32), CHECK (ISJSON(RequestJson)=1 AND DATALENGTH(RequestJson)<=CASE WHEN ConsumerKind='config' AND JSON_VALUE(RequestJson,'$.purpose')='output_enrollment' AND JSON_VALUE(RequestJson,'$.version')='4' THEN 2097152 ELSE 65536 END));
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints c WHERE c.parent_object_id=OBJECT_ID(N'dbo.ExportPreparation')
 AND c.name=N'CK_ExportPreparation_Request' AND c.is_disabled=0 AND c.is_not_trusted=0
 AND c.definition=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98RequestBoundBefore')))
 THROW 51730,'Exact trusted predecessor document bound required.',1;
ALTER TABLE dbo.ExportPreparation DROP CONSTRAINT CK_ExportPreparation_Request;
ALTER TABLE dbo.ExportPreparation WITH CHECK ADD CONSTRAINT CK_ExportPreparation_Request CHECK (ISJSON(RequestJson)=1 AND DATALENGTH(RequestJson)<=CASE WHEN ConsumerKind='config' AND JSON_VALUE(RequestJson,'$.purpose')='output_enrollment' AND JSON_VALUE(RequestJson,'$.version')='4' THEN 2097152 ELSE 65536 END);
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints c WHERE c.parent_object_id=OBJECT_ID(N'dbo.ExportPreparation')
 AND c.name=N'CK_ExportPreparation_Request' AND c.is_disabled=0 AND c.is_not_trusted=0
 AND c.definition=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98RequestBoundAfter')))
 THROW 51730,'Exact trusted replacement document bound required.',1;
DROP TABLE #K98RequestBoundBefore;
DROP TABLE #K98RequestBoundAfter;

CREATE TABLE #K98StreamBoundBefore(ScopeJson nvarchar(max),Purpose varchar(16), CHECK (ISJSON(ScopeJson)=1 AND DATALENGTH(ScopeJson)<=65536));
CREATE TABLE #K98StreamBoundAfter(ScopeJson nvarchar(max),Purpose varchar(16), CHECK (ISJSON(ScopeJson)=1 AND DATALENGTH(ScopeJson)<=CASE WHEN Purpose='enrollment' THEN 524288 ELSE 65536 END));
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints c WHERE c.parent_object_id=OBJECT_ID(N'dbo.ExportExecutionStream')
 AND c.name=N'CK_ExportExecutionStream_Scope' AND c.is_disabled=0 AND c.is_not_trusted=0
 AND c.definition=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98StreamBoundBefore')))
 THROW 51730,'Exact trusted predecessor document bound required.',1;
ALTER TABLE dbo.ExportExecutionStream DROP CONSTRAINT CK_ExportExecutionStream_Scope;
ALTER TABLE dbo.ExportExecutionStream WITH CHECK ADD CONSTRAINT CK_ExportExecutionStream_Scope CHECK (ISJSON(ScopeJson)=1 AND DATALENGTH(ScopeJson)<=CASE WHEN Purpose='enrollment' THEN 524288 ELSE 65536 END);
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints c WHERE c.parent_object_id=OBJECT_ID(N'dbo.ExportExecutionStream')
 AND c.name=N'CK_ExportExecutionStream_Scope' AND c.is_disabled=0 AND c.is_not_trusted=0
 AND c.definition=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98StreamBoundAfter')))
 THROW 51730,'Exact trusted replacement document bound required.',1;
DROP TABLE #K98StreamBoundBefore;
DROP TABLE #K98StreamBoundAfter;

CREATE TABLE #K98EvidenceBoundBefore(EvidenceJson nvarchar(max),SourceKind varchar(64), CHECK (ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=32768));
CREATE TABLE #K98EvidenceBoundAfter(EvidenceJson nvarchar(max),SourceKind varchar(64), CHECK (ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=CASE WHEN SourceKind='export_job' THEN 1048576 ELSE 32768 END));
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints c WHERE c.parent_object_id=OBJECT_ID(N'dbo.RecoveryIncident')
 AND c.name=N'CK_RecoveryIncident_Evidence' AND c.is_disabled=0 AND c.is_not_trusted=0
 AND c.definition=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98EvidenceBoundBefore')))
 THROW 51730,'Exact trusted predecessor document bound required.',1;
ALTER TABLE dbo.RecoveryIncident DROP CONSTRAINT CK_RecoveryIncident_Evidence;
ALTER TABLE dbo.RecoveryIncident WITH CHECK ADD CONSTRAINT CK_RecoveryIncident_Evidence CHECK (ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=CASE WHEN SourceKind='export_job' THEN 1048576 ELSE 32768 END);
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints c WHERE c.parent_object_id=OBJECT_ID(N'dbo.RecoveryIncident')
 AND c.name=N'CK_RecoveryIncident_Evidence' AND c.is_disabled=0 AND c.is_not_trusted=0
 AND c.definition=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID('tempdb..#K98EvidenceBoundAfter')))
 THROW 51730,'Exact trusted replacement document bound required.',1;
DROP TABLE #K98EvidenceBoundBefore;
DROP TABLE #K98EvidenceBoundAfter;
DECLARE @ObjectID int,@Installed nvarchar(max),@Apply nvarchar(max);
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportProviderRequestEventAppend',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x0fe8c04e7be2b79c983b9a3eec0b1bad1e38ccb243a89e4115f616606109c757
 THROW 51730,'Exact reviewed replacement predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51730,'Unexpected signature; preserve and review.',1;
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x2e3969435dc4da5e78b609bf249ca4648c8c39614e4b452f7712927021388f7f
 THROW 51730,'Exact reviewed replacement postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReconciliationProofIssue',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x7d830f81912767b1cf95ecf076bc4876a87574bb7030d8829b14218b5946de6e
 THROW 51730,'Exact reviewed replacement predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51730,'Unexpected signature; preserve and review.',1;
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x2fc7bc39daaf9a38585242b037f3989caaea64b1fba0dced91c4dda70ab31fb7
 THROW 51730,'Exact reviewed replacement postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportManualOutputEnrollmentTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x4743282402ad9cdd5aa1471a307e1aa8cf91421b962951d60e8a18b3b2deb97a
 THROW 51730,'Exact reviewed replacement predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51730,'Unexpected signature; preserve and review.',1;
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xe968287e1816d157099b85bf031d61347b66526b01d3c908554a08eae332ae6d
 THROW 51730,'Exact reviewed replacement postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportOutputEnrollmentTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x17a104d31cfd4582a677ba3d1d980d0191c40d5df9b5fe40e95a759c84a19214
 THROW 51730,'Exact reviewed replacement predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51730,'Unexpected signature; preserve and review.',1;
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
   OR EXISTS (SELECT 1 FROM KVK.SourceOutputOperation WHERE AccountKey=@AccountKey AND State IN (''closing'',''ready'',''running'',''uncertain''))
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x8248d1a8c490bac1c1cc13c3ee1bfef0c21fb36465e163c15d994afc7ea8d2ab
 THROW 51730,'Exact reviewed replacement postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportExecutionStreamTransition',N'P');
SET @Installed=REPLACE(OBJECT_DEFINITION(@ObjectID),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @Installed=CASE
 WHEN LEFT(@Installed,LEN(N'CREATE OR ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'CREATE   PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'CREATE   PROCEDURE' THEN STUFF(@Installed,1,LEN(N'CREATE   PROCEDURE'),N'CREATE PROCEDURE')
 WHEN LEFT(@Installed,LEN(N'ALTER PROCEDURE')) COLLATE Latin1_General_100_BIN2=N'ALTER PROCEDURE' THEN STUFF(@Installed,1,LEN(N'ALTER PROCEDURE'),N'CREATE PROCEDURE')
 ELSE @Installed END;
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xd30aeed2693ab3c551c651c44a3968bea012fd88195e3d02c1b866e4b8dfd0cd
 THROW 51730,'Exact reviewed replacement predecessor required.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@ObjectID) THROW 51730,'Unexpected signature; preserve and review.',1;
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
    OR (DATALENGTH(@ScopeJson)>65536 AND ISNULL(JSON_VALUE(@EnrollmentPlan,''$.version''),'''')<>''4'')
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x010fcd7e6895faa7888ce20b582f3567163be903cd7b4fbe10faf0640d94e31d
 THROW 51730,'Exact reviewed replacement postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementPlanCreate',N'P');
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
 DECLARE @LockResult int,@LockKey nvarchar(255),@JobID uniqueidentifier;
 SET @LockKey=N''k98-export:''+LOWER(CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(varchar(136),''account:''+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode=''Exclusive'',@LockOwner=''Transaction'',@LockTimeout=0;
 IF @LockResult<0 THROW 51727,''Account admission busy.'',1;
 SELECT @JobID=JobID FROM dbo.ExportTargetContainment WITH(UPDLOCK,HOLDLOCK)
  WHERE ContainmentID=@ContainmentID AND AccountKey=@AccountKey AND JobID IS NOT NULL
   AND PreparationID IS NULL AND OutputOperationID IS NULL;
 IF @JobID IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.ExportJob WITH(UPDLOCK,HOLDLOCK)
   WHERE JobID=@JobID AND AccountKey=@AccountKey AND State=''uncertain'')
  THROW 51727,''Exact isolated unresolved job required.'',1;
 IF EXISTS(SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID EXCEPT SELECT OldFileID FROM @Mapping)
  OR EXISTS(SELECT OldFileID FROM @Mapping EXCEPT SELECT FileID FROM dbo.ExportContainedTarget WHERE ContainmentID=@ContainmentID)
  THROW 51727,''Every isolated physical target requires a replacement.'',1;
 IF EXISTS(SELECT 1 FROM dbo.ExportResource WHERE ActiveJobID=@JobID)
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x561518c61b1bbf58fd2326a460d23ab5b760e1e386d84aa7a641f3e242f6d816
 THROW 51730,'Exact reviewed replacement postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementVerificationTransition',N'P');
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
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@PlanJson) WHERE [key]=''version'' AND type=2 AND value=N''4'' AND DATALENGTH(value)=2)
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
  IF JSON_VALUE(@PlanJson,''$.version'')<>''4'' OR JSON_VALUE(@PlanJson,''$.purpose'')<>''output_enrollment''
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
   OR JSON_VALUE(@StoredPlan,''$.version'')<>''4'' OR JSON_VALUE(@StoredPlan,''$.purpose'')<>''output_enrollment''
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
    IF @LastSequence<>5*TRY_CONVERT(int,JSON_VALUE(@StoredPlan,''$.file_count''))
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0x3f867f51b61190ebf9b3f37fcec3f8a8f342a78b0f3c5507ab0c19fbe163d9eb
 THROW 51730,'Exact reviewed replacement postimage required.',1;
SET @ObjectID=OBJECT_ID(N'dbo.usp_ExportReplacementActivate',N'P');
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
  JOIN dbo.ExportJob j ON j.JobID=c.JobID JOIN dbo.ExportReplacementVerification v ON v.ReplacementID=p.ReplacementID
  JOIN dbo.ExportPreparation prep ON prep.PreparationID=v.PreparationID
  WHERE p.ReplacementID=@ReplacementID AND p.AccountKey=@AccountKey AND p.BaseRegistrationHash=@BaseRegistrationHash
   AND c.AccountKey=@AccountKey AND j.AccountKey=@AccountKey AND j.State=''uncertain''
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
IF @Installed IS NULL OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Installed))<>0xa9d50e733bae47d77ea1a394514ab4f098c0c80dd9c7e86b587f01a7c6f024ca
 THROW 51730,'Exact reviewed replacement postimage required.',1;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportReplacementPlan TO public;
GRANT SELECT ON OBJECT::dbo.ExportReplacementPlan TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementPlan TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportReplacementPlan TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementPlan TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportReplacementTarget TO public;
GRANT SELECT ON OBJECT::dbo.ExportReplacementTarget TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementTarget TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportReplacementTarget TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementTarget TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportReplacementVerification TO public;
GRANT SELECT ON OBJECT::dbo.ExportReplacementVerification TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementVerification TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportReplacementVerification TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementVerification TO ExportExecutionReader;
DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.ExportReplacementActivation TO public;
GRANT SELECT ON OBJECT::dbo.ExportReplacementActivation TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementActivation TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportReplacementActivation TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementActivation TO ExportExecutionReader;
DENY UPDATE,DELETE ON OBJECT::dbo.ExportReplacementDelivery TO public;
GRANT INSERT ON OBJECT::dbo.ExportReplacementDelivery TO ExportExecutionReader;
GRANT SELECT ON OBJECT::dbo.ExportReplacementDelivery TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementDelivery TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.ExportReplacementDelivery TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.ExportReplacementDelivery TO ExportExecutionReader;
GRANT INSERT,UPDATE ON OBJECT::dbo.RecoveryInputDraft TO ExportExecutionReader;
DENY DELETE ON OBJECT::dbo.RecoveryInputDraft TO public;
GRANT SELECT ON OBJECT::dbo.RecoveryInputDraft TO ExportExecutionAuthority;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.RecoveryInputDraft TO ExportExecutionAuthority;
GRANT SELECT ON OBJECT::dbo.RecoveryInputDraft TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.RecoveryInputDraft TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportReplacementPlanCreate TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportReplacementPlanCreate TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportReplacementVerificationTransition TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportReplacementVerificationTransition TO ExportExecutionReader;
GRANT EXECUTE ON OBJECT::dbo.usp_ExportReplacementActivate TO ExportExecutionAuthority;
DENY EXECUTE ON OBJECT::dbo.usp_ExportReplacementActivate TO ExportExecutionReader;
GRANT SELECT,INSERT,UPDATE ON OBJECT::dbo.RecoveryIncident TO ExportExecutionReader;
GRANT SELECT ON OBJECT::dbo.RecoveryIncident TO ExportExecutionAuthority;
DENY DELETE ON OBJECT::dbo.RecoveryIncident TO public;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.RecoveryIncident TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.RecoveryIncident TO ExportExecutionAuthority;
GRANT SELECT,INSERT,UPDATE ON OBJECT::dbo.RecoveryAction TO ExportExecutionReader;
GRANT SELECT ON OBJECT::dbo.RecoveryAction TO ExportExecutionAuthority;
DENY DELETE ON OBJECT::dbo.RecoveryAction TO public;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.RecoveryAction TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON OBJECT::dbo.RecoveryAction TO ExportExecutionAuthority;
DROP TABLE #K98TargetStateBefore;
DROP TABLE #K98TargetStateAfter;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
