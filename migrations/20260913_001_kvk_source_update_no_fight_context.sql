/*
MigrationId: 20260913_001_kvk_source_update_no_fight_context
Purpose: Separate immutable period classification from confirmed no-fight update mode
Author: cwatts
CreatedUtc: 2026-09-13
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: None
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: Exactly #S8BNoFightApproval.ExpectedUpdateRows on first apply; zero on verified rerun
PreValidationQuery: Scoped update inventory and constraint catalog below
PostValidationQuery: Trusted scoped kind FK, update mode check and unchanged update count
RelatedBotPR: N/A
RelatedSQLPR: N/A
Dependencies: 20260912_001_kvk_season_complete_updates
*/
-- AUTHORED ONLY. File approval does not authorize a SQL connection or execution.
-- Use a dedicated, separately approved session with ALL source writers idle.
-- Supply exactly one row in #S8BNoFightApproval before this batch:
-- (ServerName nvarchar(128), DatabaseName sysname, BackupEvidence nvarchar(1024),
--  PreviewEvidence nvarchar(1024), ExpectedUpdateRows bigint, Mode varchar(8)).
-- Mode='preview' returns metadata and rolls back WITHOUT DDL or row changes.
-- Mode='apply' requires the reviewed target, backup/restore receipt and row preview.
-- Receipts are not automatic proof of approval. No default target or historical guesses.
-- First apply copies the existing immutable SourcePeriod.PeriodKind only. No update ID,
-- input, hash, confirmation, state, period, selection, intent or publication is rewritten.
-- SQL enforces kind scope and equal player inputs; S8B DAL additionally checks the exact
-- configured equal endpoints, actor confirmation, revision identity, eligibility and CAS.
-- Apply before the revised S8B writer. Older SourceUpdate inserts omit PeriodKind and
-- will fail closed after apply; keep writers idle across coordinated SQL/Bot rollout.
-- Do not run the S8A installer again to validate this amended object shape.
-- Forward fix only once no-fight updates in fight periods exist: do not retag/drop history.
-- Installer lock + table locks bound catalog/data races while the operator holds writers idle.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET XACT_ABORT ON;
SET NOCOUNT ON;
IF @@TRANCOUNT<>0 THROW 51900, 'S8B requires a dedicated session.', 1;
IF OBJECT_ID(N'tempdb..#S8BNoFightApproval',N'U') IS NULL
    THROW 51900, 'S8B requires explicit target, backup and preview approval inputs.', 1;
IF (SELECT COUNT_BIG(*) FROM #S8BNoFightApproval)<>1
    THROW 51900, 'S8B requires exactly one approval row.', 1;
IF EXISTS (SELECT 1 FROM #S8BNoFightApproval WHERE ServerName IS NULL OR DatabaseName IS NULL
 OR ServerName COLLATE Latin1_General_100_BIN2<>CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) COLLATE Latin1_General_100_BIN2
 OR DatabaseName COLLATE Latin1_General_100_BIN2<>DB_NAME() COLLATE Latin1_General_100_BIN2
 OR DB_ID()<=4 OR BackupEvidence IS NULL OR LEN(BackupEvidence)=0
 OR PreviewEvidence IS NULL OR LEN(PreviewEvidence)=0
 OR ExpectedUpdateRows IS NULL OR ExpectedUpdateRows<0 OR Mode IS NULL
 OR Mode COLLATE Latin1_General_100_BIN2 NOT IN ('preview','apply') OR DATALENGTH(Mode)<>LEN(Mode))
    THROW 51900, 'S8B target or evidence inputs are invalid.', 1;
