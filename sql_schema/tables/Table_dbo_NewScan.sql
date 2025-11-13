SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[NewScan]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[NewScan](
	[PowerRank] [float] NULL,
	[Governor Name] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Governor ID] [float] NULL,
	[Governor_Alliance] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [float] NULL,
	[Kill Points] [float] NULL,
	[Deads] [float] NULL,
	[T1_Kills] [float] NULL,
	[T2_Kills] [float] NULL,
	[T3_Kills] [float] NULL,
	[T4_Kills] [float] NULL,
	[T5_Kills] [float] NULL,
	[Rss Assistance] [float] NULL,
	[Helps] [float] NULL,
	[ScanDate] [datetime] NULL,
	[SCANORDER] [float] NULL
) ON [PRIMARY]
END
