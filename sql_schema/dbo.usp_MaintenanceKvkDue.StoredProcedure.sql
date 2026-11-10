SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceKvkDue @KVKNo int
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @KVKNo IS NULL OR @KVKNo<=0 OR @@TRANCOUNT=0
        THROW 51962,'KVK upkeep requires a positive KVK in its publication transaction.',1;
    IF COALESCE(APPLOCK_MODE('public','K98:maintenance-schema:v1','Transaction'),'NoLock') NOT IN ('Shared','Exclusive')
        THROW 51962,'KVK publication schema ownership required.',1;
    DECLARE @object int,@created datetime,@revision int,@generation bigint;
    SELECT @object=object_id,@created=create_date FROM sys.tables
      WHERE schema_id=SCHEMA_ID('dbo') AND name=N'EXCEL_FOR_KVK_'+CONVERT(nvarchar(11),@KVKNo);
    SELECT @revision=Revision FROM dbo.KVKFinalReportHeader
      WHERE KVK_NO=@KVKNo AND State=N'OUTPUT_COMPLETE';
    IF @object IS NULL OR @revision IS NULL
        THROW 51962,'Canonical KVK output and completion receipt required.',1;
    EXEC dbo.usp_MaintenanceDue @Kind='kvk_output';
    SELECT @generation=DueGeneration FROM dbo.MaintenanceWork WHERE Kind='kvk_output';
    -- One coalesced row per canonical output, never one row per import.
    -- Claim fields remain the original attempted identity after newer publication.
    UPDATE dbo.MaintenanceKvkWork WITH (UPDLOCK,HOLDLOCK)
       SET DueGeneration=@generation,DueObjectID=@object,DueObjectCreateDate=@created,
           DueHeaderRevision=@revision,State=CASE WHEN State='complete' THEN 'pending' ELSE State END
     WHERE KVKNo=@KVKNo;
    IF @@ROWCOUNT=0
        INSERT dbo.MaintenanceKvkWork(KVKNo,DueGeneration,DueObjectID,DueObjectCreateDate,DueHeaderRevision)
        VALUES(@KVKNo,@generation,@object,@created,@revision);
END;
GO
