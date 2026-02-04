SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DeltaMetrics]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DeltaMetrics](
	[DeltaOrder] [float] NOT NULL,
	[GovernorID] [float] NOT NULL,
	[T4KillsDelta] [float] NULL,
	[T5KillsDelta] [float] NULL,
	[T4T5KillsDelta] [float] NULL,
	[Power_Delta] [float] NULL,
	[KillPointsDelta] [bigint] NULL,
	[DeadsDelta] [float] NULL,
	[HelpsDelta] [float] NULL,
	[RSSAssistDelta] [float] NULL,
	[RSSGatheredDelta] [float] NULL,
	[HealedTroopsDelta] [bigint] NULL,
	[RangedPointsDelta] [bigint] NULL,
 CONSTRAINT [PK_DeltaMetrics] PRIMARY KEY CLUSTERED 
(
	[DeltaOrder] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DeltaMetrics]') AND name = N'IX_DeltaMetrics_GovernorID_DeltaOrder')
CREATE NONCLUSTERED INDEX [IX_DeltaMetrics_GovernorID_DeltaOrder] ON [dbo].[DeltaMetrics]
(
	[GovernorID] ASC,
	[DeltaOrder] ASC
)
INCLUDE([T4KillsDelta],[T5KillsDelta],[T4T5KillsDelta],[Power_Delta],[KillPointsDelta],[DeadsDelta],[HelpsDelta],[RSSAssistDelta],[RSSGatheredDelta],[HealedTroopsDelta],[RangedPointsDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
