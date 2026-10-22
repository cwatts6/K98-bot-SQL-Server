/*
MigrationId: 20261022_001_p0_pipeline_receipts
Purpose: Transactional remaining-report receipts and durable processing pipeline stages
Author: cwatts
CreatedUtc: 2026-10-22
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact reviewed source preimages, idle authority and writer exclusion
PostValidationQuery: Exact table contracts and paired protected source validation
*/
-- No backfill, import replay, resource settlement or authority activation.
-- Stop/drain the protected pair; apply with the reviewed paired bot contract.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51961,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int,@Object int,@Body nvarchar(max);
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51961,'Schema busy.',1;
IF OBJECT_ID(N'dbo.StatsImportExecution',N'U') IS NULL OR OBJECT_ID(N'dbo.ExportExecutionSession',N'U') IS NULL
 THROW 51961,'Reviewed import and authority prerequisites required.',1;
IF EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WITH (HOLDLOCK) WHERE State<>'closed')
 THROW 51961,'Authority sessions must be closed.',1;
EXEC @Lock=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51961,'SQL snapshot producer is live.',1;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK @LockTimeout=0,@LockResult=@Lock OUTPUT;
IF @Lock<0 THROW 51961,'Scan writer is live.',1;
IF OBJECT_ID(N'dbo.StatsImportReportContinuation') IS NULL BEGIN
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.StatsImportReportContinuation
(
    PreparationID uniqueidentifier NOT NULL,
    ContractVersion int NOT NULL CONSTRAINT DF_StatsReport_Contract DEFAULT 1,
    InputDigest binary(32) NOT NULL,
    ScanOrder int NOT NULL,
    LatestScanOrder int NOT NULL,
    KingdomRank float NOT NULL,
    KingdomSeed nvarchar(100) NOT NULL,
    ConfigurationJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RowsKS5 int NOT NULL,
    RowsKS4 int NOT NULL,
    ImportStartedUTC datetime NOT NULL,
    CompletedStage tinyint NOT NULL CONSTRAINT DF_StatsReport_Stage DEFAULT 0,
    ReportKVK int NULL,
    ReportScan int NULL,
    PrefixCompletedUTC datetime2(3) NULL,
    UploadCompletedUTC datetime2(3) NULL,
    SummaryCompletedUTC datetime2(3) NULL,
    RecoveryActionID uniqueidentifier NULL,
    RecoveryEvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NULL,
    RecoveryState varchar(12) COLLATE Latin1_General_100_BIN2 NULL,
    Version bigint NOT NULL CONSTRAINT DF_StatsReport_Version DEFAULT 1,
    CONSTRAINT PK_StatsImportReportContinuation PRIMARY KEY (PreparationID),
    CONSTRAINT FK_StatsReport_Execution FOREIGN KEY (PreparationID) REFERENCES dbo.StatsImportExecution(PreparationID),
    CONSTRAINT CK_StatsReport_Contract CHECK (ContractVersion=1 AND Version>0 AND RowsKS5>=0 AND RowsKS4>=0),
    CONSTRAINT CK_StatsReport_Config CHECK (ISJSON(ConfigurationJson)=1 AND DATALENGTH(ConfigurationJson)<=1048576),
    CONSTRAINT CK_StatsReport_Stage CHECK (
        (CompletedStage=0 AND PrefixCompletedUTC IS NULL AND UploadCompletedUTC IS NULL AND SummaryCompletedUTC IS NULL AND ReportKVK IS NULL AND ReportScan IS NULL)
        OR (CompletedStage=1 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NULL AND SummaryCompletedUTC IS NULL)
        OR (CompletedStage=2 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NOT NULL AND SummaryCompletedUTC IS NULL)
        OR (CompletedStage=3 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NOT NULL AND SummaryCompletedUTC IS NOT NULL)),
    CONSTRAINT CK_StatsReport_Action CHECK (
        (RecoveryActionID IS NULL AND RecoveryEvidenceHash IS NULL AND RecoveryState IS NULL)
        OR (RecoveryActionID IS NOT NULL AND RecoveryEvidenceHash IS NOT NULL
            AND RecoveryEvidenceHash NOT LIKE '%[^0-9a-f]%'
            AND RecoveryState IS NOT NULL AND RecoveryState IN ('running','failed','completed')))
);

END;
EXEC sys.sp_executesql N'DECLARE @Object int=OBJECT_ID(N''dbo.StatsImportReportContinuation''),@Expected int;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE #Expected
(
    PreparationID uniqueidentifier NOT NULL,
    ContractVersion int NOT NULL DEFAULT 1,
    InputDigest binary(32) NOT NULL,
    ScanOrder int NOT NULL,
    LatestScanOrder int NOT NULL,
    KingdomRank float NOT NULL,
    KingdomSeed nvarchar(100) COLLATE DATABASE_DEFAULT NOT NULL,
    ConfigurationJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RowsKS5 int NOT NULL,
    RowsKS4 int NOT NULL,
    ImportStartedUTC datetime NOT NULL,
    CompletedStage tinyint NOT NULL DEFAULT 0,
    ReportKVK int NULL,
    ReportScan int NULL,
    PrefixCompletedUTC datetime2(3) NULL,
    UploadCompletedUTC datetime2(3) NULL,
    SummaryCompletedUTC datetime2(3) NULL,
    RecoveryActionID uniqueidentifier NULL,
    RecoveryEvidenceHash char(64) COLLATE Latin1_General_100_BIN2 NULL,
    RecoveryState varchar(12) COLLATE Latin1_General_100_BIN2 NULL,
    Version bigint NOT NULL DEFAULT 1,
    PRIMARY KEY (PreparationID),
    CHECK (ContractVersion=1 AND Version>0 AND RowsKS5>=0 AND RowsKS4>=0),
    CHECK (ISJSON(ConfigurationJson)=1 AND DATALENGTH(ConfigurationJson)<=1048576),
    CHECK (
        (CompletedStage=0 AND PrefixCompletedUTC IS NULL AND UploadCompletedUTC IS NULL AND SummaryCompletedUTC IS NULL AND ReportKVK IS NULL AND ReportScan IS NULL)
        OR (CompletedStage=1 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NULL AND SummaryCompletedUTC IS NULL)
        OR (CompletedStage=2 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NOT NULL AND SummaryCompletedUTC IS NULL)
        OR (CompletedStage=3 AND PrefixCompletedUTC IS NOT NULL AND UploadCompletedUTC IS NOT NULL AND SummaryCompletedUTC IS NOT NULL)),
    CHECK (
        (RecoveryActionID IS NULL AND RecoveryEvidenceHash IS NULL AND RecoveryState IS NULL)
        OR (RecoveryActionID IS NOT NULL AND RecoveryEvidenceHash IS NOT NULL
            AND RecoveryEvidenceHash NOT LIKE ''%[^0-9a-f]%''
            AND RecoveryState IS NOT NULL AND RecoveryState IN (''running'',''failed'',''completed'')))
);

