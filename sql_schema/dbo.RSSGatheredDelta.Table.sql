SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RSSGatheredDelta]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RSSGatheredDelta](
	[GovernorID] [float] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[RSSGatheredDelta] [float] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[RSSGatheredDelta]') AND name = N'IX_RSSGatheredDelta_DeltaOrder')
CREATE NONCLUSTERED INDEX [IX_RSSGatheredDelta_DeltaOrder] ON [dbo].[RSSGatheredDelta]
(
	[DeltaOrder] ASC
)
INCLUDE([GovernorID],[RSSGatheredDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[RSSGatheredDelta]') AND name = N'IX_RSSGatheredDelta_DeltaOrder_GovernorID')
CREATE NONCLUSTERED INDEX [IX_RSSGatheredDelta_DeltaOrder_GovernorID] ON [dbo].[RSSGatheredDelta]
(
	[DeltaOrder] ASC,
	[GovernorID] ASC
)
INCLUDE([RSSGatheredDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
