SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceKvkOutput
    @Generation bigint,@ClaimID uniqueidentifier,@AllDone bit OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    -- Direct calls must obey the same session boundary as the worker.
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51962,'Maintenance child requires its own autocommit session.',1;
    IF COALESCE(APPLOCK_MODE('public','K98:post-import-stats:v1','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','k98-legacy-output-snapshot','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','K98:TargetPublication:DeltaPreprocessing','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','K98:StatsForUpload:Publish','Session'),'NoLock')<>'Exclusive'
       OR COALESCE(APPLOCK_MODE('public','K98:maintenance-schema:v1','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Exact KVK maintenance physical ownership required.',1;
    IF @ClaimID IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork
        WHERE Kind='kvk_output' AND ClaimID=@ClaimID AND ClaimedGeneration=@Generation AND State='running')
        THROW 51964,'Exact aggregate KVK maintenance claim required.',1;
    DECLARE @kvk int,@due bigint,@object int,@created datetime,@revision int,
        @table sysname,@full nvarchar(260),@idx sysname,@sql nvarchar(max);
    SET @AllDone=0;
    -- A fixed one-target budget bounds each invocation, including old seasons.
    SELECT TOP(1) @kvk=KVKNo,@due=DueGeneration,@object=DueObjectID,
        @created=DueObjectCreateDate,@revision=DueHeaderRevision
      FROM dbo.MaintenanceKvkWork
      WHERE DueGeneration<=@Generation AND CompletedGeneration<DueGeneration AND State='pending'
      ORDER BY DueGeneration,KVKNo;
    IF @kvk IS NOT NULL
    BEGIN
        UPDATE dbo.MaintenanceKvkWork SET State='running',ClaimID=@ClaimID,
            ClaimedGeneration=@due,ClaimedObjectID=@object,
            ClaimedObjectCreateDate=@created,ClaimedHeaderRevision=@revision
          WHERE KVKNo=@kvk AND DueGeneration=@due AND State='pending';
        IF @@ROWCOUNT<>1 THROW 51964,'KVK maintenance scope changed.',1;
        BEGIN TRY
            SET @table=N'EXCEL_FOR_KVK_'+CONVERT(nvarchar(11),@kvk);
            SET @full=QUOTENAME(N'dbo')+N'.'+QUOTENAME(@table);
            IF NOT EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@object
                AND schema_id=SCHEMA_ID('dbo') AND name=@table AND create_date=@created)
               OR NOT EXISTS(SELECT 1 FROM dbo.KVKFinalReportHeader
                WHERE KVK_NO=@kvk AND Revision=@revision AND State=N'OUTPUT_COMPLETE')
                THROW 51968,'KVK maintenance output identity no longer matches its receipt.',1;
            IF COL_LENGTH(@full,'Gov_ID') IS NULL OR COL_LENGTH(@full,'KVK_NO') IS NULL
                THROW 51968,'KVK maintenance output columns are missing.',1;
            -- Create only absent nonunique output indexes. Never drop a unique
            -- index/constraint or alter required output shape to do upkeep.
            SET @idx=N'IX_'+@table+N'_GovID';
            IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@object AND name=@idx)
            BEGIN
                SET @sql=N'CREATE NONCLUSTERED INDEX '+QUOTENAME(@idx)+N' ON '+@full+N'([Gov_ID]);';
                EXEC sys.sp_executesql @sql;
            END;
            SET @idx=N'IX_'+@table+N'_KVK_NO';
            IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@object AND name=@idx)
            BEGIN
                SET @sql=N'CREATE NONCLUSTERED INDEX '+QUOTENAME(@idx)+N' ON '+@full+N'([KVK_NO]);';
                EXEC sys.sp_executesql @sql;
            END;
            SET @sql=N'UPDATE STATISTICS '+@full+N' WITH FULLSCAN;';
            EXEC sys.sp_executesql @sql;
            UPDATE dbo.MaintenanceKvkWork SET CompletedGeneration=@due,CompletedUTC=SYSUTCDATETIME(),
                LastErrorNumber=NULL,State=CASE WHEN DueGeneration=@due THEN 'complete' ELSE 'pending' END
              WHERE KVKNo=@kvk AND ClaimID=@ClaimID AND ClaimedGeneration=@due AND State='running';
            IF @@ROWCOUNT<>1 THROW 51964,'KVK maintenance completion claim changed.',1;
        END TRY
        BEGIN CATCH
            DECLARE @error int=ERROR_NUMBER();
            BEGIN TRY
                UPDATE dbo.MaintenanceKvkWork SET State='failed',LastErrorNumber=@error,
                    FirstErrorNumber=COALESCE(FirstErrorNumber,@error),
                    FirstErrorUTC=COALESCE(FirstErrorUTC,SYSUTCDATETIME())
                  WHERE KVKNo=@kvk AND ClaimID=@ClaimID AND State='running';
            END TRY
            BEGIN CATCH
                -- Preserve first failure; running remains uncertain if evidence fails.
            END CATCH;
            THROW;
        END CATCH;
    END;
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceKvkWork
        WHERE DueGeneration<=@Generation AND CompletedGeneration<DueGeneration)
        SET @AllDone=1;
END;
GO
