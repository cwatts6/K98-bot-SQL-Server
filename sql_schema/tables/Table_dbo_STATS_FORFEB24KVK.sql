SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[STATS_FORFEB24KVK]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[STATS_FORFEB24KVK](
	[GovernorID] [float] NULL,
	[PowerRank] [float] NOT NULL,
	[Power] [float] NOT NULL,
	[POWER_DELTA] [float] NULL,
	[T4&T5_KILLSDelta] [float] NULL,
	[T4KillsDelta] [float] NULL,
	[T5KillsDelta] [float] NULL,
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
	[RSSGatheredDelta] [float] NULL
) ON [PRIMARY]
END
