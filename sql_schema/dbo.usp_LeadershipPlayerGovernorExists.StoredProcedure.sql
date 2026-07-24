SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_LeadershipPlayerGovernorExists]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_LeadershipPlayerGovernorExists] AS' 
END
ALTER PROCEDURE [dbo].[usp_LeadershipPlayerGovernorExists]
	@GovernorID [bigint]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @GovernorID IS NULL OR @GovernorID <= 0
        THROW 51561, 'Leadership Governor existence requires a positive Governor ID.', 1;

    SELECT
        @GovernorID AS GovernorID,
        CONVERT(bit, CASE WHEN EXISTS
        (
            SELECT 1
            FROM dbo.KingdomScanData4 AS source
            WHERE source.GovernorID = CONVERT(float, @GovernorID)
              AND TRY_CONVERT(bigint, source.GovernorID) = @GovernorID
        )
        THEN 1 ELSE 0 END) AS ExistsInDatabase;
END

