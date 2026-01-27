SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILLPOINTSSUMMARY]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KILLPOINTSSUMMARY](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[PowerRank] [int] NULL,
	[KillPoints] [bigint] NULL,
	[StartingKillPoints] [bigint] NULL,
	[OverallKillPointsDelta] [bigint] NULL,
	[KillPointsDelta12Months] [bigint] NULL,
	[KillPointsDelta6Months] [bigint] NULL,
	[KillPointsDelta3Months] [bigint] NULL,
PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[KILLPOINTSSUMMARY]') AND name = N'IX_KILLPOINTSSUMMARY_PowerRank')
CREATE NONCLUSTERED INDEX [IX_KILLPOINTSSUMMARY_PowerRank] ON [dbo].[KILLPOINTSSUMMARY]
(
	[PowerRank] ASC
)
INCLUDE([KillPoints],[StartingKillPoints],[OverallKillPointsDelta],[KillPointsDelta12Months],[KillPointsDelta6Months],[KillPointsDelta3Months]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
