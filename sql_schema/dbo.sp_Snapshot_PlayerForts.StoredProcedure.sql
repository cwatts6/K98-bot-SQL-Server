SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Snapshot_PlayerForts]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Snapshot_PlayerForts] AS' 
END
ALTER PROCEDURE [dbo].[sp_Snapshot_PlayerForts]
	@SnapshotAt [date] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @snap date = COALESCE(@SnapshotAt, CAST(SYSUTCDATETIME() AS date));

  ;WITH RC AS
  (
    SELECT
      GovernorID,
      RalliesLaunched AS FortsStarted,
      RalliesJoined   AS FortsJoined
      -- FortsTotal is computed in the table; do NOT set it here
    FROM dbo.v_RallyTotals_Current
  )
  MERGE dbo.PlayerFortsHistory AS tgt
  USING (
    SELECT GovernorID, FortsStarted, FortsJoined, @snap AS SnapshotAt
    FROM RC
  ) AS src
    ON  tgt.GovernorID = src.GovernorID
    AND tgt.SnapshotAt = src.SnapshotAt
  WHEN MATCHED THEN
    UPDATE SET
      FortsStarted = src.FortsStarted,
      FortsJoined  = src.FortsJoined
  WHEN NOT MATCHED THEN
    INSERT (GovernorID, FortsStarted, FortsJoined, SnapshotAt)
    VALUES (src.GovernorID, src.FortsStarted, src.FortsJoined, src.SnapshotAt);
END

