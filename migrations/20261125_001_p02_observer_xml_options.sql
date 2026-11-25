/*
MigrationId: 20261125_001_p02_observer_xml_options
Purpose: Correct observer XML session options; preserve original installation and retained work
Author: Codex
CreatedUtc: 2026-11-25
RequiresBackup: Yes
RiskLevel: High
Rollback: Manual
RollbackScript: N/A - reviewed forward correction after business activity
TransactionMode: Required
DataChange: No
DataSafetyPlan: Included
DataSafetyNotes: Physical drain required. One trigger amendment only. No business DML, sequence replacement, history edit or producer replay.
EstimatedRowsAffected: 0 business rows
PreValidationQuery: 20261125_001_p02_observer_xml_options.before.sql
PostValidationQuery: 20261125_001_p02_observer_xml_options.after.sql
RelatedBotPR: Pending focused correction review
RelatedSQLPR: Pending focused correction review
*/
SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
IF DB_NAME()<>N'ROK_TRACKER' OR @@TRANCOUNT<>1 OR XACT_STATE()<>1
 THROW 51974,'Exact target and one release-owned transaction required.',1;
IF COALESCE(APPLOCK_MODE(N'public',N'K98_Module_Release_v1',N'Session'),N'NoLock')<>N'Exclusive'
 THROW 51974,'Existing release coordinator must own the correction.',1;
DECLARE @options_lock int;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK @LockTimeout=0,@LockResult=@options_lock OUTPUT;
IF @options_lock IS NULL OR @options_lock NOT IN (0,1)
 THROW 51974,'Import writer is active; preserve and stop.',1;
EXEC @options_lock=sys.sp_getapplock @Resource=N'K98:maintenance-schema:v1',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @options_lock IS NULL OR @options_lock NOT IN (0,1)
 THROW 51974,'Maintenance or observer is active; preserve and stop.',1;
EXEC @options_lock=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @options_lock IS NULL OR @options_lock NOT IN (0,1)
 THROW 51974,'Legacy output owner is active; preserve and stop.',1;
EXEC @options_lock=sys.sp_getapplock @Resource=N'K98:catalogue-mutation:v1',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @options_lock IS NULL OR @options_lock NOT IN (0,1)
 THROW 51974,'Catalogue mutation owner is active; preserve and stop.',1;
-- Logical retained work is preserved. These locks supplement the outer physical drain;
-- they do not clear retained owners, prove business absence or authorize a retry.
EXEC sys.sp_executesql N'ALTER TRIGGER tr_P02CatalogueObservation ON DATABASE
FOR DDL_DATABASE_LEVEL_EVENTS
AS
BEGIN
    SET NOCOUNT ON;
    -- EVENTDATA XML methods require these options independently of the DDL caller.
    -- Trigger scope restores the caller''s options on return, including warnings OFF.
    SET ANSI_NULLS ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;
    DECLARE @event xml=EVENTDATA();
    -- Never permit reset/replacement of an admitted counter. A drained migration
    -- must explicitly remove this protection and create a new contract identity.
    IF @event.value(''(/EVENT_INSTANCE/SchemaName)[1]'',''sysname'')=''dbo''
       AND @event.value(''(/EVENT_INSTANCE/ObjectName)[1]'',''sysname'')=''P02ObservationGeneration''
        THROW 51970,''Observation sequence changes require a drained contract migration.'',1;
    -- Autocommit DDL trigger context can have a nesting count without a user
    -- transaction usable by APPLOCK_MODE (native SQL3918). Explicitly nest;
    -- the enclosing statement/transaction must retain the marker to completion.
    -- Qualification includes a later-trigger barrier to prove that lifetime.
    BEGIN TRANSACTION;
    EXEC dbo.usp_P02BeginCatalogueMutation @Owner=''Transaction'';
    COMMIT TRANSACTION;
END;
';
