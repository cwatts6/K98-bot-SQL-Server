SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceImportAttempt](
	[AttemptID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[GuildID] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[MessageID] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AttachmentID] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ActionKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ArtifactHash] [binary](32) NOT NULL,
	[ActorID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ChannelID] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[OriginalFilename] [nvarchar](512) COLLATE Latin1_General_CI_AS NOT NULL,
	[ReceivedUTC] [datetime2](0) NOT NULL,
	[Status] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[DiagnosticSummary] [nvarchar](512) COLLATE Latin1_General_CI_AS NOT NULL,
	[ObservationRevisionID] [uniqueidentifier] NULL,
	[AggregateRevisionID] [uniqueidentifier] NULL,
	[ProvenanceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceImportAttempt] PRIMARY KEY CLUSTERED 
(
	[AttemptID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceImportAttempt_Replay] UNIQUE NONCLUSTERED 
(
	[GuildID] ASC,
	[MessageID] ASC,
	[AttachmentID] ASC,
	[ActionKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceImportAttempt_AggregateRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt]  WITH CHECK ADD  CONSTRAINT [FK_SourceImportAttempt_AggregateRevision] FOREIGN KEY([SourceKey], [KVK_NO], [AggregateRevisionID])
REFERENCES [KVK].[SourceAggregateRevision] ([SourceKey], [KVK_NO], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceImportAttempt_AggregateRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt] CHECK CONSTRAINT [FK_SourceImportAttempt_AggregateRevision]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceImportAttempt_Artifact]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt]  WITH CHECK ADD  CONSTRAINT [FK_SourceImportAttempt_Artifact] FOREIGN KEY([ArtifactHash])
REFERENCES [KVK].[SourceArtifact] ([ArtifactHash])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceImportAttempt_Artifact]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt] CHECK CONSTRAINT [FK_SourceImportAttempt_Artifact]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceImportAttempt_ObservationRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt]  WITH CHECK ADD  CONSTRAINT [FK_SourceImportAttempt_ObservationRevision] FOREIGN KEY([SourceKey], [KVK_NO], [ObservationRevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceImportAttempt_ObservationRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt] CHECK CONSTRAINT [FK_SourceImportAttempt_ObservationRevision]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_SourceImportAttempt_Provenance] CHECK  ((isjson([ProvenanceJson])=(1) AND datalength([ProvenanceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt] CHECK CONSTRAINT [CK_SourceImportAttempt_Provenance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Replay]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_SourceImportAttempt_Replay] CHECK  ((len([GuildID])>(0) AND len([MessageID])>(0) AND len([AttachmentID])>(0) AND len([ActionKey])>(0) AND len([ChannelID])>(0) AND len([ActorID])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Replay]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt] CHECK CONSTRAINT [CK_SourceImportAttempt_Replay]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Result]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_SourceImportAttempt_Result] CHECK  ((([Status]='duplicate' OR [Status]='accepted') AND ([ObservationRevisionID] IS NOT NULL AND [AggregateRevisionID] IS NULL OR [ObservationRevisionID] IS NULL AND [AggregateRevisionID] IS NOT NULL) OR NOT ([Status]='duplicate' OR [Status]='accepted') AND [ObservationRevisionID] IS NULL AND [AggregateRevisionID] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Result]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt] CHECK CONSTRAINT [CK_SourceImportAttempt_Result]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_SourceImportAttempt_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt] CHECK CONSTRAINT [CK_SourceImportAttempt_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Status]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_SourceImportAttempt_Status] CHECK  (([Status]='conflict' OR [Status]='duplicate' OR [Status]='accepted' OR [Status]='rejected' OR [Status]='validated' OR [Status]='received'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceImportAttempt_Status]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceImportAttempt]'))
ALTER TABLE [KVK].[SourceImportAttempt] CHECK CONSTRAINT [CK_SourceImportAttempt_Status]
