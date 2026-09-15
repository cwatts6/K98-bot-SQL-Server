/*
MigrationId: 20260914_002_legacy_export_preparation
Purpose: Add durable legacy capture and preflight admission before immutable export jobs
Author: cwatts
CreatedUtc: 2026-09-14
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Verify accepted S10A and absent or exact S10C preparation schema
PostValidationQuery: Verify preparation membership and trusted exclusive ownership checks
RelatedBotPR:
RelatedSQLPR:
*/
-- AUTHORING ONLY. No execution, activation, receipt mutation or resource release.
-- All old claim writers must be stopped/upgraded before dependent Bot deployment.
-- Backup/actual restore and exact-target approval required before installation.
-- Forward fix only: retain tables, captures, jobs, attempts, fences and blocked claims.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @OwnTransaction bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
IF @OwnTransaction=1 BEGIN TRANSACTION;
BEGIN TRY
 DECLARE @LockResult int;
 EXEC @LockResult=sys.sp_getapplock @Resource=N'K98:S10C:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51420,'S10C schema installation busy.',1;
 IF OBJECT_ID(N'dbo.ExportJob',N'U') IS NULL OR OBJECT_ID(N'dbo.ExportResource',N'U') IS NULL OR OBJECT_ID(N'dbo.ExportJobResource',N'U') IS NULL
  THROW 51420,'S10C requires accepted S10A tables.',1;
 IF EXISTS(SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID(N'dbo') AND name IN ('ExportPreparation','ExportPreparationResource') AND type<>'U')
  THROW 51420,'S10C object type conflict.',1;
 DECLARE @Existing int=(SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dbo') AND name IN ('ExportPreparation','ExportPreparationResource'));
 IF @Existing NOT IN (0,2) OR (@Existing=0 AND COL_LENGTH('dbo.ExportResource','ActivePreparationID') IS NOT NULL) OR (@Existing=2 AND COL_LENGTH('dbo.ExportResource','ActivePreparationID') IS NULL)
  THROW 51420,'Partial S10C schema; preserve and forward-fix.',1;
 IF @Existing=0
 BEGIN
 EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportPreparation
(
 PreparationID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ConsumerKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 KVK_NO int NULL,
 RequestHash binary(32) NOT NULL,
 EnqueueSequence bigint NOT NULL,
 State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 OwnerID uniqueidentifier NULL,
 Fence bigint NOT NULL,
 Version bigint NOT NULL,
 StorageOwner varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 RequestJson nvarchar(max) NOT NULL,
 GenerationJson nvarchar(max) NULL,
 SpoolKey varchar(128) COLLATE Latin1_General_100_BIN2 NULL,
 SpoolBytes bigint NULL,
 SpoolHash binary(32) NULL,
 JobID uniqueidentifier NULL,
 Actor nvarchar(128) NOT NULL,
 Reason nvarchar(1024) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 UpdatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportPreparation PRIMARY KEY (PreparationID),
 CONSTRAINT UQ_ExportPreparation_Replay UNIQUE (AccountKey,RequestHash),
 CONSTRAINT CK_ExportPreparation_Consumer CHECK (ConsumerKind IN (''all_kvk'',''scan_data'',''config'') AND DATALENGTH(ConsumerKind)=LEN(ConsumerKind)),
 CONSTRAINT CK_ExportPreparation_Scope CHECK ((ConsumerKind=''all_kvk'' AND KVK_NO IS NOT NULL AND KVK_NO>0) OR (ConsumerKind IN (''scan_data'',''config'') AND KVK_NO IS NULL)),
 CONSTRAINT CK_ExportPreparation_State CHECK (State IN (''pending'',''preflight'',''sql_pending'',''writing'',''committed'',''captured'',''materialized'',''completed'',''unavailable'',''uncertain'') AND DATALENGTH(State)=LEN(State)),
 CONSTRAINT CK_ExportPreparation_Owner CHECK ((OwnerID IS NULL AND Fence=0 AND State=''pending'') OR (OwnerID IS NOT NULL AND Fence>0)),
 CONSTRAINT CK_ExportPreparation_Counters CHECK (Version>0 AND EnqueueSequence>0 AND UpdatedUTC>=CreatedUTC),
 CONSTRAINT CK_ExportPreparation_Text CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=DATALENGTH(LTRIM(RTRIM(AccountKey))) AND LEN(StorageOwner)>0 AND DATALENGTH(StorageOwner)=DATALENGTH(LTRIM(RTRIM(StorageOwner))) AND LEN(Actor)>0 AND LEN(Reason)>0),
 CONSTRAINT CK_ExportPreparation_Request CHECK (ISJSON(RequestJson)=1 AND DATALENGTH(RequestJson)<=65536),
 CONSTRAINT CK_ExportPreparation_Generation CHECK ((GenerationJson IS NULL AND State NOT IN (''committed'',''captured'',''materialized'')) OR (GenerationJson IS NOT NULL AND ISJSON(GenerationJson)=1 AND DATALENGTH(GenerationJson)<=65536)),
 CONSTRAINT CK_ExportPreparation_Spool CHECK ((SpoolKey IS NULL AND SpoolBytes IS NULL AND SpoolHash IS NULL AND State NOT IN (''captured'',''materialized'')) OR (SpoolKey IS NOT NULL AND SpoolBytes IS NOT NULL AND SpoolHash IS NOT NULL AND SpoolBytes>0 AND LEN(SpoolKey)>0 AND DATALENGTH(SpoolKey)=DATALENGTH(LTRIM(RTRIM(SpoolKey))) AND SpoolKey NOT LIKE ''%[^a-zA-Z0-9_-]%'' COLLATE Latin1_General_100_BIN2)),
 CONSTRAINT CK_ExportPreparation_Job CHECK ((JobID IS NULL AND State<>''materialized'') OR (JobID IS NOT NULL AND State=''materialized'' AND ConsumerKind<>''config'')),
 CONSTRAINT FK_ExportPreparation_Job FOREIGN KEY (JobID) REFERENCES dbo.ExportJob(JobID)
);
CREATE INDEX IX_ExportPreparation_Queue ON dbo.ExportPreparation(AccountKey,State,EnqueueSequence,PreparationID);
CREATE UNIQUE INDEX UX_ExportPreparation_Job ON dbo.ExportPreparation(JobID) WHERE JobID IS NOT NULL;

