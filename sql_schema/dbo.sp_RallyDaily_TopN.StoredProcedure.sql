SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_RallyDaily_TopN]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_RallyDaily_TopN] AS' 
END
ALTER PROCEDURE [dbo].[sp_RallyDaily_TopN]
	@AsOfDate [date] = NULL,
	@Metric [nvarchar](16) = N'Total',
	@TopN [int] = 3
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ResolvedDate date;

    -- If no date supplied, use latest
    IF @AsOfDate IS NULL
        SELECT @ResolvedDate = MAX(AsOfDate) FROM dbo.cur_RallyDaily;
    ELSE
        SET @ResolvedDate = @AsOfDate;

    -- If requested date has no data, fallback to latest
    IF NOT EXISTS (SELECT 1 FROM dbo.cur_RallyDaily WHERE AsOfDate = @ResolvedDate)
        SELECT @ResolvedDate = MAX(AsOfDate) FROM dbo.cur_RallyDaily;

    ;WITH X AS
    (
        SELECT
            GovernorID,
            GovernorName,
            TotalRallies,
            RalliesLaunched,
            RalliesJoined,
            CASE
                WHEN @Metric = N'Launched' THEN RalliesLaunched
                WHEN @Metric = N'Joined'   THEN RalliesJoined
                ELSE TotalRallies
            END AS SortValue
        FROM dbo.cur_RallyDaily
        WHERE AsOfDate = @ResolvedDate
    )
    SELECT TOP (@TopN)
        @ResolvedDate AS AsOfDate,
        GovernorID,
        GovernorName,
        TotalRallies,
        RalliesLaunched,
        RalliesJoined,
        SortValue    AS MetricValue,
        @Metric      AS Metric
    FROM X
    ORDER BY SortValue DESC, GovernorName;
END;

