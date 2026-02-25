SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_ArkRetentionCleanup]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_ArkRetentionCleanup] AS' 
END
ALTER PROCEDURE [dbo].[usp_ArkRetentionCleanup]
	@RetentionYears [int] = 2
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CutoffDate date = DATEADD(year, -@RetentionYears, CAST(GETUTCDATE() AS date));

    -- Delete dependent rows first to satisfy FK constraints
    DELETE s
    FROM dbo.ArkSignups s
    INNER JOIN dbo.ArkMatches m ON m.MatchId = s.MatchId
    WHERE m.ArkWeekendDate < @CutoffDate;

    DELETE l
    FROM dbo.ArkAuditLog l
    WHERE l.CreatedAtUtc < DATEADD(year, -@RetentionYears, GETUTCDATE());

    DELETE m
    FROM dbo.ArkMatches m
    WHERE m.ArkWeekendDate < @CutoffDate;

    -- Optional: prune revoked/expired bans older than retention window
    DELETE b
    FROM dbo.ArkBans b
    WHERE b.EndArkWeekendDate < @CutoffDate
      AND b.RevokedAtUtc IS NOT NULL;
END