CREATE TABLE dbo.ExportPreparationResource
(
 PreparationID uniqueidentifier NOT NULL,
 ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT PK_ExportPreparationResource PRIMARY KEY (PreparationID,ResourceKey),
 CONSTRAINT FK_ExportPreparationResource_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportPreparationResource_Resource FOREIGN KEY (ResourceKey) REFERENCES dbo.ExportResource(ResourceKey)
);
CREATE INDEX IX_ExportPreparationResource_Resource ON dbo.ExportPreparationResource(ResourceKey);

ALTER TABLE dbo.ExportResource ADD ActivePreparationID uniqueidentifier NULL;
ALTER TABLE dbo.ExportResource DROP CONSTRAINT CK_ExportResource_Ownership;
ALTER TABLE dbo.ExportResource WITH CHECK ADD CONSTRAINT CK_ExportResource_Ownership CHECK ((ActiveJobID IS NULL AND ActivePreparationID IS NULL AND OwnerID IS NULL AND Fence >= 0) OR (ActiveJobID IS NOT NULL AND ActivePreparationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NOT NULL AND OwnerID IS NOT NULL AND Fence > 0));
ALTER TABLE dbo.ExportResource WITH CHECK ADD CONSTRAINT FK_ExportResource_PreparationMembership FOREIGN KEY (ActivePreparationID,ResourceKey) REFERENCES dbo.ExportPreparationResource(PreparationID,ResourceKey);
';
 END
 IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE name='FK_ExportResource_PreparationMembership' AND parent_object_id=OBJECT_ID('dbo.ExportResource') AND is_disabled=0 AND is_not_trusted=0)
  THROW 51420,'S10C trusted preparation membership missing.',1;
 IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_ExportResource_Ownership' AND parent_object_id=OBJECT_ID('dbo.ExportResource') AND is_disabled=0 AND is_not_trusted=0 AND definition LIKE '%ActivePreparationID%')
  THROW 51420,'S10C exclusive ownership contract missing.',1;
 -- Seal the installed metadata, excluding instance-specific object IDs. Reruns
 -- compare every column, constraint and index; they never bless existing drift.
 DECLARE @Contract nvarchar(max)=(SELECT t.name AS [table],
  JSON_QUERY((SELECT c.name,ty.name AS [type],c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name,c.is_identity,c.is_computed
   FROM sys.columns c JOIN sys.types ty ON c.user_type_id=ty.user_type_id WHERE c.object_id=t.object_id ORDER BY c.column_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS columns,
  JSON_QUERY((SELECT cc.name,cc.definition,cc.is_disabled,cc.is_not_trusted,cc.is_not_for_replication FROM sys.check_constraints cc WHERE cc.parent_object_id=t.object_id ORDER BY cc.name FOR JSON PATH)) AS checks,
  JSON_QUERY((SELECT dc.name,dc.definition,c.name AS [column] FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id=dc.parent_object_id AND c.column_id=dc.parent_column_id WHERE dc.parent_object_id=t.object_id ORDER BY dc.name FOR JSON PATH)) AS defaults,
  JSON_QUERY((SELECT fk.name,OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referenced_schema,OBJECT_NAME(fk.referenced_object_id) AS referenced_table,fk.is_disabled,fk.is_not_trusted,fk.is_not_for_replication,fk.delete_referential_action,fk.update_referential_action,
    JSON_QUERY((SELECT pc.name AS parent_column,rc.name AS referenced_column FROM sys.foreign_key_columns fc JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id WHERE fc.constraint_object_id=fk.object_id ORDER BY fc.constraint_column_id FOR JSON PATH)) AS columns
   FROM sys.foreign_keys fk WHERE fk.parent_object_id=t.object_id ORDER BY fk.name FOR JSON PATH)) AS foreign_keys,
  JSON_QUERY((SELECT i.name,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.filter_definition,
    JSON_QUERY((SELECT c.name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH)) AS columns
   FROM sys.indexes i WHERE i.object_id=t.object_id AND i.index_id>0 ORDER BY i.name FOR JSON PATH,INCLUDE_NULL_VALUES)) AS indexes
  FROM sys.tables t WHERE t.schema_id=SCHEMA_ID(N'dbo') AND t.name IN ('ExportPreparation','ExportPreparationResource','ExportResource') ORDER BY t.name FOR JSON PATH);
 DECLARE @ContractHash varchar(64)=CONVERT(varchar(64),HASHBYTES('SHA2_256',@Contract),2);
 IF @Existing=0
  EXEC sys.sp_addextendedproperty @name=N'S10CPreparationContractSHA256',@value=@ContractHash,@level0type=N'SCHEMA',@level0name=N'dbo',@level1type=N'TABLE',@level1name=N'ExportPreparation';
 ELSE IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=1 AND major_id=OBJECT_ID(N'dbo.ExportPreparation') AND minor_id=0 AND name=N'S10CPreparationContractSHA256' AND CONVERT(varchar(64),value)=@ContractHash)
  THROW 51420,'S10C schema signature missing or drifted; preserve and forward-fix.',1;
 IF @OwnTransaction=1 COMMIT;
END TRY
BEGIN CATCH
 IF @OwnTransaction=1 AND XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
