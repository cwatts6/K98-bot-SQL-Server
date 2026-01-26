SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DeadsDelta]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DeadsDelta](
	[GovernorID] [float] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[DeadsDelta] [float] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DeadsDelta]') AND name = N'IX_DeadsDelta_DeltaOrder')
CREATE NONCLUSTERED INDEX [IX_DeadsDelta_DeltaOrder] ON [dbo].[DeadsDelta]
(
	[DeltaOrder] ASC
)
INCLUDE([GovernorID],[DeadsDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DeadsDelta]') AND name = N'IX_DeadsDelta_DeltaOrder_GovernorID')
CREATE NONCLUSTERED INDEX [IX_DeadsDelta_DeltaOrder_GovernorID] ON [dbo].[DeadsDelta]
(
	[DeltaOrder] ASC,
	[GovernorID] ASC
)
INCLUDE([DeadsDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
