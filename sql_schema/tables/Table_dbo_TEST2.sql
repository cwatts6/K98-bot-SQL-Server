SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TEST2]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[TEST2](
	[PowerRank] [float] NULL,
	[GovernorName] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[GovernorID] [float] NULL,
	[Alliance] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
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
	[ScanDate] [datetime] NULL,
	[SCANORDER] [float] NULL
) ON [PRIMARY]
END
