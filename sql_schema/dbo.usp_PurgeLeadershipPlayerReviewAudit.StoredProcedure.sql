SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_PurgeLeadershipPlayerReviewAudit]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_PurgeLeadershipPlayerReviewAudit] AS' 
END
ALTER PROCEDURE [dbo].[usp_PurgeLeadershipPlayerReviewAudit]
	@NowUtc [datetime2](3) = NULL,
	@EmitResult [bit] = 1
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @EffectiveNow datetime2(3) = COALESCE(@NowUtc, SYSUTCDATETIME());
    CREATE TABLE #ExpiredAggregate
    (
        AuditDateUtc date NOT NULL,
        Action nvarchar(32) COLLATE DATABASE_DEFAULT NOT NULL,
        Outcome nvarchar(24) COLLATE DATABASE_DEFAULT NOT NULL,
        EventCount bigint NOT NULL,
        PRIMARY KEY CLUSTERED (AuditDateUtc, Action, Outcome)
    );
    DECLARE @DeletedRows int;
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT INTO #ExpiredAggregate
        SELECT CONVERT(date, ExecutedAtUtc), Action, Outcome, COUNT_BIG(*)
        FROM dbo.LeadershipPlayerReviewAudit WITH (UPDLOCK, HOLDLOCK)
        WHERE ExpiresAtUtc <= @EffectiveNow
        GROUP BY CONVERT(date, ExecutedAtUtc), Action, Outcome;
        UPDATE d
        SET EventCount = d.EventCount + e.EventCount, LastAggregatedAtUtc = @EffectiveNow
        FROM dbo.LeadershipPlayerReviewAuditDaily AS d
        JOIN #ExpiredAggregate AS e
          ON e.AuditDateUtc = d.AuditDateUtc AND e.Action = d.Action AND e.Outcome = d.Outcome;
        INSERT INTO dbo.LeadershipPlayerReviewAuditDaily
            (AuditDateUtc, Action, Outcome, EventCount, LastAggregatedAtUtc)
        SELECT e.AuditDateUtc, e.Action, e.Outcome, e.EventCount, @EffectiveNow
        FROM #ExpiredAggregate AS e
        WHERE NOT EXISTS
        (
            SELECT 1 FROM dbo.LeadershipPlayerReviewAuditDaily AS d WITH (UPDLOCK, HOLDLOCK)
            WHERE d.AuditDateUtc = e.AuditDateUtc AND d.Action = e.Action AND d.Outcome = e.Outcome
        );
        DELETE FROM dbo.LeadershipPlayerReviewAudit WHERE ExpiresAtUtc <= @EffectiveNow;
        SET @DeletedRows = @@ROWCOUNT;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
    IF @EmitResult = 1
        SELECT @DeletedRows AS DeletedIdentifiedRows,
               COALESCE((SELECT SUM(EventCount) FROM #ExpiredAggregate), 0) AS AggregatedEvents;
END