IF OBJECT_ID(N'KVK.SourceUpdate',N'U') IS NULL OR OBJECT_ID(N'KVK.SourcePeriod',N'U') IS NULL
    THROW 51900, 'S8B requires the accepted S8A tables.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'KVK.SourceUpdate') AND (is_disabled=1 OR is_not_trusted=1))
 OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'KVK.SourceUpdate') AND (is_disabled=1 OR is_not_trusted=1))
    THROW 51900, 'S8B requires trusted enabled update constraints.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @LockResult int, @Rows bigint, @Periods bigint;
    EXEC @LockResult=sys.sp_getapplock @Resource=N'KVK.S8B.NoFightSchema', @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
    IF @LockResult<0 THROW 51900, 'S8B installer lock unavailable.', 1;
    SELECT @Periods=COUNT_BIG(*) FROM KVK.SourcePeriod WITH (TABLOCKX,HOLDLOCK);
    SELECT @Rows=COUNT_BIG(*) FROM KVK.SourceUpdate WITH (TABLOCKX,HOLDLOCK);
    IF @Rows<>(SELECT ExpectedUpdateRows FROM #S8BNoFightApproval)
        THROW 51900, 'S8B update inventory differs from approved preview.', 1;
    SELECT u.KVK_NO,u.PeriodID,u.PeriodKey,p.PeriodKind,u.UpdateKind,u.UpdateState,COUNT_BIG(*) AS UpdateRows
      FROM KVK.SourceUpdate u JOIN KVK.SourcePeriod p ON p.SourceKey=u.SourceKey AND p.KVK_NO=u.KVK_NO AND p.PeriodID=u.PeriodID AND p.PeriodKey=u.PeriodKey
      GROUP BY u.KVK_NO,u.PeriodID,u.PeriodKey,p.PeriodKind,u.UpdateKind,u.UpdateState;
    SELECT name,is_disabled,is_not_trusted FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'KVK.SourceUpdate');
    SELECT name,is_disabled,is_not_trusted FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'KVK.SourceUpdate');
    SELECT @Rows AS ExpectedUpdateRows,@Periods AS UnchangedPeriodRows,
      N'Add required PeriodKind copied from SourcePeriod; rebind FK_SourceUpdate_Kind; add CK_SourceUpdate_PeriodMode' AS PlannedChanges;
    IF (SELECT Mode FROM #S8BNoFightApproval)='preview'
    BEGIN
        ROLLBACK TRANSACTION;
        RETURN;
    END;
    IF COL_LENGTH(N'KVK.SourceUpdate',N'PeriodKind') IS NULL
    BEGIN
        IF OBJECT_ID(N'KVK.CK_SourceUpdate_PeriodMode',N'C') IS NOT NULL
            THROW 51900, 'S8B partial amendment; no automatic repair.', 1;
        -- Refuse unexpected baseline kind FK rather than dropping an unrelated constraint.
        IF (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE constraint_object_id=OBJECT_ID(N'KVK.FK_SourceUpdate_Kind'))<>4
          OR NOT EXISTS (SELECT 1 FROM sys.foreign_key_columns WHERE constraint_object_id=OBJECT_ID(N'KVK.FK_SourceUpdate_Kind')
            AND parent_column_id=COLUMNPROPERTY(OBJECT_ID(N'KVK.SourceUpdate'),N'UpdateKind','ColumnId')
            AND referenced_object_id=OBJECT_ID(N'KVK.SourcePeriod')
            AND referenced_column_id=COLUMNPROPERTY(OBJECT_ID(N'KVK.SourcePeriod'),N'PeriodKind','ColumnId'))
            THROW 51900, 'S8B baseline kind FK differs.', 1;
        ALTER TABLE KVK.SourceUpdate ADD PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NULL;
        -- A separate compilation sees the new column. Values and identifiers are constants.
        EXEC sys.sp_executesql N'
          UPDATE u SET PeriodKind=p.PeriodKind FROM KVK.SourceUpdate u
          JOIN KVK.SourcePeriod p ON p.SourceKey=u.SourceKey AND p.KVK_NO=u.KVK_NO AND p.PeriodID=u.PeriodID AND p.PeriodKey=u.PeriodKey
          WHERE u.PeriodKind IS NULL;
          IF @@ROWCOUNT<>(SELECT ExpectedUpdateRows FROM #S8BNoFightApproval)
            THROW 51900, ''S8B classification backfill count differs.'', 1;
          ALTER TABLE KVK.SourceUpdate ALTER COLUMN PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL;
          ALTER TABLE KVK.SourceUpdate DROP CONSTRAINT FK_SourceUpdate_Kind;
          ALTER TABLE KVK.SourceUpdate WITH CHECK ADD CONSTRAINT FK_SourceUpdate_Kind
            FOREIGN KEY (SourceKey,KVK_NO,PeriodKey,PeriodKind) REFERENCES KVK.SourcePeriod(SourceKey,KVK_NO,PeriodKey,PeriodKind);
          ALTER TABLE KVK.SourceUpdate WITH CHECK ADD CONSTRAINT CK_SourceUpdate_PeriodMode
            CHECK (DATALENGTH(PeriodKind)=LEN(PeriodKind) AND PeriodKind IN (''fight'',''overall'',''no_fight'')
              AND (UpdateKind=PeriodKind OR (PeriodKind=''fight'' AND UpdateKind=''no_fight'')));
        ';
    END;
    IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'KVK.SourceUpdate') AND name=N'PeriodKind'
      AND TYPE_NAME(user_type_id)=N'varchar' AND max_length=32 AND is_nullable=0 AND is_computed=0 AND collation_name=N'Latin1_General_100_BIN2')
      OR OBJECT_ID(N'KVK.CK_SourceUpdate_PeriodMode',N'C') IS NULL
      OR NOT EXISTS (SELECT 1 FROM sys.foreign_key_columns WHERE constraint_object_id=OBJECT_ID(N'KVK.FK_SourceUpdate_Kind')
        AND parent_column_id=COLUMNPROPERTY(OBJECT_ID(N'KVK.SourceUpdate'),N'PeriodKind','ColumnId')
        AND referenced_object_id=OBJECT_ID(N'KVK.SourcePeriod')
        AND referenced_column_id=COLUMNPROPERTY(OBJECT_ID(N'KVK.SourcePeriod'),N'PeriodKind','ColumnId'))
        THROW 51900, 'S8B amended kind catalog differs; no automatic repair.', 1;
    IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'KVK.SourceUpdate') AND (is_disabled=1 OR is_not_trusted=1))
      OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'KVK.SourceUpdate') AND (is_disabled=1 OR is_not_trusted=1))
      OR @Rows<>(SELECT COUNT_BIG(*) FROM KVK.SourceUpdate)
        THROW 51900, 'S8B post-validation failed.', 1;
    DECLARE @ExpectedKindFK TABLE (Ordinal int, ParentColumn sysname, ReferencedColumn sysname);
    INSERT @ExpectedKindFK VALUES (1,N'SourceKey',N'SourceKey'),(2,N'KVK_NO',N'KVK_NO'),
      (3,N'PeriodKey',N'PeriodKey'),(4,N'PeriodKind',N'PeriodKind');
    IF EXISTS (SELECT Ordinal,ParentColumn,ReferencedColumn FROM @ExpectedKindFK EXCEPT
      SELECT f.constraint_column_id,COL_NAME(f.parent_object_id,f.parent_column_id),COL_NAME(f.referenced_object_id,f.referenced_column_id)
      FROM sys.foreign_key_columns f WHERE f.constraint_object_id=OBJECT_ID(N'KVK.FK_SourceUpdate_Kind')
      AND f.parent_object_id=OBJECT_ID(N'KVK.SourceUpdate') AND f.referenced_object_id=OBJECT_ID(N'KVK.SourcePeriod'))
      OR (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE constraint_object_id=OBJECT_ID(N'KVK.FK_SourceUpdate_Kind'))<>4
      OR EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id=OBJECT_ID(N'KVK.FK_SourceUpdate_Kind')
        AND (delete_referential_action<>0 OR update_referential_action<>0 OR is_not_for_replication<>0))
        THROW 51900, 'S8B scoped kind FK differs.', 1;
    -- Let SQL Server canonicalize the expected expression, as in the S8A verifier.
    IF OBJECT_ID(N'tempdb..#S8BModeShape') IS NOT NULL
        THROW 51900, 'S8B shape verifier requires a fresh session.', 1;
    CREATE TABLE #S8BModeShape (PeriodKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
      UpdateKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
      CHECK (DATALENGTH(PeriodKind)=LEN(PeriodKind) AND PeriodKind IN ('fight','overall','no_fight')
        AND (UpdateKind=PeriodKind OR (PeriodKind='fight' AND UpdateKind='no_fight'))));
    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints actual
      JOIN tempdb.sys.check_constraints expected ON expected.parent_object_id=OBJECT_ID(N'tempdb..#S8BModeShape')
        AND actual.definition COLLATE Latin1_General_100_BIN2=expected.definition COLLATE Latin1_General_100_BIN2
      WHERE actual.object_id=OBJECT_ID(N'KVK.CK_SourceUpdate_PeriodMode')
        AND actual.parent_object_id=OBJECT_ID(N'KVK.SourceUpdate') AND actual.is_not_for_replication=0)
        THROW 51900, 'S8B mode check definition differs.', 1;
    EXEC sys.sp_executesql N'
      IF EXISTS (SELECT 1 FROM KVK.SourceUpdate u JOIN KVK.SourcePeriod p ON p.SourceKey=u.SourceKey AND p.KVK_NO=u.KVK_NO AND p.PeriodID=u.PeriodID
        WHERE u.PeriodKind<>p.PeriodKind OR NOT (u.UpdateKind=u.PeriodKind OR (u.PeriodKind=''fight'' AND u.UpdateKind=''no_fight'')))
        THROW 51900, ''S8B retained period mode differs.'', 1;
    ';
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
