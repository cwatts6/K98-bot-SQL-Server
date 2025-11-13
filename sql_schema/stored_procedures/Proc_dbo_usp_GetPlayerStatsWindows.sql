SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_GetPlayerStatsWindows]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_GetPlayerStatsWindows] AS' 
END
ALTER PROCEDURE [dbo].[usp_GetPlayerStatsWindows]
	@GovernorIDs [dbo].[IntList] READONLY,
	@IncludeSlicesCsv [nvarchar](max) = NULL,
	@UsePrevScanFor1d [bit] = 1,
	@IncludeAggregate [bit] = 1,
	@NowUtc [datetime2](7) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
  SET NOCOUNT ON;

  /* Anchors (from unified daily view) */
  DECLARE @Now    datetime2 = COALESCE(@NowUtc, SYSUTCDATETIME());
  DECLARE @Latest datetime2 = (SELECT MAX(AsOfDate) FROM dbo.vDaily_PlayerExport WITH (NOLOCK));
  IF @Latest IS NULL SET @Latest = @Now;

  DECLARE @PrevScan datetime2 = (
      SELECT MAX(AsOfDate) FROM dbo.vDaily_PlayerExport WITH (NOLOCK) WHERE AsOfDate < @Latest
  );

  DECLARE @ThisMonday   datetime2 = DATEADD(DAY, -DATEDIFF(DAY, 0, CAST(@Latest AS date)) % 7, CAST(CAST(@Latest AS date) AS datetime2));
  DECLARE @LastMonday   datetime2 = DATEADD(DAY, -7, @ThisMonday);
  DECLARE @EndLastWeek  datetime2 = DATEADD(SECOND, -1, @ThisMonday);

  DECLARE @FirstOfThisMonth datetime2 = DATEFROMPARTS(YEAR(@Latest), MONTH(@Latest), 1);
  DECLARE @FirstOfLastMonth date      = DATEADD(MONTH, -1, CAST(@FirstOfThisMonth AS date));
  DECLARE @EndOfLastMonth   datetime2 = DATEADD(SECOND, -1, @FirstOfThisMonth);

  DECLARE @FirstOf3MoAgo date = DATEADD(MONTH, -3, CAST(@FirstOfThisMonth AS date));
  DECLARE @FirstOf6MoAgo date = DATEADD(MONTH, -6, CAST(@FirstOfThisMonth AS date));

  DECLARE @Today date = CAST(@Latest AS date);
  DECLARE @TodayStart     datetime2 = CAST(@Today AS datetime2);
  DECLARE @YesterdayStart datetime2 = CAST(DATEADD(DAY,-1,@Today) AS datetime2);
  DECLARE @YesterdayEnd   datetime2 = DATEADD(SECOND,-1,@TodayStart);

  DECLARE @Start1d datetime2 = CASE WHEN @UsePrevScanFor1d=1 AND @PrevScan IS NOT NULL
                                    THEN @PrevScan ELSE DATEADD(DAY,-1,@Latest) END;
  DECLARE @End1d   datetime2 = @Latest;

  /* Slices */
  DECLARE @Slices TABLE (WindowKey nvarchar(32) PRIMARY KEY, WindowStartUtc datetime2, WindowEndUtc datetime2);
  IF @IncludeSlicesCsv IS NULL OR LTRIM(RTRIM(@IncludeSlicesCsv))=N''
  BEGIN
    INSERT INTO @Slices VALUES
      (N'1d',@Start1d,@End1d),(N'yesterday',@YesterdayStart,@YesterdayEnd),
      (N'wtd',@ThisMonday,@Latest),(N'last_week',@LastMonday,@EndLastWeek),
      (N'mtd',@FirstOfThisMonth,@Latest),
      (N'last_month',CAST(@FirstOfLastMonth AS datetime2),@EndOfLastMonth),
      (N'last_3m',CAST(@FirstOf3MoAgo AS datetime2),@Latest),
      (N'last_6m',CAST(@FirstOf6MoAgo AS datetime2),@Latest);
  END
  ELSE
  BEGIN
    ;WITH SS AS (
      SELECT LTRIM(RTRIM(LOWER(value))) AS SliceKey
      FROM STRING_SPLIT(@IncludeSlicesCsv, ',')
      WHERE value IS NOT NULL AND LTRIM(RTRIM(value)) <> ''
    )
    INSERT INTO @Slices
    SELECT k.*
    FROM (VALUES
      (N'1d',@Start1d,@End1d),
      (N'yesterday',@YesterdayStart,@YesterdayEnd),
      (N'wtd',@ThisMonday,@Latest),
      (N'last_week',@LastMonday,@EndLastWeek),
      (N'mtd',@FirstOfThisMonth,@Latest),
      (N'last_month',CAST(@FirstOfLastMonth AS datetime2),@EndOfLastMonth),
      (N'last_3m',CAST(@FirstOf3MoAgo AS datetime2),@Latest),
      (N'last_6m',CAST(@FirstOf6MoAgo AS datetime2),@Latest)
    ) AS k(WindowKey,WindowStartUtc,WindowEndUtc)
    WHERE EXISTS (SELECT 1 FROM SS WHERE SS.SliceKey=k.WindowKey);
  END

  /* CSV of IDs for function */
  DECLARE @GovCsv nvarchar(max) =
    STUFF((SELECT N',' + CONVERT(nvarchar(20), ID)
           FROM @GovernorIDs ORDER BY ID
           FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,1,'');

  /* Latest GovernorName/Alliance from unified view */
  ;WITH LATEST_ROW AS (
    SELECT
      v.GovernorID,
      ROW_NUMBER() OVER (PARTITION BY v.GovernorID ORDER BY v.AsOfDate DESC) AS rn,
      v.GovernorName, v.Alliance
    FROM dbo.vDaily_PlayerExport v WITH (NOLOCK)
    WHERE v.GovernorID IN (SELECT ID FROM @GovernorIDs) AND v.AsOfDate <= @Latest
  )
  SELECT GovernorID, GovernorName, Alliance
  INTO #GovMeta
  FROM LATEST_ROW WHERE rn=1;

/* Per-account rows (set-based) */
/* Create #Per explicitly so GovernorID can be NULL for ALL rows */
IF OBJECT_ID('tempdb..#Per') IS NOT NULL DROP TABLE #Per;
CREATE TABLE #Per
(
  Grouping             nvarchar(10)  NOT NULL,
  WindowKey            nvarchar(32)  NOT NULL,
  WindowStartUtc       datetime2     NOT NULL,
  WindowEndUtc         datetime2     NOT NULL,
  GovernorID           int           NULL,        -- NULL for ALL roll-up
  GovernorName         nvarchar(200) NULL,
  Alliance             nvarchar(100) NULL,

  -- snapshot ends
  PowerEnd             bigint        NULL,
  TroopPowerEnd        bigint        NULL,
  KillPointsEnd        bigint        NULL,
  DeadsEnd             bigint        NULL,
  RSSGatheredEnd       bigint        NULL,
  RSSAssistEnd         bigint        NULL,
  HelpsEnd             bigint        NULL,

  -- window sums
  PowerDelta           bigint        NULL,
  TroopPowerDelta      bigint        NULL,
  KillPointsDelta      bigint        NULL,
  DeadsDelta           bigint        NULL,
  RSSGatheredDelta     bigint        NULL,
  RSSAssistDelta       bigint        NULL,
  HelpsDelta           bigint        NULL,

  BuildingMinutesDelta bigint        NULL,
  TechDonationsDelta   bigint        NULL,

  -- forts (daily counts summed)
  FortsTotal           bigint        NULL,
  FortsLaunched        bigint        NULL,
  FortsJoined          bigint        NULL
);

-- Insert PER rows
INSERT INTO #Per
(
  Grouping, WindowKey, WindowStartUtc, WindowEndUtc,
  GovernorID, GovernorName, Alliance,
  PowerEnd, TroopPowerEnd, KillPointsEnd, DeadsEnd, RSSGatheredEnd, RSSAssistEnd, HelpsEnd,
  PowerDelta, TroopPowerDelta, KillPointsDelta, DeadsDelta, RSSGatheredDelta, RSSAssistDelta, HelpsDelta,
  BuildingMinutesDelta, TechDonationsDelta,
  FortsTotal, FortsLaunched, FortsJoined
)
SELECT
  'PER',
  s.WindowKey, s.WindowStartUtc, s.WindowEndUtc,
  t.GovernorID, m.GovernorName, m.Alliance,
  t.PowerEnd, t.TroopPowerEnd, t.KillPointsEnd, t.DeadsEnd,
  t.RSSGatheredEnd, t.RSSAssistEnd, t.HelpsEnd,
  t.PowerDelta, t.TroopPowerDelta, t.KillPointsDelta, t.DeadsDelta,
  t.RSSGatheredDelta, t.RSSAssistDelta, t.HelpsDelta,
  t.BuildingMinutesDelta, t.TechDonationsDelta,
  t.FortsTotal, t.FortsLaunched, t.FortsJoined
FROM @Slices s
CROSS APPLY dbo.fn_StatsWindowDeltas_GovCsv(s.WindowStartUtc, s.WindowEndUtc, @GovCsv) t
LEFT JOIN #GovMeta m ON m.GovernorID = t.GovernorID
WHERE t.GovernorID IN (SELECT ID FROM @GovernorIDs)
OPTION (RECOMPILE);

-- Insert ALL roll-up rows
IF @IncludeAggregate = 1
BEGIN
  INSERT INTO #Per
  (
    Grouping, WindowKey, WindowStartUtc, WindowEndUtc,
    GovernorID, GovernorName, Alliance,
    PowerEnd, TroopPowerEnd, KillPointsEnd, DeadsEnd,
    RSSGatheredEnd, RSSAssistEnd, HelpsEnd,
    PowerDelta, TroopPowerDelta, KillPointsDelta, DeadsDelta,
    RSSGatheredDelta, RSSAssistDelta, HelpsDelta,
    BuildingMinutesDelta, TechDonationsDelta,
    FortsTotal, FortsLaunched, FortsJoined
  )
  SELECT
    'ALL', s.WindowKey, s.WindowStartUtc, s.WindowEndUtc,
    NULL, N'ALL', NULL,
    SUM(t.PowerEnd), SUM(t.TroopPowerEnd), SUM(t.KillPointsEnd), SUM(t.DeadsEnd),
    SUM(t.RSSGatheredEnd), SUM(t.RSSAssistEnd), SUM(t.HelpsEnd),
    SUM(t.PowerDelta), SUM(t.TroopPowerDelta), SUM(t.KillPointsDelta), SUM(t.DeadsDelta),
    SUM(t.RSSGatheredDelta), SUM(t.RSSAssistDelta), SUM(t.HelpsDelta),
    SUM(t.BuildingMinutesDelta), SUM(t.TechDonationsDelta),
    SUM(t.FortsTotal), SUM(t.FortsLaunched), SUM(t.FortsJoined)
  FROM @Slices s
  CROSS APPLY dbo.fn_StatsWindowDeltas_GovCsv(s.WindowStartUtc, s.WindowEndUtc, @GovCsv) t
  WHERE t.GovernorID IN (SELECT ID FROM @GovernorIDs)
  GROUP BY s.WindowKey, s.WindowStartUtc, s.WindowEndUtc
  OPTION (RECOMPILE);
END

  SELECT *
  FROM #Per
  ORDER BY
    WindowStartUtc, WindowEndUtc,
    CASE WHEN GovernorID IS NULL THEN 1 ELSE 0 END,
    GovernorName;

  DROP TABLE IF EXISTS #Per;
  DROP TABLE IF EXISTS #GovMeta;
END