SET @Expected=OBJECT_ID(N''tempdb..#Expected'');

SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ActualColumns FROM sys.columns WHERE object_id=@Object;
SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ExpectedColumns FROM tempdb.sys.columns WHERE object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualColumns EXCEPT SELECT * FROM #ExpectedColumns)
 OR EXISTS(SELECT * FROM #ExpectedColumns EXCEPT SELECT * FROM #ActualColumns)
 OR (SELECT COUNT(*) FROM #ActualColumns)<>(SELECT COUNT(*) FROM #ExpectedColumns)
 THROW 51961,''StatsImportReportContinuation Columns contract differs.'',1;
DROP TABLE #ActualColumns,#ExpectedColumns;

SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ActualChecks FROM sys.check_constraints WHERE parent_object_id=@Object;
SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ExpectedChecks FROM tempdb.sys.check_constraints WHERE parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualChecks EXCEPT SELECT * FROM #ExpectedChecks)
 OR EXISTS(SELECT * FROM #ExpectedChecks EXCEPT SELECT * FROM #ActualChecks)
 OR (SELECT COUNT(*) FROM #ActualChecks)<>(SELECT COUNT(*) FROM #ExpectedChecks)
 THROW 51961,''StatsImportReportContinuation Checks contract differs.'',1;
DROP TABLE #ActualChecks,#ExpectedChecks;

SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ActualDefaults FROM sys.default_constraints d JOIN sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Object;
SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ExpectedDefaults FROM tempdb.sys.default_constraints d JOIN tempdb.sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualDefaults EXCEPT SELECT * FROM #ExpectedDefaults)
 OR EXISTS(SELECT * FROM #ExpectedDefaults EXCEPT SELECT * FROM #ActualDefaults)
 THROW 51961,''StatsImportReportContinuation defaults differ.'',1;
DROP TABLE #ActualDefaults,#ExpectedDefaults;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ActualIndexes FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Object;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ExpectedIndexes FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualIndexes EXCEPT SELECT * FROM #ExpectedIndexes)
 OR EXISTS(SELECT * FROM #ExpectedIndexes EXCEPT SELECT * FROM #ActualIndexes)
 OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@Object)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR (SELECT COUNT(*) FROM #ActualIndexes)<>(SELECT COUNT(*) FROM #ExpectedIndexes)
 THROW 51961,''StatsImportReportContinuation index contract differs.'',1;
DROP TABLE #ActualIndexes,#ExpectedIndexes;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@Object)
 OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Object AND (temporal_type<>0 OR is_memory_optimized=1 OR is_replicated=1 OR is_tracked_by_cdc=1))
 THROW 51961,''Unexpected StatsImportReportContinuation table behaviour.'',1;

IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@Object)<>1
 OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN sys.foreign_key_columns c ON c.constraint_object_id=f.object_id
 WHERE f.parent_object_id=@Object AND f.referenced_object_id=OBJECT_ID(N''dbo.StatsImportExecution'')
 AND COL_NAME(@Object,c.parent_column_id)=N''PreparationID'' AND COL_NAME(f.referenced_object_id,c.referenced_column_id)=N''PreparationID''
 AND f.is_disabled=0 AND f.is_not_trusted=0 AND f.is_not_for_replication=0
 AND f.delete_referential_action=0 AND f.update_referential_action=0)
 OR (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE parent_object_id=@Object)<>1
 THROW 51961,''StatsImportReportContinuation foreign-key contract differs.'',1;
';

IF OBJECT_ID(N'dbo.ProcessingPipelineRun') IS NULL BEGIN
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.ProcessingPipelineRun
(
    RunID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    StorageOwner nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    InputsJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegistrationJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_ProcessingPipelineRun_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ProcessingPipelineRun PRIMARY KEY (RunID),
    CONSTRAINT CK_ProcessingPipelineRun_Json CHECK (
        ISJSON(InputsJson)=1 AND DATALENGTH(InputsJson)<=32768
        AND ISJSON(RegistrationJson)=1 AND DATALENGTH(RegistrationJson)<=1048576)
);
CREATE INDEX IX_ProcessingPipelineRun_Scope ON dbo.ProcessingPipelineRun(AccountKey,StorageOwner,RunID);

END;
EXEC sys.sp_executesql N'DECLARE @Object int=OBJECT_ID(N''dbo.ProcessingPipelineRun''),@Expected int;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE #Expected
(
    RunID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    StorageOwner nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    InputsJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RegistrationJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CreatedUTC datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    PRIMARY KEY (RunID),
    CHECK (
        ISJSON(InputsJson)=1 AND DATALENGTH(InputsJson)<=32768
        AND ISJSON(RegistrationJson)=1 AND DATALENGTH(RegistrationJson)<=1048576)
);
CREATE INDEX IX_ProcessingPipelineRun_Scope ON #Expected(AccountKey,StorageOwner,RunID);

SET @Expected=OBJECT_ID(N''tempdb..#Expected'');

SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ActualColumns FROM sys.columns WHERE object_id=@Object;
SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ExpectedColumns FROM tempdb.sys.columns WHERE object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualColumns EXCEPT SELECT * FROM #ExpectedColumns)
 OR EXISTS(SELECT * FROM #ExpectedColumns EXCEPT SELECT * FROM #ActualColumns)
 OR (SELECT COUNT(*) FROM #ActualColumns)<>(SELECT COUNT(*) FROM #ExpectedColumns)
 THROW 51961,''ProcessingPipelineRun Columns contract differs.'',1;
DROP TABLE #ActualColumns,#ExpectedColumns;

SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ActualChecks FROM sys.check_constraints WHERE parent_object_id=@Object;
SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ExpectedChecks FROM tempdb.sys.check_constraints WHERE parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualChecks EXCEPT SELECT * FROM #ExpectedChecks)
 OR EXISTS(SELECT * FROM #ExpectedChecks EXCEPT SELECT * FROM #ActualChecks)
 OR (SELECT COUNT(*) FROM #ActualChecks)<>(SELECT COUNT(*) FROM #ExpectedChecks)
 THROW 51961,''ProcessingPipelineRun Checks contract differs.'',1;
DROP TABLE #ActualChecks,#ExpectedChecks;

SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ActualDefaults FROM sys.default_constraints d JOIN sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Object;
SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ExpectedDefaults FROM tempdb.sys.default_constraints d JOIN tempdb.sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualDefaults EXCEPT SELECT * FROM #ExpectedDefaults)
 OR EXISTS(SELECT * FROM #ExpectedDefaults EXCEPT SELECT * FROM #ActualDefaults)
 THROW 51961,''ProcessingPipelineRun defaults differ.'',1;
DROP TABLE #ActualDefaults,#ExpectedDefaults;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ActualIndexes FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Object;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ExpectedIndexes FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualIndexes EXCEPT SELECT * FROM #ExpectedIndexes)
 OR EXISTS(SELECT * FROM #ExpectedIndexes EXCEPT SELECT * FROM #ActualIndexes)
 OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@Object)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR (SELECT COUNT(*) FROM #ActualIndexes)<>(SELECT COUNT(*) FROM #ExpectedIndexes)
 THROW 51961,''ProcessingPipelineRun index contract differs.'',1;
DROP TABLE #ActualIndexes,#ExpectedIndexes;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@Object)
 OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Object AND (temporal_type<>0 OR is_memory_optimized=1 OR is_replicated=1 OR is_tracked_by_cdc=1))
 THROW 51961,''Unexpected ProcessingPipelineRun table behaviour.'',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@Object) THROW 51961,''Unexpected foreign key.'',1;';

IF OBJECT_ID(N'dbo.ProcessingPipelineStage') IS NULL BEGIN
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.ProcessingPipelineStage
(
    RunID uniqueidentifier NOT NULL,
    Stage varchar(24) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OperationID uniqueidentifier NOT NULL,
    State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,
    DecisionJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,
    UpdatedUTC datetime2(3) NOT NULL CONSTRAINT DF_ProcessingPipelineStage_Updated DEFAULT SYSUTCDATETIME(),
    Version bigint NOT NULL CONSTRAINT DF_ProcessingPipelineStage_Version DEFAULT 1,
    CONSTRAINT PK_ProcessingPipelineStage PRIMARY KEY (RunID,Stage),
    CONSTRAINT FK_ProcessingPipelineStage_Run FOREIGN KEY (RunID) REFERENCES dbo.ProcessingPipelineRun(RunID),
    CONSTRAINT UQ_ProcessingPipelineStage_Operation UNIQUE (OperationID),
    CONSTRAINT CK_ProcessingPipelineStage_Stage CHECK (Stage IN ('import','player_cache','name_cache','maintenance','configuration','target_cache','export')),
    CONSTRAINT CK_ProcessingPipelineStage_State CHECK (State IN ('not_started','running','observed','unconfirmed','skipped') AND Version>0),
    CONSTRAINT CK_ProcessingPipelineStage_Evidence CHECK (
        (State IN ('not_started','running') AND EvidenceJson IS NULL)
        OR (State IN ('observed','unconfirmed','skipped') AND EvidenceJson IS NOT NULL
            AND ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=32768)),
    CONSTRAINT CK_ProcessingPipelineStage_Decision CHECK (DecisionJson IS NULL OR (ISJSON(DecisionJson)=1 AND DATALENGTH(DecisionJson)<=32768))
);

END;
EXEC sys.sp_executesql N'DECLARE @Object int=OBJECT_ID(N''dbo.ProcessingPipelineStage''),@Expected int;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE #Expected
(
    RunID uniqueidentifier NOT NULL,
    Stage varchar(24) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OperationID uniqueidentifier NOT NULL,
    State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EvidenceJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,
    DecisionJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NULL,
    UpdatedUTC datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    Version bigint NOT NULL DEFAULT 1,
    PRIMARY KEY (RunID,Stage),
    UNIQUE (OperationID),
    CHECK (Stage IN (''import'',''player_cache'',''name_cache'',''maintenance'',''configuration'',''target_cache'',''export'')),
    CHECK (State IN (''not_started'',''running'',''observed'',''unconfirmed'',''skipped'') AND Version>0),
    CHECK (
        (State IN (''not_started'',''running'') AND EvidenceJson IS NULL)
        OR (State IN (''observed'',''unconfirmed'',''skipped'') AND EvidenceJson IS NOT NULL
            AND ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=32768)),
    CHECK (DecisionJson IS NULL OR (ISJSON(DecisionJson)=1 AND DATALENGTH(DecisionJson)<=32768))
);

SET @Expected=OBJECT_ID(N''tempdb..#Expected'');

SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ActualColumns FROM sys.columns WHERE object_id=@Object;
SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ExpectedColumns FROM tempdb.sys.columns WHERE object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualColumns EXCEPT SELECT * FROM #ExpectedColumns)
 OR EXISTS(SELECT * FROM #ExpectedColumns EXCEPT SELECT * FROM #ActualColumns)
 OR (SELECT COUNT(*) FROM #ActualColumns)<>(SELECT COUNT(*) FROM #ExpectedColumns)
 THROW 51961,''ProcessingPipelineStage Columns contract differs.'',1;
DROP TABLE #ActualColumns,#ExpectedColumns;

SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ActualChecks FROM sys.check_constraints WHERE parent_object_id=@Object;
SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ExpectedChecks FROM tempdb.sys.check_constraints WHERE parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualChecks EXCEPT SELECT * FROM #ExpectedChecks)
 OR EXISTS(SELECT * FROM #ExpectedChecks EXCEPT SELECT * FROM #ActualChecks)
 OR (SELECT COUNT(*) FROM #ActualChecks)<>(SELECT COUNT(*) FROM #ExpectedChecks)
 THROW 51961,''ProcessingPipelineStage Checks contract differs.'',1;
DROP TABLE #ActualChecks,#ExpectedChecks;

SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ActualDefaults FROM sys.default_constraints d JOIN sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Object;
SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ExpectedDefaults FROM tempdb.sys.default_constraints d JOIN tempdb.sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualDefaults EXCEPT SELECT * FROM #ExpectedDefaults)
 OR EXISTS(SELECT * FROM #ExpectedDefaults EXCEPT SELECT * FROM #ActualDefaults)
 THROW 51961,''ProcessingPipelineStage defaults differ.'',1;
DROP TABLE #ActualDefaults,#ExpectedDefaults;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ActualIndexes FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Object;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ExpectedIndexes FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualIndexes EXCEPT SELECT * FROM #ExpectedIndexes)
 OR EXISTS(SELECT * FROM #ExpectedIndexes EXCEPT SELECT * FROM #ActualIndexes)
 OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@Object)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR (SELECT COUNT(*) FROM #ActualIndexes)<>(SELECT COUNT(*) FROM #ExpectedIndexes)
 THROW 51961,''ProcessingPipelineStage index contract differs.'',1;
DROP TABLE #ActualIndexes,#ExpectedIndexes;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@Object)
 OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Object AND (temporal_type<>0 OR is_memory_optimized=1 OR is_replicated=1 OR is_tracked_by_cdc=1))
 THROW 51961,''Unexpected ProcessingPipelineStage table behaviour.'',1;

IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@Object)<>1
 OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN sys.foreign_key_columns c ON c.constraint_object_id=f.object_id
 WHERE f.parent_object_id=@Object AND f.referenced_object_id=OBJECT_ID(N''dbo.ProcessingPipelineRun'')
 AND COL_NAME(@Object,c.parent_column_id)=N''RunID'' AND COL_NAME(f.referenced_object_id,c.referenced_column_id)=N''RunID''
 AND f.is_disabled=0 AND f.is_not_trusted=0 AND f.is_not_for_replication=0
 AND f.delete_referential_action=0 AND f.update_referential_action=0)
 OR (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE parent_object_id=@Object)<>1
 THROW 51961,''ProcessingPipelineStage foreign-key contract differs.'',1;
';

IF OBJECT_ID(N'dbo.ExportContainmentAttestation') IS NULL BEGIN
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- New present-state attestations. Never overwrite a lost historical receipt.
CREATE TABLE dbo.ExportContainmentAttestation
(
    ActionID uniqueidentifier NOT NULL,
    ContainmentID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OriginalReference uniqueidentifier NOT NULL,
    OriginalHash binary(32) NOT NULL,
    ReviewHash binary(32) NOT NULL,
    ProjectionHash binary(32) NOT NULL,
    ReceiptReference uniqueidentifier NOT NULL,
    ReceiptHash binary(32) NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) NOT NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_ContainmentAttestation_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ExportContainmentAttestation PRIMARY KEY(ActionID),
    CONSTRAINT FK_ContainmentAttestation_Containment FOREIGN KEY(ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID),
    CONSTRAINT CK_ContainmentAttestation_Text CHECK(LEN(AccountKey)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    CONSTRAINT UQ_ContainmentAttestation_Receipt UNIQUE(ReceiptReference)
);
CREATE INDEX IX_ContainmentAttestation_Source ON dbo.ExportContainmentAttestation(AccountKey,ContainmentID,CreatedUTC,ActionID);

END;
EXEC sys.sp_executesql N'DECLARE @Object int=OBJECT_ID(N''dbo.ExportContainmentAttestation''),@Expected int;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- New present-state attestations. Never overwrite a lost historical receipt.
CREATE TABLE #Expected
(
    ActionID uniqueidentifier NOT NULL,
    ContainmentID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OriginalReference uniqueidentifier NOT NULL,
    OriginalHash binary(32) NOT NULL,
    ReviewHash binary(32) NOT NULL,
    ProjectionHash binary(32) NOT NULL,
    ReceiptReference uniqueidentifier NOT NULL,
    ReceiptHash binary(32) NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL,
    CreatedUTC datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    PRIMARY KEY(ActionID),
    CHECK(LEN(AccountKey)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    UNIQUE(ReceiptReference)
);
CREATE INDEX IX_ContainmentAttestation_Source ON #Expected(AccountKey,ContainmentID,CreatedUTC,ActionID);

SET @Expected=OBJECT_ID(N''tempdb..#Expected'');

SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ActualColumns FROM sys.columns WHERE object_id=@Object;
SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ExpectedColumns FROM tempdb.sys.columns WHERE object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualColumns EXCEPT SELECT * FROM #ExpectedColumns)
 OR EXISTS(SELECT * FROM #ExpectedColumns EXCEPT SELECT * FROM #ActualColumns)
 OR (SELECT COUNT(*) FROM #ActualColumns)<>(SELECT COUNT(*) FROM #ExpectedColumns)
 THROW 51961,''ExportContainmentAttestation Columns contract differs.'',1;
DROP TABLE #ActualColumns,#ExpectedColumns;

SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ActualChecks FROM sys.check_constraints WHERE parent_object_id=@Object;
SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ExpectedChecks FROM tempdb.sys.check_constraints WHERE parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualChecks EXCEPT SELECT * FROM #ExpectedChecks)
 OR EXISTS(SELECT * FROM #ExpectedChecks EXCEPT SELECT * FROM #ActualChecks)
 OR (SELECT COUNT(*) FROM #ActualChecks)<>(SELECT COUNT(*) FROM #ExpectedChecks)
 THROW 51961,''ExportContainmentAttestation Checks contract differs.'',1;
DROP TABLE #ActualChecks,#ExpectedChecks;

SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ActualDefaults FROM sys.default_constraints d JOIN sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Object;
SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ExpectedDefaults FROM tempdb.sys.default_constraints d JOIN tempdb.sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualDefaults EXCEPT SELECT * FROM #ExpectedDefaults)
 OR EXISTS(SELECT * FROM #ExpectedDefaults EXCEPT SELECT * FROM #ActualDefaults)
 THROW 51961,''ExportContainmentAttestation defaults differ.'',1;
DROP TABLE #ActualDefaults,#ExpectedDefaults;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ActualIndexes FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Object;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ExpectedIndexes FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualIndexes EXCEPT SELECT * FROM #ExpectedIndexes)
 OR EXISTS(SELECT * FROM #ExpectedIndexes EXCEPT SELECT * FROM #ActualIndexes)
 OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@Object)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR (SELECT COUNT(*) FROM #ActualIndexes)<>(SELECT COUNT(*) FROM #ExpectedIndexes)
 THROW 51961,''ExportContainmentAttestation index contract differs.'',1;
DROP TABLE #ActualIndexes,#ExpectedIndexes;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@Object)
 OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Object AND (temporal_type<>0 OR is_memory_optimized=1 OR is_replicated=1 OR is_tracked_by_cdc=1))
 THROW 51961,''Unexpected ExportContainmentAttestation table behaviour.'',1;

IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@Object)<>1
 OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN sys.foreign_key_columns c ON c.constraint_object_id=f.object_id
 WHERE f.parent_object_id=@Object AND f.referenced_object_id=OBJECT_ID(N''dbo.ExportTargetContainment'')
 AND COL_NAME(@Object,c.parent_column_id)=N''ContainmentID'' AND COL_NAME(f.referenced_object_id,c.referenced_column_id)=N''ContainmentID''
 AND f.is_disabled=0 AND f.is_not_trusted=0 AND f.is_not_for_replication=0
 AND f.delete_referential_action=0 AND f.update_referential_action=0)
 OR (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE parent_object_id=@Object)<>1
 THROW 51961,''ExportContainmentAttestation foreign-key contract differs.'',1;
';

IF OBJECT_ID(N'dbo.ExportRegistrationAttestation') IS NULL BEGIN
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Separate verified dependency witness; never replace the original activation.
CREATE TABLE dbo.ExportRegistrationAttestation
(
    ActionID uniqueidentifier NOT NULL,
    ActivationID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OriginalReference uniqueidentifier NOT NULL,
    OriginalHash binary(32) NOT NULL,
    ReviewHash binary(32) NOT NULL,
    ProjectionHash binary(32) NOT NULL,
    ReceiptReference uniqueidentifier NOT NULL,
    ReceiptHash binary(32) NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) NOT NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_RegistrationAttestation_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ExportRegistrationAttestation PRIMARY KEY(ActionID),
    CONSTRAINT FK_RegistrationAttestation_Activation FOREIGN KEY(ActivationID) REFERENCES dbo.ExportReplacementActivation(ActivationID),
    CONSTRAINT CK_RegistrationAttestation_Text CHECK(LEN(AccountKey)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    CONSTRAINT UQ_RegistrationAttestation_Receipt UNIQUE(ReceiptReference)
);
CREATE INDEX IX_RegistrationAttestation_Source ON dbo.ExportRegistrationAttestation(AccountKey,ActivationID,CreatedUTC,ActionID);

END;
EXEC sys.sp_executesql N'DECLARE @Object int=OBJECT_ID(N''dbo.ExportRegistrationAttestation''),@Expected int;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Separate verified dependency witness; never replace the original activation.
CREATE TABLE #Expected
(
    ActionID uniqueidentifier NOT NULL,
    ActivationID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    OriginalReference uniqueidentifier NOT NULL,
    OriginalHash binary(32) NOT NULL,
    ReviewHash binary(32) NOT NULL,
    ProjectionHash binary(32) NOT NULL,
    ReceiptReference uniqueidentifier NOT NULL,
    ReceiptHash binary(32) NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL,
    CreatedUTC datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    PRIMARY KEY(ActionID),
    CHECK(LEN(AccountKey)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    UNIQUE(ReceiptReference)
);
CREATE INDEX IX_RegistrationAttestation_Source ON #Expected(AccountKey,ActivationID,CreatedUTC,ActionID);

SET @Expected=OBJECT_ID(N''tempdb..#Expected'');

SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ActualColumns FROM sys.columns WHERE object_id=@Object;
SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ExpectedColumns FROM tempdb.sys.columns WHERE object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualColumns EXCEPT SELECT * FROM #ExpectedColumns)
 OR EXISTS(SELECT * FROM #ExpectedColumns EXCEPT SELECT * FROM #ActualColumns)
 OR (SELECT COUNT(*) FROM #ActualColumns)<>(SELECT COUNT(*) FROM #ExpectedColumns)
 THROW 51961,''ExportRegistrationAttestation Columns contract differs.'',1;
DROP TABLE #ActualColumns,#ExpectedColumns;

SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ActualChecks FROM sys.check_constraints WHERE parent_object_id=@Object;
SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ExpectedChecks FROM tempdb.sys.check_constraints WHERE parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualChecks EXCEPT SELECT * FROM #ExpectedChecks)
 OR EXISTS(SELECT * FROM #ExpectedChecks EXCEPT SELECT * FROM #ActualChecks)
 OR (SELECT COUNT(*) FROM #ActualChecks)<>(SELECT COUNT(*) FROM #ExpectedChecks)
 THROW 51961,''ExportRegistrationAttestation Checks contract differs.'',1;
DROP TABLE #ActualChecks,#ExpectedChecks;

SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ActualDefaults FROM sys.default_constraints d JOIN sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Object;
SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ExpectedDefaults FROM tempdb.sys.default_constraints d JOIN tempdb.sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualDefaults EXCEPT SELECT * FROM #ExpectedDefaults)
 OR EXISTS(SELECT * FROM #ExpectedDefaults EXCEPT SELECT * FROM #ActualDefaults)
 THROW 51961,''ExportRegistrationAttestation defaults differ.'',1;
DROP TABLE #ActualDefaults,#ExpectedDefaults;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ActualIndexes FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Object;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ExpectedIndexes FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualIndexes EXCEPT SELECT * FROM #ExpectedIndexes)
 OR EXISTS(SELECT * FROM #ExpectedIndexes EXCEPT SELECT * FROM #ActualIndexes)
 OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@Object)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR (SELECT COUNT(*) FROM #ActualIndexes)<>(SELECT COUNT(*) FROM #ExpectedIndexes)
 THROW 51961,''ExportRegistrationAttestation index contract differs.'',1;
DROP TABLE #ActualIndexes,#ExpectedIndexes;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@Object)
 OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Object AND (temporal_type<>0 OR is_memory_optimized=1 OR is_replicated=1 OR is_tracked_by_cdc=1))
 THROW 51961,''Unexpected ExportRegistrationAttestation table behaviour.'',1;

IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@Object)<>1
 OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN sys.foreign_key_columns c ON c.constraint_object_id=f.object_id
 WHERE f.parent_object_id=@Object AND f.referenced_object_id=OBJECT_ID(N''dbo.ExportReplacementActivation'')
 AND COL_NAME(@Object,c.parent_column_id)=N''ActivationID'' AND COL_NAME(f.referenced_object_id,c.referenced_column_id)=N''ActivationID''
 AND f.is_disabled=0 AND f.is_not_trusted=0 AND f.is_not_for_replication=0
 AND f.delete_referential_action=0 AND f.update_referential_action=0)
 OR (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE parent_object_id=@Object)<>1
 THROW 51961,''ExportRegistrationAttestation foreign-key contract differs.'',1;
';

IF OBJECT_ID(N'dbo.ExportUnownedHoldDisposition') IS NULL BEGIN
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.ExportUnownedHoldDisposition
(
    ActionID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    StorageOwner varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ReviewHash binary(32) NOT NULL,
    BeforeJson nvarchar(max) NOT NULL,
    AfterVersion bigint NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) NOT NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_UnownedHoldDisposition_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ExportUnownedHoldDisposition PRIMARY KEY(ActionID),
    CONSTRAINT CK_UnownedHoldDisposition_Resource CHECK(ResourceKey='sql_snapshot:legacy_outputs'),
    CONSTRAINT CK_UnownedHoldDisposition_Json CHECK(ISJSON(BeforeJson)=1 AND DATALENGTH(BeforeJson)<=16384),
    CONSTRAINT CK_UnownedHoldDisposition_Text CHECK(LEN(AccountKey)>0 AND LEN(StorageOwner)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    CONSTRAINT CK_UnownedHoldDisposition_Version CHECK(AfterVersion>1),
    CONSTRAINT UQ_UnownedHoldDisposition_Version UNIQUE(ResourceKey,AfterVersion)
);
CREATE INDEX IX_UnownedHoldDisposition_Account ON dbo.ExportUnownedHoldDisposition(AccountKey,StorageOwner,AfterVersion);

END;
EXEC sys.sp_executesql N'DECLARE @Object int=OBJECT_ID(N''dbo.ExportUnownedHoldDisposition''),@Expected int;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE #Expected
(
    ActionID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    StorageOwner varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ReviewHash binary(32) NOT NULL,
    BeforeJson nvarchar(max) COLLATE DATABASE_DEFAULT NOT NULL,
    AfterVersion bigint NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL,
    CreatedUTC datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    PRIMARY KEY(ActionID),
    CHECK(ResourceKey=''sql_snapshot:legacy_outputs''),
    CHECK(ISJSON(BeforeJson)=1 AND DATALENGTH(BeforeJson)<=16384),
    CHECK(LEN(AccountKey)>0 AND LEN(StorageOwner)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    CHECK(AfterVersion>1),
    UNIQUE(ResourceKey,AfterVersion)
);
CREATE INDEX IX_UnownedHoldDisposition_Account ON #Expected(AccountKey,StorageOwner,AfterVersion);

SET @Expected=OBJECT_ID(N''tempdb..#Expected'');

SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ActualColumns FROM sys.columns WHERE object_id=@Object;
SELECT name COLLATE Latin1_General_100_BIN2 AS name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type INTO #ExpectedColumns FROM tempdb.sys.columns WHERE object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualColumns EXCEPT SELECT * FROM #ExpectedColumns)
 OR EXISTS(SELECT * FROM #ExpectedColumns EXCEPT SELECT * FROM #ActualColumns)
 OR (SELECT COUNT(*) FROM #ActualColumns)<>(SELECT COUNT(*) FROM #ExpectedColumns)
 THROW 51961,''ExportUnownedHoldDisposition Columns contract differs.'',1;
DROP TABLE #ActualColumns,#ExpectedColumns;

SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ActualChecks FROM sys.check_constraints WHERE parent_object_id=@Object;
SELECT definition COLLATE Latin1_General_100_BIN2 AS definition,is_disabled,is_not_trusted,is_not_for_replication INTO #ExpectedChecks FROM tempdb.sys.check_constraints WHERE parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualChecks EXCEPT SELECT * FROM #ExpectedChecks)
 OR EXISTS(SELECT * FROM #ExpectedChecks EXCEPT SELECT * FROM #ActualChecks)
 OR (SELECT COUNT(*) FROM #ActualChecks)<>(SELECT COUNT(*) FROM #ExpectedChecks)
 THROW 51961,''ExportUnownedHoldDisposition Checks contract differs.'',1;
DROP TABLE #ActualChecks,#ExpectedChecks;

SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ActualDefaults FROM sys.default_constraints d JOIN sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Object;
SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ExpectedDefaults FROM tempdb.sys.default_constraints d JOIN tempdb.sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualDefaults EXCEPT SELECT * FROM #ExpectedDefaults)
 OR EXISTS(SELECT * FROM #ExpectedDefaults EXCEPT SELECT * FROM #ActualDefaults)
 THROW 51961,''ExportUnownedHoldDisposition defaults differ.'',1;
DROP TABLE #ActualDefaults,#ExpectedDefaults;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ActualIndexes FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Object;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ExpectedIndexes FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualIndexes EXCEPT SELECT * FROM #ExpectedIndexes)
 OR EXISTS(SELECT * FROM #ExpectedIndexes EXCEPT SELECT * FROM #ActualIndexes)
 OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@Object)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR (SELECT COUNT(*) FROM #ActualIndexes)<>(SELECT COUNT(*) FROM #ExpectedIndexes)
 THROW 51961,''ExportUnownedHoldDisposition index contract differs.'',1;
DROP TABLE #ActualIndexes,#ExpectedIndexes;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@Object)
 OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Object AND (temporal_type<>0 OR is_memory_optimized=1 OR is_replicated=1 OR is_tracked_by_cdc=1))
 THROW 51961,''Unexpected ExportUnownedHoldDisposition table behaviour.'',1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@Object) THROW 51961,''Unexpected foreign key.'',1;';

SET @Object=OBJECT_ID(N'dbo.usp_S11ValidateStatsReportStage');
SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=@Object);
IF (@Object IS NOT NULL AND (@Body IS NULL OR OBJECTPROPERTY(@Object,'IsProcedure')<>1))
    
 THROW 51961,'Missing or incompatible usp_S11ValidateStatsReportStage definition.',1;
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE
 WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE')
 ELSE @Body END;
IF @Body IS NOT NULL AND HASHBYTES('SHA2_256',@Body) NOT IN (0x1a4fde59149792a12c394b6e590532ace26a658237f0795a4f0d003b4b269dd1)
 THROW 51961,'Unreviewed usp_S11ValidateStatsReportStage preimage; preserve and review.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Object
 AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1 OR is_schema_bound=1))
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Object)
 THROW 51961,'Unexpected usp_S11ValidateStatsReportStage execution context or signature.',1;
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_S11ValidateStatsReportStage
    @PreparationID uniqueidentifier,
    @CompletedFileName nvarchar(260)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>1 OR XACT_STATE()<>1
        THROW 51961, ''One owned reporting transaction required.'', 1;
    DECLARE @LockResult int;
    EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK @LockTimeout=0,@LockResult=@LockResult OUTPUT;
    IF @LockResult<0 THROW 51961, ''Scan writer is active; reporting remains held.'', 1;
    -- The non-coordinated legacy entry point still uses these same business
    -- calculations. It has no durable continuation and cannot adopt one.
    IF @PreparationID IS NULL RETURN;
    DECLARE @Resource nvarchar(255)=N''S11:stats-import:''+LOWER(CONVERT(nvarchar(36),@PreparationID));
    IF COALESCE(APPLOCK_MODE(N''public'',@Resource,N''Session''),N''NoLock'')<>N''Exclusive''
       OR COALESCE(APPLOCK_MODE(N''public'',N''k98-legacy-output-snapshot'',N''Session''),N''NoLock'')<>N''Exclusive''
        THROW 51961, ''Both independent producer session guards are required.'', 1;
    IF NOT EXISTS (
        SELECT 1 FROM dbo.StatsImportExecution e WITH (UPDLOCK,HOLDLOCK)
        JOIN dbo.StatsImportReportContinuation c WITH (UPDLOCK,HOLDLOCK) ON c.PreparationID=e.PreparationID
        JOIN dbo.ExportPreparation p WITH (UPDLOCK,HOLDLOCK) ON p.PreparationID=e.PreparationID
        JOIN dbo.ExportResource r WITH (UPDLOCK,HOLDLOCK) ON r.ActivePreparationID=p.PreparationID
        JOIN dbo.KS4_ImportFileClaim f WITH (HOLDLOCK) ON f.CompletedFileName COLLATE Latin1_General_100_BIN2=e.CompletedFileName
        WHERE e.PreparationID=@PreparationID AND e.CompletedFileName=@CompletedFileName
          AND e.Resolution IS NULL AND e.State IN (''import_committed'',''partial'',''completed'')
          AND e.ScanOrder=c.ScanOrder AND c.ContractVersion=1
          AND (e.State<>''completed'' OR c.CompletedStage=3)
          AND (c.CompletedStage<>3 OR e.State=''completed'')
          AND p.ConsumerKind=''scan_data'' AND p.State IN (''writing'',''committed'',''uncertain'')
          AND p.OwnerID=e.OwnerID AND p.Fence=e.Fence
          AND p.JobID IS NULL AND p.SpoolKey IS NULL AND p.GenerationJson IS NULL
          AND r.ResourceKey=''sql_snapshot:legacy_outputs'' AND r.OwnerID=p.OwnerID AND r.Fence=p.Fence
          AND r.ActiveJobID IS NULL AND r.ActiveOutputOperationID IS NULL
          AND f.FileDigest=c.InputDigest AND f.ClaimStatus IN (''imported'',''archived'')
          AND c.LatestScanOrder=(SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4 WITH (HOLDLOCK))
          AND c.ConfigurationJson=(SELECT KVKVersion,ConfigKey,ConfigValue,LastUpdated
              FROM dbo.ProcConfig WITH (HOLDLOCK) ORDER BY KVKVersion,ConfigKey
              FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE Latin1_General_100_BIN2
          AND NOT EXISTS (SELECT 1 FROM dbo.ExportResource other WITH (HOLDLOCK)
              WHERE other.ActivePreparationID=p.PreparationID AND other.ResourceKey<>''sql_snapshot:legacy_outputs'')
    ) THROW 51961, ''Exact committed input, unchanged configuration and retained ownership required.'', 1;
END;';


SET @Object=OBJECT_ID(N'dbo.usp_S11CompleteStatsReportsCore');
SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=@Object);
IF (@Object IS NOT NULL AND (@Body IS NULL OR OBJECTPROPERTY(@Object,'IsProcedure')<>1))
    
 THROW 51961,'Missing or incompatible usp_S11CompleteStatsReportsCore definition.',1;
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE
 WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE')
 ELSE @Body END;
IF @Body IS NOT NULL AND HASHBYTES('SHA2_256',@Body) NOT IN (0x4600b4c18024583b1b5ec76c7cc6d68a134708ea105bdd860eb78ff7b15f4a8d)
 THROW 51961,'Unreviewed usp_S11CompleteStatsReportsCore preimage; preserve and review.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Object
 AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1 OR is_schema_bound=1))
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Object)
 THROW 51961,'Unexpected usp_S11CompleteStatsReportsCore execution context or signature.',1;
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_S11CompleteStatsReportsCore
    @CompletedFileName nvarchar(260),
    @ExportPreparationID uniqueidentifier = NULL,
    @actual_param1 float = NULL,
    @actual_param2 nvarchar(100) = NULL,
    @rowsKS5 int = 0,
    @rowsKS4 int = 0,
    @StartTime datetime = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;
    IF @@TRANCOUNT <> 0 THROW 51961, ''Reporting requires an unowned transaction.'', 1;
    DECLARE @CompletedStage tinyint=0;
    DECLARE @PhaseBStart datetime2=SYSUTCDATETIME(), @StepStart datetime2,
        @StepEnd datetime2, @StepDuration int, @CurrentLogUsedPct decimal(5,2)=NULL;
    DECLARE @CurrentAuditPhase NVARCHAR(64) = N''update_all2_start'';
    DECLARE @UpdateAll2PhaseAudit TABLE (
        SequenceNo INT IDENTITY(1,1) NOT NULL,
        PhaseName NVARCHAR(64) NOT NULL,
        PhaseStatus NVARCHAR(32) NOT NULL,
        StartedAtUtc DATETIME2(3) NOT NULL,
        CompletedAtUtc DATETIME2(3) NULL,
        DurationMs INT NULL,
        RowsIn INT NULL,
        RowsOut INT NULL,
        DetailsJson NVARCHAR(MAX) NULL,
        ErrorType NVARCHAR(128) NULL,
        ErrorText NVARCHAR(2000) NULL
    );

    BEGIN TRY

        BEGIN TRANSACTION;
        EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        IF @ExportPreparationID IS NOT NULL
            SELECT @CompletedStage=CompletedStage, @actual_param1=KingdomRank,
                @actual_param2=KingdomSeed, @rowsKS5=RowsKS5, @rowsKS4=RowsKS4,
                @StartTime=ImportStartedUTC
            FROM dbo.StatsImportReportContinuation WITH (UPDLOCK,HOLDLOCK)
            WHERE PreparationID=@ExportPreparationID;
        COMMIT;
        IF @CompletedStage=3 RETURN;
        SET @StartTime=COALESCE(@StartTime,GETDATE());

        -- *** NEW: Check log space at Phase B start ***
        SET @CurrentLogUsedPct = NULL;
        DECLARE @LogReuse NVARCHAR(60) = NULL;

        BEGIN TRY
            SELECT @CurrentLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC if DMV not available
            BEGIN TRY
                CREATE TABLE #LogSpace (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpace EXEC(''DBCC SQLPERF(LOGSPACE)'');
                SELECT @CurrentLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpace 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpace;
            END TRY
            BEGIN CATCH
                SET @CurrentLogUsedPct = NULL;
            END CATCH
        END CATCH

        BEGIN TRY
            SELECT @LogReuse = log_reuse_wait_desc
            FROM sys.databases
            WHERE name = DB_NAME();
        END TRY
        BEGIN CATCH
            SET @LogReuse = NULL;
        END CATCH

        PRINT ''Phase B Start - Log Usage: '' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), ''unknown'') + 
              ''%, Reuse Wait: '' + ISNULL(@LogReuse, ''unknown'');

        -- If log usage is high (>70%), force checkpoint before continuing
        IF @CurrentLogUsedPct IS NOT NULL AND @CurrentLogUsedPct > 70.0
        BEGIN
            PRINT ''Log usage elevated ('' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                  ''%); executing CHECKPOINT before Phase B operations...'';
            CHECKPOINT;
            
            -- Log this event for monitoring
            INSERT INTO dbo.ErrorAudit (ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo)
            VALUES (
                GETDATE(), ''UPDATE_ALL2'', 0, 
                ''Elevated log usage detected at Phase B start'', 0,
                ''Log usage: '' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                ''%, Reuse wait: '' + ISNULL(@LogReuse, ''unknown'')
            );
        END

        IF @CompletedStage=0
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        -- Step 1: CREATE_THE_AVERAGES
        SET @CurrentAuditPhase = N''update_all2_create_averages'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.CREATE_THE_AVERAGES;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"CREATE_THE_AVERAGES"}'');
        PRINT ''CREATE_THE_AVERAGES: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        -- Step 2: Rebuild EXCEL_FOR_DASHBOARD
        SET @CurrentAuditPhase = N''update_all2_rebuild_excel_dashboard'';
        SET @StepStart = SYSUTCDATETIME();
        IF OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'',''U'') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        EXEC dbo.sp_Rebuild_ExcelForDashboard;
        
        -- ⚡ OPTIMIZATION: Update statistics on newly built table
        IF OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'',''U'') IS NOT NULL
        BEGIN
            UPDATE STATISTICS dbo.EXCEL_FOR_DASHBOARD WITH SAMPLE 25 PERCENT;
            PRINT ''EXCEL_FOR_DASHBOARD statistics updated'';
        END
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"sp_Rebuild_ExcelForDashboard","target":"EXCEL_FOR_DASHBOARD"}'');
        PRINT ''sp_Rebuild_ExcelForDashboard: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        -- Step 3: CREATE_DASH2
        SET @CurrentAuditPhase = N''update_all2_create_dash2'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.CREATE_DASH2;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"CREATE_DASH2"}'');
        PRINT ''CREATE_DASH2: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        ----------------------------------------------------------------
        -- Step 4a: Refresh EXCEL_FOR_KVK table FIRST (lifted from SP_Stats_for_Upload)
        ----------------------------------------------------------------
        SET @StepStart = SYSUTCDATETIME();
        
        -- Determine which KVK and Scan to use (same logic as SP_Stats_for_Upload)
        DECLARE @LatestKVK_Upload INT;
        DECLARE @MaxScan_Upload INT = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4);
        DECLARE @MatchmakingScan_Upload INT;
        DECLARE @DraftScan_Upload INT;
        DECLARE @ScanToUse_Upload INT;

        SELECT TOP 1 @LatestKVK_Upload = KVKVersion
        FROM dbo.ProcConfig
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CAST(ConfigValue AS INT) <= @MaxScan_Upload
        ORDER BY KVKVersion DESC;

        IF @LatestKVK_Upload IS NOT NULL
        BEGIN
            SELECT
                @MatchmakingScan_Upload = MAX(CASE WHEN ConfigKey = ''MATCHMAKING_SCAN'' THEN TRY_CAST(ConfigValue AS INT) END),
                @DraftScan_Upload       = MAX(CASE WHEN ConfigKey = ''DRAFTSCAN''        THEN TRY_CAST(ConfigValue AS INT) END)
            FROM dbo.ProcConfig
            WHERE KVKVersion = @LatestKVK_Upload
              AND ConfigKey IN (''MATCHMAKING_SCAN'',''DRAFTSCAN'');

            -- Decide which scan to use
            SET @ScanToUse_Upload = NULL;
            IF @MatchmakingScan_Upload IS NOT NULL AND @MaxScan_Upload >= @MatchmakingScan_Upload
                SET @ScanToUse_Upload = @MatchmakingScan_Upload;
            ELSE IF @DraftScan_Upload IS NOT NULL AND @MaxScan_Upload >= @DraftScan_Upload
                SET @ScanToUse_Upload = @DraftScan_Upload;

            IF @ScanToUse_Upload IS NOT NULL
            BEGIN
                PRINT ''Step 4a: Refreshing EXCEL_FOR_KVK_'' + CAST(@LatestKVK_Upload AS VARCHAR(10)) 
                    + '' with ScanOrder='' + CAST(@ScanToUse_Upload AS VARCHAR(10)) + ''...'';
                
                -- ✅ LIFT: Call sp_ExcelOutput_ByKVK directly here
                SET @CurrentAuditPhase = N''update_all2_excel_for_kvk_refresh'';
                SET @StepStart = SYSUTCDATETIME();
                EXEC dbo.sp_ExcelOutput_ByKVK @KVK = @LatestKVK_Upload, @Scan = @ScanToUse_Upload;
                
                SET @StepEnd = SYSUTCDATETIME();
                SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
                INSERT INTO @UpdateAll2PhaseAudit
                    (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
                VALUES
                    (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
                     N''{"procedure":"sp_ExcelOutput_ByKVK","kvk":'' + CAST(@LatestKVK_Upload AS NVARCHAR(20)) +
                     N'',"scan":'' + CAST(@ScanToUse_Upload AS NVARCHAR(20)) + N''}'');
                PRINT ''sp_ExcelOutput_ByKVK: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

            END
        END

            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=1, ReportKVK=@LatestKVK_Upload, ReportScan=@ScanToUse_Upload,
                    PrefixCompletedUTC=SYSUTCDATETIME(), Version=Version+1
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=0;
                IF @@ROWCOUNT<>1 THROW 51961, ''Reporting prefix receipt changed.'', 1;
            END;
            COMMIT;
            SET @CompletedStage=1;
        END;

        IF @CompletedStage=1
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
            IF @ExportPreparationID IS NOT NULL
                SELECT @LatestKVK_Upload=ReportKVK, @ScanToUse_Upload=ReportScan
                FROM dbo.StatsImportReportContinuation WITH (UPDLOCK,HOLDLOCK)
                WHERE PreparationID=@ExportPreparationID;
            SET @CurrentAuditPhase=N''update_all2_stats_for_upload'';
            SET @StepStart=SYSUTCDATETIME();
            IF @LatestKVK_Upload IS NOT NULL AND @ScanToUse_Upload IS NOT NULL
                EXEC dbo.SP_Stats_for_Upload;
            SET @StepEnd=SYSUTCDATETIME();
            INSERT INTO @UpdateAll2PhaseAudit
                (PhaseName,PhaseStatus,StartedAtUtc,CompletedAtUtc,DurationMs,DetailsJson)
            VALUES (@CurrentAuditPhase,
                CASE WHEN @LatestKVK_Upload IS NOT NULL AND @ScanToUse_Upload IS NOT NULL
                    THEN N''completed'' ELSE N''skipped'' END,
                @StepStart,@StepEnd,DATEDIFF(millisecond,@StepStart,@StepEnd),
                N''{"procedure":"SP_Stats_for_Upload"}'');
            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=2, UploadCompletedUTC=SYSUTCDATETIME(), Version=Version+1
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=1;
                IF @@ROWCOUNT<>1 THROW 51961, ''Upload report receipt changed.'', 1;
            END;
            COMMIT;
            SET @CompletedStage=2;
        END;

        IF @CompletedStage=2
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        ----------------------------------------------------------------
        -- ⚡⚡⚡ OPTIMIZED INSERT INTO ALL_STATS_FOR_DASHBAORD ⚡⚡⚡
        ----------------------------------------------------------------
        SET @CurrentAuditPhase = N''update_all2_all_stats_dashboard'';
        SET @StepStart = SYSUTCDATETIME();
        
        TRUNCATE TABLE dbo.ALL_STATS_FOR_DASHBAORD;

        INSERT INTO dbo.ALL_STATS_FOR_DASHBAORD WITH (TABLOCK) (
            [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
            [Starting Power], [Power_Delta], [Civilization], [KvKPlayed],
            [MostKvKKill], [MostKvKDead], [MostKvKHeal],
            [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon],
            [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct],
            [Starting T4&T5_KILLS], [T4_KILLS], [T5_KILLS], [T4&T5_Kills],
            [KILLS_OUTSIDE_KVK], [Kill Target], [% of Kill target],
            [Starting Deads], Deads_Delta, [DEADS_OUTSIDE_KVK],
            [T4_Deads], [T5_Deads], [Dead Target], [% of Dead Target], [% of Dead_Target],
            [Zeroed], [DKP_SCORE], [DKP Target], [% of DKP Target],
            HelpsDelta, RSS_Assist_Delta, RSS_Gathered_Delta,
            [Pass 4 Kills], [Pass 6 Kills], [Pass 7 Kills], [Pass 8 Kills],
            [Pass 4 Deads], [Pass 6 Deads], [Pass 7 Deads], [Pass 8 Deads],
            [Starting HealedTroops], [HealedTroopsDelta],
            [Starting KillPoints], [KillPointsDelta],
            [RangedPoints], [RangedPointsDelta],
            [AutarchTimes],
            [Max_PreKvk_Points], [Max_HonorPoints],
            [PreKvk_Rank], [Honor_Rank], [KVK_NO]
        )
        SELECT
            ed.[Rank], 
            ed.[KVK_RANK], 
            ed.[Gov_ID],
            RTRIM(COALESCE(ed.[Governor_Name], '''')) AS [Governor_Name],
            
            -- Numeric columns with COALESCE (handles NULL efficiently)
            COALESCE(ed.[Starting Power], 0),
            COALESCE(ed.[Power_Delta], 0),
            ed.[Civilization],  -- NULL allowed
            COALESCE(ed.[KvKPlayed], 0),
            
            COALESCE(ed.[MostKvKKill], 0),
            COALESCE(ed.[MostKvKDead], 0),
            COALESCE(ed.[MostKvKHeal], 0),
            COALESCE(ed.[Acclaim], 0),
            COALESCE(ed.[HighestAcclaim], 0),
            COALESCE(ed.[AOOJoined], 0),
            COALESCE(ed.[AOOWon], 0),
            COALESCE(ed.[AOOAvgKill], 0),
            COALESCE(ed.[AOOAvgDead], 0),
            COALESCE(ed.[AOOAvgHeal], 0),
            ed.[Conduct],
            
            COALESCE(ed.[Starting_T4&T5_KILLS], 0),
            COALESCE(ed.[T4_KILLS], 0),
            COALESCE(ed.[T5_KILLS], 0),
            COALESCE(ed.[T4&T5_Kills], 0),
            COALESCE(ed.[KILLS_OUTSIDE_KVK], 0),
            COALESCE(ed.[Kill Target], 0),
            COALESCE(ed.[% of Kill Target], 0),
            
            COALESCE(ed.[Starting_Deads], 0),
            COALESCE(ed.[Deads_Delta], 0),
            COALESCE(ed.[DEADS_OUTSIDE_KVK], 0),
            COALESCE(ed.[T4_Deads], 0),
            COALESCE(ed.[T5_Deads], 0),
            COALESCE(ed.[Dead_Target], 0),
            COALESCE(ed.[% of Dead Target], 0),
            COALESCE(ed.[% of Dead Target], 0),  -- Duplicate column (fix in schema later)
            
            COALESCE(ed.[Zeroed], 0),
            COALESCE(ed.[DKP_SCORE], 0),
            COALESCE(ed.[DKP Target], 0),
            COALESCE(ed.[% of DKP Target], 0),
            
            COALESCE(ed.[HelpsDelta], 0),
            COALESCE(ed.[RSS_Assist_Delta], 0),
            COALESCE(ed.[RSS_Gathered_Delta], 0),
            
            COALESCE(ed.[Pass 4 Kills], 0),
            COALESCE(ed.[Pass 6 Kills], 0),
            COALESCE(ed.[Pass 7 Kills], 0),
            COALESCE(ed.[Pass 8 Kills], 0),
            COALESCE(ed.[Pass 4 Deads], 0),
            COALESCE(ed.[Pass 6 Deads], 0),
            COALESCE(ed.[Pass 7 Deads], 0),
            COALESCE(ed.[Pass 8 Deads], 0),
            
            COALESCE(ed.[Starting_HealedTroops], 0),
            COALESCE(ed.[HealedTroopsDelta], 0),
            COALESCE(ed.[Starting_KillPoints], 0),
            COALESCE(ed.[KillPointsDelta], 0),
            COALESCE(ed.[RangedPoints], 0),
            COALESCE(ed.[RangedPointsDelta], 0),
            COALESCE(ed.[AutarchTimes], 0),
            
            COALESCE(ed.[Max_PreKvk_Points], 0),
            COALESCE(ed.[Max_HonorPoints], 0),
            COALESCE(ed.[PreKvk_Rank], 0),
            COALESCE(ed.[Honor_Rank], 0),
            COALESCE(ed.[KVK_NO], 0)
        FROM dbo.EXCEL_FOR_DASHBOARD AS ed
        WHERE ed.Gov_ID <> 12025033
        OPTION (RECOMPILE);  -- Fresh execution plan with current statistics
        
        DECLARE @RowsInserted INT = @@ROWCOUNT;
        
        -- ⚡ OPTIMIZATION: Update statistics after bulk insert
        UPDATE STATISTICS dbo.ALL_STATS_FOR_DASHBAORD WITH FULLSCAN;
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"ALL_STATS_FOR_DASHBAORD"}'');
        PRINT ''ALL_STATS_FOR_DASHBAORD insert: '' + CAST(@RowsInserted AS VARCHAR(10)) + '' rows, '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';
        
        ----------------------------------------------------------------
        -- Continue with POWER_BY_MONTH and remaining steps
        ----------------------------------------------------------------
        SET @CurrentAuditPhase = N''update_all2_power_by_month'';
        SET @StepStart = SYSUTCDATETIME();
        
        TRUNCATE TABLE dbo.POWER_BY_MONTH;

        INSERT INTO dbo.POWER_BY_MONTH (
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS], 
            DEADS, [MONTH], HealedTroops, RangedPoints
        )
        SELECT 
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
            DEADS, [MONTH], HealedTroops, RangedPoints
        FROM (
            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.KingdomScanData4
            WHERE GovernorID NOT IN (0, 12025033)
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

            UNION ALL

            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.THE_AVERAGES
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)
        ) AS T
        ORDER BY GovernorID, [MONTH];
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"target":"POWER_BY_MONTH"}'');
        PRINT ''POWER_BY_MONTH: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        SET @CurrentAuditPhase = N''update_all2_refresh_inactive_governors'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.sp_RefreshInactiveGovernors;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"sp_RefreshInactiveGovernors"}'');

        DECLARE @MAXDATE DATETIME = (SELECT TOP 1 ScanDate FROM dbo.KingdomScanData4 ORDER BY ScanDate DESC);

        SET @CurrentAuditPhase = N''update_all2_ks_summary_insert'';
        SET @StepStart = SYSUTCDATETIME();
        INSERT INTO dbo.KS (
            KINGDOM_POWER, Governors, KP, [KILL], [DEAD], [CH25], 
            HealedTroops, RangedPoints, [Last Update], KINGDOM_RANK, KINGDOM_SEED
        )
        SELECT
            SUM(CAST([Power] AS BIGINT)), COUNT(GovernorID), SUM([KillPoints]),
            SUM([TOTAL_KILLS]), SUM([DEADS]),
            CAST(SUM(CASE WHEN [City Hall] = 25 THEN 1 ELSE 0 END) AS INT),
            SUM(ISNULL([HealedTroops], 0)), SUM(ISNULL([RangedPoints], 0)),
            @MAXDATE, @actual_param1, @actual_param2
        FROM dbo.KingdomScanData4
        WHERE ScanDate = @MAXDATE;
        SET @RowsInserted = @@ROWCOUNT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"KS"}'');

        SET @CurrentAuditPhase = N''update_all2_summary_proc'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.SUMMARY_PROC;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"SUMMARY_PROC"}'');

        SET @CurrentAuditPhase = N''update_all2_governor_names'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.GOVERNOR_NAMES_PROC;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"GOVERNOR_NAMES_PROC"}'');

        SET @CurrentAuditPhase = N''update_all2_scan_list'';
        SET @StepStart = SYSUTCDATETIME();
        TRUNCATE TABLE dbo.SCAN_LIST;

        INSERT INTO dbo.SCAN_LIST (SCANORDER, ScanDate)
        SELECT SCANORDER, ScanDate
        FROM dbo.KingdomScanData4
        GROUP BY SCANORDER, ScanDate;
        SET @RowsInserted = @@ROWCOUNT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"SCAN_LIST"}'');

        ----------------------------------------------------------------
        -- *** NEW: Phase B Completion - Log Management ***
        ----------------------------------------------------------------
        
        -- Force checkpoint to write dirty pages and minimize recovery time
        SET @CurrentAuditPhase = N''update_all2_checkpoint_log'';
        SET @StepStart = SYSUTCDATETIME();
        PRINT ''Executing CHECKPOINT to flush dirty pages...'';
        CHECKPOINT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"operation":"CHECKPOINT"}'');
        PRINT ''CHECKPOINT complete.'';

        -- Get final log usage
        DECLARE @FinalLogUsedPct DECIMAL(5,2) = NULL;
        BEGIN TRY
            SELECT @FinalLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC
            BEGIN TRY
                CREATE TABLE #LogSpaceFinal (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpaceFinal EXEC(''DBCC SQLPERF(LOGSPACE)'');
                SELECT @FinalLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpaceFinal 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpaceFinal;
            END TRY
            BEGIN CATCH
                SET @FinalLogUsedPct = NULL;
            END CATCH
        END CATCH

        -- Insert signal record for Python bot to detect
        IF OBJECT_ID(''dbo.LogBackupTriggerQueue'', ''U'') IS NOT NULL
        BEGIN
            INSERT INTO dbo.LogBackupTriggerQueue (
                TriggerTime, 
                ProcedureName, 
                Reason, 
                LogUsedPctBefore
            )
            VALUES (
                SYSDATETIME(), 
                ''UPDATE_ALL2'', 
                ''post_heavy_operation'',
                @FinalLogUsedPct
            );
            PRINT ''Log backup trigger queued (log usage: '' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), ''unknown'') + ''%).'';
        END

        -- Attempt to trigger log backup job (non-blocking, best effort)
        DECLARE @LogBackupTriggered BIT = 0;
        PRINT ''Log backup trigger queued for Python processing.'';

        DECLARE @EndTime DATETIME = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
        DECLARE @PhaseBDuration INT = DATEDIFF(MILLISECOND, @PhaseBStart, SYSUTCDATETIME());

        PRINT ''========================================'';
        PRINT ''Phase B Total: '' + CAST(@PhaseBDuration AS VARCHAR(10)) + ''ms'';
        PRINT ''Log Usage: Initial='' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), ''unknown'') + 
              ''%, Final='' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), ''unknown'') + ''%'';
        PRINT ''Log Backup Triggered: '' + CASE WHEN @LogBackupTriggered = 1 THEN ''Yes'' ELSE ''No (queued for Python)'' END;
        PRINT ''========================================'';

        DECLARE @S11CompletionCounters TABLE (LastRunCounter int NOT NULL);
        INSERT INTO dbo.SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
        OUTPUT inserted.LastRunCounter INTO @S11CompletionCounters (LastRunCounter)
        VALUES (
            ''UPDATE_ALL2'', ''Complete'', @EndTime,
            ISNULL((SELECT MAX(LastRunCounter) FROM dbo.SP_TaskStatus WITH (UPDLOCK,HOLDLOCK) WHERE TaskName=''UPDATE_ALL2''), 0) + 1,
            @DurationSeconds
        );

        IF @ExportPreparationID IS NOT NULL
        BEGIN
            UPDATE dbo.StatsImportExecution SET State=''completed'',
                LastRunCounter=(SELECT LastRunCounter FROM @S11CompletionCounters),
                UpdatedUTC=SYSUTCDATETIME(), Version=Version+1
            WHERE PreparationID=@ExportPreparationID AND CompletedFileName=@CompletedFileName AND State IN (''import_committed'',''partial'') AND Resolution IS NULL;
            IF @@ROWCOUNT <> 1 THROW 51960, ''Missing exact Phase B execution receipt.'', 1;
        END;
            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=3, SummaryCompletedUTC=SYSUTCDATETIME(), Version=Version+1,
                    RecoveryState=CASE WHEN RecoveryActionID IS NOT NULL THEN ''completed'' END
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=2;
                IF @@ROWCOUNT<>1 THROW 51961, ''Summary receipt changed.'', 1;
            END;
            INSERT INTO dbo.Update_ALL_Complete (CompletionTime) VALUES (GETDATE());
            COMMIT;
        END;

        SELECT
            PhaseName,
            PhaseStatus,
            StartedAtUtc,
            CompletedAtUtc,
            DurationMs,
            RowsIn,
            RowsOut,
            DetailsJson,
            ErrorType,
            ErrorText
        FROM @UpdateAll2PhaseAudit
        ORDER BY SequenceNo;

        SELECT 
            @rowsKS5 AS RowsInsertedKS5,
            @rowsKS4 AS RowsInsertedKS4,
            @DurationSeconds AS DurationSeconds,
            @PhaseBDuration AS PhaseBDurationMS,
            @CurrentLogUsedPct AS LogUsedPctBefore,
            @FinalLogUsedPct AS LogUsedPctAfter,
            @LogBackupTriggered AS LogBackupTriggered,
            ''SUCCESS'' AS Status;

    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;';


SET @Object=OBJECT_ID(N'dbo.usp_S11CompleteStatsReports');
SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=@Object);
IF (@Object IS NOT NULL AND (@Body IS NULL OR OBJECTPROPERTY(@Object,'IsProcedure')<>1))
    
 THROW 51961,'Missing or incompatible usp_S11CompleteStatsReports definition.',1;
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE
 WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE')
 ELSE @Body END;
IF @Body IS NOT NULL AND HASHBYTES('SHA2_256',@Body) NOT IN (0x78fd1381a630d4ec23fce8a1c4381642956a32d7b7145d74e457f63d8a6d3fd7)
 THROW 51961,'Unreviewed usp_S11CompleteStatsReports preimage; preserve and review.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Object
 AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1 OR is_schema_bound=1))
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Object)
 THROW 51961,'Unexpected usp_S11CompleteStatsReports execution context or signature.',1;
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_S11CompleteStatsReports
    @CompletedFileName nvarchar(260),
    @ExportPreparationID uniqueidentifier = NULL,
    @actual_param1 float = NULL,
    @actual_param2 nvarchar(100) = NULL,
    @rowsKS5 int = 0,
    @rowsKS4 int = 0,
    @StartTime datetime = NULL
AS
BEGIN
    SET NOCOUNT ON;
    -- The nullable legacy path is private and reached only by UPDATE_ALL2''s
    -- same-owner static call. Recovery callers must present durable authority.
    IF @ExportPreparationID IS NULL
        THROW 51961, ''Recovery reporting requires a preparation ID.'', 1;
    EXEC dbo.usp_S11CompleteStatsReportsCore
        @CompletedFileName=@CompletedFileName,
        @ExportPreparationID=@ExportPreparationID,
        @actual_param1=@actual_param1, @actual_param2=@actual_param2,
        @rowsKS5=@rowsKS5, @rowsKS4=@rowsKS4, @StartTime=@StartTime;
END;';


SET @Object=OBJECT_ID(N'dbo.UPDATE_ALL2');
SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=@Object);
IF (@Object IS NOT NULL AND (@Body IS NULL OR OBJECTPROPERTY(@Object,'IsProcedure')<>1))
    OR @Object IS NULL
 THROW 51961,'Missing or incompatible UPDATE_ALL2 definition.',1;
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE
 WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE')
 ELSE @Body END;
IF @Body IS NOT NULL AND HASHBYTES('SHA2_256',@Body) NOT IN (0x4a5640dbdf811d645ba9ed83062f08408f5d02e6c9c2338585042b031af080bc,0x873e30f87ec06efb1d38a281494a1a1bb08ad07ccb8ce77e9b8e0558c75f9c15)
 THROW 51961,'Unreviewed UPDATE_ALL2 preimage; preserve and review.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Object
 AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1 OR is_schema_bound=1))
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Object)
 THROW 51961,'Unexpected UPDATE_ALL2 execution context or signature.',1;
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[UPDATE_ALL2]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL,
    @CompletedFileName [nvarchar](260),
    @ExportPreparationID uniqueidentifier = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    -- REQUIRED SET Options for DML against indexed views / persisted computed columns
    SET ANSI_NULLS ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET QUOTED_IDENTIFIER ON;
    SET NUMERIC_ROUNDABORT OFF;

    IF @@TRANCOUNT <> 0
        THROW 51818, ''UPDATE_ALL2 refuses caller-owned transactions; execute the public entry point with no active transaction.'', 1;

    IF @ExportPreparationID IS NOT NULL
    BEGIN
        DECLARE @ExecutionResource nvarchar(255)=N''S11:stats-import:'' + LOWER(CONVERT(nvarchar(36),@ExportPreparationID));
        IF COALESCE(APPLOCK_MODE(N''public'',@ExecutionResource,N''Session''),N''NoLock'') <> N''Exclusive''
           OR NOT EXISTS (SELECT 1 FROM dbo.StatsImportExecution WHERE PreparationID=@ExportPreparationID
               AND CompletedFileName=@CompletedFileName AND State=''running'' AND Resolution IS NULL)
            THROW 51960, ''Exact S11 wrapper session and running receipt required.'', 1;
    END;

    SET XACT_ABORT ON;

    DECLARE @rc INT, @rowsKS5 INT, @rowsKS4 INT = 0;
    DECLARE @ImportLockResult INT;
    DECLARE @AllocatedScanOrder INT;
    DECLARE @StagedRows INT;
    DECLARE @ImportFileDigest BINARY(32);
    DECLARE @ImportClaimedPath NVARCHAR(4000);
    DECLARE @ImportArchivePath NVARCHAR(4000);
    DECLARE @ImportError NVARCHAR(2000);
    DECLARE @ArchiveReturnCode INT;
    DECLARE @CurrentAuditPhase NVARCHAR(64) = N''update_all2_start'';
    DECLARE @UpdateAll2PhaseAudit TABLE (
        SequenceNo INT IDENTITY(1,1) NOT NULL,
        PhaseName NVARCHAR(64) NOT NULL,
        PhaseStatus NVARCHAR(32) NOT NULL,
        StartedAtUtc DATETIME2(3) NOT NULL,
        CompletedAtUtc DATETIME2(3) NULL,
        DurationMs INT NULL,
        RowsIn INT NULL,
        RowsOut INT NULL,
        DetailsJson NVARCHAR(MAX) NULL,
        ErrorType NVARCHAR(128) NULL,
        ErrorText NVARCHAR(2000) NULL
    );

    BEGIN TRY
        EXEC dbo.CLAIM_KS4_IMPORT_FILE
            @CompletedFileName = @CompletedFileName,
            @FileDigest = @ImportFileDigest OUTPUT,
            @ClaimedPath = @ImportClaimedPath OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT;

        ----------------------------------------------------------------
        -- Phase A: Import → KS5 → (maybe) KS4  [commit early]
        ----------------------------------------------------------------
        BEGIN TRANSACTION;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51810, ''UPDATE_ALL2 could not acquire the KingdomScanData4 import mutex within 60000 ms; Phase A was not started.'', 1;

        -- Get deterministic defaults from KS. Choose "latest" row by [Last Update] if present.
        DECLARE @actual_param1 FLOAT = NULL,
                @actual_param2 NVARCHAR(100) = NULL;

        SELECT TOP (1)
            @actual_param1 = COALESCE(@param1, KINGDOM_RANK, 0),
            @actual_param2 = COALESCE(@param2, KINGDOM_SEED, N'''')
        FROM dbo.KS
        WHERE KINGDOM_RANK IS NOT NULL OR KINGDOM_SEED IS NOT NULL
        ORDER BY [Last Update] DESC; 

        IF @actual_param1 IS NULL SET @actual_param1 = COALESCE(@param1, 0);
        IF @actual_param2 IS NULL SET @actual_param2 = COALESCE(@param2, N'''');

        DECLARE @StartTime DATETIME = GETDATE();

        -- 1) Refresh latest data
        EXEC @rc = dbo.IMPORT_STAGING_PROC_CORE
            @CompletedFileName = @CompletedFileName,
            @ImportFileDigest = @ImportFileDigest OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT,
            @ImportError = @ImportError OUTPUT;
        IF @rc <> 0
        BEGIN
            SET @ImportError = COALESCE(
                @ImportError,
                N''UPDATE_ALL2 stopped because IMPORT_STAGING_PROC failed without returning error detail.''
            );
            THROW 51819, @ImportError, 1;
        END

        SELECT
            @AllocatedScanOrder = MIN(SCANORDER),
            @StagedRows = COUNT(*)
        FROM dbo.IMPORT_STAGING;

        IF @AllocatedScanOrder IS NULL
           OR @AllocatedScanOrder <> (SELECT MAX(SCANORDER) FROM dbo.IMPORT_STAGING)
           OR @StagedRows <> (SELECT COUNT(DISTINCT [Governor ID]) FROM dbo.IMPORT_STAGING)
            THROW 51811, ''UPDATE_ALL2 rejected empty, mixed-scan, or duplicate-governor canonical staging.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @AllocatedScanOrder
        )
            THROW 51812, ''UPDATE_ALL2 refused to reuse an existing KingdomScanData5 SCANORDER.'', 1;

        -- 2) Insert into KingdomScanData5
        INSERT INTO dbo.KingdomScanData5 (
              PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
            , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
            , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
            , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
        )
        SELECT
              ROW_NUMBER() OVER (ORDER BY [Power] DESC, [Governor ID] ASC) AS PowerRank
            , RTRIM([Name])
            , [Governor ID]
            , NULLIF(
				  LTRIM(RTRIM(
					REPLACE(REPLACE(CONVERT(nvarchar(255), [Alliance]), CHAR(13), ''''), CHAR(10), '''')
				  )),
				  N''''
			  ) AS Alliance
            , [Power]
            , [Total Kill Points]
            , [Dead Troops]
            , [T1-Kills], [T2-Kills], [T3-Kills], [T4-Kills], [T5-Kills]
            , [Kills (T4+)]
            , [KILLS]
            , [RSS Gathered], [RSS Assistance], [Alliance Helps]
            , [ScanDate], [SCANORDER]
            , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
            , [HealedTroops], [RangedPoints], [Civilization], [AutarchTimes], [KvKPlayed], [MostKvKKill], [MostKvKDead], [MostKvKHeal]
            , [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon], [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct]
        FROM dbo.IMPORT_STAGING WITH (TABLOCK);

        SET @rowsKS5 = @@ROWCOUNT;

        IF @rowsKS5 = 0
        BEGIN
            RAISERROR(''No rows inserted into KingdomScanData5 (IMPORT_STAGING was empty).'', 16, 1);
        END

        IF @rowsKS5 <> @StagedRows
           OR EXISTS
              (
                  SELECT 1
                  FROM dbo.KingdomScanData5
                  WHERE SCANORDER = @AllocatedScanOrder
                  GROUP BY SCANORDER, GovernorID
                  HAVING COUNT_BIG(*) > 1
              )
            THROW 51813, ''UPDATE_ALL2 KingdomScanData5 row-count or duplicate-key validation failed.'', 1;

        -- SMART INDEX MAINTENANCE: Only update stats for KS5 (lightweight)
        -- Full index rebuild happens nightly via maintenance job
        PRINT ''Updating statistics for KingdomScanData5 (quick sample)...'';
        UPDATE STATISTICS dbo.KingdomScanData5 WITH SAMPLE 20 PERCENT;
        PRINT ''KingdomScanData5 statistics refreshed.'';

        -- Cache MAX(SCANORDER) values to avoid repeated scans
        DECLARE @MaxScanOrder5 INT = (SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData5 ORDER BY SCANORDER DESC);
        DECLARE @MaxScanOrder4 INT = (SELECT TOP 1 SCANORDER FROM dbo.KingdomScanData4 ORDER BY SCANORDER DESC);

        IF @MaxScanOrder5 <> @AllocatedScanOrder
            THROW 51814, ''UPDATE_ALL2 allocated scan does not match the latest KingdomScanData5 scan.'', 1;

        -- 3) Promote to KS4 if newer
        IF @MaxScanOrder5 > @MaxScanOrder4
        BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.KingdomScanData4
                WHERE SCANORDER = @AllocatedScanOrder
            )
                THROW 51815, ''UPDATE_ALL2 refused to reuse an existing KingdomScanData4 SCANORDER.'', 1;

            INSERT INTO dbo.KingdomScanData4 (
                  PowerRank, GovernorName, GovernorID, Alliance, [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , RSS_Gathered, RSSAssistance, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
            )
            SELECT
                  PowerRank, GovernorName, GovernorID,
                  NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), ''''),
                  [Power], KillPoints, Deads
                , T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS
                , Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER
                , [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
                , HealedTroops, RangedPoints, Civilization, AutarchTimes, KvKPlayed, MostKvKKill, MostKvKDead, MostKvKHeal
                , Acclaim, HighestAcclaim, AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @MaxScanOrder5

            SET @rowsKS4 = @@ROWCOUNT;

            IF @rowsKS4 <> @rowsKS5
               OR EXISTS
                  (
                      SELECT 1
                      FROM dbo.KingdomScanData4
                      WHERE SCANORDER = @AllocatedScanOrder
                      GROUP BY SCANORDER, GovernorID
                      HAVING COUNT_BIG(*) > 1
                  )
                THROW 51816, ''UPDATE_ALL2 KingdomScanData4 row-count or duplicate-key validation failed.'', 1;

            ----------------------------------------------------------------
            -- SMART INDEX MAINTENANCE for KS4: Check fragmentation first
            -- Thresholds: 
            --   - Skip if < 10% fragmentation
            --   - REORGANIZE if 10-30% fragmentation (online, low impact)
            --   - REBUILD if > 30% fragmentation
            ----------------------------------------------------------------
            PRINT ''Checking KingdomScanData4 index fragmentation...'';
            
            DECLARE @IndexMaintLog TABLE (
                IndexName NVARCHAR(128),
                FragmentationPercent DECIMAL(5,2),
                Action NVARCHAR(20)
            );

            -- Check fragmentation of critical indexes
            DECLARE @IndexName NVARCHAR(128);
            DECLARE @Fragmentation DECIMAL(5,2);
            DECLARE @SQL NVARCHAR(MAX);

            DECLARE idx_cursor CURSOR LOCAL FAST_FORWARD FOR
                SELECT 
                    i.name AS IndexName,
                    ips.avg_fragmentation_in_percent AS Fragmentation
                FROM sys.dm_db_index_physical_stats(
                    DB_ID(), 
                    OBJECT_ID(''dbo.KingdomScanData4''), 
                    NULL, NULL, ''LIMITED''
                ) AS ips
                INNER JOIN sys.indexes AS i 
                    ON ips.object_id = i.object_id 
                    AND ips.index_id = i.index_id
                WHERE 
                    i.name IN (
                        ''CIX_KS4_ScanOrder_Governor'',
                        ''IX_KSD4_Governor_ScanOrder'', 
                        ''IX_KS4_Governor_ScanDate'',
                        ''IX_KSD4_Gov_ScanOrder''
                    )
                    AND ips.avg_fragmentation_in_percent IS NOT NULL;

            OPEN idx_cursor;
            FETCH NEXT FROM idx_cursor INTO @IndexName, @Fragmentation;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @Fragmentation < 10
                BEGIN
                    -- Skip - fragmentation is low
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, ''SKIPPED'');
                    PRINT ''  '' + @IndexName + '': '' + CAST(@Fragmentation AS VARCHAR(10)) + ''% - Skipped'';
                END
                ELSE IF @Fragmentation < 30
                BEGIN
                    -- REORGANIZE - medium fragmentation, online operation
                    SET @SQL = N''ALTER INDEX ['' + @IndexName + N''] ON dbo.KingdomScanData4 REORGANIZE;'';
                    EXEC sp_executesql @SQL;
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, ''REORGANIZED'');
                    PRINT ''  '' + @IndexName + '': '' + CAST(@Fragmentation AS VARCHAR(10)) + ''% - Reorganized'';
                END
                ELSE
                BEGIN
                    -- REBUILD - high fragmentation
                    SET @SQL = N''ALTER INDEX ['' + @IndexName + N''] ON dbo.KingdomScanData4 REBUILD WITH (SORT_IN_TEMPDB = ON, MAXDOP = 0);'';
                    EXEC sp_executesql @SQL;
                    INSERT INTO @IndexMaintLog VALUES (@IndexName, @Fragmentation, ''REBUILT'');
                    PRINT ''  '' + @IndexName + '': '' + CAST(@Fragmentation AS VARCHAR(10)) + ''% - Rebuilt'';
                END

                FETCH NEXT FROM idx_cursor INTO @IndexName, @Fragmentation;
            END

            CLOSE idx_cursor;
            DEALLOCATE idx_cursor;

            -- Always update statistics after any index maintenance
            UPDATE STATISTICS dbo.KingdomScanData4 WITH SAMPLE 25 PERCENT;
            PRINT ''KingdomScanData4 statistics refreshed.'';

			EXEC [dbo].[Refresh_PlayerScanMeta] @MinScanOrder = @MaxScanOrder5
			UPDATE STATISTICS dbo.PlayerScanMeta WITH SAMPLE 25 PERCENT;

            -- Log index maintenance actions
            SELECT * FROM @IndexMaintLog;
        END

        EXEC dbo.usp_UpsertGovernorNameHistoryForScan @ScanOrder = @MaxScanOrder5;

        -- 4) Truncate staging (safe post-insert)
        TRUNCATE TABLE dbo.IMPORT_STAGING;

        IF @ExportPreparationID IS NOT NULL
        BEGIN
            UPDATE dbo.StatsImportExecution SET State=''import_committed'', ScanOrder=@AllocatedScanOrder,
                UpdatedUTC=SYSUTCDATETIME(), Version=Version+1
            WHERE PreparationID=@ExportPreparationID AND CompletedFileName=@CompletedFileName AND State=''running'';
            IF @@ROWCOUNT <> 1 THROW 51960, ''Missing exact Phase A execution receipt.'', 1;
            -- Created only with the import commit. Historical partial work is never
            -- backfilled into this contract from a reservation or phase audit row.
            INSERT dbo.StatsImportReportContinuation
                (PreparationID,InputDigest,ScanOrder,LatestScanOrder,KingdomRank,KingdomSeed,
                 ConfigurationJson,RowsKS5,RowsKS4,ImportStartedUTC)
            SELECT @ExportPreparationID,@ImportFileDigest,@AllocatedScanOrder,
                (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4),@actual_param1,@actual_param2,
                (SELECT KVKVersion,ConfigKey,ConfigValue,LastUpdated
                 FROM dbo.ProcConfig WITH (HOLDLOCK)
                 ORDER BY KVKVersion,ConfigKey FOR JSON PATH,INCLUDE_NULL_VALUES),
                @rowsKS5,@rowsKS4,@StartTime;

        END;
        COMMIT;  -- ✅ Import is now durable even if later steps fail

        EXEC @ArchiveReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
            @CompletedFileName = @CompletedFileName;

        IF @ArchiveReturnCode <> 0
            THROW 51817, ''UPDATE_ALL2 committed Phase A but the immutable-file archive handoff did not complete.'', 1;

        -- Return / Log Phase A summary values
        SELECT
            @MaxScanOrder5    AS Ks5_MaxScanOrder,
            @rowsKS5          AS Ks5_RowsInserted,
            @rowsKS4          AS Ks4_RowsInserted,
            (SELECT COUNT(*) FROM dbo.IMPORT_STAGING) AS ImportStaging_RowsAfterPhaseA,
            (SELECT COUNT(*) FROM dbo.KingdomScanData4 WHERE SCANORDER = @MaxScanOrder4) AS Ks4_RowsInLatest,
            @ImportArchivePath AS ArchivedFilePath;

        -- Reporting uses transactional checkpoints. Recovery calls this reporting-only
        -- procedure, never UPDATE_ALL2 or its committed import stage.
        EXEC dbo.usp_S11CompleteStatsReportsCore
            @CompletedFileName=@CompletedFileName, @ExportPreparationID=@ExportPreparationID,
            @actual_param1=@actual_param1, @actual_param2=@actual_param2,
            @rowsKS5=@rowsKS5, @rowsKS4=@rowsKS4, @StartTime=@StartTime;

    END TRY
	BEGIN CATCH
		DECLARE @ErrNum  INT = ERROR_NUMBER();
		DECLARE @ErrMsg  NVARCHAR(MAX) = ERROR_MESSAGE();
		DECLARE @ErrLine INT = ERROR_LINE();
		DECLARE @ErrProc NVARCHAR(200) = ERROR_PROCEDURE();
        DECLARE @PersistedImportError NVARCHAR(2000) =
            LEFT(
                COALESCE(
                    @ImportError,
                    CONCAT(
                        N''Error '',
                        ERROR_NUMBER(),
                        N'' in '',
                        COALESCE(ERROR_PROCEDURE(), N''UPDATE_ALL2''),
                        N'' line '',
                        ERROR_LINE(),
                        N'': '',
                        COALESCE(ERROR_MESSAGE(), N''(no message)'')
                    )
                ),
                2000
            );

		-- ✅ capture transaction state before doing anything
		DECLARE @XState INT = XACT_STATE();

		-- ✅ if a transaction exists, you MUST rollback first (especially if @XState = -1)
		IF @XState <> 0
			ROLLBACK;

        BEGIN TRY
            UPDATE dbo.KS4_ImportFileClaim
            SET LastError = @PersistedImportError
            WHERE CompletedFileName = @CompletedFileName
              AND ClaimStatus = N''claimed'';
        END TRY
        BEGIN CATCH
            -- Never mask the original UPDATE_ALL2 failure.
        END CATCH;

		-- ✅ now you''re in autocommit, logging is allowed
		BEGIN TRY
			INSERT INTO dbo.ErrorAudit (
				ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo
			)
			VALUES (
				GETDATE(), ISNULL(@ErrProc, ''UPDATE_ALL2''), @ErrNum, @ErrMsg, @ErrLine,
				N''XACT_STATE='' + CAST(@XState AS NVARCHAR(10)) +
				N''; CurrentPhase='' + ISNULL(@CurrentAuditPhase, N''unknown'') +
				N''; Phase info: KS5_Rows='' + ISNULL(CAST(@rowsKS5 AS NVARCHAR(20)), N''NULL'') +
				N'', KS4_Rows='' + ISNULL(CAST(@rowsKS4 AS NVARCHAR(20)), N''NULL'')
			);
		END TRY
		BEGIN CATCH
			-- If even logging fails, don''t mask the original error
		END CATCH;

		THROW;
	END CATCH
END';


SET @Object=OBJECT_ID(N'dbo.usp_update_stats');
SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=@Object);
IF (@Object IS NOT NULL AND (@Body IS NULL OR OBJECTPROPERTY(@Object,'IsProcedure')<>1))
    OR @Object IS NULL
 THROW 51961,'Missing or incompatible usp_update_stats definition.',1;
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE
 WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE')
 ELSE @Body END;
IF @Body IS NOT NULL AND HASHBYTES('SHA2_256',@Body) NOT IN (0x7250d35b61546e8b5812c3dfa22c71623c20c79836ad1ecdeaad2e8322f2bea7,0xbfd72c9e25a6fdf3467a38a670c96e19fd0ecdd36a6fa9287a2bc6499d9752ad,0xcd094d389a6ec315b1de9c8b28bade14687f047ac0272c2dadaed52fb1720dfc)
 THROW 51961,'Unreviewed usp_update_stats preimage; preserve and review.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Object
 AND (execute_as_principal_id<>-2 OR execute_as_principal_id IS NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1 OR is_schema_bound=1))
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Object)
 THROW 51961,'Unexpected usp_update_stats execution context or signature.',1;
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[usp_update_stats]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Exclusion lives on the actual SQL worker session. A Python deadline or
    -- lost journal connection cannot permit a concurrent maintenance replay.
    DECLARE @LockResult int;
    EXEC @LockResult=sys.sp_getapplock @Resource=N''K98:post-import-stats:v1'',
        @LockMode=''Exclusive'',@LockOwner=''Session'',@LockTimeout=0;
    IF @LockResult<0 THROW 51961, ''Post-import maintenance is still active.'', 1;
    BEGIN TRY
        EXEC sp_updatestats;
        EXEC sys.sp_releaseapplock @Resource=N''K98:post-import-stats:v1'',@LockOwner=''Session'';
    END TRY
    BEGIN CATCH
        EXEC sys.sp_releaseapplock @Resource=N''K98:post-import-stats:v1'',@LockOwner=''Session'';
        THROW;
    END CATCH;
END';

DENY EXECUTE ON OBJECT::dbo.usp_S11CompleteStatsReportsCore TO public;
GRANT EXECUTE ON OBJECT::dbo.usp_S11ValidateStatsReportStage TO ExportLegacyEntryReader;
GRANT EXECUTE ON OBJECT::dbo.usp_S11CompleteStatsReports TO ExportLegacyEntryReader;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
