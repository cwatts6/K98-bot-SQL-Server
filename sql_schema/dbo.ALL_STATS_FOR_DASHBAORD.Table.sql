SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ALL_STATS_FOR_DASHBAORD]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ALL_STATS_FOR_DASHBAORD](
	[Rank] [float] NOT NULL,
	[KVK_RANK] [bigint] NULL,
	[Gov_ID] [float] NULL,
	[Governor_Name] [nvarchar](255) COLLATE Latin1_General_CI_AS NOT NULL,
	[Starting Power] [float] NOT NULL,
	[Power_Delta] [float] NOT NULL,
	[T4_Kills] [float] NOT NULL,
	[T5_Kills] [float] NOT NULL,
	[T4&T5_Kills] [float] NOT NULL,
	[Kill Target] [float] NOT NULL,
	[% of Kill target] [float] NOT NULL,
	[Deads_Delta] [float] NOT NULL,
	[T4_Deads] [float] NOT NULL,
	[T5_Deads] [float] NOT NULL,
	[Dead Target] [float] NOT NULL,
	[% of Dead Target] [float] NOT NULL,
	[Zeroed] [bit] NOT NULL,
	[DKP_SCORE] [float] NOT NULL,
	[DKP Target] [float] NOT NULL,
	[% of DKP Target] [float] NOT NULL,
	[HelpsDelta] [float] NOT NULL,
	[RSS_Assist_Delta] [float] NOT NULL,
	[RSS_Gathered_Delta] [float] NOT NULL,
	[Pass 4 Kills] [float] NOT NULL,
	[Pass 6 Kills] [float] NOT NULL,
	[Pass 7 Kills] [float] NOT NULL,
	[Pass 8 Kills] [float] NOT NULL,
	[Pass 4 Deads] [float] NOT NULL,
	[Pass 6 Deads] [float] NOT NULL,
	[Pass 7 Deads] [float] NOT NULL,
	[Pass 8 Deads] [float] NOT NULL,
	[KVK_NO] [float] NULL,
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
	[KillPoints] [bigint] NULL,
	[KILLS_OUTSIDE_KVK] [bigint] NOT NULL,
	[DEADS_OUTSIDE_KVK] [bigint] NOT NULL,
	[Dead_Target] [bigint] NOT NULL,
	[Starting HealedTroops] [bigint] NOT NULL,
	[Starting KillPoints] [bigint] NOT NULL,
	[Starting Deads] [bigint] NOT NULL,
	[Starting T4&T5_KILLS] [bigint] NOT NULL,
	[HealedTroopsDelta] [bigint] NOT NULL,
	[KillPointsDelta] [bigint] NOT NULL,
	[% of Dead_Target] [decimal](9, 4) NOT NULL,
	[RangedPointsDelta] [bigint] NULL,
	[AutarchTimes] [bigint] NULL,
	[Max_PreKvk_Points] [bigint] NULL,
	[Max_HonorPoints] [bigint] NULL,
	[PreKvk_Rank] [int] NULL,
	[Honor_Rank] [int] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_KILLS_OUTSIDE_KVK]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_KILLS_OUTSIDE_KVK]  DEFAULT ((0)) FOR [KILLS_OUTSIDE_KVK]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_DEADS_OUTSIDE_KVK]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_DEADS_OUTSIDE_KVK]  DEFAULT ((0)) FOR [DEADS_OUTSIDE_KVK]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_Dead_Target]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_Dead_Target]  DEFAULT ((0)) FOR [Dead_Target]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_StartingHealedTroops]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_StartingHealedTroops]  DEFAULT ((0)) FOR [Starting HealedTroops]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_StartingKillPoints]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_StartingKillPoints]  DEFAULT ((0)) FOR [Starting KillPoints]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_StartingDeads]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_StartingDeads]  DEFAULT ((0)) FOR [Starting Deads]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_StartingT45Kills]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_StartingT45Kills]  DEFAULT ((0)) FOR [Starting T4&T5_KILLS]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_HealedTroopsDelta]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_HealedTroopsDelta]  DEFAULT ((0)) FOR [HealedTroopsDelta]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_KillPointsDelta]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_KillPointsDelta]  DEFAULT ((0)) FOR [KillPointsDelta]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ASFD_PctDead_Target]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ALL_STATS_FOR_DASHBAORD] ADD  CONSTRAINT [DF_ASFD_PctDead_Target]  DEFAULT ((0)) FOR [% of Dead_Target]
END

