SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Import_Rally_AllTime]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Import_Rally_AllTime] AS' 
END
ALTER PROCEDURE [dbo].[sp_Import_Rally_AllTime]
WITH EXECUTE AS CALLER
AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  BEGIN TRAN;

  -- Replace baseline snapshot
  DELETE FROM dbo.cur_RallyTotals_Base;

  INSERT dbo.cur_RallyTotals_Base (GovernorID, GovernorName, TotalRallies, RalliesLaunched, RalliesJoined)
  SELECT
      CAST(GovernorID AS bigint),
      CAST(GovernorName AS nvarchar(120)),
      CAST(TotalRallies AS int),
      CAST(RalliesLaunched AS int),
      CAST(RalliesJoined AS int)
  FROM dbo.stg_RallyAllTime;

  COMMIT;

  -- Rebuild export from baseline + daily
  EXEC dbo.sp_Rebuild_RALLY_EXPORT;

  -- Compute snapshot date in a variable, then pass it
  DECLARE @snap_raw   date = (SELECT CONVERT(date, MAX(SnapshotAt)) FROM dbo.cur_RallyTotals_Base);
  DECLARE @snap_final date = ISNULL(@snap_raw, CAST(SYSUTCDATETIME() AS date));

  EXEC dbo.sp_Snapshot_PlayerForts @SnapshotAt = @snap_final;
END

