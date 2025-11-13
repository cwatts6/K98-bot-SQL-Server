SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotHeader]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[AllianceActivitySnapshotHeader](
	[SnapshotId] [bigint] IDENTITY(1,1) NOT NULL,
	[SnapshotTsUtc] [datetime2](0) NOT NULL,
	[WeekStartUtc] [datetime2](0) NOT NULL,
	[SourceMessageId] [bigint] NULL,
	[SourceChannelId] [bigint] NULL,
	[SourceFileName] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[SourceFileSha1] [varbinary](20) NULL,
	[Row_Count] [int] NULL,
	[CreatedUtc] [datetime2](0) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[SnapshotId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_AllianceActivitySnapshotHeader_WeekSha1] UNIQUE NONCLUSTERED 
(
	[WeekStartUtc] ASC,
	[SourceFileSha1] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotHeader]') AND name = N'IX_AASH_WeekStart_SnapshotTs')
CREATE NONCLUSTERED INDEX [IX_AASH_WeekStart_SnapshotTs] ON [dbo].[AllianceActivitySnapshotHeader]
(
	[WeekStartUtc] ASC,
	[SnapshotTsUtc] DESC
)
INCLUDE([SnapshotId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotHeader]') AND name = N'IX_AASH_WeekStart_SnapTs')
CREATE NONCLUSTERED INDEX [IX_AASH_WeekStart_SnapTs] ON [dbo].[AllianceActivitySnapshotHeader]
(
	[WeekStartUtc] ASC,
	[SnapshotTsUtc] ASC,
	[SnapshotId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotHeader]') AND name = N'IX_AllActHdr_WeekStart')
CREATE NONCLUSTERED INDEX [IX_AllActHdr_WeekStart] ON [dbo].[AllianceActivitySnapshotHeader]
(
	[WeekStartUtc] ASC,
	[SnapshotTsUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotHeader]') AND name = N'IX_AllianceActivityHeader_Week_Ts')
CREATE NONCLUSTERED INDEX [IX_AllianceActivityHeader_Week_Ts] ON [dbo].[AllianceActivitySnapshotHeader]
(
	[WeekStartUtc] ASC,
	[SnapshotTsUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotHeader]') AND name = N'IX_Header_WeekStart_SnapshotTs')
CREATE NONCLUSTERED INDEX [IX_Header_WeekStart_SnapshotTs] ON [dbo].[AllianceActivitySnapshotHeader]
(
	[WeekStartUtc] ASC,
	[SnapshotTsUtc] DESC,
	[SnapshotId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivitySnapshotHeader]') AND name = N'UX_AllianceActivityHeader_Week_File')
CREATE UNIQUE NONCLUSTERED INDEX [UX_AllianceActivityHeader_Week_File] ON [dbo].[AllianceActivitySnapshotHeader]
(
	[WeekStartUtc] ASC,
	[SourceFileSha1] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_AllActHdr_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[AllianceActivitySnapshotHeader] ADD  CONSTRAINT [DF_AllActHdr_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

