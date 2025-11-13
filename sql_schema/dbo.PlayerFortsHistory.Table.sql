SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PlayerFortsHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[PlayerFortsHistory](
	[GovernorID] [bigint] NOT NULL,
	[FortsStarted] [int] NOT NULL,
	[FortsJoined] [int] NOT NULL,
	[FortsTotal]  AS ([FortsStarted]+[FortsJoined]) PERSISTED,
	[SnapshotAt] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_PlayerFortsHistory] PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC,
	[SnapshotAt] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PlayerFortsHistory]') AND name = N'IX_Forts_Gov_Snapshot')
CREATE NONCLUSTERED INDEX [IX_Forts_Gov_Snapshot] ON [dbo].[PlayerFortsHistory]
(
	[GovernorID] ASC,
	[SnapshotAt] DESC
)
INCLUDE([FortsStarted],[FortsJoined],[FortsTotal]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PlayerFortsHistory]') AND name = N'IX_PFH_Gov_Snapshot')
CREATE NONCLUSTERED INDEX [IX_PFH_Gov_Snapshot] ON [dbo].[PlayerFortsHistory]
(
	[GovernorID] ASC,
	[SnapshotAt] ASC
)
INCLUDE([FortsTotal]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_PlayerFortsHistory_SnapshotAt]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[PlayerFortsHistory] ADD  CONSTRAINT [DF_PlayerFortsHistory_SnapshotAt]  DEFAULT (sysutcdatetime()) FOR [SnapshotAt]
END

