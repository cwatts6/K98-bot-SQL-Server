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
	[CompletionState] [nvarchar](24) COLLATE Latin1_General_CI_AS NOT NULL,
	[ExpectedGovernorCount] [int] NULL,
	[ObservedGovernorCount] [int] NULL,
	[MissingExpectedGovernorCount] [int] NULL,
	[MissingMetricCount] [int] NULL,
	[InvalidMetricCount] [int] NULL,
	[ValidatedAtUtc] [datetime2](0) NULL,
	[CompletionBasis] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
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
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_AllianceActivityHeader_CompletionState]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[AllianceActivitySnapshotHeader] ADD CONSTRAINT [DF_AllianceActivityHeader_CompletionState] DEFAULT (N'LEGACY_UNVERIFIED') FOR [CompletionState]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_AllianceActivityHeader_CompletionState]') AND type = 'C')
BEGIN
ALTER TABLE [dbo].[AllianceActivitySnapshotHeader] WITH CHECK ADD CONSTRAINT [CK_AllianceActivityHeader_CompletionState]
CHECK ([CompletionState] IN (N'COMPLETE', N'PARTIAL', N'LEGACY_UNVERIFIED'))
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_AllianceActivityHeader_EvidenceCounts]') AND type = 'C')
BEGIN
ALTER TABLE [dbo].[AllianceActivitySnapshotHeader] WITH CHECK ADD CONSTRAINT [CK_AllianceActivityHeader_EvidenceCounts]
CHECK (([ExpectedGovernorCount] IS NULL OR [ExpectedGovernorCount] >= 0)
AND ([ObservedGovernorCount] IS NULL OR [ObservedGovernorCount] >= 0)
AND ([MissingExpectedGovernorCount] IS NULL OR [MissingExpectedGovernorCount] >= 0)
AND ([MissingMetricCount] IS NULL OR [MissingMetricCount] >= 0)
AND ([InvalidMetricCount] IS NULL OR [InvalidMetricCount] >= 0))
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_AllianceActivityHeader_CompletionBasis]') AND type = 'C')
BEGIN
ALTER TABLE [dbo].[AllianceActivitySnapshotHeader] WITH CHECK ADD CONSTRAINT [CK_AllianceActivityHeader_CompletionBasis]
CHECK (([CompletionState] = N'LEGACY_UNVERIFIED' AND [CompletionBasis] IS NULL)
OR ([CompletionState] IN (N'COMPLETE', N'PARTIAL')
AND [CompletionBasis] IN (N'SOURCE_VALIDATED', N'LEGACY_ASSUMED_ZERO')))
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CK_AllianceActivityHeader_CompleteEvidence]') AND type = 'C')
BEGIN
ALTER TABLE [dbo].[AllianceActivitySnapshotHeader] WITH CHECK ADD CONSTRAINT [CK_AllianceActivityHeader_CompleteEvidence]
CHECK ([CompletionState] <> N'COMPLETE'
OR ([ExpectedGovernorCount] IS NOT NULL
AND [ObservedGovernorCount] IS NOT NULL
AND [MissingExpectedGovernorCount] IS NOT NULL
AND [MissingMetricCount] IS NOT NULL
AND [InvalidMetricCount] IS NOT NULL
AND [ValidatedAtUtc] IS NOT NULL
AND [MissingExpectedGovernorCount] = 0
AND [MissingMetricCount] = 0
AND [InvalidMetricCount] = 0))
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

