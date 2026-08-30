SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KingdomScanData5]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KingdomScanData5](
	[PowerRank] [int] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[GovernorID] [bigint] NOT NULL,
	[Alliance] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Power] [bigint] NOT NULL,
	[KillPoints] [bigint] NOT NULL,
	[Deads] [bigint] NOT NULL,
	[T1_Kills] [bigint] NOT NULL,
	[T2_Kills] [bigint] NOT NULL,
	[T3_Kills] [bigint] NOT NULL,
	[T4_Kills] [bigint] NOT NULL,
	[T5_Kills] [bigint] NOT NULL,
	[T4&T5_KILLS] [bigint] NULL,
	[TOTAL_KILLS] [bigint] NULL,
	[RSS_Gathered] [bigint] NULL,
	[RSSAssistance] [bigint] NOT NULL,
	[Helps] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[SCANORDER] [int] NULL,
	[SCAN_UNO] [int] IDENTITY(1,1) NOT NULL,
	[Troops Power] [float] NULL,
	[City Hall] [float] NULL,
	[Tech Power] [float] NULL,
	[Building Power] [float] NULL,
	[Commander Power] [float] NULL,
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
	[AutarchTimes] [int] NULL,
	[Conduct] [decimal](5, 2) NULL,
 CONSTRAINT [PK__KingdomS__26A0969B2AE75AE9] PRIMARY KEY CLUSTERED 
(
	[SCAN_UNO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
