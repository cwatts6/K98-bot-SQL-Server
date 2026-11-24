SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_P02ReadObservationBoundary
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @transactionMode nvarchar(32)=N'NoLock',@isolation smallint,
        @g1 bigint,@g2 bigint,@object1 int,@object2 int,@created1 datetime,@created2 datetime,
        @modified1 datetime,@modified2 datetime,@grantable smallint,@health nvarchar(max);
    -- APPLOCK_MODE(Transaction) raises 3918 in an actual zero-transaction session.
    IF @@TRANCOUNT>0
        SET @transactionMode=APPLOCK_MODE('public','K98:catalogue-mutation:v1','Transaction');
    SELECT @isolation=transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID;
    IF @@TRANCOUNT>1 OR XACT_STATE() NOT IN (0,1) OR @isolation<>2
       OR COALESCE(@transactionMode,N'Unknown')<>N'NoLock'
       OR COALESCE(APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session'),N'Unknown')<>N'NoLock'
        THROW 51971,'Observation requires an unmarked READ COMMITTED cursor.',1;
    -- Check presence before touching module catalogues: an already active DDL
    -- writer must not make its observer wait on the writer's metadata locks.
    SELECT @g1=CONVERT(bigint,current_value),@object1=object_id,
        @created1=create_date,@modified1=modify_date
      FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration','SO')
        AND system_type_id=127 AND CONVERT(bigint,start_value)=1
        AND CONVERT(bigint,minimum_value)=1 AND CONVERT(bigint,increment)=1
        AND CONVERT(bigint,maximum_value)=9223372036854775807
        AND is_cycling=0 AND is_cached=0 AND is_exhausted=0;
    SET @grantable=APPLOCK_TEST('public','K98:catalogue-mutation:v1','Exclusive','Session');
    IF @grantable=1
    BEGIN
    -- The legacy role has schema ALTER. These explicit denials are part of the
    -- invalidation contract: without them TRUNCATE or bulk trigger suppression
    -- can change lifecycle state without advancing the sequence. Recheck on
    -- every quiet boundary; a database-only generation never caches effective
    -- server permissions, which the actual admission cursor checks separately.
    IF (SELECT COUNT_BIG(*) FROM sys.database_permissions
        WHERE grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader')
          AND class=1 AND minor_id=0 AND state='D' AND permission_name=N'ALTER'
          AND major_id IN (OBJECT_ID(N'dbo.KVKFinalReportHeader','U'),
                           OBJECT_ID(N'dbo.MaintenanceKvkWork','U'),
                           OBJECT_ID(N'dbo.MaintenanceWork','U')))<>3
        THROW 51972,'Lifecycle invalidation permissions differ from the reviewed contract.',1;
    SELECT @health=(
        SELECT o.name,m.definition,m.uses_ansi_nulls,m.uses_quoted_identifier,
            m.execute_as_principal_id,t.is_disabled,t.is_not_for_replication
        FROM sys.sql_modules m
        JOIN (SELECT object_id,name FROM sys.objects UNION ALL
              SELECT object_id,name FROM sys.triggers WHERE parent_class=0) o ON o.object_id=m.object_id
        LEFT JOIN sys.triggers t ON t.object_id=m.object_id
        WHERE o.name IN ('usp_P02BeginCatalogueMutation','usp_P02EndCatalogueMutation',
            'usp_P02ReadObservationBoundary','tr_P02HeaderObservation',
            'tr_P02KvkWorkObservation','tr_P02MaintenanceObservation','tr_P02CatalogueObservation')
        ORDER BY o.name COLLATE Latin1_General_100_BIN2
        FOR JSON PATH,INCLUDE_NULL_VALUES);
    END;
    SELECT @g2=CONVERT(bigint,current_value),@object2=object_id,
        @created2=create_date,@modified2=modify_date
      FROM sys.sequences WHERE object_id=OBJECT_ID(N'dbo.P02ObservationGeneration','SO');
    SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS ServerName,
        DB_NAME() AS DatabaseName,DB_ID() AS DatabaseID,USER_NAME() AS PrincipalName,
        ORIGINAL_LOGIN() AS OriginalLogin,@@SPID AS SessionID,@@TRANCOUNT AS TransactionCount,
        XACT_STATE() AS TransactionState,@isolation AS IsolationLevel,
        @g1 AS GenerationBefore,@grantable AS WriterAbsent,@g2 AS GenerationAfter,
        @object1 AS SequenceObjectBefore,@created1 AS SequenceCreatedBefore,@modified1 AS SequenceModifiedBefore,
        @object2 AS SequenceObjectAfter,@created2 AS SequenceCreatedAfter,@modified2 AS SequenceModifiedAfter,
        @health AS ContractHealth;
END;
GO
