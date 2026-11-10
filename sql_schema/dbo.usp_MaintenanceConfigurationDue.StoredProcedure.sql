SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceConfigurationDue
    @RowsProcessed int, @LastScan int
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT=0 OR @RowsProcessed<=0 THROW 51962,'Configuration due requires its business transaction and positive rows.',1;
    IF COALESCE(APPLOCK_MODE('public','K98:TargetPublication:DeltaPreprocessing','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Configuration due requires its delta owner.',1;
    EXEC dbo.usp_MaintenanceDue @Kind='configuration';
    DECLARE @generation bigint=(SELECT DueGeneration FROM dbo.MaintenanceWork WHERE Kind='configuration');
    UPDATE dbo.MaintenanceConfigurationWork
       SET DueRows=DueRows+@RowsProcessed,LastBatchRows=@RowsProcessed,LastScan=@LastScan,
           LargeBatchGeneration=CASE WHEN @RowsProcessed>=5000 THEN @generation ELSE LargeBatchGeneration END
     WHERE ID=1;
    IF @@ROWCOUNT<>1 THROW 51962,'Configuration maintenance summary missing.',1;
END;
