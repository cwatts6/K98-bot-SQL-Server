SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CURRENT_STATS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[CURRENT_STATS](
	[GovernorID] [float] NOT NULL,
	[PowerRank] [float] NOT NULL,
	[Power] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T4&T5_KILLSDelta] [float] NULL,
	[P4T4&T5_KILLSDelta] [float] NULL,
	[P6T4&T5_KillsDelta] [float] NULL,
	[P7T4&T5_KillsDelta] [float] NULL,
	[P8T4&T5_KillsDelta] [float] NULL,
	[DeadsDelta] [float] NULL,
	[P4DeadsDelta] [float] NULL,
	[P6DeadsDelta] [float] NULL,
	[P7DeadsDelta] [float] NULL,
	[P8DeadsDelta] [float] NULL,
	[HelpsDelta] [float] NULL,
	[RSSASSISTDelta] [float] NULL,
	[RSSGatheredDelta] [float] NULL
) ON [PRIMARY]
END
