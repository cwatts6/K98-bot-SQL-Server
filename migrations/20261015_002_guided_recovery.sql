/*
MigrationId: 20261015_002_guided_recovery
Purpose: Durable scoped recovery incidents and audited action execution
Author: cwatts
CreatedUtc: 2026-10-15
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Both recovery tables absent; approved target and backup
PostValidationQuery: Both new tables, constraints and indexes present
RelatedBotPR:
RelatedSQLPR:
*/
-- Additive source only. Install before the companion bot. Never drop recovery history.
-- The migration runner records successful application and skips an applied ID.
-- Existing or partial objects are refused: do not silently adopt a different contract.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @RecoveryOwnTransaction bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
IF @RecoveryOwnTransaction=1 BEGIN TRANSACTION;
BEGIN TRY
DECLARE @RecoveryLock int;
EXEC @RecoveryLock=sys.sp_getapplock @Resource=N'K98:GuidedRecovery:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @RecoveryLock<0 THROW 51630,'Recovery schema lock unavailable.',1;
IF OBJECT_ID(N'dbo.RecoveryIncident') IS NOT NULL OR OBJECT_ID(N'dbo.RecoveryAction') IS NOT NULL
    THROW 51630,'Recovery objects already exist; verify migration history and contract before a forward fix.',1;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.RecoveryIncident
(
    IncidentID uniqueidentifier NOT NULL CONSTRAINT PK_RecoveryIncident PRIMARY KEY,
    ScopeKey char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceJson nvarchar(max) NOT NULL,
    Revision bigint NOT NULL CONSTRAINT DF_RecoveryIncident_Revision DEFAULT 1,
    FirstSeenUTC datetime2(3) NOT NULL CONSTRAINT DF_RecoveryIncident_First DEFAULT SYSUTCDATETIME(),
    LastSeenUTC datetime2(3) NOT NULL CONSTRAINT DF_RecoveryIncident_Last DEFAULT SYSUTCDATETIME(),
    AlertMessageID bigint NULL,
    AlertChannelID bigint NULL,
    AlertedRevision bigint NOT NULL CONSTRAINT DF_RecoveryIncident_AlertRevision DEFAULT 0,
    AlertCheckedUTC datetime2(3) NULL,
    AlertAttemptUTC datetime2(3) NULL,
    CONSTRAINT UQ_RecoveryIncident_Source UNIQUE (ScopeKey,SourceKind,SourceID),
    CONSTRAINT CK_RecoveryIncident_State CHECK (State IN ('open','resolved')),
    CONSTRAINT CK_RecoveryIncident_Evidence CHECK (ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=32768),
    CONSTRAINT CK_RecoveryIncident_Revision CHECK (Revision>0 AND AlertedRevision>=0 AND AlertedRevision<=Revision),
    CONSTRAINT CK_RecoveryIncident_Alert CHECK ((AlertMessageID IS NULL AND AlertChannelID IS NULL) OR (AlertMessageID IS NOT NULL AND AlertChannelID IS NOT NULL AND AlertMessageID>0 AND AlertChannelID>0))
);
CREATE INDEX IX_RecoveryIncident_Pending ON dbo.RecoveryIncident(ScopeKey,State,LastSeenUTC,IncidentID);

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.RecoveryAction
(
    ActionID uniqueidentifier NOT NULL CONSTRAINT PK_RecoveryAction PRIMARY KEY,
    IncidentID uniqueidentifier NOT NULL,
    IncidentRevision bigint NOT NULL,
    ActionKind varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Actor nvarchar(128) NOT NULL,
    Reason nvarchar(512) NOT NULL,
    State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResultJson nvarchar(max) NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_RecoveryAction_Created DEFAULT SYSUTCDATETIME(),
    UpdatedUTC datetime2(3) NOT NULL CONSTRAINT DF_RecoveryAction_Updated DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_RecoveryAction_Incident FOREIGN KEY (IncidentID) REFERENCES dbo.RecoveryIncident(IncidentID),
    CONSTRAINT UQ_RecoveryAction_Revision UNIQUE (IncidentID,IncidentRevision),
    CONSTRAINT CK_RecoveryAction_State CHECK (State IN ('dispatched','unknown','verified','not_applied')),
    CONSTRAINT CK_RecoveryAction_Revision CHECK (IncidentRevision>0),
    CONSTRAINT CK_RecoveryAction_Result CHECK (ResultJson IS NULL OR (ISJSON(ResultJson)=1 AND DATALENGTH(ResultJson)<=32768))
);
CREATE INDEX IX_RecoveryAction_Pending ON dbo.RecoveryAction(IncidentID,State,CreatedUTC);

IF @RecoveryOwnTransaction=1 COMMIT;
END TRY
BEGIN CATCH
IF @RecoveryOwnTransaction=1 AND XACT_STATE()<>0 ROLLBACK;
THROW;
END CATCH;
