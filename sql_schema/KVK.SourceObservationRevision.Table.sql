SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceObservationRevision](
	[RevisionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[ObservationID] [uniqueidentifier] NOT NULL,
	[RevisionNo] [int] NOT NULL,
	[SemanticHash] [binary](32) NOT NULL,
	[DigestVersion] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SchemaVersion] [varchar](64) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ArtifactHash] [binary](32) NOT NULL,
	[SupersedesRevisionID] [uniqueidentifier] NULL,
	[AcceptanceState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AcceptedUTC] [datetime2](0) NOT NULL,
	[AcceptedBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[MetadataJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceObservationRevision] PRIMARY KEY CLUSTERED 
(
	[RevisionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceObservationRevision_Digest] UNIQUE NONCLUSTERED 
(
	[ObservationID] ASC,
	[DigestVersion] ASC,
	[SchemaVersion] ASC,
	[SemanticHash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceObservationRevision_Number] UNIQUE NONCLUSTERED 
(
	[ObservationID] ASC,
	[RevisionNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceObservationRevision_Parent] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ObservationID] ASC,
	[RevisionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceObservationRevision_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[RevisionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservationRevision_Artifact]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision]  WITH CHECK ADD  CONSTRAINT [FK_SourceObservationRevision_Artifact] FOREIGN KEY([ArtifactHash])
REFERENCES [KVK].[SourceArtifact] ([ArtifactHash])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservationRevision_Artifact]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision] CHECK CONSTRAINT [FK_SourceObservationRevision_Artifact]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservationRevision_Observation]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision]  WITH CHECK ADD  CONSTRAINT [FK_SourceObservationRevision_Observation] FOREIGN KEY([SourceKey], [KVK_NO], [ObservationID])
REFERENCES [KVK].[SourceObservation] ([SourceKey], [KVK_NO], [ObservationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservationRevision_Observation]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision] CHECK CONSTRAINT [FK_SourceObservationRevision_Observation]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservationRevision_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision]  WITH CHECK ADD  CONSTRAINT [FK_SourceObservationRevision_Supersedes] FOREIGN KEY([SourceKey], [KVK_NO], [ObservationID], [SupersedesRevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [ObservationID], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservationRevision_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision] CHECK CONSTRAINT [FK_SourceObservationRevision_Supersedes]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_Metadata]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservationRevision_Metadata] CHECK  ((isjson([MetadataJson])=(1) AND datalength([MetadataJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_Metadata]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision] CHECK CONSTRAINT [CK_SourceObservationRevision_Metadata]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_Number]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservationRevision_Number] CHECK  (([RevisionNo]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_Number]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision] CHECK CONSTRAINT [CK_SourceObservationRevision_Number]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservationRevision_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision] CHECK CONSTRAINT [CK_SourceObservationRevision_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservationRevision_State] CHECK  ((([AcceptanceState]='corrected' OR [AcceptanceState]='accepted') AND ([AcceptanceState]<>'corrected' OR [SupersedesRevisionID] IS NOT NULL) AND len([AcceptedBy])>(0) AND len([Reason])>(0) AND len([DigestVersion])>(0) AND len([SchemaVersion])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision] CHECK CONSTRAINT [CK_SourceObservationRevision_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservationRevision_Supersedes] CHECK  (([SupersedesRevisionID] IS NULL OR [SupersedesRevisionID]<>[RevisionID]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservationRevision_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservationRevision]'))
ALTER TABLE [KVK].[SourceObservationRevision] CHECK CONSTRAINT [CK_SourceObservationRevision_Supersedes]
