SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenancePostImport
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF COALESCE(APPLOCK_MODE('public','K98:TargetPublication:DeltaPreprocessing','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Maintenance delta guard required.',1;
    IF APPLOCK_MODE('public','K98:post-import-stats:v1','Session')<>'Exclusive'
       OR APPLOCK_MODE('public','k98-legacy-output-snapshot','Session')<>'Exclusive'
        THROW 51961, 'Exact maintenance worker ownership required.', 1;
    IF COALESCE(APPLOCK_MODE('public','K98:maintenance-schema:v1','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Maintenance schema guard required.',1;
    EXEC sys.sp_updatestats;
END;
