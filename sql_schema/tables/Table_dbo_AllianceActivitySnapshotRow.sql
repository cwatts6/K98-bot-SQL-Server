SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotRow]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[AllianceActivitySnapshotRow](
	[SnapshotId] [bigint] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[AllianceTag] [nvarchar](16) COLLATE Latin1_General_CI_AS NULL,
	[Power] [bigint] NULL,
	[KillPoints] [bigint] NULL,
	[HelpTimes] [int] NULL,
	[RssTrading] [bigint] NULL,
	[BuildingTotal] [int] NOT NULL,
	[TechDonationTotal] [int] NOT NULL,
 CONSTRAINT [PK_AllActRow] PRIMARY KEY CLUSTERED 
(
	[SnapshotId] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotRow]') AND name = N'IX_AASR_Gov_Snap')
CREATE NONCLUSTERED INDEX [IX_AASR_Gov_Snap] ON [dbo].[AllianceActivitySnapshotRow]
(
	[GovernorID] ASC,
	[SnapshotId] ASC
)
INCLUDE([GovernorName],[AllianceTag],[BuildingTotal],[TechDonationTotal]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotRow]') AND name = N'IX_AASR_Snapshot_Governor')
CREATE NONCLUSTERED INDEX [IX_AASR_Snapshot_Governor] ON [dbo].[AllianceActivitySnapshotRow]
(
	[SnapshotId] ASC,
	[GovernorID] ASC
)
INCLUDE([BuildingTotal],[TechDonationTotal],[GovernorName],[AllianceTag]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotRow]') AND name = N'IX_AllActRow_Gov')
CREATE NONCLUSTERED INDEX [IX_AllActRow_Gov] ON [dbo].[AllianceActivitySnapshotRow]
(
	[GovernorID] ASC,
	[SnapshotId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotRow]') AND name = N'IX_AllianceActivityRow_Snapshot_Governor')
CREATE NONCLUSTERED INDEX [IX_AllianceActivityRow_Snapshot_Governor] ON [dbo].[AllianceActivitySnapshotRow]
(
	[SnapshotId] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotRow]') AND name = N'IX_Row_Gov_Snapshot')
CREATE NONCLUSTERED INDEX [IX_Row_Gov_Snapshot] ON [dbo].[AllianceActivitySnapshotRow]
(
	[GovernorID] ASC,
	[SnapshotId] ASC
)
INCLUDE([GovernorName],[AllianceTag],[BuildingTotal],[TechDonationTotal]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK__AllianceA__Snaps__5902735E]') AND parent_object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotRow]'))
ALTER TABLE [dbo].[AllianceActivitySnapshotRow]  WITH CHECK ADD FOREIGN KEY([SnapshotId])
REFERENCES [dbo].[AllianceActivitySnapshotHeader] ([SnapshotId])
