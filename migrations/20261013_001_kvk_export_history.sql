/*
MigrationId: 20261013_001_kvk_export_history
Purpose: Durable scoped report import-history snapshots
Author: cwatts
CreatedUtc: 2026-10-13
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Accepted SourceExportIntent scoped key; absent or exact new tables; approved target and backup
PostValidationQuery: Exact new metadata and unchanged existing intent/receipt data
RelatedBotPR:
RelatedSQLPR:
*/
-- Local source only. No installation, grants, cleanup, activation or predecessor execution.
-- Deploy SQL before enabling the Stage 2 reader API. Preserve history on rollback.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
DECLARE @HistoryOwnTransaction bit=CASE WHEN @@TRANCOUNT=0 THEN 1 ELSE 0 END;
IF @HistoryOwnTransaction=1 BEGIN TRANSACTION;
BEGIN TRY
DECLARE @HistoryLock int;
EXEC @HistoryLock=sys.sp_getapplock @Resource=N'K98:ExportHistory:schema', @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=0;
IF @HistoryLock<0 THROW 51620, 'Export history schema lock unavailable.', 1;
IF OBJECT_ID(N'KVK.SourceExportIntent',N'U') IS NULL
    THROW 51620, 'SourceExportIntent prerequisite missing.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes i WHERE i.object_id=OBJECT_ID(N'KVK.SourceExportIntent')
    AND i.is_unique=1 AND i.is_disabled=0 AND i.has_filter=0
    AND (SELECT STRING_AGG(CONVERT(nvarchar(max),c.name),N',') WITHIN GROUP (ORDER BY ic.key_ordinal)
         FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
         WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=N'SourceKey,KVK_NO,IntentID')
    THROW 51620, 'SourceExportIntent scoped key missing.', 1;
IF EXISTS (SELECT 1 FROM sys.objects WHERE schema_id=SCHEMA_ID(N'KVK') AND name IN (N'SourceExportHistory',N'SourceExportHistoryRow') AND type<>'U')
    THROW 51620, 'Export history object type conflict.', 1;
DECLARE @HistoryExisting int=(SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'KVK') AND name IN (N'SourceExportHistory',N'SourceExportHistoryRow'));
IF @HistoryExisting NOT IN (0,2) THROW 51620, 'Partial export history schema; preserve and forward-fix.', 1;
CREATE TABLE #History_SourceExportHistory
(
    IntentID uniqueidentifier NOT NULL,
    GuildID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    HistoryVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    VectorHash binary(32) NOT NULL,
    CapturedUTC datetime2(0) NOT NULL,
    AttemptCount bigint NOT NULL,
    ContentHash binary(32) NOT NULL,
    PRIMARY KEY (IntentID,GuildID,HistoryVersion),
    CHECK (SourceKey='snapshot_report_v1' AND DATALENGTH(SourceKey)=18 AND KVK_NO>0),
    CHECK (DATALENGTH(GuildID) BETWEEN 1 AND 32 AND GuildID NOT LIKE '%[^0-9]%'),
    CHECK (HistoryVersion='source_export_history_v1' AND DATALENGTH(HistoryVersion)=24),
    CHECK (AttemptCount>=0)
);
CREATE TABLE #History_SourceExportHistoryRow
(
    IntentID uniqueidentifier NOT NULL,
    GuildID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    HistoryVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Ordinal bigint NOT NULL,
    AttemptID uniqueidentifier NOT NULL,
    PayloadJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RowHash binary(32) NOT NULL,
    PRIMARY KEY (IntentID,GuildID,HistoryVersion,Ordinal),
    UNIQUE (IntentID,GuildID,HistoryVersion,AttemptID),
    CHECK (Ordinal>0),
    CHECK (ISJSON(PayloadJson)=1 AND DATALENGTH(PayloadJson)<=16384)
);

