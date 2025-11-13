SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[THE_AVERAGES]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[THE_AVERAGES](
	[PowerRank] [varchar](3) COLLATE Latin1_General_CI_AS NOT NULL,
	[GovernorName] [varchar](15) COLLATE Latin1_General_CI_AS NOT NULL,
	[GovernorID] [varchar](9) COLLATE Latin1_General_CI_AS NOT NULL,
	[Alliance] [varchar](11) COLLATE Latin1_General_CI_AS NOT NULL,
	[Power] [float] NULL,
	[KillPoints] [float] NULL,
	[Deads] [float] NULL,
	[T1_Kills] [float] NULL,
	[T2_Kills] [float] NULL,
	[T3_Kills] [float] NULL,
	[T4_Kills] [float] NULL,
	[T5_Kills] [float] NULL,
	[T4&T5_KILLS] [float] NULL,
	[TOTAL_KILLS] [float] NULL,
	[RSS_Gathered] [float] NULL,
	[RSSAssistance] [float] NULL,
	[Helps] [float] NULL,
	[ScanDate] [datetime] NOT NULL,
	[SCANORDER] [float] NOT NULL,
	[SCAN_UNO] [varchar](9) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
END
