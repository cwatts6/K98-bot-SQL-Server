SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KingdomScanData5]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KingdomScanData5](
	[PowerRank] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[GovernorID] [float] NOT NULL,
	[Alliance] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [float] NOT NULL,
	[KillPoints] [float] NOT NULL,
	[Deads] [float] NOT NULL,
	[T1_Kills] [float] NOT NULL,
	[T2_Kills] [float] NOT NULL,
	[T3_Kills] [float] NOT NULL,
	[T4_Kills] [float] NOT NULL,
	[T5_Kills] [float] NOT NULL,
	[T4&T5_KILLS] [float] NULL,
	[TOTAL_KILLS] [float] NULL,
	[RSS_Gathered] [float] NULL,
	[RSSAssistance] [float] NOT NULL,
	[Helps] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[SCANORDER] [float] NULL,
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
PRIMARY KEY CLUSTERED 
(
	[SCAN_UNO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