IF @HistoryExisting=0
BEGIN
-- HISTORY_INSTALL_PAYLOAD_BEGIN
EXEC sys.sp_executesql N'CREATE TABLE KVK.SourceExportHistory
(
    IntentID uniqueidentifier NOT NULL,
    GuildID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    HistoryVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    VectorHash binary(32) NOT NULL,
    CapturedUTC datetime2(0) NOT NULL,
    AttemptCount bigint NOT NULL,
    ContentHash binary(32) NOT NULL,
    CONSTRAINT PK_SourceExportHistory PRIMARY KEY (IntentID,GuildID,HistoryVersion),
    CONSTRAINT FK_SourceExportHistory_Intent FOREIGN KEY (SourceKey,KVK_NO,IntentID) REFERENCES KVK.SourceExportIntent (SourceKey,KVK_NO,IntentID),
    CONSTRAINT CK_SourceExportHistory_Scope CHECK (SourceKey=''snapshot_report_v1'' AND DATALENGTH(SourceKey)=18 AND KVK_NO>0),
    CONSTRAINT CK_SourceExportHistory_Guild CHECK (DATALENGTH(GuildID) BETWEEN 1 AND 32 AND GuildID NOT LIKE ''%[^0-9]%''),
    CONSTRAINT CK_SourceExportHistory_Version CHECK (HistoryVersion=''source_export_history_v1'' AND DATALENGTH(HistoryVersion)=24),
    CONSTRAINT CK_SourceExportHistory_Count CHECK (AttemptCount>=0)
);
CREATE TABLE KVK.SourceExportHistoryRow
(
    IntentID uniqueidentifier NOT NULL,
    GuildID varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    HistoryVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Ordinal bigint NOT NULL,
    AttemptID uniqueidentifier NOT NULL,
    PayloadJson nvarchar(max) COLLATE Latin1_General_100_BIN2 NOT NULL,
    RowHash binary(32) NOT NULL,
    CONSTRAINT PK_SourceExportHistoryRow PRIMARY KEY (IntentID,GuildID,HistoryVersion,Ordinal),
    CONSTRAINT UQ_SourceExportHistoryRow_Attempt UNIQUE (IntentID,GuildID,HistoryVersion,AttemptID),
    CONSTRAINT FK_SourceExportHistoryRow_History FOREIGN KEY (IntentID,GuildID,HistoryVersion) REFERENCES KVK.SourceExportHistory (IntentID,GuildID,HistoryVersion),
    CONSTRAINT CK_SourceExportHistoryRow_Ordinal CHECK (Ordinal>0),
    CONSTRAINT CK_SourceExportHistoryRow_Payload CHECK (ISJSON(PayloadJson)=1 AND DATALENGTH(PayloadJson)<=16384)
);
';
-- HISTORY_INSTALL_PAYLOAD_END
END;
DECLARE @HistoryMap TABLE (Name nvarchar(128),ActualID int,ExpectedID int);
INSERT @HistoryMap VALUES
(N'KVK.SourceExportHistory',OBJECT_ID(N'KVK.SourceExportHistory',N'U'),OBJECT_ID(N'tempdb..#History_SourceExportHistory')),
(N'KVK.SourceExportHistoryRow',OBJECT_ID(N'KVK.SourceExportHistoryRow',N'U'),OBJECT_ID(N'tempdb..#History_SourceExportHistoryRow'));
DECLARE @HistoryFK TABLE (ParentName nvarchar(128),ConstraintName nvarchar(128),Ordinal int,ParentColumn nvarchar(128),TargetName nvarchar(128),TargetColumn nvarchar(128));
INSERT @HistoryFK VALUES
(N'KVK.SourceExportHistory',N'FK_SourceExportHistory_Intent',1,N'SourceKey',N'KVK.SourceExportIntent',N'SourceKey'),
(N'KVK.SourceExportHistory',N'FK_SourceExportHistory_Intent',2,N'KVK_NO',N'KVK.SourceExportIntent',N'KVK_NO'),
(N'KVK.SourceExportHistory',N'FK_SourceExportHistory_Intent',3,N'IntentID',N'KVK.SourceExportIntent',N'IntentID'),
(N'KVK.SourceExportHistoryRow',N'FK_SourceExportHistoryRow_History',1,N'IntentID',N'KVK.SourceExportHistory',N'IntentID'),
(N'KVK.SourceExportHistoryRow',N'FK_SourceExportHistoryRow_History',2,N'GuildID',N'KVK.SourceExportHistory',N'GuildID'),
(N'KVK.SourceExportHistoryRow',N'FK_SourceExportHistoryRow_History',3,N'HistoryVersion',N'KVK.SourceExportHistory',N'HistoryVersion');
IF EXISTS (SELECT 1 FROM @HistoryMap WHERE ActualID IS NULL)
    THROW 51620, 'History prerequisite/object type conflict; no predecessor execution authorized.', 1;
