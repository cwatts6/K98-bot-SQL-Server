SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivityDelta]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[AllianceActivityDelta](
	[SnapshotId] [bigint] NOT NULL,
	[PrevSnapshotId] [bigint] NULL,
	[GovernorID] [bigint] NOT NULL,
	[BuildingDelta] [int] NOT NULL,
	[TechDonationDelta] [int] NOT NULL,
	[Note] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_AllActDelta] PRIMARY KEY CLUSTERED 
(
	[SnapshotId] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivityDelta]') AND name = N'IX_AAD_Week_Governor_Snapshot')
CREATE NONCLUSTERED INDEX [IX_AAD_Week_Governor_Snapshot] ON [dbo].[AllianceActivityDelta]
(
	[GovernorID] ASC,
	[SnapshotId] ASC
)
INCLUDE([BuildingDelta],[TechDonationDelta],[PrevSnapshotId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivityDelta]') AND name = N'IX_AllActDelta_Week')
CREATE NONCLUSTERED INDEX [IX_AllActDelta_Week] ON [dbo].[AllianceActivityDelta]
(
	[SnapshotId] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
