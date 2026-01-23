SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KillPointsDelta]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KillPointsDelta](
	[GovernorID] [float] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[KillPointsDelta] [bigint] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[KillPointsDelta]') AND name = N'IX_KillPointsDelta_DeltaOrder')
CREATE NONCLUSTERED INDEX [IX_KillPointsDelta_DeltaOrder] ON [dbo].[KillPointsDelta]
(
	[DeltaOrder] ASC
)
INCLUDE([GovernorID],[KillPointsDelta]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