-- EXCEPT in both directions rejects missing, extra, disabled, untrusted or altered shape.
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @HistoryMap m JOIN sys.columns c ON c.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @HistoryMap m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @HistoryMap m JOIN tempdb.sys.columns c ON c.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.column_id, c.name COLLATE Latin1_General_100_BIN2, c.system_type_id, c.max_length, c.[precision], c.scale, c.collation_name COLLATE Latin1_General_100_BIN2, c.is_nullable, c.is_identity, c.is_computed, c.is_rowguidcol, c.is_sparse, c.generated_always_type FROM @HistoryMap m JOIN sys.columns c ON c.object_id=m.ActualID)
    THROW 51620, 'History column shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @HistoryMap m JOIN sys.columns c ON c.object_id=m.ActualID WHERE c.user_type_id<>c.system_type_id) THROW 51620, 'History alias type conflict.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @HistoryMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @HistoryMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @HistoryMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, c.definition COLLATE Latin1_General_100_BIN2, c.is_disabled, c.is_not_trusted, c.is_not_for_replication FROM @HistoryMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID)
    THROW 51620, 'History check constraint shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @HistoryMap m JOIN sys.indexes i ON i.object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @HistoryMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM tempdb.sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @HistoryMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, i.type, i.is_unique, i.is_primary_key, i.is_unique_constraint, i.is_disabled, i.ignore_dup_key, i.filter_definition COLLATE Latin1_General_100_BIN2, (SELECT ic.index_column_id, ic.column_id, ic.key_ordinal, ic.is_descending_key, ic.is_included_column FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH) COLLATE Latin1_General_100_BIN2 FROM @HistoryMap m JOIN sys.indexes i ON i.object_id=m.ActualID)
    THROW 51620, 'History index shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @HistoryMap m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @HistoryMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @HistoryMap m JOIN tempdb.sys.indexes i ON i.object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @HistoryMap m JOIN sys.indexes i ON i.object_id=m.ActualID GROUP BY m.Name)
    THROW 51620, 'History index count shape conflict; preserve history and forward-fix.', 1;
IF EXISTS (SELECT 1 FROM @HistoryMap m JOIN sys.triggers t ON t.parent_id=m.ActualID)
OR EXISTS (SELECT 1 FROM @HistoryMap m JOIN sys.tables t ON t.object_id=m.ActualID WHERE t.temporal_type<>0 OR t.is_memory_optimized<>0)
    THROW 51620, 'History unexpected default, trigger or table mode.', 1;
-- No defaults are part of this snapshot contract.
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @HistoryMap m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @HistoryMap m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @HistoryMap m JOIN tempdb.sys.default_constraints d ON d.parent_object_id=m.ExpectedID
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, d.parent_column_id, d.definition COLLATE Latin1_General_100_BIN2 FROM @HistoryMap m JOIN sys.default_constraints d ON d.parent_object_id=m.ActualID)
    THROW 51620, 'History default shape conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @HistoryMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @HistoryMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name)
OR EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @HistoryMap m JOIN tempdb.sys.check_constraints c ON c.parent_object_id=m.ExpectedID GROUP BY m.Name
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, COUNT(*) FROM @HistoryMap m JOIN sys.check_constraints c ON c.parent_object_id=m.ActualID GROUP BY m.Name)
    THROW 51620, 'History check count conflict; preserve and forward-fix.', 1;
IF EXISTS (SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @HistoryMap m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
EXCEPT
SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @HistoryFK e WHERE EXISTS (SELECT 1 FROM @HistoryMap m WHERE m.Name=e.ParentName))
OR EXISTS (SELECT e.ParentName COLLATE Latin1_General_100_BIN2, ConstraintName COLLATE Latin1_General_100_BIN2, Ordinal, ParentColumn COLLATE Latin1_General_100_BIN2, TargetName COLLATE Latin1_General_100_BIN2, TargetColumn COLLATE Latin1_General_100_BIN2, 0,0,0,0,0 FROM @HistoryFK e WHERE EXISTS (SELECT 1 FROM @HistoryMap m WHERE m.Name=e.ParentName)
EXCEPT
SELECT m.Name COLLATE Latin1_General_100_BIN2, f.name COLLATE Latin1_General_100_BIN2, fc.constraint_column_id,
pc.name COLLATE Latin1_General_100_BIN2, (OBJECT_SCHEMA_NAME(f.referenced_object_id)+N'.'+OBJECT_NAME(f.referenced_object_id)) COLLATE Latin1_General_100_BIN2,
rc.name COLLATE Latin1_General_100_BIN2, f.is_disabled, f.is_not_trusted, f.is_not_for_replication, f.delete_referential_action, f.update_referential_action
FROM @HistoryMap m JOIN sys.foreign_keys f ON f.parent_object_id=m.ActualID
JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id)
    THROW 51620, 'History foreign key shape conflict; preserve history and forward-fix.', 1;
DROP TABLE #History_SourceExportHistoryRow;
DROP TABLE #History_SourceExportHistory;
IF @HistoryOwnTransaction=1 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @HistoryOwnTransaction=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
