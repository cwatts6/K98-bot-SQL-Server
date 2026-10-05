SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceAggregateRevision](
	[RevisionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[ReportID] [uniqueidentifier] NOT NULL,
	[PeriodKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RevisionNo] [int] NOT NULL,
	[ArtifactHash] [binary](32) NOT NULL,
	[SemanticHash] [binary](32) NOT NULL,
	[DigestVersion] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SchemaVersion] [varchar](64) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ScanStartUTC] [datetime2](0) NOT NULL,
	[TimePrecision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[CoverageStartUTC] [datetime2](0) NOT NULL,
	[CoverageEndUTC] [datetime2](0) NOT NULL,
	[AsOfUTC] [datetime2](0) NOT NULL,
	[ReportState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SupersedesRevisionID] [uniqueidentifier] NULL,
	[AcceptedUTC] [datetime2](0) NOT NULL,
	[AcceptedBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[MappingDigest] [binary](32) NOT NULL,
	[ScopeDigest] [binary](32) NOT NULL,
	[MetadataJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceAggregateRevision] PRIMARY KEY CLUSTERED 
(
	[RevisionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceAggregateRevision_Mapping] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[RevisionID] ASC,
	[MappingDigest] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceAggregateRevision_Number] UNIQUE NONCLUSTERED 
(
	[ReportID] ASC,
	[RevisionNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceAggregateRevision_Parent] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ReportID] ASC,
	[RevisionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceAggregateRevision_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[RevisionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]') AND name = N'IX_SourceAggregateRevision_AsOf')
CREATE NONCLUSTERED INDEX [IX_SourceAggregateRevision_AsOf] ON [KVK].[SourceAggregateRevision]
(
	[ReportID] ASC,
	[AsOfUTC] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateRevision_Artifact]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [FK_SourceAggregateRevision_Artifact] FOREIGN KEY([ArtifactHash])
REFERENCES [KVK].[SourceArtifact] ([ArtifactHash])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateRevision_Artifact]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [FK_SourceAggregateRevision_Artifact]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateRevision_Report]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [FK_SourceAggregateRevision_Report] FOREIGN KEY([SourceKey], [KVK_NO], [ReportID], [PeriodKind])
REFERENCES [KVK].[SourceAggregateReport] ([SourceKey], [KVK_NO], [ReportID], [PeriodKind])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateRevision_Report]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [FK_SourceAggregateRevision_Report]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateRevision_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [FK_SourceAggregateRevision_Supersedes] FOREIGN KEY([SourceKey], [KVK_NO], [ReportID], [SupersedesRevisionID])
REFERENCES [KVK].[SourceAggregateRevision] ([SourceKey], [KVK_NO], [ReportID], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateRevision_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [FK_SourceAggregateRevision_Supersedes]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Metadata]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateRevision_Metadata] CHECK  ((len([AcceptedBy])>(0) AND len([Reason])>(0) AND len([DigestVersion])>(0) AND len([SchemaVersion])>(0) AND isjson([MetadataJson])=(1) AND datalength([MetadataJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Metadata]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [CK_SourceAggregateRevision_Metadata]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Number]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateRevision_Number] CHECK  (([RevisionNo]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Number]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [CK_SourceAggregateRevision_Number]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateRevision_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [CK_SourceAggregateRevision_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateRevision_State] CHECK  ((([ReportState]='corrected_final' OR [ReportState]='final' OR [ReportState]='live') AND ([PeriodKind]<>'overall' OR ([ReportState]='corrected_final' OR [ReportState]='final')) AND ([ReportState]<>'corrected_final' OR [SupersedesRevisionID] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [CK_SourceAggregateRevision_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateRevision_Supersedes] CHECK  (([SupersedesRevisionID] IS NULL OR [SupersedesRevisionID]<>[RevisionID]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [CK_SourceAggregateRevision_Supersedes]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateRevision_Time] CHECK  ((([TimePrecision]='second' OR [TimePrecision]='minute') AND ([TimePrecision]<>'minute' OR datepart(second,[ScanStartUTC])=(0)) AND [CoverageEndUTC]>=[CoverageStartUTC] AND [AsOfUTC]>=[CoverageEndUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateRevision_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateRevision]'))
ALTER TABLE [KVK].[SourceAggregateRevision] CHECK CONSTRAINT [CK_SourceAggregateRevision_Time]
