SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RangedPointsDelta]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RangedPointsDelta](
	[GovernorID] [bigint] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[RangedPointsDelta] [bigint] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[RangedPointsDelta]') AND name = N'IX_RangedPointsDelta_DeltaOrder')
CREATE NONCLUSTERED INDEX [IX_RangedPointsDelta_DeltaOrder] ON [dbo].[RangedPointsDelta]
(
	[DeltaOrder] ASC
)
INCLUDE([GovernorID],[RangedPointsDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[RangedPointsDelta]') AND name = N'IX_RangedPointsDelta_DeltaOrder_GovernorID')
CREATE NONCLUSTERED INDEX [IX_RangedPointsDelta_DeltaOrder_GovernorID] ON [dbo].[RangedPointsDelta]
(
	[DeltaOrder] ASC,
	[GovernorID] ASC
)
INCLUDE([RangedPointsDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
