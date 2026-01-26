SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HealedTroopsDelta]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[HealedTroopsDelta](
	[GovernorID] [bigint] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[HealedTroopsDelta] [bigint] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[HealedTroopsDelta]') AND name = N'IX_HealedTroopsDelta_DeltaOrder')
CREATE NONCLUSTERED INDEX [IX_HealedTroopsDelta_DeltaOrder] ON [dbo].[HealedTroopsDelta]
(
	[DeltaOrder] ASC
)
INCLUDE([GovernorID],[HealedTroopsDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[HealedTroopsDelta]') AND name = N'IX_HealedTroopsDelta_DeltaOrder_GovernorID')
CREATE NONCLUSTERED INDEX [IX_HealedTroopsDelta_DeltaOrder_GovernorID] ON [dbo].[HealedTroopsDelta]
(
	[DeltaOrder] ASC,
	[GovernorID] ASC
)
INCLUDE([HealedTroopsDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
