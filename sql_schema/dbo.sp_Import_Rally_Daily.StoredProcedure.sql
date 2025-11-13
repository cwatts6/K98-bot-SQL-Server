SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Import_Rally_Daily]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Import_Rally_Daily] AS' 
END
ALTER PROCEDURE [dbo].[sp_Import_Rally_Daily]
	@AsOfDate [date]
WITH EXECUTE AS CALLER
AS
BEGIN
  SET NOCOUNT ON;

  ;WITH S AS (
    SELECT
      CAST(AsOfDate AS date) AsOfDate,
      CAST(GovernorID AS bigint) GovernorID,
      CAST(GovernorName AS nvarchar(120)) GovernorName,
      CAST(TotalRallies AS int) TotalRallies,
      CAST(RalliesLaunched AS int) RalliesLaunched,
      CAST(RalliesJoined AS int) RalliesJoined
    FROM dbo.stg_RallyDaily
  )
  MERGE dbo.cur_RallyDaily AS T
  USING (SELECT * FROM S WHERE AsOfDate = @AsOfDate) AS D
  ON (T.AsOfDate = D.AsOfDate AND T.GovernorID = D.GovernorID)
  WHEN MATCHED THEN UPDATE SET
      T.GovernorName    = D.GovernorName,
      T.TotalRallies    = D.TotalRallies,
      T.RalliesLaunched = D.RalliesLaunched,
      T.RalliesJoined   = D.RalliesJoined,
      T.InsertedAt      = SYSUTCDATETIME()
  WHEN NOT MATCHED BY TARGET THEN
      INSERT (AsOfDate, GovernorID, GovernorName, TotalRallies, RalliesLaunched, RalliesJoined)
      VALUES (D.AsOfDate, D.GovernorID, D.GovernorName, D.TotalRallies, D.RalliesLaunched, D.RalliesJoined);

  EXEC dbo.sp_Rebuild_RALLY_EXPORT;  -- materialize final table for consumers
  EXEC dbo.sp_Snapshot_PlayerForts @SnapshotAt = @AsOfDate;
END;

