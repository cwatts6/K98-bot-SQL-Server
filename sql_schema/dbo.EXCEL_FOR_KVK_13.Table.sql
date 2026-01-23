SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_FOR_KVK_13]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EXCEL_FOR_KVK_13](
	[Rank] [int] NULL,
	[KVK_RANK] [int] NULL,
	[Gov_ID] [bigint] NULL,
	[Governor_Name] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Starting Power] [bigint] NULL,
	[Power_Delta] [bigint] NULL,
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
	[Starting_T4&T5_KILLS] [bigint] NULL,
	[T4_KILLS] [bigint] NULL,
	[T5_KILLS] [bigint] NULL,
	[T4&T5_Kills] [bigint] NULL,
	[KILLS_OUTSIDE_KVK] [bigint] NULL,
	[Kill Target] [bigint] NULL,
	[% of Kill Target] [decimal](9, 2) NULL,
	[Starting_Deads] [bigint] NULL,
	[Deads_Delta] [bigint] NULL,
	[DEADS_OUTSIDE_KVK] [bigint] NULL,
	[T4_Deads] [bigint] NULL,
	[T5_Deads] [bigint] NULL,
	[Dead_Target] [bigint] NULL,
	[% of Dead Target] [decimal](9, 2) NULL,
	[Zeroed] [bit] NULL,
	[DKP_SCORE] [bigint] NULL,
	[DKP Target] [bigint] NULL,
	[% of DKP Target] [decimal](9, 2) NULL,
	[HelpsDelta] [bigint] NULL,
	[RSS_Assist_Delta] [bigint] NULL,
	[RSS_Gathered_Delta] [bigint] NULL,
	[Pass 4 Kills] [bigint] NULL,
	[Pass 6 Kills] [bigint] NULL,
	[Pass 7 Kills] [bigint] NULL,
	[Pass 8 Kills] [bigint] NULL,
	[Pass 4 Deads] [bigint] NULL,
	[Pass 6 Deads] [bigint] NULL,
	[Pass 7 Deads] [bigint] NULL,
	[Pass 8 Deads] [bigint] NULL,
	[Starting_HealedTroops] [bigint] NULL,
	[HealedTroopsDelta] [bigint] NULL,
	[Starting_KillPoints] [bigint] NULL,
	[KillPointsDelta] [bigint] NULL,
	[RangedPoints] [bigint] NULL,
	[RangedPointsDelta] [bigint] NULL,
	[Max_PreKvk_Points] [bigint] NULL,
	[Max_HonorPoints] [bigint] NULL,
	[PreKvk_Rank] [bigint] NULL,
	[Honor_Rank] [bigint] NULL,
	[KVK_NO] [int] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_FOR_KVK_13]') AND name = N'IX_EXCEL_FOR_KVK_13_GovID')
CREATE NONCLUSTERED INDEX [IX_EXCEL_FOR_KVK_13_GovID] ON [dbo].[EXCEL_FOR_KVK_13]
(
	[Gov_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_FOR_KVK_13]') AND name = N'IX_EXCEL_FOR_KVK_13_KVK_NO')
CREATE NONCLUSTERED INDEX [IX_EXCEL_FOR_KVK_13_KVK_NO] ON [dbo].[EXCEL_FOR_KVK_13]
(
	[KVK_NO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
