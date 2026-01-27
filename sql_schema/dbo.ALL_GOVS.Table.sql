SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ALL_GOVS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ALL_GOVS](
	[GovernorID] [bigint] NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Max Power] [bigint] NULL,
	[Latest Power] [bigint] NULL,
	[KillPoints] [bigint] NULL,
	[T1_Kills] [bigint] NULL,
	[T2_Kills] [bigint] NULL,
	[T3_Kills] [bigint] NULL,
	[T4_Kills] [bigint] NULL,
	[T5_Kills] [bigint] NULL,
	[T4&T5_KILLS] [bigint] NULL,
	[TOTAL_KILLS] [bigint] NULL,
	[Deads] [bigint] NULL,
	[Helps] [bigint] NULL,
	[RSS_Gathered] [bigint] NULL,
	[RSSAssistance] [bigint] NULL,
	[Last Scan] [datetime] NULL,
	[Previous Scan] [datetime] NULL,
	[First Scan] [datetime] NULL,
	[HealedTroops] [bigint] NULL,
	[RangedPoints] [bigint] NULL,
	[Civilization] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[KvKPlayed] [int] NULL,
	[MostKvKKill] [bigint] NULL,
	[MostKvKDead] [bigint] NULL,
	[MostKvKHeal] [bigint] NULL,
	[Acclaim] [bigint] NULL,
	[HighestAcclaim] [bigint] NULL,
	[AOOJoined] [bigint] NULL,
	[AOOWon] [int] NULL,
	[AOOAvgKill] [bigint] NULL,
	[AOOAvgDead] [bigint] NULL,
	[AOOAvgHeal] [bigint] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ALL_GOVS]') AND name = N'IX_ALL_GOVS_GovernorID')
CREATE NONCLUSTERED INDEX [IX_ALL_GOVS_GovernorID] ON [dbo].[ALL_GOVS]
(
	[GovernorID] ASC
)
INCLUDE([GovernorName],[Last Scan],[Latest Power],[Max Power]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
