/*
MigrationId: 20260721_003_allow_partial_leadership_activity_ranking
Purpose: Keep partial leadership activity observations rankable without imputing missing values
Author: cwatts
CreatedUtc: 2026-07-21
RequiresBackup: No
RiskLevel: Low
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: 0
PreValidationQuery: SELECT OBJECT_ID(N'dbo.usp_GetLeadershipPlayerReview', N'P') AS ReviewProcedure;
PostValidationQuery: SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_GetLeadershipPlayerReview', N'P')) AS ReviewDefinition;
RelatedBotPR: https://github.com/cwatts6/k98-bot/pull/537
RelatedSQLPR:

Contract change:
- A metric with at least one valid observation is available for rate-based comparison and rank.
- Missing observations remain excluded from totals and valid-day denominators; they are not zero-filled.
- Coverage, reset counts, PARTIAL freshness, new-arrival safeguards, and prompt suppression remain unchanged.
- Building and Tech remain unavailable for an unallied current governor or when no valid observation exists.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @ReviewObjectId int = OBJECT_ID(N'dbo.usp_GetLeadershipPlayerReview', N'P');
DECLARE @ReviewDefinition nvarchar(max) = OBJECT_DEFINITION(@ReviewObjectId);

IF @ReviewDefinition IS NULL
    THROW 51540, 'dbo.usp_GetLeadershipPlayerReview was not found.', 1;

/*
Remove the Stats component all-observations-present gate. The surrounding EXISTS predicate
continues to require at least one non-null delta in the selected window.
*/
DECLARE @StatsAvailabilityStart int = CHARINDEX(
    N'CONVERT(bit, CASE WHEN EXISTS', @ReviewDefinition
);
DECLARE @StatsStrictStart int = CHARINDEX(
    N'AND NOT EXISTS', @ReviewDefinition, @StatsAvailabilityStart
);
DECLARE @StatsStrictEnd int = CHARINDEX(
    N') THEN 1 ELSE 0 END)', @ReviewDefinition, @StatsStrictStart
);
DECLARE @StatsAvailabilityEnd int = CHARINDEX(
    N'FROM #Population AS population', @ReviewDefinition, @StatsAvailabilityStart
);

IF @StatsAvailabilityStart = 0
   OR @StatsStrictStart = 0
   OR @StatsStrictEnd = 0
   OR @StatsAvailabilityEnd = 0
   OR @StatsStrictStart >= @StatsAvailabilityEnd
   OR @StatsStrictEnd >= @StatsAvailabilityEnd
    THROW 51541, 'The expected Stats availability contract was not found.', 1;

SET @ReviewDefinition = STUFF(
    @ReviewDefinition,
    @StatsStrictStart,
    @StatsStrictEnd - @StatsStrictStart + 1,
    N''
);

/*
Remove the Alliance Activity full-coverage gate. Current alliance membership and at least one
valid Building/Tech delta remain mandatory; missing and reset observations remain excluded.
*/
DECLARE @ActivityAvailabilityStart int = CHARINDEX(
    N'WHEN population.IsCurrentlyAllied = 0 THEN 0', @ReviewDefinition
);
DECLARE @ActivityValidObservationStart int = CHARINDEX(
    N'WHEN COUNT(daily.MetricValue) = 0 THEN 0',
    @ReviewDefinition,
    @ActivityAvailabilityStart
);
DECLARE @ActivityStrictCoverageStart int = CHARINDEX(
    N'WHEN COUNT(DISTINCT headers.SnapshotDate) = 0 THEN 0',
    @ReviewDefinition,
    @ActivityAvailabilityStart
);
DECLARE @ActivityEligibilityEnd int = CHARINDEX(
    N'FROM #Population AS population',
    @ReviewDefinition,
    @ActivityAvailabilityStart
);
DECLARE @ActivityAlliedMarker nvarchar(80) =
    N'WHEN population.IsCurrentlyAllied = 0 THEN 0';
DECLARE @ActivityAlliedEnd int =
    @ActivityAvailabilityStart + LEN(@ActivityAlliedMarker);

