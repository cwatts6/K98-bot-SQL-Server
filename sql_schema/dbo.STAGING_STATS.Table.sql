SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[STAGING_STATS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[STAGING_STATS](
	[GovernorID] [float] NOT NULL,
	[PowerRank] [float] NOT NULL,
	[Power] [float] NOT NULL,
	[Power_Delta] [float] NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T4KillsDelta] [float] NULL,
	[T5KillsDelta] [float] NULL,
	[T4&T5_KILLSDelta] [float] NULL,
	[KILLS_OUTSIDE_KVK] [float] NULL,
	[P4T4&T5_KILLSDelta] [float] NULL,
	[P6T4&T5_KillsDelta] [float] NULL,
	[P7T4&T5_KillsDelta] [float] NULL,
	[P8T4&T5_KillsDelta] [float] NULL,
	[DeadsDelta] [float] NULL,
	[DEADS_OUTSIDE_KVK] [float] NULL,
	[P4DeadsDelta] [float] NULL,
	[P6DeadsDelta] [float] NULL,
	[P7DeadsDelta] [float] NULL,
	[P8DeadsDelta] [float] NULL,
	[HelpsDelta] [float] NULL,
	[RSSASSISTDelta] [float] NULL,
	[RSSGatheredDelta] [float] NULL,
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
	[AOOAvgHeal] [bigint] NULL,
	[KillPointsDelta] [bigint] NULL,
	[KillPoints] [bigint] NULL,
	[HealedTroopsDelta] [bigint] NULL,
	[Starting_Deads] [float] NULL,
	[Starting_T4&T5_KILLS] [float] NULL,
	[MaxPreKvkPoints] [bigint] NULL,
	[MaxHonorPoints] [bigint] NULL,
	[PreKvkRank] [bigint] NULL,
	[HonorRank] [bigint] NULL,
	[RangedPointsDelta] [bigint] NULL,
	[AutarchTimes] [bigint] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_STAGING_STATS_RangedPointsDelta]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[STAGING_STATS] ADD  CONSTRAINT [DF_STAGING_STATS_RangedPointsDelta]  DEFAULT ((0)) FOR [RangedPointsDelta]
END

