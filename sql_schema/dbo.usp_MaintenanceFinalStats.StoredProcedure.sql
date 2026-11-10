SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceFinalStats
    @Dashboard bit, @Summary bit, @Generation bigint, @ClaimID uniqueidentifier
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
    IF COALESCE(APPLOCK_MODE('public','K98:StatsForUpload:Publish','Session'),'NoLock')<>'Exclusive'
        THROW 51962,'Maintenance player publication guard required.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork WHERE Kind='final_stats'
        AND State='running' AND ClaimID=@ClaimID AND ClaimedGeneration=@Generation)
        THROW 51964,'Exact final maintenance claim required.',1;
    IF @Dashboard=1 AND OBJECT_ID('dbo.EXCEL_FOR_DASHBOARD','U') IS NOT NULL
        UPDATE STATISTICS dbo.EXCEL_FOR_DASHBOARD WITH SAMPLE 25 PERCENT;
    IF @Summary=1
    BEGIN
        UPDATE STATISTICS dbo.ALL_STATS_FOR_DASHBAORD WITH FULLSCAN;
        CHECKPOINT;
    END;
END;