IF @ActivityAvailabilityStart = 0
   OR @ActivityValidObservationStart = 0
   OR @ActivityStrictCoverageStart = 0
   OR @ActivityEligibilityEnd = 0
   OR @ActivityStrictCoverageStart >= @ActivityValidObservationStart
   OR @ActivityValidObservationStart >= @ActivityEligibilityEnd
    THROW 51542, 'The expected Alliance Activity availability contract was not found.', 1;

SET @ReviewDefinition = STUFF(
    @ReviewDefinition,
    @ActivityAlliedEnd,
    @ActivityValidObservationStart - @ActivityAlliedEnd,
    NCHAR(13) + NCHAR(10) + REPLICATE(N' ', 15)
);

/* OBJECT_DEFINITION may retain CREATE syntax; replay existing modules with ALTER semantics. */
DECLARE @UpperReviewDefinition nvarchar(max) = UPPER(@ReviewDefinition);
DECLARE @HeaderPosition int = 1;
WHILE @HeaderPosition <= LEN(@UpperReviewDefinition)
      AND UNICODE(SUBSTRING(@UpperReviewDefinition, @HeaderPosition, 1)) IN (9, 10, 13, 32)
    SET @HeaderPosition += 1;

IF @HeaderPosition NOT BETWEEN 1 AND 64
    THROW 51543, 'Leadership review module header starts outside the allowed prefix.', 1;

IF SUBSTRING(@UpperReviewDefinition, @HeaderPosition, LEN(N'CREATE OR ALTER')) = N'CREATE OR ALTER'
    SET @ReviewDefinition = STUFF(
        @ReviewDefinition, @HeaderPosition, LEN(N'CREATE OR ALTER'), N'ALTER'
    );
ELSE IF SUBSTRING(@UpperReviewDefinition, @HeaderPosition, LEN(N'CREATE')) = N'CREATE'
    SET @ReviewDefinition = STUFF(
        @ReviewDefinition, @HeaderPosition, LEN(N'CREATE'), N'ALTER'
    );
ELSE IF SUBSTRING(@UpperReviewDefinition, @HeaderPosition, LEN(N'ALTER')) <> N'ALTER'
    THROW 51543, 'Leadership review module header is not CREATE or ALTER.', 1;

EXEC sys.sp_executesql @ReviewDefinition;
GO

DECLARE @DeployedDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_GetLeadershipPlayerReview', N'P'));
DECLARE @DeployedStatsStart int = CHARINDEX(
    N'CONVERT(bit, CASE WHEN EXISTS', @DeployedDefinition
);
DECLARE @DeployedStatsEnd int = CHARINDEX(
    N'FROM #Population AS population', @DeployedDefinition, @DeployedStatsStart
);
DECLARE @DeployedStatsStrict int = CHARINDEX(
    N'AND NOT EXISTS', @DeployedDefinition, @DeployedStatsStart
);
DECLARE @DeployedActivityStart int = CHARINDEX(
    N'WHEN population.IsCurrentlyAllied = 0 THEN 0', @DeployedDefinition
);
DECLARE @DeployedActivityEnd int = CHARINDEX(
    N'FROM #Population AS population', @DeployedDefinition, @DeployedActivityStart
);
DECLARE @DeployedActivityStrict int = CHARINDEX(
    N'WHEN COUNT(DISTINCT headers.SnapshotDate) = 0 THEN 0',
    @DeployedDefinition,
    @DeployedActivityStart
);

IF @DeployedDefinition IS NULL
   OR @DeployedStatsStart = 0
   OR @DeployedStatsEnd = 0
   OR @DeployedActivityStart = 0
   OR @DeployedActivityEnd = 0
   OR (@DeployedStatsStrict > @DeployedStatsStart
       AND @DeployedStatsStrict < @DeployedStatsEnd)
   OR (@DeployedActivityStrict > @DeployedActivityStart
       AND @DeployedActivityStrict < @DeployedActivityEnd)
    THROW 51544, 'Partial leadership activity ranking contract verification failed.', 1;
GO
